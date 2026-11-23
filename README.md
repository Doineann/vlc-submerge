# SubMerge

A **VLC 3** Lua extension that merges two external `.srt` subtitle files into one dual-language track. The primary language appears at the bottom in standard text, and the secondary language appears above it in yellow. The merged subtitle will be loaded and activated automatically.

## Usage

The plugin expects the filename of the subtitles to be the same as the video, for example:

`<videoname>.<any-video-extension>`
`<videoname>.<first-language>.srt`
`<videoname>.<second-language>.srt`

Then:

1. Open a local video in VLC.
2. Go to **View → SubMerge**.
3. Select your **First language** (primary) and **Second language** (yellow).
4. Click **Merge and load**.

SubMerge saves `<video-name>.<first-language>-<second-language>.srt` next to your video, activates it automatically, and closes the dialog. 

- **Existing files:** Prompts you to **Overwrite** or **Skip** if the merged file already exists.
- **Rescanning:** Click **Refresh** if you add or rename subtitle files while VLC is open.

SubMerge scans the video's folder as well as `Subs`, `Subtitles`, `Subtitle`, and `Sub` subfolders. (NOTE: not extensively tested)

## Requirements

- **VLC 3.x** (desktop, opened at least once)
- A **local** video file called `<video-name>.<video-extension>`
- At least two matching `.srt` files formatted as `<video-name>.<language>.srt` (e.g., `movie.en.srt`, `movie.de.srt`, or `movie.en-US.srt`)

## Installation

### Via script

Run the included installer script for your OS, then **restart VLC**:

- **Linux / macOS:** Run `./install.sh` in your terminal.
- **Windows:** Double-click `install.bat`.

### Manual

Copy `submerge.lua` to your VLC extensions folder, then **restart VLC**:

| OS | Extension Directory |
| :--- | :--- |
| **Linux** | `~/.local/share/vlc/lua/extensions/` |
| **macOS** | `~/Library/Application Support/org.videolan.vlc/lua/extensions/` |
| **Windows** | `%APPDATA%\vlc\lua\extensions\` |

## Uninstall

### Via script

Run the included installer script for your OS, then **restart VLC**:

- **Linux / macOS:** Run `./uninstall.sh` in your terminal.
- **Windows:** Double-click `uninstall.bat`.

### Manual

Delete `submerge.lua` from your VLC extensions directory (see above) and restart VLC.

## Troubleshooting

- **SubMerge isn't in the View menu:** Ensure `submerge.lua` is directly inside the `lua/extensions/` folder and completely restart VLC.
- **No subtitles found:** Verify the video is local, filenames match `<video-name>.<lang>.srt`, and click **Refresh**.
- **Subtitles aren't showing:** Enable subtitles in VLC and select the new track under **Subtitle → Subtitle Track**.
- **Dialog stays open after merging:** The file was created, but VLC couldn't auto-load it. Check the `STATUS:` line in the dialog for details.

## License

Licensed under **GPL-3.0-or-later**. See [LICENSE](LICENSE) for details.
