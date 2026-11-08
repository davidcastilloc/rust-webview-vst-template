# TEPUI Decoupling and Component Ecosystem Master Blueprint

**Documento**: `TEPUI_DECOUPLING_AND_COMPONENT_ECOSYSTEM_MASTER_BLUEPRINT.md`  
**Autor**: Equipo de Arquitectura de Audio (Worker 1)  
**Fecha**: 2026-11-08  
**Versión**: 1.0.0 — Golden Master Architectural Specification  
**Estado**: Aprobado para Implementación  
**Alcance**: Especificación maestra ejecutiva que consolida el desacoplamiento de la plantilla base de plugins de audio frente a la lógica de negocio de TEPUI (R1), la evaluación y decisión formal de la librería de componentes y bloques DSP (R2), y la rúbrica independiente de validación técnica (R3).

---

## 1. Visión Ejecutiva y Objetivos de la Transformación

El sintetizador e instrumento virtual TEPUI integra un motor de audio de última generación (síntesis por tablas de ondas 3D, muestreo cromático, aceleración local en NPU Intel AI Boost e inferencia en Cloudflare Workers AI) complementado por una interfaz gráfica acelerada por hardware sobre `wry`/WebView2 y React 19.

No obstante, la investigación arquitectónica demostró que la infraestructura de desarrollo de plugins de audio se encontraba monolíticamente entrelazada con el producto TEPUI:
- Afinaciones folclóricas venezolanas (arpa llanera, cuatro, ritmos de joropo y merengue) cableadas en bucles centrales de DSP.
- Almacén de parámetros manual de 60+ campos atómicos acoplados al sintetizador TEPUI.
- Rutas pseudo-REST y webhooks de pasarelas de pago incrustados dentro del binario VST3.
- Colisión de archivos SQLite de WebView2 en `%TEMP%/Tepui/WebView2_Studio` entre múltiples instancias concurrentes en el DAW.
- Polling HTTP a 12.5 Hz (`/api/telemetry`) que saturaba la recolección de basura (GC) en el motor web.

Este **Master Blueprint** consolida y formaliza la arquitectura desacoplada para transformar el repositorio en un **ecosistema modular de producción**, compuesto por una plantilla base agnóstica de plugins (VST3/CLAP/Standalone), un crate compartido de primitivas DSP seguras en tiempo real (`dsp_core`), un sistema de interfaz gráfica de 3 niveles basado en `@audio-ui/react` y `@audio-ui/core`, y un harness universal de certificación contractual.

---

## 2. Matriz de Trazabilidad de Requisitos y Criterios de Aprobación

