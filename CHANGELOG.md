# Changelog

All notable changes to this project will be documented in this file. This file is automatically maintained by [semantic-release](https://github.com/semantic-release/semantic-release).

## [1.0.0](https://github.com/davidcastilloc/rust-webview-vst-template/releases/tag/v1.0.0) (2026-11-08)

### Features

* **dsp_core:** zero-allocation DSP primitives (`StateVariableFilter` TPT ZDF, `LadderFilter24dB`, `CombFilter`, `AllpassFilter`, `AdsrEnvelope`, `LfoOscillator`, `FeedForwardCompressor`, `BrickwallLimiter`, `StereoDelayLine`, `StereoChorus`, `AlgorithmicReverb`, `OnePoleSmoother`, `SeqLockArray`, `SpscRingBuffer`).
* **base_plugin_core:** universal `DspEngine` trait with PDC (`latency_samples`, `tail_samples`), $O(1)$ `AtomicParamBank`, and `declare_plugin_contract!` certification macro.
* **base_plugin_webview:** serverless `GenericWebViewEditor` (`app://localhost/index.html`), 60 FPS `AtomicMeterBridge`, Win32 `HWND_MESSAGE` timer pump, resizable window styles, and per-host WebView2 User Data Folder isolation.
* **base-plugin-ui:** `@plugin-base/ui-bridge` component library over `@audio-ui/react` & `@audio-ui/core` with 6 Hardware Skins (`minimal`, `dark`, `retro`, `synth70`, `gunmetal`, `phosphor`).
* **studio_bus_comp:** complete VCA Bus Compressor + Sidechain HPF + Tape Saturator reference plugin (`.vst3`, `.clap`, and `.exe` standalone with built-in 120 BPM test loop).
* **ai-ready:** `llms.txt`, `llms-full.txt`, and `docs/VIBE_CODING_PROMPTS.md` for autonomous coding agents and vibe coders.
