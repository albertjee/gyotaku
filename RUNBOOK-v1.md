# Gyotaku Runbook (v1)

Operator reference for running Gyotaku from a console. Covers what is on `main`.
Features that exist only on unmerged branches are listed at the end.

Gyotaku searches every screenshot by the text inside it. It OCRs images, stores the
text in a local index, and searches that index. Nothing leaves the machine.

## 1. Components

| Program | What it is |
|---|---|
| `gyotaku` | Command-line tool: index, search, watch, inspect |
| `gyotaku-app` | Window app: search window, settings, tray. Stays resident and opens on a shortcut key |

Both read the same `config.toml` and the same index.

## 2. Quick checks

```powershell
gyotaku --version
gyotaku stats          # prints where the index lives and how much is in it
```

`gyotaku stats` is the authoritative answer to "where is my data". Use it rather than
guessing paths.

## 3. CLI commands

Global options: `-h, --help`, `-V, --version`. Every subcommand also accepts `--help`.

| Command | Purpose | Options |
|---|---|---|
| `gyotaku search <QUERY>...` | Screenshots containing every word of the query | `-n, --limit <N>` (default 20) |
| `gyotaku index [DIRS]...` | Index the folders, then exit. No folders means the ones in your config | `--threads <N>` (default from config) |
| `gyotaku watch [DIRS]...` | Index everything, then keep watching for new screenshots at idle priority. No folders means follow the config as it changes | `--threads <N>` |
| `gyotaku stats` | Index location and size | none |
| `gyotaku ocr <IMAGE>` | Print the text of one image. Does not index it | `--boxes`, `--threads <N>` (default 4), `--script <NAME>` |

Details:

- `search` prints the path of each hit, then the matching lines indented under it.
  A path marked `(near match)` is a fuzzy hit.
- `ocr --boxes` also prints each line's box as `x y w h` (fractions of the image) and a score.
- `ocr --script devanagari` reads an extra script. Default scripts come from config.
  Default reader covers Latin, Chinese, Japanese and Greek.
- A hidden `clipboard-incoming <dir>` command exists. The clipboard watcher calls it.
  Do not run it by hand.

Typical sequences:

```powershell
gyotaku index C:\Users\me\Pictures\Screenshots      # one-off build of the index
gyotaku search invoice 4471                         # both words must appear
gyotaku search -n 50 "network diagram"
gyotaku ocr .\shot.png --boxes                      # debug a single image
gyotaku watch                                       # keep the index current
```

## 4. Window app

`gyotaku-app` takes these flags (hand-parsed, there is no `--help`):

| Flag | Effect |
|---|---|
| `--window` | Open an ordinary window and skip the launcher. For testing |
| `--once` | Exit when the window closes instead of staying resident |
| `--background` | Start resident with no window. This is how it starts at Windows sign-in |

- Without `--once`, launching it a second time wakes the running instance and exits.
- Quit the resident instance with Ctrl+Q.
- The shortcut key that opens it also closes the window. The window restores its
  last query, selection and open screenshot.

Windows note: a running `gyotaku-app.exe` locks its own file. Close it before
rebuilding or replacing the binary, or the build fails with "Access is denied".

## 5. Configuration

| Item | Location / value |
|---|---|
| Config file | `%APPDATA%\gyotaku\config\config.toml` |
| Index and data | Run `gyotaku stats` to see the exact path |
| Edit via | App Settings, or edit `config.toml` directly |

The background indexer applies changes to the folder list, to saving copied images
and to the scripts it reads without a restart. Changing the shortcut key needs the
app quit (Ctrl+Q) and reopened.

Keys written to `config.toml` are only the ones you changed, for example:

```toml
[keys]
trash = "ctrl-backspace"
```

Settings stored there include `dynamic_window_size`, `paused` and `clipboard_folder`.

## 6. Environment variables

| Variable | Effect |
|---|---|
| `RUST_LOG=warn` | Show window and GPU problems on the console. First thing to try when the app misbehaves |
| `GYOTAKU_THEME=light` or `dark` | Override the theme setting and the system appearance |
| `GYOTAKU_FRAME_STATS` | Any value turns on frame statistics |

PowerShell:

```powershell
$env:RUST_LOG = "warn"; gyotaku-app --once
```

The release build has no console window. Run it from a terminal with `RUST_LOG=warn`
and `--once` to see output.

## 7. Troubleshooting pointers

- Shortcut key does nothing: another program has claimed it. Open Gyotaku from the
  Start menu, or choose a different key in `config.toml`, then quit (Ctrl+Q) and reopen.
- Nothing found: run `gyotaku stats` to confirm the index has entries, and confirm the
  folder is in your config.
- Reading is paused: the **Pause reading** setting (also in the tray menu) stops OCR
  until turned off. Already-read screenshots stay searchable.
- More cases: `docs/troubleshooting.md`. Full usage: `docs/usage.md`.

## 8. Not on `main` yet

These exist only on feature branches and are not in a build from `main`:

- `gyotaku name <PATHS>...`: recommend and batch-rename screenshots from their OCR
  headings. Dry run by default; `--apply` renames in place and needs confirmation or `-y`.
- The "Rename images" review window in the app.

Branches: `feat/cli-batch-naming`, `feat/gui-batch-rename`. Design:
`docs/batch-naming-spec.md` (on those branches). Update this runbook when they merge.
