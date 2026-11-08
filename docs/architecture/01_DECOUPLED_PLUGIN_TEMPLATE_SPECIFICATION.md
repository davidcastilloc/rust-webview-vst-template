# Especificación Técnica de la Plantilla Base Desacoplada de Plugins de Audio

**Documento**: `01_DECOUPLED_PLUGIN_TEMPLATE_SPECIFICATION.md`  
**Autor**: Equipo de Arquitectura de Audio (Worker 1)  
**Fecha**: 2026-11-08  
**Estado**: Aprobado para Implementación  
**Alcance**: Desacoplamiento integral de la infraestructura de plugins (VST3/CLAP sobre `nih-plug` + Webview nativo `wry` + React 19) frente a la lógica de negocio de TEPUI.

---

## 1. Resumen Ejecutivo y Motivación Arquitectónica

El sintetizador e instrumento virtual TEPUI integra un motor de audio de nivel profesional: síntesis espectral por tablas de ondas 3D, muestreo cromático polifónico, aceleración en silicio local (Intel AI Boost NPU vía OpenVINO) y puente hacia la nube (Cloudflare Workers AI). Asimismo, cuenta con un host de interfaz gráfica de latencia ultra-baja montado sobre `wry`/WebView2 y React 19, capaz de renderizar a 60 FPS sin servidor HTTP externo.

No obstante, la investigación de arquitectura evidenció que los componentes de **infraestructura reutilizable de plugin** se encuentran fuertemente acoplados a la lógica cultural, comercial y de síntesis de TEPUI:
- Variables de afinaciones venezolanas (arpa llanera, cuatro, ritmos de joropo y merengue) hardcodeadas en enumeradores y bucles de audio centrales.
- Almacén de parámetros monolítico de 60+ campos fijos con comprobaciones delta manuales ($O(M)$) por bloque de audio.
- Protocolo virtual `tepui://` con más de 30 prefijos de comandos textuales sin tipado y rutas de cobro webhooks dentro del binario VST3.
- Colisión de concurrencia en WebView2 debido a un directorio de caché compartido estáticamente en `%TEMP%/Tepui/WebView2_Studio`.
- Compuertas de certificación contractual que exigen obligatoriamente 6 pantallas OLED y un motor de 16 voces de sampler.

El objetivo de esta especificación es definir una **plantilla base desacoplada y escalable** estructurada en crates independientes, con interfaces polimórficas (`DspEngine`, `ParamRegistry`, `IpcBus`), sincronización atómica libre de bloqueos ($O(1)$) y ciclo de vida seguro de Webview, permitiendo desarrollar cualquier tipo de plugin (efectos de audio, procesadores dinámicos, ecualizadores o sintetizadores) con cero residuos del dominio TEPUI.

---

## 2. Inventario Exhaustivo de Acoplamientos Existentes con TEPUI

A continuación se detalla cada punto concreto de acoplamiento identificado en el árbol de código actual, con referencia exacta de archivo, líneas y estrategia de desacoplamiento requerida:

### 2.1 Crate `synth_core` (`crates/synth_core/`)

| Archivo | Líneas | Elemento Acoplado a TEPUI | Descripción del Acoplamiento | Estrategia de Desacoplamiento |
|---|---|---|---|---|
| `src/arp.rs` | 12–23 | `enum ArpMode` (`Joropo = 3`, `Merengue = 4`) | Modos rítmicos de folklore venezolano fijados en el enum central del arpegiador. | Mover a `tepui_synth`. El crate base solo provee arpegiador estándar (Up, Down, UpDown, Random). |
| `src/arp.rs` | 103–108 | `DEFAULT_ARP_ACCENTS_JOROPO`, `DEFAULT_ARP_ACCENTS_MERENGUE` | Arreglos estáticos de velocidades sincopadas para cadencias de 6/8 y 5/8. | Extraer como configuración dinámica inyectable por preset o script de usuario. |
| `src/arp.rs` | 112–763 | `struct TepuiArpeggiator` | Arpegiador polifónico nombrado y acoplado a la vista `#oled-arp` de TEPUI. | Generalizar como `StepSequencerEngine` en `dsp_core`. |
| `src/voice.rs` | 77–79 | `const JOROPO_LLANERO_HARP_CENTS` | Temperamento microtonal en cents del arpa llanera venezolana. | Trasladar tablas microtonales a archivos de afinación (`.scl`/`.kbm`) en `tepui_synth`. |
| `src/voice.rs` | 86–95 | `fn tuning_cents_for_note` (modo 2) | Enlace cableado que conmuta a afinación de arpa llanera. | Generalizar mediante trait `MicrotuningTable` abstracto. |
| `src/voice_manager.rs` | 23–30 | `fn expand_chord_intervals` (modo 3) | Acorde `CHORD:STRUM` cableado a intervalos `&[0, 7, 12, 16]` (voicing de Cuatro). | Extraer como definición dinámica de acordes configurable por el plugin concreto. |
| `src/voice_manager.rs` | 33–116 | `struct VoiceManager` | Motor de 16 voces fijado a topología TEPUI (Wavetable 3D + Hermite + Sub + Matriz 5x5 + SVF 9 modos). | Aislar en `tepui_synth`. El crate base solo define el trait `DspEngine`. |
| `src/fx.rs` | 1–3, 158, 221 | `struct StereoFxRack` | Denominación y preset de "Reverberación Cañón del Tepui". Cadena fija Drive -> OTT -> Reverb. | Extraer primitivas en `dsp_core` (`Delay`, `Reverb`, `Compressor`) desacopladas de la cadena master. |
| `src/filter.rs` | 7–62 | `enum FilterMode` (9 modos) | Combinaciones fijas de SVF ZDF + Moog Ladder + Formante vocal A-E-I-O-U. | Proveer `StateVariableFilter` básico en `dsp_core`; los modos compuestos residen en `tepui_synth`. |

### 2.2 Crate `ai_bridge` (`crates/ai_bridge/`)

