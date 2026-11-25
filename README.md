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

## Command line

```sh
./dist/mctext/mctext --list
./dist/mctext/mctext --copy "Email reply"
./dist/mctext/mctext --help
```

`-nw`, `--nw` and `--no-window` also select no-window mode. Passing `--list`, `--copy` or `--help` switches to no-window mode automatically.

## GUI layout

```text
[ Search snippets...                                  ]

Groups               Snippets
Work                 Email reply
Home                 Common shell commands
Code                 Code review prompt

Selected text:
[ editable text area ]

[New group] [New text] [Rename] [Save] [Copy] [Delete] [Quit]
Status: Copied "Email reply" to clipboard.
```

- Click a group to show its snippets.
- Click a snippet to load its text.
- Press **Copy** to copy the full text to the clipboard.
- Right-click a snippet for **Copy to clipboard** or **Delete**.
- Right-click a group to create a new snippet in it.

## Clipboard

- Linux: `wl-copy`, `xclip` or `xsel`
- macOS: `pbcopy`
- Windows: PowerShell `Set-Clipboard`

McText does not inject text into other apps. It writes to the system clipboard; you paste with the normal paste command of the target app.

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
