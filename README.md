# Cable82 for macOS — Block Programming v3.2.0

Eric Wittliff's customized Cable82 macOS 27 source, preserved from the known-good M1 baseline.

Includes normal programming blocks, Segment Blocks with multiple folders, three-line guide titles, a native SwiftUI server window, channel-folder selection, and bulk uploads.

## Build and run

1. Install Xcode with the macOS 27 SDK and Node.js 18 or newer for your Mac.
2. Open `Cable82-macOS27.xcodeproj` and select the `Cable82` scheme and My Mac destination.
3. Build and run. If signing is required, select your own development team.
4. Click Open Cable82, or visit `http://localhost:1982`. Configuration is at `/config`.

The app looks for Node at `/opt/homebrew/bin/node`, `/usr/local/bin/node`, or `/usr/bin/node`; the archive does not bundle a Node runtime. It stores configuration and media in `~/Movies/Cable82`, with an option to select another channels folder.

To run the server directly:

```sh
node Cable82-macOS27/Main.js
```

The server listens on the local network. Its control and upload endpoints are intended for a trusted LAN; do not expose them directly to the internet.

## Source provenance

Source archive: `Cable82-macOS27-Block-Programming-v3.2.0.zip`

SHA-256: `1c4520aa1d3a0a633038ebb613eaacf3279e8e8702165cf371fe9a2d07351578`

The application source and Xcode project are preserved byte-for-byte from that archive. This baseline retains the archive's original Xcode version settings, including `MARKETING_VERSION = 1.0`; v3.2.0 identifies the source archive. No files from the later macOS 14 Universal v3.2.1 build are included.

User videos, music, personal configuration, credentials, Xcode user settings, build products, and unused reference photos and screenshots from the archive's `images/` folder are excluded. Required interface icons and the licensed font remain included.

## Credits and licensing

Based on [Cable 82 by Hans Scharler](https://github.com/nothans/cable-82), distributed under the MIT license in `LICENSE`. The bundled IBM VGA font is by VileR and remains under CC BY-SA 4.0; see `Cable82-macOS27/fonts/LICENSE.txt`.