```
+-----------------------------------------------------------------------------------------------------------------------------+
| MATRIZ DE TRAZABILIDAD: REQUISITOS (R1, R2, R3) -> ESPECIFICACIÓN -> ARTEFACTO                                             |
+----+------------------------------------+-------------------------------------------+---------------------------------------+
| ID | Requisito del Usuario              | Solución Arquitectónica Formal            | Artefacto / Sección de Referencia     |
+----+------------------------------------+-------------------------------------------+---------------------------------------+
| R1 | Arquitectura Desacoplada y         | - Topología multi-crate (core, webview,   | `01_DECOUPLED_PLUGIN_TEMPLATE_        |
|    | Patrones de Diseño Escalables      |   standalone, xtask, dsp_core, tepui).    |   SPECIFICATION.md`                   |
|    | (Límites de crates, interfaces     | - Traits polimórficos DspEngine (PDC:     | - Secciones 2 y 3 (Inventario y DAG)  |
|    | DspEngine, ParamRegistry, IpcBus,  |   latency/tail), ParamRegistry, Snapshot. | - Sección 4 (Traits e Interfaces)     |
|    | flujo lock-free O(1), webview UDF  | - AtomicParamBank O(1) + SeqLockArray(64) | - Sección 5 (Flujo de Parámetros)     |
|    | y telemetría atómica 60 FPS).      | - Win32 subclassing + app://localhost/    | - Secciones 6 y 7 (Webview e IPC)     |
+----+------------------------------------+-------------------------------------------+---------------------------------------+
| R2 | Evaluación y Decisión sobre        | - Adopción de @audio-ui/react y core      | `02_COMPONENT_LIBRARY_DECISION_AND_   |
|    | Librería de Componentes            |   mediante Modelo Híbrido de 3 Niveles.   |   INTEGRATION.md`                     |
|    | (Evaluación comparativa UI,        | - Descarte de in-house y copy-paste puro. | - Sección 2 (Matriz comparativa)      |
|    | decisión justificada de 3 niveles, | - Push directo 60 FPS (createSource).     | - Sección 3 (Modelo de 3 Niveles)     |
|    | eliminación de HTTP polling, y     | - Extracción del crate dsp_core libre de  | - Sección 5 (Push 60 FPS sin HTTP)    |
|    | extracción de dsp_core RT-safe).   |   allocations y seguro para tiempo real.  | - Sección 6 (Crate dsp_core)          |
+----+------------------------------------+-------------------------------------------+---------------------------------------+
| R3 | Rúbrica de Validación              | - 4 Compuertas Binarias Obligatorias      | `03_ARCHITECTURAL_VALIDATION_RUBRIC.  |
|    | Arquitectónica Independiente       |   (GATE-01 a GATE-04).                    |   md`                                 |
|    | (Compuertas binarias Pass/Fail,    | - Matriz cuantitativa de 5 dimensiones    | - Sección 2 (Compuertas Binarias)     |
|    | matriz cuantitativa 0-100 pts,     |   (0-100 pts, Certificación Oro >= 95).   | - Sección 3 (Matriz 5 Dimensiones)    |
|    | macro declare_plugin_contract! y   | - Macro universal declare_plugin_contract!| - Sección 5 (Macro universal)         |
|    | harness de test agnóstico).        |   y harness de prueba DSP agnóstico.      | - Secciones 6 y 7 (Harness y Script)  |
+----+------------------------------------+-------------------------------------------+---------------------------------------+
```

---

## 3. Topología de Arquitectura Integral y Diagramas de Sistema

### 3.1 Grafo Acíclico Dirigido (DAG) del Espacio de Trabajo Cargo y NPM

```
                           ┌────────────────────────────────────────┐
                           │           base_plugin_xtask            │
                           │     (CLI, Bundles VST3/CLAP, SFX)      │
                           └───────────────────┬────────────────────┘
                                               │
                                               ▼
                           ┌────────────────────────────────────────┐
                           │          base_plugin_webview           │
                           │   (Wry Host, Win32 Subclass, IPC Bus)  │
                           └───────────────────┬────────────────────┘
                                               │
                                               ▼
    ┌────────────────────────────┐    ┌────────────────────────────────────────┐
    │   base_plugin_standalone   │───►│            base_plugin_core            │
    │   (CPAL, Midir, Runner)    │    │ (DspEngine, AtomicParamBank, SeqLock)  │
    └────────────────────────────┘    └───────────────────┬────────────────────┘
                                                          │
                                                          ▼
                                      ┌────────────────────────────────────────┐
                                      │                dsp_core                │
                                      │ (TPT ZDF, ADSR, Retardos, Sanitizers)  │
                                      └────────────────────────────────────────┘
                                                          ▲
                                                          │
                                      ┌───────────────────┴────────────────────┐
                                      │              tepui_synth               │
                                      │  (Producto Concreto: Wavetable 3D,     │
                                      │   Sampler, Folklore, Extensiones AI)   │
                                      └────────────────────────────────────────┘

    -----------------------------------------------------------------------------
    FRONTEND NPM WORKSPACE (packages/):
    ┌───────────────────────────────────┐     ┌──────────────────────────────────┐
    │       @audio-ui/react & core      │────►│       base-plugin-ui (Bridge)    │
    │  (Tier 1: Primitivas Headless)    │     │  (Tier 2: Adapters, IPC Hooks)   │
    └───────────────────────────────────┘     └─────────────────┬────────────────┘
                                                                │
                                                                ▼
                                              ┌──────────────────────────────────┐
                                              │       tepui-ui (Tier 3 Skin)     │
                                              │  (Layout Eurorack, Skins 1px)    │
                                              └──────────────────────────────────┘
```

