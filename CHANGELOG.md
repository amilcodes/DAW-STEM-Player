# Changelog

## 2.1.0

- Replaced the Processing prototype with a native SwiftUI and AVAudioEngine application.
- Added synchronized stem playback, level, pan, tone, mute, solo, metering, seeking, and loops.
- Added local four-stem separation through a Rust/Core ML helper.
- Added a 4 × 3 multitouch trackpad drum surface with keyboard controls.
- Added twelve generated drum sounds, custom samples, choke groups, and velocity.
- Added a 16-step pattern editor with recording, tempo, bars, and swing.
- Added portable `.stemproject` packages and 32-bit float WAV export.
- Rebuilt the interface as a labeled hardware-style instrument.
- Added a deterministic app icon builder and local app-bundle packaging.

## Original prototype

The first version was a Processing/Minim experiment with separate Java classes for two-, three-, and four-stem songs. It is kept in `Legacy/Processing` for reference.