| Archivo | Líneas | Elemento Acoplado a TEPUI | Descripción del Acoplamiento | Estrategia de Desacoplamiento |
|---|---|---|---|---|
| `src/fallback_synth.rs` | 70–100, 120–510 | Síntesis procedural folklórica | Generadores para: Cuatro, Arpa Llanera, Bandola, Maracas, Cumaco, Quitiplás, Furruco. | Exclusivo de `tepui_synth`. No debe formar parte de la plantilla base. |
| `src/cloudflare.rs` | 20–25, 40–120 | Endpoints Cloudflare TEPUI | URLs fijas (`DEFAULT_CF_EDGE_WORKER_URL`), costos de crédito (`PRESET_GENERATION_CREDIT_COST`). | Eliminar de la plantilla base. Los servicios de nube son extensiones de producto. |
| `src/cloudflare.rs` | 130–280 | Licenciamiento y Vouchers | `CloudLicenseConfig`, `redeem_cloud_license_code`, `generate_signed_voucher_code`. | Eliminar del core. El licenciamiento comercial es independiente de la plantilla de audio. |
| `src/cloudflare.rs` | 300–400 | Webhooks de Checkout y HMAC | `process_checkout_webhook_payload`, verificación HMAC de compras. | Eliminar radicalmente del VST3. Ningún plugin de audio debe albergar webhooks de checkout. |
| `src/npu_synth.rs` | 30–80, 100–180 | Parser léxico y tablas 64x32 | Detección de timbres folklóricos (`arpa`, `cuatro`) y matrices orientadas a TEPUI. | Mover a crate opcional de IA para TEPUI (`tepui_ai_extension`). |

### 2.3 Crate `plugin_vst` (`crates/plugin_vst/`)

| Archivo | Líneas | Elemento Acoplado a TEPUI | Descripción del Acoplamiento | Estrategia de Desacoplamiento |
|---|---|---|---|---|
| `src/params.rs` | 148–236 | `struct TepuiPatch` | Cabecera mágica `"TEPUI_PATCH_V1"`, vendor `"Gran Sabana Sonic Lab"`, Base64 WAV. | Reemplazar por serialización de estado genérica (`PluginStateEnvelope`) con JSON/bincode. |
| `src/params.rs` | 700–816 | `struct SamplerParams` | 40+ parámetros atómicos de TEPUI con macros fijas de `nih-plug`. | Reemplazar por macro declarativa `declare_params!` y almacén dinámico `AtomicParamBank`. |
| `src/params.rs` | 1070–1187 | `struct LiveParamStore` | Estructura con 60+ celdas atómicas manuales (`AtomicU32`, `AtomicI32`) de TEPUI. | Reemplazar por `AtomicParamBank<MAX_PARAMS>` indexado numéricamente. |
| `src/params.rs` | 2801–2948 | `fn project_to_dsp` | Proyector monolítico atado a `VoiceManager` y `StereoFxRack`. | Implementado dentro de cada `DspEngine::process()` específico. |
| `src/web_editor.rs` | 2949–3357 | Protocolo `tepui://` | Registra esquema virtual `tepui`, inyecta `__TEPUI_INIT_STATE__` en window. | Esquema estándar `app://localhost/` con inicialización agnóstica `__PLUGIN_INIT__`. |
| `src/web_editor.rs` | 1453–2527 | Parser IPC con `strip_prefix` | Más de 1,000 líneas con cadenas arbitrarias (`wtdraw:`, `p,id,val`, `arp,mode`, etc.). | Bus de comandos tipados (`GuiToHostCommand` / `HostToGuiEvent`) y trait `IpcExtensionHandler`. |
| `src/web_editor.rs` | 240, 2941 | Rutas en disco duro fijas | Carpetas fijas `%LOCALAPPDATA%/Tepui/Presets` y `%TEMP%/Tepui/WebView2_Studio`. | Aislamiento por `Vendor/PluginName` en `%LOCALAPPDATA%`. |
| `src/ui_dsp_contract.rs` | 61–180, 1521 | `SynthControlId` y tests | 70+ variantes de controles TEPUI y aserción rígida de 6 pantallas OLED. | Macro universal `declare_plugin_contract!` y harness agnóstico en `03_ARCHITECTURAL_VALIDATION_RUBRIC.md`. |

### 2.4 Frontend y Componentes UI (`crates/plugin_vst/ui/`)

| Archivo | Elemento Acoplado a TEPUI | Descripción del Acoplamiento | Estrategia de Desacoplamiento |
|---|---|---|---|
| `ui/src/types.ts` | `FOLKLORE_PADS` | 7 pads fijos de géneros musicales de TEPUI. | Definición de pads específica del producto `tepui-ui`. |
| `ui/src/types.ts` | `STUDIO_CHIPS` | 7 chips fijos de timbres orquestales/folklóricos. | Configurable por plugin o reemplazable por selector genérico de presets. |
| `ui/src/types.ts` | `UI_SKINS` | 6 skins de chasis Eurorack con metadatos específicos. | Sistema de diseño agnóstico basado en variables CSS (`--bg-primary`, `--accent`). |
| `ui/src/components/EurorackMatrix.tsx` | Estructura de 6 módulos | 6 módulos físicos fijos con lienzos OLED y pestaña `Arps 6/8`. | Desacoplar en layout libre de React; la plantilla solo ofrece controles atómicos (`Knob`, `Fader`). |
| `ui/src/components/CommandDock.tsx` | Barra superior de comandos | Botón SYNTHESIZE, prompts de IA, sound packs de TEPUI. | Reemplazar por barra de herramientas configurable (`PluginHeader`). |
| `ui/src/engine/oledEngine.ts` | 238 KB de dibujo Canvas | Renderizadores 2D para SVF, ADSR y Arp de TEPUI con polling HTTP a 80 ms. | Reemplazar por componentes declarativos `@audio-ui/react` y push atómico a 60 FPS. |

### 2.5 Crate `xtask` y Scripts de Compilación (`crates/xtask/`, `build.rs`)

| Archivo | Elemento Acoplado a TEPUI | Descripción del Acoplamiento | Estrategia de Desacoplamiento |
|---|---|---|---|
| `crates/xtask/src/main.rs` | Nombres de salida y SFX | Genera exclusivamente `TEPUI.vst3`, `TEPUI.clap`, y SFX con firma `b"TEPUI_SFX_V1"`. | Parametrizar mediante manifiesto `PluginManifest.toml` o argumentos CLI. |
| `crates/plugin_vst/build.rs` | Iconos y recursos Win32 | Enlaza rígidamente `assets/tepui-icon.ico`. | Rutas de iconos configurables en el crate final del plugin. |

---

