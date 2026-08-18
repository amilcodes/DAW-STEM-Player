# Contributing

## Before opening a change

- Build on an Apple silicon Mac running macOS 14 or newer.
- Keep file decoding, separation, storage, and waveform work off the real-time audio path.
- Keep performance controls available from the keyboard.
- Do not add samples, models, or artwork without clear redistribution rights.
- Match the existing four-color control map and labeled hardware-style interface.

## Check your work

```sh
make app
make test
```

For interface changes, check all three workspaces at the minimum window size:

- Mix with one stem and four stems
- Pads with trackpad mode on and off
- Pattern with one and several bars

Also verify the empty state, file drop state, session menu, keyboard reference, and settings.

Regenerate and inspect the product images before committing an interface change:

```sh
make previews
```

## Commit messages

Use a short command-style subject that describes one change:

```text
Add synchronized stem playback graph
Map simultaneous trackpad touches to pads
Document the project package format
```

Keep generated folders and local `.stemproject` sessions out of commits.