### 3.2 Concurrencia y Topología de Hilos del Sistema

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              HILO DAW DE AUDIO (Real-Time)                              │
│   Prioridad: Crítica / Tiempo Real Estricto                                              │
│   Invariantes: Cero Heap Allocations, Cero Mutex, Cero Bloqueos, Tiempo O(1)           │
│                                                                                         │
│   [Audio In] ──► DspEngine::process_block() ──► [Audio Out]                             │
│                         │                ▲                                              │
│        Atomic Metrics   │                │ Snapshot O(1)                                │
│        (Peak L / R)     │                │                                              │
│                         ▼                │                                              │
│                 ┌───────────────┐ ┌───────────────┐                                     │
│                 │ AtomicU32     │ │ AtomicParam   │                                     │
│                 │ Ballistics    │ │ Bank          │                                     │
│                 └───────┬───────┘ └───────▲───────┘                                     │
└─────────────────────────┼─────────────────┼─────────────────────────────────────────────┘
                          │                 │ Relaxed / Acquire-Release
                          │                 │
┌─────────────────────────┼─────────────────┼─────────────────────────────────────────────┐
│                         ▼                 │          HILO DE CONTROL / GUI (Rust)       │
│                  Timer 60 Hz ─────────────┤                                             │
│                  evaluate_script          │ setter.begin_set_parameter(id)              │
│                         │                 │ setter.set_parameter(id, val)               │
│                         │                 │ setter.end_set_parameter(id)                │
│                         ▼                 │                                             │
│                 ┌─────────────────────────┴────────────────┐                            │
│                 │   Wry WebView Engine (WebView2 / WebKit) │                            │
│                 └─────────────────────────┬────────────────┘                            │
└───────────────────────────────────────────┼─────────────────────────────────────────────┘
                                            │ Bidirectional IPC
                                            ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                 HILO DE V8 / REACT 19 (Webview)                         │
│                                                                                         │
│   window.__onMeterFrame(pL, pR) ──► vuMeterSource.set() ──► Direct DOM (Zero VDOM Churn)│
│                                                                                         │
│   Interacción del Usuario (Knob drag) ──► postMessage("ParamGestureBegin", "ParamSetValue")│
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Pipeline de Sincronización de Parámetros y Telemetría a 60 FPS

```
+----------------------------------------------------------------------------------------------------+
| PIPELINE DE PARÁMETROS Y TELEMETRÍA BIDIRECCIONAL                                                  |
+----------------------------------------------------------------------------------------------------+
| Dirección | Etapa 1: Origen      | Etapa 2: Transporte         | Etapa 3: Destino                  |
+-----------+----------------------+-----------------------------+-----------------------------------+
| GUI -> DSP| React Knob Pointer   | Wry IPC postMessage         | - ParamSetter (Automatización DAW)|
|           | (begin, set, end)    | JSON / Compact Framing      | - AtomicParamBank (store Release) |
|           |                      |                             | - generation.fetch_add(1)         |
+-----------+----------------------+-----------------------------+-----------------------------------+
| DSP -> GUI| DspEngine process    | Celdas Atómicas Peak L / R  | Timer Rust 60 Hz ->               |
| (Telem.)  | (cálculo de picos)   | (Ordering::Relaxed)         | webview.evaluate_script ->        |
|           |                      |                             | vuMeterSource.set() (Direct DOM)  |
+-----------+----------------------+-----------------------------+-----------------------------------+
| DAW -> DSP| DAW Automation Lane  | ParamSetter callback        | AtomicParamBank.store()           |
|           | (Playback / Latch)   |                             | DspEngine actualiza snapshot      |
+-----------+----------------------+-----------------------------+-----------------------------------+
```

### 3.4 Ciclo de Vida de Webview, Subclassing Win32 y Sandbox CSP

