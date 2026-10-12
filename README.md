# Hum

A native macOS menu bar controller for Sonos speakers. Hum finds the speakers on your local network and lets you change their volume, playback and grouping from the menu bar, without opening the Sonos app or reaching for your phone.

## Problem

I work at my Mac with Sonos speakers around me. Every small change, like turning the music down for a call, skipping a track or checking what's playing in another room, meant picking up my phone and opening the Sonos app. I wanted these controls one click away in the menu bar, and I wanted my keyboard's media keys to work with the speakers.

I also couldn't install Xcode: it needs tens of gigabytes my machine didn't have free. So Hum had to build with only the Swift toolchain in Apple's Command Line Tools.

## Features

- **Discovery:** finds speakers automatically with SSDP and reads room and group layout from the speakers themselves.
- **Volume:** a slider for each room, for each speaker inside a group, and for every room at once. Group changes keep the balance between speakers.
- **Now playing:** artwork, track details, play/pause, skip, and seeking within the track.
- **Source and quality:** shows where playback comes from (Spotify, AirPlay, Apple Music, TV, Line-In, Radio) and the stream format, such as 16-bit / 44.1 kHz, with a Hi-Res badge when it applies.
- **Spotify links:** click the artwork to open the track in Spotify, or copy a share link.
- **Shuffle and repeat:** available when playing from the speaker's queue. During Spotify Connect, Spotify controls these itself.
- **Lyrics:** time-synced lyrics for the current track, from [LRCLIB](https://lrclib.net).
- **System integration:** the keyboard media keys and macOS's Now Playing widget in Control Center control the active room.
- **Call handling:** music is lowered or paused automatically while any app is using a microphone, and restored afterwards.
- **Rooms:** move playback to another room, add rooms to the current one, or group and ungroup every room.
- **Sound and speaker settings:** bass, treble, loudness, crossfade, the status light and the touch-control lock, plus each speaker's model and firmware version.
- **Sleep timer:** runs on the speaker itself, so it still works if the Mac goes to sleep. While the Mac is awake, Hum also fades the music out over the final 30 seconds.
- **Global shortcuts:** `⌃⌥↑` / `⌃⌥↓` volume, `⌃⌥Space` play/pause, `⌃⌥←` / `⌃⌥→` previous/next track, `⌃⌥M` mute. Each shows an on-screen indicator.

## Requirements

- macOS 14 Sonoma or later, on Apple Silicon
- Xcode Command Line Tools (`xcode-select --install`). Xcode itself isn't needed.
- Sonos speakers on the same local network as the Mac

## Build and install

```bash
git clone https://github.com/VishaalVenkatesan/hum.git
cd hum
./scripts/build-app.sh            # builds build/Hum.app
./scripts/build-app.sh --install  # copies to /Applications and launches it
```

The script compiles the Swift package in release mode, builds the `.app` bundle, and signs it locally (ad-hoc). The first time Hum runs, macOS asks for **Local Network** access, which it needs to reach the speakers.

## How it works

Hum talks to the speakers directly over the local network. It doesn't use a cloud API, a Sonos account, a bridge server or any third-party dependencies.

| Layer | Responsibility |
|---|---|
| `SSDPDiscovery` | Sends an M-SEARCH for `urn:schemas-upnp-org:device:ZonePlayer:1` by UDP multicast and broadcast. |
| `SonosSOAP`, `SonosController` | UPnP SOAP calls to each speaker on port 1400: AVTransport, RenderingControl and ZoneGroupTopology. |
| `TopologyParser`, `DIDLParser` | Parse room and group layout and DIDL-Lite track metadata. |
| `PlaybackSource`, `AudioQuality` | Work out the playback source from transport URIs and service IDs, and the stream format from `r:streamInfo`. |
| `SpeakerStore` | Observable state: polls every 3 seconds, waits briefly before sending volume changes, and updates the UI immediately on input. |
| `NowPlayingBridge` | Publishes to `MPNowPlayingInfoCenter` and handles `MPRemoteCommandCenter` commands. |
| `CallMonitor` | Uses Core Audio to check whether any input device is running. It never accesses audio data. |
| `HotKeyCenter` | Global shortcuts via Carbon `RegisterEventHotKey`, so no Accessibility permission is needed. |

The UI is SwiftUI using `MenuBarExtra`, with Observation for state.

## Privacy

- All speaker communication stays on your local network.
- When lyrics are turned on, the current track's title and artist are sent to the public LRCLIB API.
- Call detection only checks whether a microphone is in use. It doesn't record, read or send any audio.
- Hum has no analytics or telemetry.

## Limitations

- State is polled every 3 seconds, so changes made from other controllers can take up to 3 seconds to appear.
- Builds are signed ad-hoc and not notarized. To run a build on another Mac, you may need to allow it in System Settings → Privacy & Security.
- So far it has been tested with a single speaker. Grouping and moving playback between rooms follow the UPnP spec but haven't been tested on larger setups.

## Development

Hum was built with [Claude Code](https://claude.com/claude-code) using Claude Opus 5.5. That included porting the protocol from an existing Node.js Sonos bridge, writing the Swift implementation, and testing it against real hardware.

## Disclaimer

Hum is an independent project. It is not affiliated with, endorsed by or sponsored by Sonos, Inc. Sonos is a trademark of Sonos, Inc.
