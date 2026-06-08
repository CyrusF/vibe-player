# Vibe Player

Vibe Player is a macOS 14+ menu bar utility for local, camera-based focus detection while watching video on a secondary display.

The MVP runs fully on-device:

- AVFoundation captures low-resolution camera frames.
- Apple Vision extracts face and eye geometry.
- A personal calibration classifies whether the user is looking at the selected playback screen.
- Apple Events control the selected Chrome/Safari video tab without a browser extension.
- A system Play/Pause media key fallback is available but disabled by default.

## Build and Run

```sh
./script/build_and_run.sh --verify
```

The script builds the SwiftPM executable, stages `dist/VibePlayer.app`, and launches it as a real macOS app bundle so camera and automation usage strings are present.

## Star history

[![Star History Chart](https://api.star-history.com/svg?repos=CyrusF/vibe-player&type=timeline&legend=top-left)](https://www.star-history.com/#CyrusF/vibe-player&type=timeline&legend=top-left)