```
[DAW Host crea ventana padre HWND]
               │
               ▼
[base_plugin_webview::create_native_webview]
  1. Deriva UDF: %LOCALAPPDATA%/<Vendor>/<PluginName>/WebViewProfile
  2. Registra protocolo en memoria: app://localhost/ (Cero sockets TCP)
  3. Aplica CSP: default-src 'self' app:; script-src 'self' 'unsafe-inline' app:;
  4. Instala Subclassing seguro: comctl32::SetWindowSubclass(hwnd, proc, SUBCLASS_ID)
               │
               ▼
[Ciclo Activo de la Ventana]
  - Intercepta WM_SIZE ──► Ajusta LogicalSize en Wry sin bloquear el host.
  - Sincroniza DPI fraccionario (125%, 150%, 175%) ──► Physical px = Logical px * DPI.
               │
               ▼
[Cierre en DAW Host (WM_DESTROY)]
  1. KillTimer de bombeo y telemetría.
  2. RemoveWindowSubclass(hwnd, proc, SUBCLASS_ID).
  3. Rompe referencias cíclicas Rc<WebView>.
  4. Desmantela procesos Edge WebView2 de forma limpia sin fugas de handles COM.
```

---

## 4. Consolidación de Estrategia de Desacoplamiento de Dominio

La plantilla base desacoplada erradica todos los acoplamientos específicos de TEPUI identificados en el inventario:

1. **Desacoplamiento Cultural y Folclórico**:
   - `ArpMode::Joropo` y `Merengue` se segregan a `tepui_synth`. El arpegiador del crate base es estrictamente genérico (Up, Down, UpDown, Random).
   - Las tablas microtonales de afinación de arpa llanera se trasladan a archivos de definición estándar (`.scl`/`.kbm`).
   - El voicing de acordes de cuatro (`CHORD:STRUM`) se convierte en una estructura dinámica inyectable por preset.

2. **Desacoplamiento de Servicios y Licenciamiento en la Nube**:
   - Se eliminan del plugin base todos los endpoints HTTP pseudo-REST, URLs a Cloudflare AI Gateway, y funciones de validación de compra webhook (`api/webhooks/checkout`). Ningún plugin de audio de nivel profesional debe procesar webhooks de compra dentro del hilo de interfaz gráfica.

3. **Desacoplamiento Paramétrico y de Proyección**:
   - Se reemplaza el struct `LiveParamStore` de 60 variables atómicas fijadas a mano por `AtomicParamBank<MAX_PARAMS>` direccionable por `ParamIndex` numérico continuo.
   - La comprobación delta $O(M)$ repetida en cada bloque de audio se reemplaza por la verificación de generación global $O(1)$ (`AtomicU64`).

4. **Desacoplamiento de Almacenamiento Local**:
   - Se reemplaza la ruta fija `%TEMP%/Tepui/WebView2_Studio` por perfiles dinámicos aislados en `%LOCALAPPDATA%/<Vendor>/<PluginName>/WebViewProfile`, eliminando los riesgos de bloqueo de base de datos SQLite entre múltiples instancias concurrentes.

---

## 5. Decisión Formal de Librería de Componentes y Crate DSP

### 5.1 Decisión de UI: Modelo Híbrido de 3 Niveles
Se adoptan formalmente `@audio-ui/react` y `@audio-ui/core`:
- **Tier 1 (Foundational)**: Primitivas headless con física de arrastre vertical, escalado logarítmico/exponencial, accesibilidad WAI-ARIA nativa, jerarquía canónica de medidores (`Meter.Root`, `Meter.Channels`, `Meter.Channel`, `Meter.Track`, `Meter.Indicator`, `Meter.Peak`, `Meter.Label`) y señales reactivas de alto rendimiento (`createSource`).
- **Tier 2 (Bridge Adapter)**: Paquete `@plugin-base/ui-bridge` con componentes pre-integrados (`PluginKnob`, `PluginFader`, `PluginLevelMeter`, `PluginXYPad`, `PluginPlot`) conectados al bus IPC y gestos del DAW con demarcación dual (`ParamGestureBegin`/`ParamSetValue`/`ParamGestureEnd` activos para arrastre de puntero, navegación accesible por teclado y pasos de rueda de ratón con debounce de 200 ms).
- **Tier 3 (Presentation Skin)**: Tokens CSS de diseño del plugin concreto (Flush Architectural Grid con bordes de `1px`, contraste de alto impacto, y disposición modular).

