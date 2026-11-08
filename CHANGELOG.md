## 1.0.0 (2026-11-08)

### Features

* **docs:** add visual identity, semantic-release, GitHub Pages portal, and llms.txt vibe-coding kit ([ea515a1](https://github.com/davidcastilloc/rust-webview-vst-template/commit/ea515a131476026c46ad9cfeae4c8dfcc778aa2f))
* initial release of decoupled Rust + WebView + audio-ui VST3/CLAP/Standalone template & SDK ([73710bb](https://github.com/davidcastilloc/rust-webview-vst-template/commit/73710bb80a271c3a37a2af8388a6de951dce868a))

### Bug Fixes

* **ci:** allow vst3_com macro trailing semicolon lint across Rust compiler versions ([88b0b60](https://github.com/davidcastilloc/rust-webview-vst-template/commit/88b0b60c481b6ada15ce85e6948fdf6dd60e81a9))
* **release:** include conventional-changelog-conventionalcommits preset in npx runner ([9bb3999](https://github.com/davidcastilloc/rust-webview-vst-template/commit/9bb3999460d104ea7d6d1ba9f89dcf37218a78c5))

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
