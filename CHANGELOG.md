# Changelog

## 2.5.0

- Replaced the mixed display typography with Helvetica Neue for controls and SF Mono only for measured values.
- Reduced the interface to warm neutrals, black working surfaces, one vermilion action color, and a muted green run state.
- Removed decorative shadows, colored channel identities, duplicate workspace headers, and nonessential status labels.
- Moved separation and sequencer bank actions into the existing hardware key rows.
- Rebuilt waveforms, pads, meters, faders, knobs, and steps with thinner lines and flatter construction.
- Regenerated all product screenshots from the finished 320 × 520-point instrument.

## 2.4.0

- Rebuilt the instrument as a narrow 320 × 520 floating device instead of a desktop-width rectangle.
- Replaced the four-column mixer with four dense horizontal signal rows.
- Stacked the 4 × 3 pad field above one compact voice and multitouch control deck.
- Repacked all sixteen sequencer steps into a narrow matrix without paging or hiding voices.
- Split transport and file actions into two short physical key rows.
- Added a horizontal hardware fader designed for the vertical mixer layout.
- Rebuilt the keyboard reference and product screenshots for the new aspect ratio.

## 2.3.0

- Reduced the default instrument from 1160 × 620 to 680 × 360 points, with a 640 × 340 minimum.
- Combined session, waveform, mode, and playback state into one 42-point hardware control band.
- Replaced the large transport footer with a 28-point row of direct utility keys.
- Repacked the mixer into four contiguous channel strips with short faders and compact rotary controls.
- Fit the full 4 × 3 drum field beside sample, choke, recording, and raw multitouch controls.
- Kept all sixteen sequencer steps and four voices visible inside the smaller chassis.
- Reduced labels to operational terms and moved guidance into tooltips and the keyboard map.
- Shrunk the keyboard overlay and regenerated every product image at the actual default window size.

## 2.2.0

- Replaced the app-style sidebar, inspector, and tab bar with one compact 1160 × 620 instrument faceplate.
- Added a three-position Stem, Drum, and Sequence mode switch with Command-1, Command-2, and Command-3 shortcuts.
- Moved level, pan, tone, mute, solo, reset, sample, choke, and performance controls onto their working surfaces.
- Split the sequencer into three four-voice banks so all sixteen steps remain large enough to play.
- Added per-step velocity choices and a live sequencer playhead.
- Retrigger pads when a trackpad contact crosses into a new cell.
- Added a deterministic offscreen renderer for the README product screenshots.

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