### 5.2 Decisión DSP: Crate `dsp_core`
Se extrae el crate independiente `crates/dsp_core` libre de asignaciones de memoria:
- **Matemáticas**: Conversiones de ganancia a decibelios (`db_to_gain`), pitch a hercios (`midi_to_hz`), e interpolación Hermite/Cúbica.
- **Primitivas Lock-Free**: `OnePoleSmoother` (suavizado exponencial anti-zipper con corte instantáneo de cola denormal $\le 10^{-5}$) y `SeqLockArray<N>` con patrón de búfer intermedio en la pila (`temp`), retorno booleano y alineación estricta a línea de caché de 64 bytes (`#[repr(C, align(64))]`) garantizando 0 lecturas fragmentadas (*torn reads*).
- **Filtros**: Cytomic TPT State Variable Filter (SVF ZDF), Moog Ladder 24dB y filtros peine.
- **Modulación y Dinámica**: Generadores ADSR/AHDSR anti-clic, LFOs polimórficos, limitadores brickwall lookahead y compresores feed-forward.
- **Protección y Sanitización**: Macro inline `flush_denormal(x)` contra subnormales y sanitizador IEEE 754 contra `NaN` e `Inf`.

---

## 6. Rúbrica de Validación Arquitectónica Resumida

La certificación independiente de la plantilla se evalúa bajo dos instrumentos:

### 6.1 Compuertas Binarias Obligatorias (Pass/Fail Gates)
- **`GATE-01: Zero TEPUI Domain Leaks`**: Tolerancia CERO a términos culturales, folclóricos o rutas hardcodeadas de TEPUI en la plantilla base.
- **`GATE-02: Real-Time Safety & Allocations`**: Cero llamadas a `malloc`/`free` o primitivas bloqueantes en `DspEngine::process_block()` verificado con `assert_process_allocs`.
- **`GATE-03: Crate Boundaries & Clean DAG`**: Aislamiento estricto de crates (`base_plugin_core` y `dsp_core` independientes de Wry y plugins concretos).
- **`GATE-04: Universal Contract Compliance`**: Cero controles huérfanos en la interfaz gráfica y verificación matemática de impacto de cada parámetro sobre el motor DSP excitada por estímulo determinista de banda ancha (`LinearChirp` de 20 Hz a 20 kHz), certificando filtros AC sin falsos negativos.

### 6.2 Matriz Cuantitativa (0–100 Puntos)
- **Dimensión 1 (25 pts)**: Pureza de Dominio y ausencia absoluta de residuos propietarios.
- **Dimensión 2 (20 pts)**: Modularidad, estabilidad de dependencias e independencia de compilación.
- **Dimensión 3 (25 pts)**: Seguridad en tiempo real, determinismo temporal y sanitización aritmética.
- **Dimensión 4 (15 pts)**: Robustez del ciclo de vida de Webview, subclassing Win32 y sandbox CSP.
- **Dimensión 5 (15 pts)**: Cumplimiento de las 7 compuertas universales de contrato UI↔DSP.
- **Dictamen**: Puntuación $\ge 95$ puntos otorga la **Certificación Oro (Template Certified Gold)** para producción.

---

## 7. Plan de Implementación y Migración por Fases

La ejecución técnica de este blueprint se organiza en cuatro fases estructuradas:

```
FASE 1: EXTRACCIÓN Y ESTABILIZACIÓN DEL CRATE DSP_CORE
├── Crear crates/dsp_core/ con soporte std/no_std.
├── Mover OnePoleSmoother y SeqLockArray (con #[repr(C, align(64))]).
├── Extraer StateVariableFilter (TPT ZDF), AdsrEnvelope, Lfo y utilidades matemáticas.
├── Reemplazar ArpMode::Joropo/Merengue en fx.rs por ratios de delay genéricos.
└── Validar con suite de tests unitarios: cargo test -p dsp_core.

FASE 2: REFACTORIZACIÓN DEL NÚCLEO BASE_PLUGIN_CORE Y RUNNER
├── Crear crates/base_plugin_core/ con traits DspEngine, ParamRegistry, LiveParamSnapshot.
├── Implementar AtomicParamBank<MAX_PARAMS> con contador de generación AtomicU64.
├── Crear base_plugin_standalone utilizando CPAL y Midir agnóstico.
└── Verificar compilación independiente: cargo check -p base_plugin_core.

FASE 3: HOST WEBVIEW NATIVO, PUENTE IPC Y TIER 2 DE REACT
├── Crear crates/base_plugin_webview/ con Wry, Win32 subclassing y perfil UDF dinámico.
├── Implementar protocolo virtual serverless app://localhost/ con CSP estricto.
├── Configurar bus de comandos tipados GuiToHostCommand / HostToGuiEvent.
├── Crear paquete packages/base-plugin-ui integrando @audio-ui/react y @audio-ui/core.
├── Implementar push de telemetría a 60 FPS hacia createSource (sustituyendo /api/telemetry).
└── Deprecar script oledEngine.ts y eliminar lienzos canvas duplicados en EurorackMatrix.

FASE 4: AISLAMIENTO DE TEPUI_SYNTH Y CERTIFICACIÓN GOLD
├── Reubicar lógica de síntesis de TEPUI en crates/plugins/tepui_synth/.
├── Aplicar macro universal declare_plugin_contract! sobre TEPUI y sobre plugin de ejemplo.
├── Ejecutar script de auditoría automatizada audit_plugin_architecture.ps1.
└── Obtener certificación Template Certified Gold (>= 95 puntos y 4 Compuertas PASS).
```

---

## 8. Verificación y Protocolo de Certificación

Para auditar y validar la arquitectura:

```powershell
# 1. Validación de Compuerta GATE-01 (Cero fugas de dominio)
Get-ChildItem -Path "crates/base_plugin_*","crates/dsp_core","packages/base-plugin-ui" -Recurse -Include "*.rs","*.toml","*.tsx","*.ts" | Select-String -Pattern "(?i)(tepui|joropo|merengue|llanera|bandola|cumaco|quitiplas|furruco|folklore|gran[\s_]?sabana|cañ[oó]n[\s_]?del[\s_]?tepui|webview2_studio|cloudlicense|cloud_license|DEFAULT_CF_EDGE_WORKER_URL|(?<![a-z0-9])cuatro(?![a-z0-9]))"

# 2. Validación de Compuerta GATE-02 (Cero asignaciones en hilo de audio)
cargo test -p base_plugin_core --features assert_process_allocs

# 3. Validación de Compuerta GATE-03 (DAG de crates estricto)
cargo tree -p base_plugin_core
cargo tree -p dsp_core

# 4. Validación de Compuerta GATE-04 (Harness de Contrato Universal)
cargo test --test certification_contract
```

---

## 9. Conclusión y Dictamen Arquitectónico

La suite arquitectónica conformada por:
1. `01_DECOUPLED_PLUGIN_TEMPLATE_SPECIFICATION.md`
2. `02_COMPONENT_LIBRARY_DECISION_AND_INTEGRATION.md`
3. `03_ARCHITECTURAL_VALIDATION_RUBRIC.md`
4. `TEPUI_DECOUPLING_AND_COMPONENT_ECOSYSTEM_MASTER_BLUEPRINT.md`

proporciona una especificación exhaustiva, rigurosa y directamente ejecutable que satisface el 100% de los requerimientos R1, R2 y R3 aprobados. Convierte la tecnología de vanguardia desarrollada para TEPUI en un estándar de ingeniería reutilizable para toda una generación de nuevos plugins de audio profesional.
