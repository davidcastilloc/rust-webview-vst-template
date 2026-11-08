# Guía de Contribución (`CONTRIBUTING.md`)

¡Gracias por tu interés en contribuir a **Open Audio Stack (`rust-webview-vst-template`)**! Este repositorio es tanto la **plantilla base para creadores de plugins** como el **SDK central (`dsp_core`, `base_plugin_core`, `base_plugin_webview`, `@plugin-base/ui-bridge`)** que impulsa todo el ecosistema.

---

## 1. Principios de Ingeniería Innegociables (Las 4 Compuertas)

Todo Pull Request es auditado automáticamente mediante `./scripts/audit_plugin_architecture.ps1` en GitHub Actions y debe aprobar las **4 Compuertas de Certificación (`GATE-01` a `GATE-04`)**:

1. **`GATE-01` — Cero Acoplamiento de Dominio**:
   * Los crates base (`dsp_core`, `base_plugin_core`, `base_plugin_webview`, `base_plugin_standalone`) y `packages/base-plugin-ui` deben mantenerse 100 % agnósticos al tipo de plugin. Jamás incluir nombres de marcas específicas, presets de un sintetizador particular ni lógica de negocio ajena al SDK.
2. **`GATE-02` — Seguridad Estricta en Tiempo Real (`0` Asignaciones en el Hilo de Audio)**:
   * Dentro de `DspEngine::process()` o cualquier primitiva de `dsp_core`, queda **terminantemente prohibido** usar `Box::new`, `Vec::push`, `String`, `format!`, `Mutex::lock`, `RwLock` o llamadas al sistema operativo.
   * Toda memoria dinámica o tabla de retardo debe preasignarse exclusivamente dentro de `DspEngine::prepare(sample_rate, max_block_size)`.
3. **`GATE-03` — Jerarquía Acíclica de Crates (Clean DAG)**:
   * `dsp_core` no depende de ningún crate de UI ni de `nih_plug`.
   * `base_plugin_core` depende únicamente de `dsp_core`.
   * `base_plugin_webview` encapsula `wry` y `nih_plug` sin contaminar `dsp_core`.
4. **`GATE-04` — Prueba Matemática de Contrato UI <-> IPC <-> DSP (`declare_plugin_contract!`)**:
   * Ningún control visual (`PluginKnob`, `PluginFader`, `PluginXYPad`, botón de bypass) puede fusionarse sin su entrada correspondiente en `declare_plugin_contract!` que demuestre matemáticamente que mutar el parámetro altera la señal DSP (`AmplifiesRms`, `AttenuatesRms`, `AltersFrequencyResponse`, `MutatesTransient`, `MutatesWaveform` o `PassThroughEqual`).

---

## 2. Flujo de Trabajo y `Conventional Commits` (Semantic Release)

Este repositorio utiliza **[Semantic Release](https://github.com/semantic-release/semantic-release)** para publicar versiones, actualizar `CHANGELOG.md` y adjuntar binarios automáticamente al hacer merge en `main`.

Por favor, formatea tus mensajes de commit siguiendo **Conventional Commits**:

* `feat(dsp_core): add 4x polyphase oversampler for non-linear saturators` -> Dispara versión **MINOR (`1.x.0`)**.
* `fix(webview): prevent DPI scaling drift on secondary monitors` -> Dispara versión **PATCH (`1.0.x`)**.
* `perf(dsp_core): vectorize SVF inner loop` -> Dispara versión **PATCH (`1.0.x`)**.
* `docs(llms): add FM synth recipe to VIBE_CODING_PROMPTS.md` -> Actualiza documentación sin disparar binario innecesario.
* `feat(core)!: change DspEngine trait signature` -> Dispara versión **MAJOR (`x.0.0`)**.

---

## 3. Verificación Local antes de Abrir un Pull Request

Ejecuta estos 3 comandos desde PowerShell (Windows) o Bash (macOS/Linux):

```powershell
# 1. Auditoría de las 4 Compuertas (Certificación Nivel Oro)
powershell -ExecutionPolicy Bypass -File scripts/audit_plugin_architecture.ps1

# 2. Linter estricto sin advertencias
cargo clippy --workspace --all-targets --no-deps -- -D warnings

# 3. Suite completa de pruebas unitarias y de contrato
cargo test --workspace
```

---

## 4. Cómo Agregar un Nuevo Módulo a `dsp_core`

1. Crea tu módulo dentro de `crates/dsp_core/src/filters/`, `dynamics/`, `fx/` o `modulation/`.
2. Asegúrate de que el struct sea `#[derive(Debug, Clone)]` (o `Copy` si no usa buffers preasignados) y exponga `prepare(&mut self, sample_rate: f32)` y `reset(&mut self)`.
3. Aplica `flush_denormal()` en todos los lazos de realimentación (IIR, reverb, compresores) para evitar picos de CPU por números subnormales IEEE 754.
4. Añade pruebas unitarias deterministas en `crates/dsp_core/src/lib.rs`.
