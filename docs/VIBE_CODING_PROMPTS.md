# Vibe-Coding Prompt Recipes (`docs/VIBE_CODING_PROMPTS.md`)

Want to build your own commercial-grade VST3 / CLAP / Standalone audio plugin in minutes using **Cursor**, **Claude Code**, **Antigravity**, or **Windsurf**?

Copy any of the prompts below and paste it directly into your AI coding agent inside this repository!

---

## Recipe 1: Analog Tube & Tape Saturator (`Velvet Warmth`)

```text
Read `llms.txt` and `llms-full.txt`.
Use `cargo run --package xtask -- new-plugin --name "Velvet Warmth" --vendor "VibeAudio" --id "com.vibeaudio.velvetwarmth"` to scaffold a new plugin crate, then customize `crates/velvet_warmth`:

1. DSP Engine (`crates/velvet_warmth/src/lib.rs`):
   - Use `dsp_core::SoftClipper::process_asymmetric_tube` for warm even-harmonic tube saturation (`drive_db`: 0..24 dB, `bias`: 0..0.4).
   - Add a `dsp_core::BiquadFilter` High-Cut tape roll-off (`tone_hz`: 1500..20000 Hz) and a Low-Shelf bass bump (`warmth_db`: 0..9 dB at 90 Hz).
   - Include `mix_pct` (0..100%), `output_db` (-18..+18 dB), and `bypass` (0..1).
   - Smooth all continuous parameters with `OnePoleSmoother`.

2. UI (`crates/velvet_warmth/ui/dist/index.html`):
   - Include all 6 hardware skins (`minimal`, `dark`, `retro`, `synth70`, `gunmetal`, `phosphor`).
   - Add rotary knobs (`id="knob-drive"`, `id="knob-bias"`, `id="knob-tone"`, `id="knob-warmth"`, `id="knob-mix"`, `id="knob-output"`) and `id="btn-bypass"`.
   - Render a live harmonic saturation glow meter driven by `window.__ON_PLUGIN_TELEMETRY__`.

3. Contract & Verification:
   - Register all 7 parameters in `declare_plugin_contract!` with accurate `DspImpact` assertions.
   - Run `powershell -ExecutionPolicy Bypass -File scripts/audit_plugin_architecture.ps1` and fix any issues until it outputs `TEMPLATE CERTIFIED GOLD`.
```

---

## Recipe 2: 4-Band Mastering Parametric EQ (`Prism Mastering EQ`)

```text
Read `llms.txt` and `llms-full.txt`.
Scaffold a new plugin using `cargo run --package xtask -- new-plugin --name "Prism Mastering EQ" --vendor "VibeAudio" --id "com.vibeaudio.prismeq"`, then implement a 4-Band Stereo Mastering Equalizer in `crates/prism_mastering_eq`:

1. DSP Engine:
   - Chain 4 stereo pairs of `dsp_core::BiquadFilter`:
     * Band 1: `BiquadMode::HighPass` (`hp_hz`: 20..400 Hz)
     * Band 2: `BiquadMode::LowShelf` (`low_gain_db`: -15..+15 dB at 110 Hz)
     * Band 3: `BiquadMode::Peaking` (`mid_freq_hz`: 250..6000 Hz, `mid_gain_db`: -15..+15 dB, Q = 1.0)
     * Band 4: `BiquadMode::HighShelf` (`air_gain_db`: -15..+15 dB at 10000 Hz)
   - Add `output_db` (-12..+12 dB) and `bypass`.

2. UI & Contract:
   - Build a 6-Skin Mastering Console UI with an interactive SVG frequency response curve that updates in real time as the user drags the EQ knobs.
   - Bind every control in `declare_plugin_contract!` using `DspImpact::AltersFrequencyResponse` and verify with `scripts/audit_plugin_architecture.ps1`.
```

---

## Recipe 3: Stereo Bucket-Brigade Chorus & Doubler (`Dimension BBD`)

```text
Read `llms.txt` and `llms-full.txt`.
Scaffold `Dimension BBD` via `cargo run --package xtask -- new-plugin --name "Dimension BBD" --vendor "VibeAudio" --id "com.vibeaudio.dimensionbbd"`:

1. DSP Engine:
   - Use two `dsp_core::DelayLine<8192>` instances (left and right) with quadrature LFO phase (90-degree stereo offset).
   - Parameters: `rate_hz` (0.1..5.0 Hz), `depth_ms` (0.5..12.0 ms), `feedback_pct` (0..70%), `warmth_hz` (2000..18000 Hz `BiquadMode::LowPass`), `mix_pct` (0..100%), and `bypass`.
   - Use `flush_denormal` in the feedback path and `OnePoleSmoother` on all parameters.

2. UI & Contract:
   - Create a 6-Skin UI featuring a stereo phase Lissajous visualizer (`<canvas>`) and rotary controls.
   - Prove every parameter in `declare_plugin_contract!` and run `scripts/audit_plugin_architecture.ps1`.
```

---

## Recipe 4: Transient Punch & Clipper (`Snap Forger`)

```text
Read `llms.txt` and `llms-full.txt`.
Scaffold `Snap Forger` via `cargo run --package xtask -- new-plugin --name "Snap Forger" --vendor "VibeAudio" --id "com.vibeaudio.snapforger"`:

1. DSP Engine:
   - Implement a differential envelope transient shaper using two `dsp_core::EnvelopeFollower` detectors (fast attack 1 ms vs slow attack 35 ms) to isolate transient attacks from sustain.
   - Parameters: `attack_db` (-12..+12 dB), `sustain_db` (-12..+12 dB), `clip_drive_db` (0..12 dB into `SoftClipper::process_tanh`), `output_db` (-12..+12 dB), and `bypass`.

2. UI & Contract:
   - Build a 6-Skin UI with a real-time transient spike scope and verify all 4 Gates via `scripts/audit_plugin_architecture.ps1`.
```