## 3. Topología de Crates Desacoplada

La plantilla base se organiza en un espacio de trabajo Cargo multi-crate modular con estricto respeto a la jerarquía del Grafo Acíclico Dirigido (DAG):

```
                        ┌─────────────────────────────────┐
                        │        base_plugin_xtask        │
                        │    (Bundles, SFX, Validadores)  │
                        └────────────────┬────────────────┘
                                         │
                                         ▼
                        ┌─────────────────────────────────┐
                        │       base_plugin_webview       │
                        │ (Wry, Win32 Subclass, IPC Bus)  │
                        └────────────────┬────────────────┘
                                         │
                                         ▼
 ┌────────────────────────┐     ┌─────────────────────────────────┐
 │ base_plugin_standalone │────►│        base_plugin_core         │
 │ (CPAL, Midir, Runner)  │     │ (DspEngine, AtomicParamBank,    │
 └────────────────────────┘     │  SeqLockArray, OnePoleSmoother) │
                                └────────────────┬────────────────┘
                                                 │
                                                 ▼
                                ┌─────────────────────────────────┐
                                │            dsp_core             │
                                │ (Filtros ZDF, ADSR, Retardo,    │
                                │  Sanitizers, Fast Math, Denorm) │
                                └─────────────────────────────────┘
                                                 ▲
                                                 │
                                ┌────────────────┴────────────────┐
                                │           tepui_synth           │
                                │ (Producto Concreto: Wavetable   │
                                │  3D, Sampler, Folklore, AI)     │
                                └─────────────────────────────────┘
```

### 3.1 Responsabilidades y Límites de Cada Crate

1. **`dsp_core` (Primitivas Matemáticas y de Audio Reutilizables)**:
   - **Responsabilidad**: Bloques DSP puros (`#![no_std]` opcional), libres de asignaciones dinámicas y sin dependencias de GUI, `nih-plug` o sistemas operativos.
   - **Contenido**: Filtros de variable de estado (TPT ZDF), generadores de envolvente ADSR/AHDSR, LFOs polimórficos, líneas de retardo fraccionarias, limitadores de pico, suavizadores exponenciales (`OnePoleSmoother`), sanitizadores IEEE 754 y purgado de denormales.
   - **Invariante**: $0$ allocations en tiempo de proceso, $0$ mutexes, tiempo de ejecución acotado $O(1)$.

2. **`base_plugin_core` (Núcleo Agnóstico de Plugin)**:
   - **Responsabilidad**: Definir los contratos centrales del plugin, sincronización atómica de parámetros y telemetría en tiempo real.
   - **Contenido**: Trait `DspEngine`, banco de parámetros `AtomicParamBank<MAX_PARAMS>`, estructura lock-free `SeqLockArray<N>` alineada a línea de caché (64 bytes), descriptores de parámetros y sanitización de transporte.
   - **Invariante**: Cero dependencias de renderizado web (`wry`) ni frameworks gráficos.

3. **`base_plugin_webview` (Host de Interfaz Webview e IPC)**:
   - **Responsabilidad**: Incrustación de WebView2/WebKit dentro del contenedor de la ventana DAW mediante `raw-window-handle 0.6`.
   - **Contenido**: Subclassing seguro Win32 (`comctl32::SetWindowSubclass`), protocolo serverless virtual en memoria `app://localhost/`, aislamiento de perfil de datos UDF, enrutador IPC bidireccional tipado (`GuiToHostCommand` / `HostToGuiEvent`) y streaming de telemetría a 60 FPS sin contrapresión.
   - **Invariante**: No realiza suposiciones sobre el layout visual ni la cantidad de perillas o controles.

4. **`base_plugin_standalone` (Host Autónomo de Ejecución)**:
   - **Responsabilidad**: Ejecutar el plugin como ejecutable de escritorio independiente sin requerir un DAW comercial.
   - **Contenido**: Backend CPAL para audio I/O de baja latencia (WASAPI exclusivo / ASIO / CoreAudio / ALSA), reconexión MIDI en caliente con `midir`, y persistencia agnóstica de configuración de hardware.

5. **`base_plugin_xtask` (Automatización de Build y Empaquetado)**:
   - **Responsabilidad**: Orquestar la compilación, generación de bundles VST3 y CLAP multiplataforma, empaquetado SFX y validación de contratos.
   - **Contenido**: Generación determinista de UUID v5 (RFC 4122), extracción de metadatos de manifiesto, y validadores de empaquetado.

6. **`tepui_synth` (Implementación de Referencia de Producto)**:
   - **Responsabilidad**: Implementar el sintetizador e instrumento virtual TEPUI consumiendo `base_plugin_core`, `base_plugin_webview` y `dsp_core`.
   - **Contenido**: Osciladores wavetable 3D, sampler cromático, arpegiador con modos Joropo/Merengue, y extensiones opcionales de IA.

---

## 4. Interfaces y Traits de Abstracción

### 4.1 Trait del Motor de Audio: `DspEngine`

Todo procesador de audio (instrumento, procesador dinámico o efecto) implementa el trait `DspEngine`. Está completamente desacoplado del host de ventana y de la interfaz web:

```rust
use std::time::Duration;

/// Estado de procesamiento del bloque de audio.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProcessStatus {
    /// El motor procesó audio normalmente.
    Normal,
    /// El motor se encuentra en silencio (permite al DAW suspender el plugin para ahorrar CPU).
    Sleep,
}

/// Contexto de transporte provisto por el host DAW.
#[derive(Debug, Clone)]
pub struct HostTransportContext {
    pub sample_rate: f32,
    pub tempo_bpm: Option<f64>,
    pub time_sig_numerator: u16,
    pub time_sig_denominator: u16,
    pub is_playing: bool,
    pub is_recording: bool,
    pub song_position_samples: Option<i64>,
}

/// Evento MIDI normalizado de entrada.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct MidiEvent {
    pub sample_offset: u32,
    pub channel: u8,
    pub message: MidiMessage,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum MidiMessage {
    NoteOn { note: u8, velocity: f32 },
    NoteOff { note: u8, velocity: f32 },
    PolyphonicAftertouch { note: u8, pressure: f32 },
    ChannelAftertouch { pressure: f32 },
    PitchBend { semitones: f32 },
    ControlChange { controller: u8, value: f32 },
    AllNotesOff,
}

/// Buffer para emitir eventos MIDI hacia el host DAW sin asignaciones de heap.
pub struct MidiOutputBuffer<'a> {
    events: &'a mut [Option<MidiEvent>],
    count: usize,
}

impl<'a> MidiOutputBuffer<'a> {
    pub fn new(slice: &'a mut [Option<MidiEvent>]) -> Self {
        Self { events: slice, count: 0 }
    }

    #[inline(always)]
    pub fn push(&mut self, event: MidiEvent) -> bool {
        if self.count < self.events.len() {
            self.events[self.count] = Some(event);
            self.count += 1;
            true
        } else {
            false
        }
    }

    #[inline(always)]
    pub fn len(&self) -> usize {
        self.count
    }
}

/// Trait central que deben implementar todos los motores DSP.
pub trait DspEngine: Send + 'static {
    /// Tipo de telemetría emitido hacia la interfaz gráfica (medidores, estados, analizadores).
    type Telemetry: serde::Serialize + Send + Sync + 'static;

    /// Inicializa buffers internos según la tasa de muestreo y tamaño máximo de bloque.
    /// Se invoca en el hilo de audio antes de iniciar el procesamiento.
    fn initialize(&mut self, sample_rate: f32, max_buffer_size: usize);

    /// Reinicia estados internos (integradores, colas de retardo, fases de osciladores).
    fn reset(&mut self);

    /// Procesa un bloque de audio multicanal con estricta seguridad en tiempo real.
    ///
    /// # Invariantes:
    /// - 0 asignaciones dinámicas de memoria (Heap).
    /// - 0 operaciones bloqueantes (Mutex, semáforos, I/O de disco o sockets).
    /// - Complejidad temporal O(N) predecible y acotada.
    fn process_block(
        &mut self,
        inputs: &[&[f32]],
        outputs: &mut [&mut [f32]],
        midi_in: &[MidiEvent],
        midi_out: &mut MidiOutputBuffer<'_>,
        context: &HostTransportContext,
        param_snapshot: &LiveParamSnapshot,
    ) -> ProcessStatus;

    /// Captura una instantánea de telemetría de forma atómica para publicación en la GUI.
    fn capture_telemetry(&self) -> Self::Telemetry;

    /// Latencia algorítmica interna en muestras para compensación de retardo (PDC) en el host DAW.
    /// Lookahead limiters, filtros de fase lineal o procesadores espectrales deben sobreescribir este método.
    /// Por defecto retorna 0 (procesamiento causal de retardo cero).
    #[inline(always)]
    fn latency_samples(&self) -> u32 {
        0
    }

    /// Tiempo de cola residual (decay/reverb tail) en muestras tras cesar la entrada de audio o reproducción.
    /// Evita truncamiento abrupto en efectos temporales (reverbs, delays) cuando el transporte del DAW se detiene.
    /// Por defecto retorna 0 (sin cola residual).
    #[inline(always)]
    fn tail_samples(&self) -> u32 {
        0
    }
}
```

### 4.2 Registro y Descriptores de Parámetros: `ParamRegistry`

En lugar de definir estructuras rígidas con 40+ campos manuales, los parámetros se registran de forma declarativa con identificadores numéricos continuos:

```rust
pub type ParamIndex = u16;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ParamScale {
    Linear,
    Logarithmic { min_hz: f32, max_hz: f32 },
    Decibels { min_db: f32, max_db: f32 },
    Exponential { curve: f32 },
}

#[derive(Debug, Clone)]
pub struct ParamDescriptor {
    pub index: ParamIndex,
    pub id_str: &'static str,
    pub display_name: &'static str,
    pub min_plain: f32,
    pub max_plain: f32,
    pub default_plain: f32,
    pub scale: ParamScale,
    pub unit: &'static str,
    pub smoothing_ms: f32,
    pub is_integer: bool,
}

impl ParamDescriptor {
    #[inline(always)]
    pub fn to_normalized(&self, plain: f32) -> f32 {
        let clamped = plain.clamp(self.min_plain, self.max_plain);
        match self.scale {
            ParamScale::Linear => (clamped - self.min_plain) / (self.max_plain - self.min_plain),
            ParamScale::Logarithmic { min_hz, max_hz } => {
                let ratio = (clamped / min_hz).max(1e-5);
                (ratio.ln() / (max_hz / min_hz).ln()).clamp(0.0, 1.0)
            }
            ParamScale::Decibels { min_db, max_db } => {
                (clamped - min_db) / (max_db - min_db)
            }
            ParamScale::Exponential { curve } => {
                let norm_lin = (clamped - self.min_plain) / (self.max_plain - self.min_plain);
                norm_lin.powf(1.0 / curve)
            }
        }
    }

    #[inline(always)]
    pub fn to_plain(&self, normalized: f32) -> f32 {
        let norm = normalized.clamp(0.0, 1.0);
        match self.scale {
            ParamScale::Linear => self.min_plain + norm * (self.max_plain - self.min_plain),
            ParamScale::Logarithmic { min_hz, max_hz } => {
                min_hz * (max_hz / min_hz).powf(norm)
            }
            ParamScale::Decibels { min_db, max_db } => {
                self.min_db_interp(norm, min_db, max_db)
            }
            ParamScale::Exponential { curve } => {
                self.min_plain + norm.powf(curve) * (self.max_plain - self.min_plain)
            }
        }
    }

    #[inline(always)]
    fn min_db_interp(&self, norm: f32, min_db: f32, max_db: f32) -> f32 {
        min_db + norm * (max_db - min_db)
    }
}
```

### 4.3 Instantánea de Parámetros en Pila: `LiveParamSnapshot`

Al inicio del bloque de procesamiento de audio, se construye una instantánea local en la pila que el motor DSP consulta en tiempo constante $O(1)$ sin asignaciones de memoria ni comparaciones de strings:

```rust
pub const MAX_PLUGIN_PARAMS: usize = 256;

#[derive(Clone, Copy)]
pub struct LiveParamSnapshot {
    plain_values: [f32; MAX_PLUGIN_PARAMS],
    normalized_values: [f32; MAX_PLUGIN_PARAMS],
    generation: u64,
}

impl LiveParamSnapshot {
    pub fn empty() -> Self {
        Self {
            plain_values: [0.0; MAX_PLUGIN_PARAMS],
            normalized_values: [0.0; MAX_PLUGIN_PARAMS],
            generation: 0,
        }
    }

    #[inline(always)]
    pub fn get_plain(&self, index: ParamIndex) -> f32 {
        self.plain_values[index as usize]
    }

    #[inline(always)]
    pub fn get_normalized(&self, index: ParamIndex) -> f32 {
        self.normalized_values[index as usize]
    }

    #[inline(always)]
    pub fn generation(&self) -> u64 {
        self.generation
    }
}
```

---

## 5. Patrón Escalable de Flujo y Sincronización de Parámetros

El flujo de parámetros sincroniza tres hilos concurrentes con distintas prioridades y garantías temporales:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        HILO DE INTERFAZ GRÁFICA (V8)                   │
│   Eventos táctiles y de puntero:                                       │
│   - pointerdown ──► postMessage("p_begin:4")                           │
│   - pointermove ──► postMessage("p_set:4:0.654")                       │
│   - pointerup   ──► postMessage("p_end:4")                             │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ IPC Tipado (Wry Handler)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        HILO HOST DAW / GUI (Rust)                      │
│   - setter.begin_set_parameter(param)                                  │
│   - setter.set_parameter(param, plain_val)                             │
│   - AtomicParamBank.store_normalized(4, 0.654)                         │
│   - generation.fetch_add(1, Release)                                   │
│   - setter.end_set_parameter(param)                                    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Lock-Free Atomic Sync (Acquire/Release)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                    HILO DE AUDIO EN TIEMPO REAL (DSP)                  │
│   1. if bank.current_generation() != cached_gen:                       │
│        snapshot.update_from(bank)                                      │
│   2. OnePoleSmoother::set_target(snapshot.get_plain(4))                │
│   3. Per-sample/block smoothing ──► Render Audio                       │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Almacén Atómico de Parámetros: `AtomicParamBank`

```rust
use std::sync::atomic::{AtomicU32, AtomicU64, Ordering};

pub struct AtomicParamBank<const MAX_PARAMS: usize = MAX_PLUGIN_PARAMS> {
    values: [AtomicU32; MAX_PARAMS],
    generation: AtomicU64,
}

impl<const MAX_PARAMS: usize> AtomicParamBank<MAX_PARAMS> {
    pub fn new(default_norm: f32) -> Self {
        let bits = default_norm.clamp(0.0, 1.0).to_bits();
        Self {
            values: std::array::from_fn(|_| AtomicU32::new(bits)),
            generation: AtomicU64::new(0),
        }
    }

    #[inline(always)]
    pub fn load_normalized(&self, index: ParamIndex) -> f32 {
        if (index as usize) < MAX_PARAMS {
            f32::from_bits(self.values[index as usize].load(Ordering::Relaxed))
        } else {
            0.0
        }
    }

    #[inline(always)]
    pub fn store_normalized(&self, index: ParamIndex, value: f32) {
        if (index as usize) < MAX_PARAMS && value.is_finite() {
            let clamped = value.clamp(0.0, 1.0);
            self.values[index as usize].store(clamped.to_bits(), Ordering::Release);
            self.generation.fetch_add(1, Ordering::Release);
        }
    }

    #[inline(always)]
    pub fn current_generation(&self) -> u64 {
        self.generation.load(Ordering::Acquire)
    }

    /// Carga atómica masiva de todos los parámetros en un snapshot en pila.
    pub fn take_snapshot(&self, descriptors: &[ParamDescriptor], out: &mut LiveParamSnapshot) {
        let count = descriptors.len().min(MAX_PARAMS);
        for i in 0..count {
            let norm = f32::from_bits(self.values[i].load(Ordering::Relaxed));
            out.normalized_values[i] = norm;
            out.plain_values[i] = descriptors[i].to_plain(norm);
        }
        out.generation = self.current_generation();
    }
}
```

### 5.2 Sincronización de Arreglos Densos sin False Sharing: `SeqLockArray`

Para formas de onda, tablas de modulación o envolventes multipunto, la estructura `SeqLockArray` implementa aislamiento estricto de línea de caché de 64 bytes (`#[repr(C, align(64))]`) para erradicar contiendas de coherencia entre los núcleos de CPU que ejecutan la GUI y el audio:

```rust
use std::sync::atomic::{fence, AtomicU32, Ordering};

#[repr(C, align(64))]
pub struct SeqLockArray<const N: usize> {
    seq: AtomicU32,
    _pad: [u8; 60], // Garantiza que `seq` habite su propia línea de caché de 64 bytes
    cells: [AtomicU32; N],
}

impl<const N: usize> SeqLockArray<N> {
    pub fn new(default_value: f32) -> Self {
        let bits = default_value.to_bits();
        Self {
            seq: AtomicU32::new(0),
            _pad: [0u8; 60],
            cells: std::array::from_fn(|_| AtomicU32::new(bits)),
        }
    }

    /// Escritura desde el hilo de control (UI / IPC).
    pub fn write_slice(&self, values: &[f32], default_val: f32) {
        // 1. Marcar inicio de escritura (impar)
        self.seq.fetch_add(1, Ordering::AcqRel);

        let count = values.len().min(N);
        for i in 0..count {
            let val = if values[i].is_finite() { values[i] } else { default_val };
            self.cells[i].store(val.to_bits(), Ordering::Relaxed);
        }

        // 2. Marcar fin de escritura (vuelve a ser par)
        self.seq.fetch_add(1, Ordering::Release);
    }

    /// Lectura en tiempo real con respaldo garantizado libre de lecturas fragmentadas (torn reads).
    /// Utiliza un búfer temporal en la pila (`temp`) para no contaminar `cached_snapshot`
    /// hasta certificar la consistencia de secuencia (`s1 == s2`).
    /// Retorna `true` si la lectura fue exitosa; `false` si hubo contención extrema y se preservó intacto.
    #[inline(always)]
    pub fn read_into_snapshot(&self, cached_snapshot: &mut [f32; N]) -> bool {
        let mut temp = [0.0_f32; N];
        for _ in 0..3 {
            let s1 = self.seq.load(Ordering::Acquire);
            if (s1 & 1) != 0 {
                std::hint::spin_loop();
                continue;
            }
            for (dst, cell) in temp.iter_mut().zip(self.cells.iter()) {
                *dst = f32::from_bits(cell.load(Ordering::Relaxed));
            }
            fence(Ordering::Acquire);
            let s2 = self.seq.load(Ordering::Relaxed);
            if s1 == s2 {
                *cached_snapshot = temp;
                return true; // Lectura consistente exitosa
            }
        }
        // Ante contención extrema, preserva intacto cached_snapshot,
        // garantizando 0 fallos de audio y determinismo O(1).
        false
    }
}
```

