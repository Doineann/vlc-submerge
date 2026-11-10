# SubMerge

A small **VLC 3** Lua extension that merges two external, language-tagged
**SRT** subtitle files into one combined subtitle track.

You pick which language is the primary text and which language is shown in
yellow above it. SubMerge merges the cues, writes a new `.srt` file next to
the video, and loads and activates it immediately.

Your original subtitle files are never modified.

---

## Features

- Scans the current video's folder (and common subtitle subfolders) for
  external SRT files.
- Merges two SRT files chronologically into a single subtitle track.
- Primary language is written first; at identical timestamps the primary cue
  comes before the secondary cue.
- Secondary language is wrapped in yellow:
  `<font color="#FFFF00">…</font>`.
- Any language can be primary — whichever language you choose first is the
  primary, the other one is yellow.
- The output file is loaded and activated in VLC automatically.
- The extension closes itself after a successful merge/load.
- Asks before overwriting an existing merged file (Overwrite / Skip).
- A `STATUS:` line reports refreshes, merges, skips, and errors.
- Only one dialog is used, as required by VLC 3.

---

## Requirements

- **VLC 3.x** (desktop version).
- A **local** video file (streams and network URLs are not supported).
- At least **two external `.srt` subtitle files** that match the video name.
- VLC must have been started at least once so its extension directory exists.

Subtitle files are matched by name:

```
<video-name>.<language>.srt
```

Examples:

```
movie.mkv
movie.en.srt
movie.de.srt
```

Language tags may be 2–3 letters and may include a region or suffix:

```
movie.en-US.srt
movie.en.forced.srt
```

SubMerge also looks in `Subs`, `Subtitles`, `Subtitle`, and `Sub` folders
(and their case variants) inside the video's folder.

---

## Installation

### Linux / macOS (script)

```bash
git clone <this-repository>
cd submerge
chmod +x install.sh
./install.sh
```

The script installs `submerge.lua` into the first existing VLC extension
directory:

- **Linux:** `$XDG_DATA_HOME/vlc/lua/extensions`
  (usually `~/.local/share/vlc/lua/extensions`), or `~/.vlc/lua/extensions`
- **macOS:** `~/Library/Application Support/org.videolan.vlc/lua/extensions`,
  or `~/.vlc/lua/extensions`

Then **restart VLC**.

### Windows (script)

Double-click `install.bat`, or run it from a command prompt:

```bat
install.bat
```

It copies `submerge.lua` to:

```
%APPDATA%\vlc\lua\extensions
```

Then **restart VLC**.

### Manual installation

Copy `submerge.lua` into the VLC extension directory for your platform:

| Platform | Directory |
| --- | --- |
| Linux | `~/.local/share/vlc/lua/extensions/` |
| macOS | `~/Library/Application Support/org.videolan.vlc/lua/extensions/` |
| Windows | `%APPDATA%\vlc\lua\extensions\` |

Restart VLC after copying.

---

## Usage

1. Open a **local video** in VLC.
2. Make sure the matching subtitle files are next to the video, for example
   `movie.en.srt` and `movie.de.srt`.
3. In VLC, open the menu **View → SubMerge**.
4. Choose the:
   - **First language:** — primary text, not coloured.
   - **Second language (yellow)** — displayed in yellow above the primary.
5. Click **Merge and load**.

SubMerge writes `<video-name>.<first>-<second>.srt` next to the video and
activates it in VLC.

For example:

- first `en`, second `de` → `movie.en-de.srt`
- first `de`, second `en` → `movie.de-en.srt`

If the merged file already exists, you are asked whether to **Overwrite** or
**Skip**. Skipping leaves the existing file untouched.

Click **Refresh** to rescan the folder after adding or removing subtitles.

The dropdowns only appear when at least two matching SRT files are found.
Otherwise the dialog shows what SubMerge expects.

---

## Merge behaviour

- Cues are sorted by start time.
- If two cues start at the same time, the primary language is written first.
- The secondary language's cue text is wrapped in a yellow font tag.
- The output is not added to the dropdowns on the next scan, so merged files
  are not offered as source languages again.
- Existing merged files are excluded for any language pair, not just a fixed
  list of languages.
- If VLC cannot activate the merged subtitle automatically, the file is still
  written and the `STATUS:` line explains what happened; the extension stays
  open so you can read it.

English is only treated specially in the dropdown order:

- first dropdown: English is listed first and selected by default;
- second dropdown: the list is reversed, so English is at the end.

That is only a preference. Selecting another language as primary is fully
supported.

### Language tag aliases

Language tags are free-form. A small alias table is used to recognise
equivalent forms when checking that the two files are different languages:

- `eng` / `en`
- `dut` / `nl`
- `ger` / `de`

---

## Uninstall

Delete `submerge.lua` from the VLC extension directory and restart VLC:

```bash
rm ~/.local/share/vlc/lua/extensions/submerge.lua
```

On Windows, delete `%APPDATA%\vlc\lua\extensions\submerge.lua`.

---

## Troubleshooting

**SubMerge is not in the View menu**

- Confirm `submerge.lua` is directly inside the `lua/extensions` folder.
- Restart VLC completely.
- Check the VLC version is 3.x.

**No subtitles are found**

- The video must be a local file.
- Subtitle files must be named `<video-name>.<language>.srt`.
- Make sure they are in the video's folder or a supported subfolder.
- Click **Refresh** after changing files.

**The merged subtitle is not visible**

- Check VLC's **Subtitle → Subtitle Track** menu and select the new track.
- Make sure subtitles are enabled.

**The extension stays open after merging**

- The file was written, but VLC could not activate it automatically. Read the
  `STATUS:` line for the reason.

---

## License

SubMerge is licensed under the **GNU General Public License, version 3 or
later** (`GPL-3.0-or-later`).

The full license text is included in [LICENSE](LICENSE). The same terms are
declared in the header of `submerge.lua`.
