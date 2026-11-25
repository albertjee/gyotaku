# Gyotaku Runbook (v3)

Operator reference for running Gyotaku from a console or from source. Covers what is on `main`.
Changes since v1: the `launch.ps1` script, `ORT_DYLIB_PATH`, and batch naming (now on `main`).
Changes since v2: **Select all** and **Select none** in the Rename images window.

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
| `gyotaku name <PATHS>...` | Recommend and batch-rename screenshots from their OCR headings. Dry run unless `--apply` | See section 8 |
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
`launch.ps1` (below) does this for the copy under `target\`.

### Launching from source with launch.ps1

`launch.ps1` is at the repository root. It builds `gyotaku-app` and starts it, so a
source checkout runs in one command.

```powershell
.\launch.ps1                  # build (debug), then start
.\launch.ps1 -Window          # ordinary window, the mode used for testing
.\launch.ps1 -Window -Once    # ordinary window, exits when it closes
.\launch.ps1 -Background      # resident with no window, summon with Alt+Shift+S
.\launch.ps1 -Release         # build and run the release profile
.\launch.ps1 -NoBuild         # start what is already in target\
```

| Parameter | Effect |
|---|---|
| `-Once` | Passes `--once`: no resident process, exits when the window closes |
| `-Window` | Passes `--window`: ordinary window instead of the floating launcher panel |
| `-Background` | Passes `--background`: start resident with no window |
| `-Release` | Builds and runs `target\release` instead of `target\debug` |
| `-NoBuild` | Skips `cargo build` and runs the existing exe. Fails if the exe is missing |

All parameters are switches and can be combined. With no parameters the script builds
the debug profile and starts the app with no flags.

What the script does, in order:

1. Stops any `gyotaku-app` process whose path is under this repository's `target\`
   folder, because a running copy locks the exe and fails the build. An installed
   copy elsewhere is not touched.
2. Runs `cargo build -p gyotaku-app` (adds `--release` with `-Release`) and stops
   on a build failure.
3. If `ORT_DYLIB_PATH` is not set and there is no `onnxruntime.dll` beside the exe,
   sets `ORT_DYLIB_PATH` to `%LOCALAPPDATA%\Programs\gyotaku\onnxruntime.dll` when
   that file exists. A source build otherwise tries to download the library on first
   use, and that download can fail (HTTP 404 or a blocked network), which leaves OCR
   and the rename proposals unable to run.
4. Starts the exe detached, so the terminal is free afterwards.

Because `-Once` is not the default, a plain `.\launch.ps1` leaves a resident
instance running. The next run stops it before building.

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
| `ORT_DYLIB_PATH` | Full path of the ONNX Runtime library to load. Takes precedence over the library beside the exe and over the download. `launch.ps1` sets it for the app it starts when needed |

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
- Rename proposals stay on "Proposed filename" with a "downloading..." status: the
  ONNX Runtime library could not be loaded or downloaded, so OCR never ran. Check
  `watch.log` in the data folder for a download error. Start the app with
  `launch.ps1`, or set `ORT_DYLIB_PATH` to an existing `onnxruntime.dll`.
- More cases: `docs/troubleshooting.md`. Full usage: `docs/usage.md`.

## 8. Batch naming

Recommends names for screenshots from the headings OCR finds in them, and renames
files in place. No copies are made. Design: `docs/batch-naming-spec.md`.

### Command line

`gyotaku name [OPTIONS] <PATHS>...` takes files or folders (folders are processed
recursively). It reports proposed renames and changes nothing unless `--apply` is given.

| Option | Effect |
|---|---|
| `--dry-run` | Report proposed renames without touching files (the default) |
| `--apply` | Rename on disk |
| `-y, --yes` | Skip the confirmation prompt when applying |
| `--limit <N>` | Process at most N images per run |
| `--sort <newest\|oldest\|name>` | Order before `--limit` (default `newest`) |
| `--format <table\|csv\|json\|script>` | Report format (default `table`) |
| `--case <snake\|kebab\|title\|camel>` | Filename casing (default `snake`) |
| `--max-length <N>` | Maximum slug length, cut at word boundaries (default 50) |
| `--prefix-date` | Prefix the file's modified date, for example `2026-11-23_name.png` |
| `--fallback <skip\|keep\|error>` | What to do when no confident title is found (default `skip`) |
| `--threads <N>` | Cores per image for uncached OCR (default 4) |
| `--config <PATH>` | Path to a custom `config.json` |

```powershell
gyotaku name C:\Users\me\Pictures\Screenshots --limit 20          # dry run
gyotaku name C:\Users\me\Pictures\Screenshots --apply -y          # rename
```

### Rename images window

Open the app and choose **name images** in the search window. The window offers:

- **Specific images** or **Folder** as the source, with **Choose images** or
  **Choose folder** opening the system picker, and **Include subfolders** for a folder.
- A name preview with the original name and path, the proposed name, and a status such
  as Ready, Already named or Needs name. The original column scrolls sideways for long
  names and paths. Click a proposed name (or press Enter on the row) to edit it.
- Space selects or clears a row. Existing names are blocked. **Rename N images**
  renames the selected files in place.
- Every row that has a proposed name starts selected, so a large folder starts with
  thousands selected. **Select none** (beside the "N shown, N selected" count) clears
  them all, so only the rows ticked afterwards are renamed. **Select all** ticks every
  row that has a proposed name again. Both leave rows that are already renamed or
  blocked alone, and do nothing while a rename is running. They are mouse controls
  and are not in the Tab order. Check the count on the **Rename N images** button
  before pressing it.

Proposals need OCR to run. See the `ORT_DYLIB_PATH` entry in section 6 if every row
stays on "downloading...".