### 5.3 Suavizado de Parámetros: `OnePoleSmoother`

Para eliminar el ruido de cremallera (*zipper noise*) sin calcular exponenciales por muestra:

```rust
#[derive(Debug, Clone, Copy)]
pub struct OnePoleSmoother {
    current: f32,
    target: f32,
    coeff: f32,
}

impl OnePoleSmoother {
    pub fn new(initial_value: f32, time_ms: f32, sample_rate: f32) -> Self {
        let mut smoother = Self {
            current: initial_value,
            target: initial_value,
            coeff: 0.0,
        };
        smoother.set_time(time_ms, sample_rate);
        smoother
    }

    pub fn set_time(&mut self, time_ms: f32, sample_rate: f32) {
        if time_ms <= 0.0 || sample_rate <= 0.0 {
            self.coeff = 0.0;
        } else {
            let tau = time_ms * 0.001;
            self.coeff = (-1.0 / (tau * sample_rate)).exp();
        }
    }

    #[inline(always)]
    pub fn set_target(&mut self, target: f32) {
        if target.is_finite() {
            self.target = target;
        }
    }

    #[inline(always)]
    pub fn next(&mut self) -> f32 {
        let diff = self.current - self.target;
        if diff.abs() <= 1e-5 {
            self.current = self.target;
        } else {
            self.current = self.target + self.coeff * diff;
        }
        self.current
    }

    #[inline(always)]
    pub fn advance_samples(&mut self, frames: usize) -> f32 {
        if frames == 0 {
            return self.current;
        }
        let diff = self.current - self.target;
        if diff.abs() <= 1e-5 {
            self.current = self.target;
            return self.current;
        }
        let factor = self.coeff.powi(frames as i32);
        self.current = self.target + factor * diff;
        if (self.current - self.target).abs() <= 1e-5 {
            self.current = self.target;
        }
        self.current
    }

    #[inline(always)]
    pub fn is_smoothing(&self) -> bool {
        (self.current - self.target).abs() > 1e-5
    }
}
```

---

## 6. Patrón Escalable de Ciclo de Vida de Webview

### 6.1 Integración Multiplataforma con `raw-window-handle 0.6`

La ventana del plugin se incrusta en el contenedor nativo provisto por el host DAW a través de `HasWindowHandle`:

```rust
use raw_window_handle::{HasWindowHandle, RawWindowHandle};

pub fn create_native_webview(
    parent: &dyn HasWindowHandle,
    vendor_name: &str,
    plugin_name: &str,
    width: u32,
    height: u32,
    ipc_handler: impl Fn(String) + 'static,
) -> Result<wry::WebView, Box<dyn std::error::Error>> {
    let window_handle = parent.window_handle()?.as_raw();

    // Directorio de perfil aislado por vendor y plugin en %LOCALAPPDATA%
    let profile_dir = dirs::data_local_dir()
        .unwrap_or_else(std::env::temp_dir)
        .join("AudioPlugins")
        .join(vendor_name)
        .join(plugin_name)
        .join("WebViewProfile");

    std::fs::create_dir_all(&profile_dir)?;

    let mut web_context = wry::WebContext::new(Some(profile_dir));

    let mut builder = wry::WebViewBuilder::new_as_child(&parent)
        .with_bounds(wry::Rect {
            position: wry::dpi::Position::Logical(wry::dpi::LogicalPosition::new(0.0, 0.0)),
            size: wry::dpi::Size::Logical(wry::dpi::LogicalSize::new(width as f64, height as f64)),
        })
        .with_web_context(&mut web_context)
        .with_devtools(cfg!(debug_assertions))
        .with_ipc_handler(move |msg| ipc_handler(msg));

    // Registro de protocolo virtual en memoria sin sockets TCP
    builder = register_virtual_protocol(builder);

    let webview = builder.build()?;
    Ok(webview)
}
```

### 6.2 Subclassing Seguro en Windows (`comctl32::SetWindowSubclass`)

Para interceptar eventos de redimensionamiento `WM_SIZE` y destrucción `WM_DESTROY` sin romper la cadena de hooks de otros plugins o del DAW:

