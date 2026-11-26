# AGENTS.md — mctext

## What this is
A local-first desktop text vault built with Common Lisp, McCLIM and SBCL. It stores reusable snippets in groups, shows them as clickable presentations, and copies the selected text to the system clipboard.

The app has a main McCLIM frame with groups, snippets, an editable text pane, buttons and status output, plus a second `clipboard-log-frame` window that lists text seen on the desktop clipboard during the current session. It also has a no-window command line mode.

## Stack
- Common Lisp (SBCL)
- McCLIM via Quicklisp
- CLX on Linux/macOS/FreeBSD, SDL2 on Windows by default
- `cl-json` for the local document store
- `bordeaux-threads` for the clipboard watcher
- `anathema` and `anathema-doom` from Quicklisp for the dark, light and high-contrast themes
- No network code in the app

## Structure
- `mctext.asd` — ASDF system; depends on `mcclim`, `cl-json`, `bordeaux-threads`, `anathema` and `anathema-doom`
- `main.lisp` — launcher; loads Quicklisp, selects backend, quickloads `mctext`, activates the Anathema dark theme, handles bundled font, calls `mctext:main`
- `dev.lisp` — development REPL loader with `dev-start`, `dev-reload`, `dev-force-reload`, `dev-watch-start` and `dev-watch-stop`
- `src/package.lisp` — `MCTEXT` package
- `src/model.lisp` — group and snippet structs plus filter helpers
- `src/store.lisp` — JSON document store with `id`, `_rev` and `doc`
- `src/clipboard-log.lisp` — session-only clipboard log, watcher thread and reader commands
- `src/clipboard.lisp` — clipboard shims for wl-copy/xclip/xsel, pbcopy and PowerShell
- `src/theme.lisp` — Anathema theme definitions, activation and Settings status
- `src/gui.lisp` — main frame and `clipboard-log-frame`, panes, presentation types, commands and translators
- `src/cli.lisp` — `--list`, `--copy`, `--help` and no-window dispatch
- `sdl2-runtime.lisp` — SDL2 runtime fix; loaded only for SDL2 builds
- `sdl2.sh` — pins McCLIM 1.0.0 for SDL2 builds and downloads `SDL2.dll` on Windows
- `ask.sh` — task runner menu
- `ask.d/lib.sh` — shared task helpers
- `ask.d/setup.sh` — task 1: install SBCL/Quicklisp and register this repo in `~/quicklisp/local-projects/mctext`
- `ask.d/build.sh` — task 2: embed font and save a self-contained executable
- `ask.d/run.sh` — task 3: run `sbcl --script main.lisp`
- `ask.d/dmg.sh` — task 4: build a macOS `.app` and DMG
- `ask.d/clean.sh` — task 5: remove build outputs
- `ask.d/dev.sh` — task 6: start the GUI and a development REPL with automatic reload on source changes
- `README.md` — project title, logo and commands
- `mctext.svg` — README logo
- `pages/public/` — GitHub Pages site
- `.github/workflows/` — build and release workflows

## Run
```sh
./ask.sh
```

Direct source run:

```sh
sbcl --script main.lisp
```

Built executable:

```sh
./dist/mctext/mctext
./dist/mctext/mctext --list
./dist/mctext/mctext --copy "Email reply"
```

The user builds and runs all Lisp code. Do not compile or run Lisp code in the agent environment.

## Patterns
- Frame names are `mctext-frame` and `clipboard-log-frame`; each has a command table of the same name.
- Both frames use `:reinitialize-frames t` so reloading `src/gui.lisp` rebuilds panes and layouts in running windows.
- Menu bar is `mctext-menu-bar` with File, Edit, Settings and Help menus; the log window is opened from the button row.
- Settings has Dark, Light and High contrast; startup uses Anathema's Doom One dark theme.
- Presentation types are `mctext-group`, `mctext-snippet` and `clipboard-entry`.
- Left click selects; right click opens commands from `:gesture :menu` translators; left-clicking a log entry saves it to the `Clipboard` group.
- Clipboard copy uses external OS tools; McText does not inject keystrokes into other apps.
- The watcher polls `wl-paste`, X11 CLIPBOARD/PRIMARY via `xclip`/`xsel`, `pbpaste` and PowerShell, deduplicates text, and ignores McText's own writes.
- The log exists only in memory for one GUI session; only clicked entries are written to the JSON store. Wayland needs a compositor/portal helper for reliable background watching.
- Store path is `~/.local/share/mctext/mctext.json` on POSIX and `%APPDATA%\McText\mctext.json` on Windows.
- `MCTEXT_BACKEND` overrides backend; `MCCLIM_BACKEND` is accepted as a fallback.

## Conventions
- Keep the README logo as its first line.
- No comments in code unless asked.
- Do not add networking or telemetry.
- Preserve the document store shape: `docs` entries contain `id`, `_rev` and `doc`.
- Keep the clipboard log session-only; persist an entry only when the user clicks it.
- Start with the dark theme; Settings switches themes at runtime and repaints the open frames.
- Apply workspace permissions after edits: `chown -R 1000:33 <project>` and `chmod -R g+w <project>`.
