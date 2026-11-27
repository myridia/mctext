<img src="mctext.svg" alt="McText logo" width="120">

# McText

McText is a local-first desktop text vault built with Common Lisp and McCLIM. It stores reusable text — email replies, shell commands, code snippets, AI prompts and notes — then copies the selected text to the system clipboard so you can paste it into any other desktop app.

The GUI uses McCLIM presentations: each group and snippet on screen is the real object, so clicking and right-clicking act directly on it.

## Run from source

```sh
sbcl --script main.lisp
```

Or use the task runner:

```sh
./ask.sh
```

## Setup

Run task 1 in `./ask.sh` on Linux or FreeBSD, task 8 on macOS, or task 7 on Windows. Each installs SBCL and Quicklisp and registers this repo as a local project; the Windows task also downloads `SDL2.dll`, and the macOS task installs SDL2. macOS uses the SDL2 backend by default, so no X server is needed.

## Interactive development

Run task 6 in `./ask.sh` to start a REPL with the GUI already open. A source watcher reloads `src/*.lisp` and `mctext.asd` automatically when a file changes. The McCLIM frames use `:reinitialize-frames t`, so a reload of `src/gui.lisp` rebuilds panes and layouts in the open window.

```lisp
(clim-user:dev-reload)
(clim-user:dev-force-reload)
(clim-user:dev-watch-stop)
(clim-user:dev-watch-start)
(clim-user:dev-start)
```

`dev-reload` lets ASDF recompile changed files. `dev-force-reload` recompiles every mctext file. `dev-watch-stop` disables automatic reload; `dev-watch-start` enables it again. `dev-start` reopens the GUI if you close the window and restarts watching if needed. If you edit `main.lisp` or `dev.lisp`, reload the dev script with `(load "dev.lisp")`.

## Command line

```sh
./dist/mctext/mctext --list
./dist/mctext/mctext --copy "Email reply"
./dist/mctext/mctext --help
```

`-nw`, `--nw` and `--no-window` also select no-window mode. Passing `--list`, `--copy` or `--help` switches to no-window mode automatically.

## GUI layout

```text
File  Edit  Settings  Help

[New group] [New Snippets] [Rename] [Save] [Copy] [Delete] [Clipboard log] [Quit]

Groups               Snippets
Work                 Email reply
Home                 Common shell commands
Code                 Code review prompt

Selected text:
[ editable text area                                  ↕ ]

Status: Copied "Email reply" to clipboard.
```

- Use the top menu bar for **File**, **Edit**, **Settings** and **Help** commands.
- Click a group to show its snippets.
- Click a snippet to load its text.
- Press **Copy** to copy the full text to the clipboard.
- Right-click a snippet for **Copy to clipboard** or **Delete**.
- Right-click a group to create a new snippet in it.
- Press **Clipboard log** to open the session log.

## Theme

McText starts with Anathema's Doom One dark theme, installed from Quicklisp. Use **Settings → Dark**, **Light** or **High contrast** to switch themes while the app is open.

## Clipboard

- Linux: `wl-copy`, `xclip` or `xsel`
- macOS: `pbcopy`
- Windows: PowerShell `Set-Clipboard`

McText does not inject text into other apps. It writes to the system clipboard; you paste with the normal paste command of the target app.

## Clipboard log

While the GUI is open, McText polls the desktop clipboard and keeps a session-only list of distinct texts. The **Clipboard log** window shows each entry with its time, source and a preview. Click an entry to save the full text as a snippet in the **Clipboard** group; nothing is written to the JSON store until you click. **Clear** empties the session list; **Close** returns to the main window.

Linux reads `wl-paste` plus X11 CLIPBOARD and PRIMARY through `xclip`/`xsel`; macOS reads `pbpaste`; Windows reads PowerShell `Get-Clipboard`. Wayland needs a compositor/portal helper for reliable background watching. McText's own copies are skipped.

## Storage

The default store is:

```text
Linux/macOS: $XDG_DATA_HOME/mctext/mctext.json or ~/.local/share/mctext/mctext.json
Windows:     %APPDATA%\McText\mctext.json
```

Documents are stored as:

```json
{
  "version": 1,
  "docs": [
    {
      "id": "group-general",
      "_rev": "1-4f3z",
      "doc": {"type": "group", "name": "General", "sort": 0}
    }
  ]
}
```

Each save increments the CouchDB-style `_rev`.

## Backend

Windows defaults to the McCLIM SDL2 backend and needs `SDL2.dll` beside the executable or on `PATH`. Other platforms use CLX and need a display.

Override the backend with:

```sh
MCTEXT_BACKEND=clx sbcl --script main.lisp
MCTEXT_BACKEND=sdl2 sbcl --script main.lisp
```

`MCCLIM_BACKEND` is also accepted for compatibility with the McCLIM setup scripts.

## Task runner

| Task | Description |
| --- | --- |
| 1 | Setup: check/install SBCL, Quicklisp, McCLIM and register the local project |
| 2 | Build: save a single SBCL executable in `bin/` and copy it to `dist/mctext/` |
| 3 | Run: `sbcl --script main.lisp` |
| 4 | macOS DMG (macOS only) |
| 5 | Clean `bin/`, `dist/` and `.app` bundles |
| 0 | Exit |

## Build output

Task 2 embeds `DejaVuSans.ttf` in the SBCL image and writes it to `~/.cache/mctext/` at startup. The saved executable needs no SBCL, Quicklisp or font files on the target machine.

## License

GPL-3.0-or-later. See `LICENSE`.
