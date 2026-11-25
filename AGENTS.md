# AGENTS.md — mctext

## What this is
A local-first desktop text vault built with Common Lisp, McCLIM and SBCL. It stores reusable snippets in groups, shows them as clickable presentations, and copies the selected text to the system clipboard.

The app is a full McCLIM application frame with search, groups, snippets, an editable text pane, buttons, status output and an interactor pane. It also has a no-window command line mode.

## Stack
- Common Lisp (SBCL)
- McCLIM via Quicklisp
- CLX on Linux/macOS/FreeBSD, SDL2 on Windows by default
- `cl-json` for the local document store
- No network code in the app

## Structure
- `mctext.asd` — ASDF system; depends on `mcclim` and `cl-json`
- `main.lisp` — launcher; loads Quicklisp, selects backend, quickloads `mctext`, handles bundled font, calls `mctext:main`
- `src/package.lisp` — `MCTEXT` package
- `src/model.lisp` — group and snippet structs plus filter helpers
- `src/store.lisp` — JSON document store with `id`, `_rev` and `doc`
- `src/clipboard.lisp` — clipboard shims for wl-copy/xclip/xsel, pbcopy and PowerShell
- `src/gui.lisp` — application frame, panes, presentation types, commands and translators
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
- Frame name is `mctext-frame`; command table is `mctext-frame`.
- Presentation types are `mctext-group` and `mctext-snippet`.
- Left click selects; right click opens commands from `:gesture :menu` translators.
- Clipboard copy uses external OS tools; McText does not inject keystrokes into other apps.
- Store path is `~/.local/share/mctext/mctext.json` on POSIX and `%APPDATA%\McText\mctext.json` on Windows.
- `MCTEXT_BACKEND` overrides backend; `MCCLIM_BACKEND` is accepted as a fallback.

## Conventions
- Keep the README logo as its first line.
- No comments in code unless asked.
- Do not add networking or telemetry.
- Preserve the document store shape: `docs` entries contain `id`, `_rev` and `doc`.
- Apply workspace permissions after edits: `chown -R 1000:33 <project>` and `chmod -R g+w <project>`.
