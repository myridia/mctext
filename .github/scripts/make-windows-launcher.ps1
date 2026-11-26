param(
  [Parameter(Mandatory = $true)][string]$Core,
  [Parameter(Mandatory = $true)][string]$Dll,
  [Parameter(Mandatory = $true)][string]$Output
)

$ErrorActionPreference = 'Stop'

$corePath = (Resolve-Path -LiteralPath $Core).Path
$dllPath = (Resolve-Path -LiteralPath $Dll).Path
$outputPath = [IO.Path]::GetFullPath($Output)

$temp = Join-Path $env:RUNNER_TEMP 'mctext-launcher'
Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
$stage = Join-Path $temp 'payload'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
Copy-Item -LiteralPath $corePath -Destination (Join-Path $stage 'mctext_windows_raw.exe')
Copy-Item -LiteralPath $dllPath -Destination (Join-Path $stage 'SDL2.dll')
$package = Join-Path $temp 'payload.zip'
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $package -Force

$source = Join-Path $temp 'Launcher.cs'
$csharp = @'
using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Windows.Forms;

internal static class MctextLauncher
{
    private const string Magic = "MCTEXTPK";

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool AttachConsole(int processId);

    [STAThread]
    private static int Main(string[] args)
    {
        AttachConsole(-1);
        try
        {
            string directory = ExtractPayload();
            string core = Path.Combine(directory, "mctext_windows_raw.exe");
            if (!File.Exists(core))
            {
                throw new FileNotFoundException(core);
            }
            ProcessStartInfo start = new ProcessStartInfo(core, BuildArguments(args));
            start.UseShellExecute = false;
            start.CreateNoWindow = false;
            using (Process process = Process.Start(start))
            {
                if (process == null)
                {
                    throw new InvalidOperationException("Failed to start McText.");
                }
                process.WaitForExit();
                return process.ExitCode;
            }
        }
        catch (Exception error)
        {
            MessageBox.Show(error.Message, "McText launcher", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    private static string ExtractPayload()
    {
        string launcher = Assembly.GetExecutingAssembly().Location;
        long fileLength = new FileInfo(launcher).Length;
        if (fileLength < 16)
        {
            throw new InvalidDataException("Launcher is too short.");
        }
        byte[] footer = new byte[16];
        using (FileStream stream = new FileStream(launcher, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
        {
            stream.Seek(fileLength - footer.Length, SeekOrigin.Begin);
            stream.Read(footer, 0, footer.Length);
        }
        if (Encoding.ASCII.GetString(footer, 0, 8) != Magic)
        {
            throw new InvalidDataException("Launcher payload marker is missing.");
        }
        long packageLength = BitConverter.ToInt64(footer, 8);
        long packageStart = fileLength - footer.Length - packageLength;
        if (packageLength <= 0 || packageStart < 0)
        {
            throw new InvalidDataException("Launcher payload length is invalid.");
        }
        byte[] package = new byte[packageLength];
        using (FileStream stream = new FileStream(launcher, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
        {
            stream.Seek(packageStart, SeekOrigin.Begin);
            int offset = 0;
            while (offset < package.Length)
            {
                int read = stream.Read(package, offset, package.Length - offset);
                if (read == 0)
                {
                    throw new EndOfStreamException("Launcher payload is truncated.");
                }
                offset += read;
            }
        }
        string id;
        using (SHA256 sha = SHA256.Create())
        {
            id = BitConverter.ToString(sha.ComputeHash(package)).Replace("-", "").ToLowerInvariant();
        }
        string directory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "McText", "Windows", id);
        Directory.CreateDirectory(directory);
        using (MemoryStream memory = new MemoryStream(package))
        using (ZipArchive archive = new ZipArchive(memory, ZipArchiveMode.Read))
        {
            foreach (ZipArchiveEntry entry in archive.Entries)
            {
                if (entry.FullName.EndsWith("/"))
                {
                    continue;
                }
                string name = Path.GetFileName(entry.FullName);
                if (name != "mctext_windows_raw.exe" && name != "SDL2.dll")
                {
                    continue;
                }
                string target = Path.Combine(directory, name);
                if (File.Exists(target) && new FileInfo(target).Length == entry.Length)
                {
                    continue;
                }
                using (Stream input = entry.Open())
                using (FileStream outputFile = new FileStream(target, FileMode.Create, FileAccess.Write))
                {
                    input.CopyTo(outputFile);
                }
            }
        }
        return directory;
    }

    private static string BuildArguments(string[] args)
    {
        StringBuilder result = new StringBuilder();
        for (int index = 0; index < args.Length; index++)
        {
            if (index > 0)
            {
                result.Append(' ');
            }
            result.Append(Quote(args[index]));
        }
        return result.ToString();
    }

    private static string Quote(string value)
    {
        if (value.Length == 0)
        {
            return "\"\"";
        }
        if (value.IndexOfAny(new char[] { ' ', '\t', '"' }) < 0)
        {
            return value;
        }
        StringBuilder result = new StringBuilder("\"");
        int backslashes = 0;
        foreach (char character in value)
        {
            if (character == '\\')
            {
                backslashes++;
                continue;
            }
            if (character == '"')
            {
                result.Append('\\', backslashes * 2 + 1);
                result.Append('"');
                backslashes = 0;
                continue;
            }
            result.Append('\\', backslashes);
            result.Append(character);
            backslashes = 0;
        }
        result.Append('\\', backslashes * 2);
        result.Append('"');
        return result.ToString();
    }
}
'@
Set-Content -LiteralPath $source -Value $csharp -Encoding UTF8

Add-Type -Path $source -OutputAssembly $outputPath -OutputType WindowsApplication -ReferencedAssemblies @(
  'System.dll',
  'System.Core.dll',
  'System.IO.Compression.dll',
  'System.Windows.Forms.dll'
) | Out-Null

$payloadBytes = [IO.File]::ReadAllBytes($package)
$launcherBytes = [IO.File]::ReadAllBytes($outputPath)
$footer = New-Object byte[] 16
[Text.Encoding]::ASCII.GetBytes('MCTEXTPK').CopyTo($footer, 0)
[BitConverter]::GetBytes([long]$payloadBytes.Length).CopyTo($footer, 8)
$stream = [IO.File]::Open($outputPath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
  $stream.Write($launcherBytes, 0, $launcherBytes.Length)
  $stream.Write($payloadBytes, 0, $payloadBytes.Length)
  $stream.Write($footer, 0, $footer.Length)
} finally {
  $stream.Dispose()
}
Write-Host "ok    $outputPath"
