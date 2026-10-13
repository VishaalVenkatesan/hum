# Hum

A native macOS menu bar controller for Sonos speakers. Hum finds the speakers on your local network and puts volume, playback and grouping one click away in the menu bar, with no Sonos app, account or phone required.

## Features

- **Discovery:** finds speakers automatically and reads room and group layout from the speakers themselves.
- **Volume:** a slider for each room, for each speaker inside a group, and for every room at once. Group changes keep the balance between speakers.
- **Now playing:** artwork, track details, play/pause, skip, and seeking within the track.
- **Source and quality:** shows where playback comes from (Spotify, AirPlay, Apple Music, TV, Line-In, Radio) and the stream format, such as 16-bit / 44.1 kHz, with a Hi-Res badge when it applies.
- **Spotify links:** open the current track in Spotify or copy a share link.
- **Shuffle and repeat:** available when playing from the speaker's queue. During Spotify Connect, Spotify controls these itself.
- **Lyrics:** time-synced lyrics for the current track, from [LRCLIB](https://lrclib.net).
- **System integration:** the keyboard media keys and the Now Playing widget in Control Center control the active room.
- **Call handling:** music is lowered or paused automatically while any app is using a microphone, and restored afterwards.
- **Rooms:** move playback to another room, add rooms to the current one, or group and ungroup every room.
- **Sound and speaker settings:** bass, treble, loudness, crossfade, the status light and the touch-control lock, plus each speaker's model and firmware version.
- **Sleep timer:** runs on the speaker itself, so it keeps working if the Mac sleeps. While the Mac is awake, Hum also fades the music out over the final 30 seconds.
- **Global shortcuts:** control volume and playback from any app, with an on-screen indicator.

## Requirements

- macOS 14 Sonoma or later
- A Mac with Apple Silicon
- Sonos speakers on the same network as the Mac

## Installation

### Quick install

Run this in Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/VishaalVenkatesan/hum/main/scripts/install.sh | bash
```

This downloads the latest release, installs it to `/Applications` and launches it. Run the same command again to update.

### Manual download

1. Download `Hum.zip` from the [latest release](https://github.com/VishaalVenkatesan/hum/releases/latest).
2. Unzip it and move `Hum.app` to your Applications folder.
3. Hum isn't notarized by Apple yet, so macOS blocks it on first launch. Open **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to the message about Hum. Alternatively, run:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Hum.app
   ```

### Build from source

Requires the Swift toolchain, which comes with Xcode or the Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/VishaalVenkatesan/hum.git
cd hum
./scripts/build-app.sh --install
```

This builds a release version, packages `Hum.app`, copies it to `/Applications` and launches it. Use `./scripts/build-app.sh` on its own to build into `build/Hum.app` without installing.

## Getting started

1. **Launch Hum.** It runs in the menu bar only, with no Dock icon.
2. **Allow local network access.** On first launch macOS asks whether Hum can find devices on your local network. Click **Allow**; Hum can't reach your speakers without it. If you dismissed the prompt, enable Hum under **System Settings → Privacy & Security → Local Network**.
3. **Open the menu.** Click the Hum icon in the menu bar. Your rooms appear within a few seconds.

## Usage guide

### Playback

The top of the menu shows what's playing in the active room. Use the transport controls to play, pause and skip, and drag the progress bar to seek. The source and stream quality appear under the track details. Click the artwork to open the track in Spotify, or use the track menu to copy a link or the song name.

### Volume and rooms

Each room has its own volume slider. For grouped rooms, the group slider adjusts every speaker while keeping their relative levels, and each speaker inside the group also has its own slider.

From the rooms section you can:

- Move playback to another room
- Join a room to the current group, or have it leave the group
- Group or ungroup every room at once

### Sound settings

Open the sound settings from the main menu to adjust bass, treble, loudness and crossfade for each speaker, toggle the status light and touch-control lock, and see the model and firmware version. **Reset** restores a speaker's sound to its defaults.

### Lyrics

Turn on lyrics from the controls under the player. Hum shows time-synced lyrics when they're available for the current track.

### Sleep timer

Choose a duration from the sleep timer menu. The timer runs on the speaker itself, so playback stops on time even if your Mac goes to sleep. Choose **Cancel Sleep Timer** to stop it.

### Keyboard shortcuts

These work from any app:

| Shortcut | Action |
|---|---|
| `⌃⌥↑` | Volume up |
| `⌃⌥↓` | Volume down |
| `⌃⌥Space` | Play / pause |
| `⌃⌥←` | Previous track |
| `⌃⌥→` | Next track |
| `⌃⌥M` | Mute |

The keyboard's media keys and the Now Playing widget in Control Center also control the active room.

### Preferences

Click the gear icon in the menu to change:

| Setting | Description |
|---|---|
| Show Song in Menu Bar | Shows the current track next to the menu bar icon. |
| Media Keys & Control Center | Lets the media keys and Control Center control your speakers. |
| When I'm on a Call | Lower music, pause music or do nothing while a microphone is in use. |
| Open at Login | Starts Hum automatically when you log in. |
| Keyboard Shortcuts | Turns the global shortcuts on or off. |

## Troubleshooting

**No speakers are found**
- Make sure the Mac and the speakers are on the same network. Guest networks and some mesh or VPN setups block device discovery.
- Check that Hum is enabled under **System Settings → Privacy & Security → Local Network**.
- Click **Try Again** in the menu to search again.

**macOS says Hum can't be opened**
- See step 3 of [Manual download](#manual-download).

**Changes made in the Sonos app appear late**
- Hum refreshes speaker state every 3 seconds, so changes from other controllers can take a moment to show up.

## Uninstall

1. Turn off **Open at Login** in Hum's preferences, then quit Hum.
2. Delete `/Applications/Hum.app`.
3. Optionally, remove its preferences: `defaults delete com.vishaalvenkatesan.hum`

## Privacy

- All speaker communication stays on your local network. Hum doesn't use a cloud service or a Sonos account.
- When lyrics are turned on, the current track's title and artist are sent to the public LRCLIB API.
- Call detection only checks whether a microphone is in use. It never records, reads or sends any audio.
- Hum has no analytics or telemetry.

## How it works

Hum talks to the speakers directly over the local network using UPnP, with no third-party dependencies.

| Component | Responsibility |
|---|---|
| `SSDPDiscovery` | Finds speakers with an SSDP M-SEARCH for `urn:schemas-upnp-org:device:ZonePlayer:1`. |
| `SonosSOAP`, `SonosController` | UPnP SOAP calls on port 1400: AVTransport, RenderingControl and ZoneGroupTopology. |
| `TopologyParser`, `DIDLParser` | Parse room and group layout and DIDL-Lite track metadata. |
| `PlaybackSource`, `AudioQuality` | Determine the playback source and stream format. |
| `SpeakerStore` | Observable app state. Polls every 3 seconds and debounces volume changes. |
| `NowPlayingBridge` | Integrates with `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`. |
| `CallMonitor` | Uses Core Audio to detect whether any input device is running. |
| `HotKeyCenter` | Global shortcuts via Carbon `RegisterEventHotKey`, so no Accessibility permission is needed. |

The UI is built with SwiftUI's `MenuBarExtra` and the Observation framework.

## Known limitations

- Builds aren't notarized yet, so macOS asks for confirmation on first launch.
- Intel Macs aren't supported.
- Grouping and moving playback between rooms follow the UPnP spec but have had limited testing on large multi-room setups. Bug reports are welcome.

## Contributing

Issues and pull requests are welcome. Please open an issue first to discuss larger changes.

## Disclaimer

Hum is an independent project and is not affiliated with, endorsed by or sponsored by Sonos, Inc. Sonos is a trademark of Sonos, Inc.