```rust
#[cfg(windows)]
pub mod win32_subclass {
    use std::ffi::c_void;

    pub type HWND = *mut c_void;
    pub type LRESULT = isize;
    pub type UINT = u32;
    pub type WPARAM = usize;
    pub type LPARAM = isize;
    pub type UINT_PTR = usize;
    pub type DWORD_PTR = usize;

    const SUBCLASS_ID: UINT_PTR = 0x41554449; // "AUDI"

    #[link(name = "comctl32")]
    extern "system" {
        pub fn SetWindowSubclass(
            hWnd: HWND,
            pfnSubclass: unsafe extern "system" fn(HWND, UINT, WPARAM, LPARAM, UINT_PTR, DWORD_PTR) -> LRESULT,
            uIdSubclass: UINT_PTR,
            dwRefData: DWORD_PTR,
        ) -> i32;

        pub fn RemoveWindowSubclass(
            hWnd: HWND,
            pfnSubclass: unsafe extern "system" fn(HWND, UINT, WPARAM, LPARAM, UINT_PTR, DWORD_PTR) -> LRESULT,
            uIdSubclass: UINT_PTR,
        ) -> i32;

        pub fn DefSubclassProc(hWnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT;
    }

    /// Estructura de contexto asociada a la ventana nativa mediante `dwRefData` en `SetWindowSubclass`.
    pub struct WindowSubclassContext {
        pub webview: *mut wry::WebView,
        pub base_width: u32,
        pub base_height: u32,
    }

    pub unsafe extern "system" fn plugin_window_subclass_proc(
        hwnd: HWND,
        msg: UINT,
        wparam: WPARAM,
        lparam: LPARAM,
        uid: UINT_PTR,
        ref_data: DWORD_PTR,
    ) -> LRESULT {
        const WM_SIZE: UINT = 0x0005;
        const WM_DPICHANGED: UINT = 0x02E0;
        const WM_DESTROY: UINT = 0x0002;

        match msg {
            WM_SIZE => {
                // Adaptar tamaño del WebView hijo cuando el DAW redimensiona el contenedor
                let width = (lparam & 0xFFFF) as u32;
                let height = ((lparam >> 16) & 0xFFFF) as u32;
                if ref_data != 0 {
                    let ctx = &*(ref_data as *const WindowSubclassContext);
                    if !ctx.webview.is_null() {
                        let _ = (*ctx.webview).set_bounds(wry::Rect {
                            position: wry::dpi::Position::Logical(wry::dpi::LogicalPosition::new(0.0, 0.0)),
                            size: wry::dpi::Size::Physical(wry::dpi::PhysicalSize::new(width, height)),
                        });
                    }
                }
                DefSubclassProc(hwnd, msg, wparam, lparam)
            }
            WM_DPICHANGED => {
                // Manejar cambio dinámico de escala DPI (p. ej., arrastrar la ventana entre monitores con 100% y 150%)
                if ref_data != 0 {
                    let ctx = &*(ref_data as *const WindowSubclassContext);
                    if !ctx.webview.is_null() {
                        let _ = (*ctx.webview).set_bounds(wry::Rect {
                            position: wry::dpi::Position::Logical(wry::dpi::LogicalPosition::new(0.0, 0.0)),
                            size: wry::dpi::Size::Logical(wry::dpi::LogicalSize::new(ctx.base_width as f64, ctx.base_height as f64)),
                        });
                    }
                }
                DefSubclassProc(hwnd, msg, wparam, lparam)
            }
            WM_DESTROY => {
                RemoveWindowSubclass(hwnd, plugin_window_subclass_proc, uid);
                DefSubclassProc(hwnd, msg, wparam, lparam)
            }
            _ => DefSubclassProc(hwnd, msg, wparam, lparam),
        }
    }
}
```

### 6.3 Protocolo Virtual en Memoria y Sandbox CSP

- **Esquema de URI**: `app://localhost/index.html` (reemplaza `tepui://localhost/`).
- **Cero Sockets Abiertos**: No se expone ningún puerto local (`127.0.0.1`), protegiendo al usuario contra ataques de secuestro de puertos locales o avisos del firewall de Windows.
- **Cabeceras de Seguridad CSP Endurecidas**:
  ```http
  Content-Security-Policy: default-src 'self' app:; script-src 'self' 'unsafe-inline' app:; style-src 'self' 'unsafe-inline' app:; img-src 'self' data: app:; connect-src 'self' app:; object-src 'none'; frame-ancestors 'none';
  X-Content-Type-Options: nosniff
  ```

---

## 7. Patrón de IPC UI↔DSP y Streaming a 60 FPS

### 7.1 Bus de Comandos Tipados (`GuiToHostCommand` y `HostToGuiEvent`)

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "cmd", content = "data")]
pub enum GuiToHostCommand {
    /// Delimitación de inicio de gesto DAW
    ParamGestureBegin { param_id: u16 },
    /// Mutación de valor normalizado
    ParamSetValue { param_id: u16, value: f32 },
    /// Delimitación de fin de gesto DAW
    ParamGestureEnd { param_id: u16 },
    /// Eventos de teclado virtual
    MidiNoteOn { note: u8, velocity: f32 },
    MidiNoteOff { note: u8 },
    MidiPitchBend { semitones: f32 },
    /// Control de ventana
    RequestResize { width: u32, height: u32 },
    /// Presets genéricos
    LoadPreset { preset_id: String },
    SavePreset { name: String },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "evt", content = "data")]
pub enum HostToGuiEvent {
    /// Sincronización de parámetro modificado por automatización DAW
    ParamSync { param_id: u16, value: f32 },
    /// Telemetría y medidores a 60 FPS
    MeterUpdate {
        peak_l: f32,
        peak_r: f32,
        rms_l: f32,
        rms_r: f32,
        active_voices: u16,
    },
    /// Respuesta de preset
    PresetLoaded { preset_id: String, success: bool },
}

/// Trait para permitir a plugins derivados añadir comandos IPC sin modificar el core.
pub trait IpcExtensionHandler: Send + Sync + 'static {
    fn handle_custom_command(
        &self,
        command_name: &str,
        payload: &serde_json::Value,
    ) -> Option<serde_json::Value>;
}
```

### 7.2 Streaming de Medidores con Balística Atómica y Cero Contrapresión

El hilo de audio calcula los picos de forma atómica en tiempo constante $O(1)$:

```rust
// Dentro de DspEngine::process_block()
let mut max_l = 0.0_f32;
let mut max_r = 0.0_f32;

for i in 0..buffer_len {
    max_l = max_l.max(outputs[0][i].abs());
    max_r = max_r.max(outputs[1][i].abs());
}

self.peak_l_cell.store(max_l.to_bits(), Ordering::Relaxed);
self.peak_r_cell.store(max_r.to_bits(), Ordering::Relaxed);
```

El hilo de interfaz gráfica (Rust GUI timer o evaluate script) lee las celdas atómicas a 60 FPS:
- **Zero Backpressure**: Si la interfaz se ralentiza o pierde un frame, el valor atómico se sobreescribe. El hilo de audio jamás se bloquea esperando confirmación de la GUI.
- **Push Directo**: En lugar de `fetch('/api/telemetry')` con sobrecarga HTTP, Rust ejecuta `webview.evaluate_script("window.__onMeterFrame(peakL, peakR)")` o inyecta en el objeto `createSource` de `@audio-ui/react`.

---

## 8. Contratos de Interfaz en TypeScript

```typescript
export interface ParamDescriptor {
  index: number;
  id: string;
  displayName: string;
  min: number;
  max: number;
  defaultValue: number;
  unit: string;
  scale: 'linear' | 'log' | 'db' | 'exp';
}

export type GuiCommand =
  | { cmd: 'ParamGestureBegin'; data: { param_id: number } }
  | { cmd: 'ParamSetValue'; data: { param_id: number; value: number } }
  | { cmd: 'ParamGestureEnd'; data: { param_id: number } }
  | { cmd: 'MidiNoteOn'; data: { note: number; velocity: number } }
  | { cmd: 'MidiNoteOff'; data: { note: number } }
  | { cmd: 'RequestResize'; data: { width: number; height: number } };

