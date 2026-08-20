# Architecture

Stem Player is one Swift application plus one Rust helper process.

## Runtime components

```text
SwiftUI views
    |
    v
AppState ---------------- ProjectStore
    |                           |
    |                           `-- .stemproject package
    |
    +-- AudioEngineController -- AVAudioEngine
    +-- SystemAudioTempoSync -- ScreenCaptureKit
    |       `-- TempoEstimator -- onset / period / phase tracker
    +-- MixExporter ----------- offline WAV render
    +-- KeyboardMonitor ------- NSEvent
    +-- TrackpadTouchView ----- NSTouch
    `-- SeparationService ----- stem-worker process
                                      |
                                      `-- Core ML separation model
```

`AppState` owns the current project and translates UI or keyboard actions into audio, storage, and separation calls. Views do not open files or mutate the audio graph directly.

## Audio graph

Each stem has its own player, tone filter, and mixer path. All stem player nodes are scheduled from the same engine time so they remain sample-aligned.

```text
stem file
  -> AVAudioPlayerNode
  -> tone filter
  -> per-stem mixer: level and pan
  -> main mixer
  -> output
```

Drum pads use a pool of player nodes connected to the main mixer. Choke groups stop related voices, such as the open and closed hi-hat, before the new voice starts.

Meter taps read short buffers from mixer nodes and publish peak and RMS values for the UI. File decoding, waveform analysis, separation, and export do not run on the real-time callback.

## Playback and looping

The controller tracks a project timeline instead of relying on independent node positions. Seeking stops and reschedules every stem at the same frame. Loop playback schedules the same project range for all stems and restarts from the loop start when the playhead reaches the loop end.

## Pattern timing

Patterns store beats rather than seconds. The app converts the current audio time to beats using project BPM, applies swing to alternating sixteenth notes, and triggers events when the playhead crosses their scheduled beat.

## External beat clock

`SystemAudioTempoSync` captures only system audio through ScreenCaptureKit and excludes the current process. It folds captured PCM to mono and passes samples to `TempoEstimator`. No captured audio is stored.

The estimator reduces audio to a 100 Hz onset-strength envelope, correlates candidate periods from 55–200 BPM, resolves half- and double-tempo candidates, smooths stable locks, and finds the strongest phase within the selected period. ScreenCaptureKit presentation timestamps place that phase on the macOS host clock. `AudioEngineController` can therefore schedule a pad node at the next sixteenth-note boundary with `AVAudioTime`, instead of firing after a UI timer.

An estimate must clear a confidence threshold before it controls the pads. The clock expires when fresh rhythmic evidence disappears. Until lock, pad input remains immediate.

## Import path

1. `AudioImportService` checks whether AVFoundation can open the source.
2. Unsupported files are converted with FFmpeg when it is installed.
3. `ProjectStore` copies readable audio into the project package.
4. The app probes duration, sample rate, and channel count.
5. The audio graph is rebuilt and waveform analysis runs off the playback path.

## Separation boundary

`SeparationService` starts the bundled `stem-worker` executable and reads structured progress messages from standard output. The Rust process owns model loading and inference. A crash or cancellation in the helper does not bring down the audio UI.

## Project package

A `.stemproject` is a directory package:

```text
Song.stemproject/
├── manifest.json
├── Audio/
│   ├── drums.wav
│   └── vocals.wav
└── Samples/
    └── custom-snare.wav
```

`manifest.json` stores relative asset paths, mixer settings, pads, pattern events, loop points, duration, and sample rate. Saves are written through a temporary file and replaced atomically. The schema version is checked when a project opens.

## Build output

`Scripts/build-app.sh` compiles the Swift sources and Rust helper, renders the icon with AppKit, creates a standard app bundle, and signs it locally. Generated output stays under `.direct-build`, `Helpers/stem-worker/target`, and `dist`; all three are ignored by Git.

`Scripts/render-previews.sh` uses the real SwiftUI surfaces with deterministic preview data to render the Mix, Pads, and Pattern images in `docs/images`. Native menus and the audio graph are disabled only inside that offscreen renderer.
