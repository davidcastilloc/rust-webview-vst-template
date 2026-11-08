# Rust + WebView + `@audio-ui` — VST3 / CLAP / Standalone Plugin Template & SDK

Plantilla oficial de código abierto y SDK modular para construir **plugins de audio profesionales (VST3, CLAP y aplicaciones Standalone `.exe`)** combinando un motor DSP en **Rust 100 % *real-time safe* (`0` asignaciones en el hilo de audio)** con interfaces gráficas **HTML5 / CSS3 / React (`@audio-ui/react` + `@audio-ui/core`)** renderizadas de forma *serverless* en memoria sobre **WebView2 / WebKit (`wry`)**.

---

## Por qué este Stack

1. **Cero Servidores Locales, Cero Puertos TCP**: La UI se sirve desde memoria mediante el protocolo virtual nativo `app://localhost/index.html` con cabeceras de seguridad endurecidas y aislamiento automático de perfil por proceso (`%LOCALAPPDATA%/AudioPlugins/<Vendor>/<Plugin>/WebViewProfile_<host>`).
2. **Arquitectura de Capas Desacopladas (4 Crates Base + Paquete UI)**:
   * `crates/dsp_core`: Bloques de procesamiento de señales *zero-allocation* (filtros TPT ZDF `StateVariableFilter`, `LadderFilter24dB`, `CombFilter`, `AllpassFilter`, envolventes `AdsrEnvelope`, `LfoOscillator`, `FeedForwardCompressor`, `BrickwallLimiter`, `StereoDelayLine`, `StereoChorus`, `AlgorithmicReverb`, suavizadores `OnePoleSmoother`, `SeqLockArray` alineado a 64 bytes con `0` *torn reads* y `SpscRingBuffer`).
   * `crates/base_plugin_core`: Contrato universal `trait DspEngine` (con soporte de compensación de latencia PDC `latency_samples()` y `tail_samples()`), banco atómico $O(1)$ `AtomicParamBank` y macro declarativa de certificación `declare_plugin_contract!`.
   * `crates/base_plugin_webview`: Editor nativo `GenericWebViewEditor` (`nih_plug::prelude::Editor`), puente de medidores atómicos a 60 FPS (`AtomicMeterBridge`), bombeo Win32 `HWND_MESSAGE` libre de bloqueos y soporte de redimensionado dinámico.
   * `crates/base_plugin_standalone`: Ejecutor standalone independiente de cualquier DAW.
   * `packages/base-plugin-ui` (`@plugin-base/ui-bridge`): Librería de componentes sobre `@audio-ui/react` y `@audio-ui/core` (`PluginKnob`, `PluginFader`, `PluginXYPad`, `PluginLevelMeter`, `PluginHeader`) con **6 Hardware Skins** (`minimal`, `dark`, `retro`, `synth70`, `gunmetal`, `phosphor`).
3. **Certificación Formal de 4 Compuertas (`GATE-01` a `GATE-04`)**:
   * `GATE-01`: Cero acoplamiento o fugas de dominio en las capas base.
   * `GATE-02`: Cero asignaciones dinámicas en el camino de audio (`assert_no_alloc`).
   * `GATE-03`: Jerarquía DAG estricta entre crates verificada con `cargo tree`.
   * `GATE-04`: Certificación matemática de contrato UI <-> IPC <-> DSP (`declare_plugin_contract!` demuestra con señales de prueba `LinearChirp` que cada control del DOM muta físicamente el audio procesado).

---

## Inicio Rápido (Crear tu propio Plugin en 60 Segundos)

### Opción A — Usar como Plantilla Completa (`Use this template`)

1. Haz clic en el botón **"Use this template" -> "Create a new repository"** arriba a la derecha en GitHub y clona tu nuevo repositorio:
   ```powershell
   git clone https://github.com/<tu-usuario>/<tu-plugin>.git
   cd <tu-plugin>
   ```
2. Genera un nuevo plugin dentro del workspace con un solo comando:
   ```powershell
   cargo run --package xtask -- new-plugin --name "Tape Delay Pro" --vendor "MiEstudio" --id "com.miestudio.tapedelaypro"
   ```
3. Compila el ejecutable `.exe` standalone y empaqueta los binarios `.vst3` y `.clap`:
   ```powershell
   cargo build --release -p tape_delay_pro --bin tape_delay_pro_app
   cargo run --package xtask -- bundle tape_delay_pro --release
   ```
4. Ejecuta la auditoría de las 4 Compuertas de Arquitectura:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts/audit_plugin_architecture.ps1
   ```

---

### Opción B — Usar como SDK Central (Recibir mejoras para todos tus plugins a la vez)

Puedes importar los crates base directamente vía Git en el `Cargo.toml` de cualquiera de tus plugins:

```toml
[dependencies]
dsp_core = { git = "https://github.com/davidcastilloc/rust-webview-vst-template.git", branch = "main" }
base_plugin_core = { git = "https://github.com/davidcastilloc/rust-webview-vst-template.git", branch = "main" }
base_plugin_webview = { git = "https://github.com/davidcastilloc/rust-webview-vst-template.git", branch = "main" }
base_plugin_standalone = { git = "https://github.com/davidcastilloc/rust-webview-vst-template.git", branch = "main" }
```

Cuando el SDK central reciba nuevos filtros en `dsp_core`, nuevos *Hardware Skins* o mejoras de rendimiento en `base_plugin_webview`:
* Basta con ejecutar `cargo update` en tu plugin (o disparar el workflow incluido `.github/workflows/sync-upstream-sdk.yml` desde la pestaña **Actions** de GitHub) para que **todos tus plugins reciban la actualización automáticamente**.

---

## Plugin de Referencia Incluido: `Studio Bus Comp` (`crates/studio_bus_comp`)

El repositorio incluye de fábrica un **Compresor de Bus VCA Estéreo + Filtro Paso-Alto de Sidechain + Saturador de Cinta** completamente funcional:

* **Ejecutable Standalone con Loop de Prueba a 120 BPM**:
  ```powershell
  cargo run --release -p studio_bus_comp --bin studio_bus_comp_app
  ```
* **Empaquetado VST3 y CLAP (`target/bundled/studio_bus_comp.vst3` y `.clap`)**:
  ```powershell
  cargo run --package xtask -- bundle studio_bus_comp --release
  ```

---

## Licencia

Distribuido bajo licencia **MIT**. Libre para proyectos Open-Source y comerciales.