export interface MeterFrame {
  peakL: number;
  peakR: number;
  rmsL: number;
  rmsR: number;
  activeVoices: number;
}

export interface PluginIpcBridge {
  postCommand: (cmd: GuiCommand) => void;
  onParamSync: (callback: (paramId: number, value: number) => void) => () => void;
  onMeterFrame: (callback: (frame: MeterFrame) => void) => () => void;
}
```

---

## 9. Ejemplos de Implementación de Referencia

### 9.1 Ejemplo 1: Efecto de Saturación Estéreo (`AudioEffect`)

```rust
use base_plugin_core::{
    DspEngine, HostTransportContext, LiveParamSnapshot, MidiEvent, MidiOutputBuffer,
    ProcessStatus, ParamDescriptor, ParamScale,
};

pub struct StereoDriveEffect {
    sample_rate: f32,
    peak_l: std::sync::atomic::AtomicU32,
    peak_r: std::sync::atomic::AtomicU32,
}

impl DspEngine for StereoDriveEffect {
    type Telemetry = (f32, f32);

    fn initialize(&mut self, sample_rate: f32, _max_buffer_size: usize) {
        self.sample_rate = sample_rate;
    }

    fn reset(&mut self) {}

    fn process_block(
        &mut self,
        inputs: &[&[f32]],
        outputs: &mut [&mut [f32]],
        _midi_in: &[MidiEvent],
        _midi_out: &mut MidiOutputBuffer<'_>,
        _context: &HostTransportContext,
        params: &LiveParamSnapshot,
    ) -> ProcessStatus {
        let drive = params.get_plain(0); // Drive: 1.0 .. 20.0
        let mix = params.get_plain(1);   // Mix: 0.0 .. 1.0

        let num_samples = outputs[0].len();
        let mut max_l = 0.0_f32;
        let mut max_r = 0.0_f32;

        for i in 0..num_samples {
            let in_l = inputs[0][i];
            let in_r = inputs[1][i];

            let wet_l = (in_l * drive).tanh();
            let wet_r = (in_r * drive).tanh();

            let out_l = in_l * (1.0 - mix) + wet_l * mix;
            let out_r = in_r * (1.0 - mix) + wet_r * mix;

            outputs[0][i] = out_l;
            outputs[1][i] = out_r;

            max_l = max_l.max(out_l.abs());
            max_r = max_r.max(out_r.abs());
        }

        self.peak_l.store(max_l.to_bits(), std::sync::atomic::Ordering::Relaxed);
        self.peak_r.store(max_r.to_bits(), std::sync::atomic::Ordering::Relaxed);

        ProcessStatus::Normal
    }

    fn capture_telemetry(&self) -> Self::Telemetry {
        let l = f32::from_bits(self.peak_l.load(std::sync::atomic::Ordering::Relaxed));
        let r = f32::from_bits(self.peak_r.load(std::sync::atomic::Ordering::Relaxed));
        (l, r)
    }
}
```

### 9.2 Ejemplo 2: Sintetizador Monofónico Sustractivo (`Instrument`)

```rust
use base_plugin_core::{
    DspEngine, HostTransportContext, LiveParamSnapshot, MidiEvent, MidiMessage,
    MidiOutputBuffer, ProcessStatus,
};
use dsp_core::filters::StateVariableFilter;

pub struct MonophonicSynth {
    sample_rate: f32,
    phase: f32,
    current_freq_hz: f32,
    target_freq_hz: f32,
    gate: bool,
    filter: StateVariableFilter,
}

impl DspEngine for MonophonicSynth {
    type Telemetry = f32;

    fn initialize(&mut self, sample_rate: f32, _max_buffer_size: usize) {
        self.sample_rate = sample_rate;
        self.filter.set_sample_rate(sample_rate);
    }

    fn reset(&mut self) {
        self.phase = 0.0;
        self.filter.reset();
    }

    fn process_block(
        &mut self,
        _inputs: &[&[f32]],
        outputs: &mut [&mut [f32]],
        midi_in: &[MidiEvent],
        _midi_out: &mut MidiOutputBuffer<'_>,
        _context: &HostTransportContext,
        params: &LiveParamSnapshot,
    ) -> ProcessStatus {
        for event in midi_in {
            match event.message {
                MidiMessage::NoteOn { note, .. } => {
                    self.target_freq_hz = 440.0 * 2.0_f32.powf((note as f32 - 69.0) / 12.0);
                    self.current_freq_hz = self.target_freq_hz;
                    self.gate = true;
                }
                MidiMessage::NoteOff { .. } => {
                    self.gate = false;
                }
                _ => {}
            }
        }

        let cutoff = params.get_plain(0); // Cutoff: 20 .. 20000 Hz
        let resonance = params.get_plain(1); // Resonance: 0.1 .. 10.0
        self.filter.set_params(cutoff, resonance);

        let phase_inc = self.current_freq_hz / self.sample_rate;
        let num_samples = outputs[0].len();

        for i in 0..num_samples {
            let raw_osc = if self.gate {
                (self.phase * 2.0) - 1.0 // Diente de sierra básica
            } else {
                0.0
            };

            self.phase = (self.phase + phase_inc).fract();
            let filtered = self.filter.process_lowpass(raw_osc);

            outputs[0][i] = filtered;
            outputs[1][i] = filtered;
        }

        ProcessStatus::Normal
    }

    fn capture_telemetry(&self) -> Self::Telemetry {
        self.current_freq_hz
    }
}
```

---

## 10. Conclusión

Esta especificación desacopla el 100% de los elementos de infraestructura de audio de TEPUI:
1. Elimina todos los enumeradores folklóricos, endpoints de compra y parámetros fijos del núcleo.
2. Reemplaza comprobaciones delta manuales por el almacén atómico `AtomicParamBank` con comprobación $O(1)$.
3. Corrige la contención de línea de caché en `SeqLockArray` con alineación a 64 bytes (`#[repr(C, align(64))]`).
4. Provee aislamiento de perfil de WebView2 por plugin en `%LOCALAPPDATA%` con subclassing Win32 seguro.
5. Garantiza que la plantilla base pueda compilar de forma aislada y servir de cimiento para cualquier procesador de dinámica, efecto o instrumento de audio profesional.
