# Instructions for AI Coding Agents (`CLAUDE.md` / `.cursorrules`)

You are working inside the **Open Audio Stack (`rust-webview-vst-template`)** repository — a modular Rust (`nih-plug`) + Serverless WebView2/WebKit (`wry`) + `@audio-ui` SDK and template for building VST3, CLAP, and Standalone audio plugins.

## 1. Read First
Before generating or modifying a plugin, read:
- `llms.txt` (architecture overview)
- `llms-full.txt` (complete API signatures for `dsp_core`, `base_plugin_core`, `base_plugin_webview`, and `@plugin-base/ui-bridge`)
- `crates/studio_bus_comp/src/lib.rs` (canonical reference plugin)

## 2. Non-Negotiable Engineering Rules (4 Certification Gates)
1. **GATE-01 (Zero Domain Leaks)**: Keep `crates/dsp_core`, `crates/base_plugin_*`, and `packages/base-plugin-ui` 100% generic. Put plugin-specific DSP and UI inside `crates/<your_plugin_slug>/`.
2. **GATE-02 (Real-Time Audio Safety)**: Inside `DspEngine::process()`, NEVER allocate memory (`Vec`, `Box`, `String`, `format!`) or lock a `Mutex`/`RwLock`. Always use `OnePoleSmoother` for continuous parameters and `flush_denormal()` inside feedback loops.
3. **GATE-03 (Clean DAG)**: Never add UI or `wry` dependencies to `dsp_core` or `base_plugin_core`.
4. **GATE-04 (Mathematical UI->DSP Contract)**: Every interactive control in the HTML/React UI (`id="knob-..."`, `id="btn-..."`) MUST be declared in `declare_plugin_contract!` at the bottom of `src/lib.rs` with a `DspImpact` proof (`AmplifiesRms`, `AttenuatesRms`, `AltersFrequencyResponse`, `MutatesTransient`, `MutatesWaveform`, or `PassThroughEqual`) and all 6 skins (`minimal`, `dark`, `retro`, `synth70`, `gunmetal`, `phosphor`).

## 3. Scaffolding & Verification Commands
- Create a new plugin crate automatically:
  `cargo run --package xtask -- new-plugin --name "Plugin Name" --vendor "VendorName" --id "com.vendor.pluginname"`
- Verify all 4 Gates:
  `powershell -ExecutionPolicy Bypass -File scripts/audit_plugin_architecture.ps1`
- Build Standalone `.exe` and bundle `.vst3` + `.clap`:
  `cargo build --release -p <slug> --bin <slug>_app`
  `cargo run --package xtask -- bundle <slug> --release`
