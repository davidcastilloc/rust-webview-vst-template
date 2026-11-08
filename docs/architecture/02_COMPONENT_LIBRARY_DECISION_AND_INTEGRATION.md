# Decisión e Integración de Librería de Componentes y Ecosistema DSP

**Documento**: `02_COMPONENT_LIBRARY_DECISION_AND_INTEGRATION.md`  
**Autor**: Equipo de Arquitectura de Audio (Worker 1)  
**Fecha**: 2026-11-08  
**Estado**: Aprobado para Implementación  
**Alcance**: Evaluación comparativa, decisión formal y modelo de integración de componentes de interfaz de usuario (`@audio-ui/react`, `@audio-ui/core`) y extracción del crate reutilizable de procesamiento de audio en tiempo real (`dsp_core`).

---

## 1. Resumen Ejecutivo y Decisiones Formales

Para consolidar un ecosistema de plugins de audio profesional de alto rendimiento sobre el stack Rust (`nih-plug` + `wry` WebView2) y React 19, se han adoptado dos decisiones arquitectónicas de carácter formal e inapelable:

1. **Decisión Formal sobre Librería de Interfaz de Usuario (UI)**:  
   **ADOPTAR `@audio-ui/react` y `@audio-ui/core` mediante una Arquitectura Híbrida de 3 Niveles**.  
   - Se **rechaza** el desarrollo in-house de una librería de componentes desde cero: el costo de ingeniería para reinventar la física de arrastre vertical, escalas no lineales logarítmicas/exponenciales, accesibilidad WAI-ARIA y motores de animación sin asignaciones de basura excede los beneficios de personalización y genera una deuda de mantenimiento innecesaria.  
   - Se **rechaza** el modelo de bloques copy-paste desarticulados (tipo shadcn clásico sin anclaje a paquetes semánticos) para la lógica de interacción y matemáticas de audio, debido al riesgo inminente de divergencia de bugs y discrepancias funcionales entre distintos plugins del catálogo.  
   - La arquitectura adopta las primitivas headless de `@audio-ui/react` y el motor matemático agnóstico de `@audio-ui/core` en el **Nivel 1 (Tier 1)**, encapsuladas por un adaptador de plantilla **Nivel 2 (Tier 2)** (`@plugin-base/ui-bridge`) que enlaza bidireccionalmente el IPC y los gestos del DAW, permitiendo que cada plugin defina únicamente sus tokens visuales y layout en el **Nivel 3 (Tier 3)**.

2. **Decisión Formal sobre Librería de Bloques DSP/Audio**:  
   **EXTRAER EL CRATE COMPARTIDO `dsp_core` (LIBRE DE ALLOCATIONS Y SEGURO PARA TIEMPO REAL)**.  
   - Actualmente, `crates/synth_core` mezcla primitivas matemáticas universales (`OnePoleSmoother`, `SeqLockArray`, filtros SVF, envolventes ADSR) con la lógica musical de TEPUI (`ArpMode::Joropo`, afinaciones de arpa llanera, acordes de cuatro venezolano y motores de sampler polifónico de 16 voces).  
   - Se extrae un crate independiente (`dsp_core`) compatible con `#![no_std]` (o con `std` sin asignaciones de heap en tiempo de proceso), con protección automática contra números subnormales (*denormals*) y sanitización IEEE 754, sirviendo como fundamento común para compresores, ecualizadores, delays, reverbs y sintetizadores.

---

## 2. Evaluación Comparativa Rigurosa de Alternativas de UI

### 2.1 Requisitos Únicos del Software de Audio Frente a la Web Tradicional

Las librerías de componentes web generales (Radix UI, Headless UI, Material UI, shadcn tradicional de formularios) no están preparadas para las exigencias de un plugin de audio VST3/CLAP:

1. **Física de Arrastre Vertical en Controles Rotativos**:  
   En audio, los diales y perillas no se giran siguiendo la curvatura del círculo con el cursor; se arrastran verticalmente con una relación de sensibilidad calibrada ($\sim 150 \text{ px}$ de recorrido completo) y tecla modificadora `Shift` para micro-ajuste de precisión ($0.1\times$).
2. **Funciones de Transferencia No Lineales**:  
   La frecuencia de corte de un filtro abarca de $20 \text{ Hz}$ a $20 \text{ kHz}$ de forma logarítmica; la ganancia se expresa en decibelios ($-\infty \text{ dB}$ a $+6 \text{ dB}$); y las fases de envolvente exigen curvaturas exponenciales continuas.
3. **Telemetría a 60 FPS sin Sobrecarga del Virtual DOM (VDOM Churn)**:  
   Los medidores de pico (Peak/RMS), analizadores FFT de 64 bandas y osciloscopios se refrescan a 60 FPS. Actualizar el estado convencional de React (`useState`) a esta tasa genera una avalancha de objetos en el recolector de basura (GC) y provoca micro-tirones (*frame drops*) en el WebView2.
4. **Ciclo de Vida de Gestos DAW (Automatización Táctil y Accesible)**:  
   La grabación de automatización en DAWs (modos Touch, Latch y Write) exige la delimitación estricta de gestos: `begin_set_parameter` al iniciar la interacción (presión de puntero, primera pulsación de teclado o primer paso de rueda) y `end_set_parameter` al finalizarla (liberación de puntero, confirmación de tecla o debounce tras ráfaga de rueda). Un evento `onChange` plano de HTML5 o una vinculación exclusiva a puntero corrompe el historial de deshacer (*undo stack*) del DAW en navegación accesible por teclado o rueda de ratón.

### 2.2 Matriz Comparativa Multidimensional

| Criterio de Evaluación | Opción A: Primitivas Headless `@audio-ui/react` + `@audio-ui/core` | Opción B: Desarrollo In-House Propietario desde Cero | Opción C: Bloques Copy-Paste Puros (Shadcn sin Paquetes) |
|---|---|---|---|
| **Velocidad de Salida al Mercado** | **Inmediata**: Primitivas probadas y maduras listas para uso. | **Muy Lenta**: 4 a 6 meses de desarrollo y estabilización de matemáticas. | **Media**: Requiere copiar y adaptar manualmente código en cada repo. |
| **Física de Perilla (Rotary Drag)** | **Excelente**: Modos vertical, circular, incremental y tecla `Shift` nativos. | Requiere escribir y probar eventos de puntero en Windows, macOS y Linux. | Código duplicado susceptible a divergencias entre plugins. |
| **Escalas y Mapeos de Audio** | **Nativo**: Escalas logarítmicas, exponenciales, dB y anclaje bipolar integradas. | Debe codificarse y validarse contra estándares acústicos a mano. | Funciones matemáticas copiadas con riesgo de bugs no corregidos. |
| **Telemetría a 60 FPS sin VDOM** | **Nativo vía `createSource`**: Modifica propiedades DOM/CSS directamente sin reconciliar React. | Requiere diseñar un motor de señales o suscripciones DOM propietario. | Tiende a caer en `useState` lento o selectores `querySelector` frágiles. |
| **Demarcación de Gestos DAW** | **Nativa**: Separación desacoplada entre `onValueChange` y `onValueCommitted`. | Debe implementarse una máquina de estados para capturar gestos. | Implementación ad-hoc con riesgo de omitir `begin`/`end` gestures. |
| **Accesibilidad (WAI-ARIA & WCAG)** | **Completa**: Atributos `role="slider"`, `aria-valuenow`, soporte de teclado (flechas, Home, End). | Elevado riesgo de omitir soporte de accesibilidad y tabulaciones de foco. | Inconsistente; depende de la disciplina individual de cada desarrollador. |
| **Catálogo de Controles** | Knobs, Faders, XY Pads, Medidores, Plots FFT, Envolventes, Secuenciadores, Teclados. | Habitualmente limitado a Knob y Fader por restricciones de presupuesto. | Cobertura variable; envolventes y secuenciadores rara vez disponibles. |
| **Mantenimiento y Corrección de Bugs** | Centralizado upstream con versionado semántico en npm. | Carga permanente de mantenimiento sobre el equipo interno. | Desincronización y deriva de código entre plugins con el tiempo. |

### 2.3 Justificación Técnica y Económica del Descarte

- **Descarte de la Opción B (In-House desde cero)**: Construir una suite de controles accesible, optimizada para 60 FPS y compatible con eventos táctiles y de puntero implica duplicar el trabajo que `@audio-ui` ya ha resuelto de forma canónica. No aporta ventaja competitiva al negocio y drena recursos que deben dedicarse a algoritmos DSP y diseño de sonido.
- **Descarte de la Opción C (Copy-Paste puro)**: Aunque el paradigma copy-paste es útil para componentes visuales estáticos (botones simples, modales), aplicarlo a diales de audio con física matemática compleja introduce deuda técnica instantánea: cualquier corrección en el cálculo logarítmico o en la gestión de eventos de puntero debe replicarse manualmente en todos los repositorios derivados.

---

## 3. Decisión Formal de UI: Modelo Híbrido de 3 Niveles

La solución arquitectónica óptima es el **Modelo Híbrido de 3 Niveles**, el cual combina la robustez de un paquete semántico probado con la flexibilidad estética de skins desacopladas:

```
┌────────────────────────────────────────────────────────────────────────┐
│ TIER 3: Presentación, Skins y Layout Específico del Plugin             │
│  - Chasis Eurorack, paneles industriales, acabados aluminio/madera     │
│  - Tokens CSS (Flush Architectural Grid: continuous 1px borders)       │
│  - Distribución de paneles: <FilterSection>, <DynamicsRack>, etc.      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Inyección de Tokens y Clases CSS
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ TIER 2: Puente de Integración de Plantilla (@plugin-base/ui-bridge)     │
│  - Componentes adaptadores: <PluginKnob>, <PluginFader>, <PluginMeter> │
│  - Hook `usePluginParam(id)`: Sincronización IPC bidireccional         │
│  - Hook `usePluginTelemetry(ch)`: Suscripción createSource 60 FPS      │
│  - Demarcación de gestos DAW: begin_set_param / end_set_param          │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Primitivas Headless y Matemáticas
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ TIER 1: Motor Fundacional (@audio-ui/react y @audio-ui/core)           │
│  - Primitivas Headless: Knob.Root, Fader.Thumb, XYPad.Handle           │
│  - Matemáticas puras: log/exp/dB scalers, bipolar anchors              │
│  - Gestión de puntero: drag vertical, delta de rueda, tecla Shift      │
│  - Señales reactivas de alto rendimiento: createSource                 │
│  - Accesibilidad nativa: WAI-ARIA role="slider" y navegación teclado   │
└────────────────────────────────────────────────────────────────────────┘
```

### 3.1 Especificación de los Tres Niveles

1. **Tier 1 — Motor Fundacional (`@audio-ui/react` y `@audio-ui/core`)**:
   - Reside como dependencia versionada en `package.json`.
   - Provee los componentes atómicos sin estilos (*headless*) y los algoritmos de escalado matemático.
   - Gestiona eventos de puntero nativos (`PointerEvent`) normalizados entre sistemas operativos.

2. **Tier 2 — Puente de Integración de Plantilla (`@plugin-base/ui-bridge`)**:
   - Crate/paquete interno que expone componentes listos para usar en la plantilla base (`PluginKnob`, `PluginFader`, `PluginMeter`, `PluginXYPad`).
   - Envuelve las llamadas de interacción con el bus IPC nativo de `wry`: emite comandos `p_begin`, `p_set` y `p_end` para asegurar transacciones atómicas de automatización en el DAW.
   - Conecta las celdas atómicas de telemetría provenientes de Rust directamente a las fuentes de datos `createSource` de `@audio-ui/react`, puenteando por completo el reconciliador de React.

3. **Tier 3 — Presentación y Skins Específicas del Plugin**:
   - Cada plugin concreto (ej. `tepui-ui`, `reverb-ui`, `compressor-ui`) define su chasis visual mediante variables CSS y componentes de layout.
   - Aplica el sistema **Flush Architectural Grid (`1px` continuous border)**, contrastes industriales y tipografías monoespaciadas sin tocar la lógica matemática de los controles.

---

## 4. Catálogo Técnico y Especificación de Controles de Audio

### 4.1 Inventario de Controles del Ecosistema

```
+---------------------------------------------------------------------------------------------------+
| CATÁLOGO DE CONTROLES DE AUDIO (TIER 1 PRIMITIVE -> TIER 2 WRAPPER)                               |
+---------------------------------------------------------------------------------------------------+
| Componente      | Primitiva Base         | Uso Principal en Plugins               | Frecuencia/Modo       |
+-----------------+------------------------+----------------------------------------+-----------------------+
| PluginKnob      | @audio-ui/react/knob   | Cutoff, Resonancia, Drive, Attack, Mix | Reactivo (IPC Gestures|
| PluginFader     | @audio-ui/react/fader  | Ganancia Master, Faders ADSR, Niveles  | Reactivo (IPC Gestures|
| PluginXYPad     | @audio-ui/react/xypad  | Morfología 2D, Espacio vs Dinámica     | Reactivo (Dual-Axis)  |
| PluginMeter     | @audio-ui/react/meter  | Vúmetros Pico/RMS, Reducción Ganancia  | 60 FPS (createSource) |
| PluginPlot      | @audio-ui/react/plot   | Curvas de Filtro ZDF, FFT Analyzer     | 60 FPS (createSource) |
| PluginEnvelope  | @audio-ui/react/envel. | Envolventes ADSR/AHDSR multipunto      | Interactivo / 60 FPS  |
| PluginSequencer | @audio-ui/react/seq.   | Arpegiadores y Secuenciadores de Paso  | Interactivo / Clock   |
| PluginKeyboard  | @audio-ui/react/piano  | Teclado Virtual con Glissando y Choke  | MIDI Note Events      |
+-----------------+------------------------+----------------------------------------+-----------------------+
```

### 4.2 Especificaciones Detalladas por Control

#### 1. Perillas Rotativas (`PluginKnob`)
- **Modo de Arrastre**: Obligatoriamente `dragMode="vertical"`. El desplazamiento horizontal se ignora para evitar saltos bruscos.
- **Micro-Tuning**: Presionar la tecla `Shift` reduce la velocidad de variación al $10\%$ ($0.1\times$).
- **Reinicio a Valor Predeterminado**: Doble clic sobre la perilla restaura inmediatamente el `default_value`.
- **Anillo de Modulación**: Capa vectorial SVG con `stroke-dasharray` para visualizar profundidades de modulación LFO/envolvente en tiempo real.
- **Edición Numérica**: `Knob.Value` editable permite teclear valores numéricos con unidades (ej. teclear `"2.5k"` interpreta $2,500 \text{ Hz}$).

#### 2. Faders Lineales (`PluginFader`)
- **Orientación**: Vertical por defecto (`orientation="vertical"`).
- **Calibración**: Escala en decibelios con marca prominente en $0 \text{ dB}$ (Unity Gain) y escala expandida entre $-12 \text{ dB}$ y $+6 \text{ dB}$.

#### 3. Superficies de Morfología 2D (`PluginXYPad`)
- **Uso**: Control simultáneo de dos parámetros acoplados (ej. Tiempo de Reverb en eje X vs Difusión en eje Y; o Timbre vs Tensión).
- **Visualización**: Retícula de cuadrante con punto de mira (*crosshair*) e interpolación continua de valores.

#### 4. Medidores Estéreo de Nivel (`PluginMeter`)
- **Balística Acústica**: Ataque casi instantáneo ($< 1 \text{ ms}$) y decaimiento balístico de $300 \text{ ms}$, con barra retenedora de pico (*peak hold*) de $1.5 \text{ s}$.
- **Garantía de Rendimiento**: Conectado estrictamente a `vuMeterSource.set()`. Queda prohibido el paso de datos de nivel mediante `useState` o propiedades de React.

#### 5. Gráfico de Respuesta de Filtro y Analizador Espectral (`PluginPlot`)
- **Ejes**: Eje horizontal logarítmico ($20 \text{ Hz} - 20 \text{ kHz}$), eje vertical lineal ($-18 \text{ dB} - +18 \text{ dB}$).
- **Capas**:
  - `Plot.Curve`: Curva estática/paramétrica calculada a partir de los coeficientes del filtro ZDF ($|H(\omega)|$).
  - `Plot.Trace`: Curva dinámica del analizador de espectro FFT de 64 bandas alimentada a 60 FPS.
  - `Plot.Handle`: Puntos interactivos 2D que permiten arrastrar la frecuencia de corte y la resonancia directamente sobre el gráfico.

---

## 5. Sustitución de Telemetría HTTP Polling por Push Atómico a 60 FPS

### 5.1 Diagnóstico del Cuello de Botella Actual

La auditoría de código identificó una severa degradación en la capa de telemetría de TEPUI:
- En `crates/plugin_vst/ui/src/engine/oledEngine.ts` (líneas 710–749), el streaming se realiza mediante un `setInterval` en JavaScript que ejecuta `fetch('/api/telemetry')` cada 80 ms (~12.5 Hz).
- En `crates/plugin_vst/src/web_editor.rs` (líneas 3019–3024), cada petición serializa una cadena JSON completa de 50+ campos en Rust (`build_telemetry_json`), la transfiere sobre el protocolo virtual y la parsea en el motor V8 del WebView2.
- **Consecuencias**:
  1. Tasa de actualización limitada a 12.5 Hz (imposible lograr 60 FPS reales).
  2. Asignaciones masivas de memoria y presión continua sobre el recolector de basura (GC) en JavaScript.
  3. Coexistencia redundante de lienzos `<canvas id="oled-svf">` heredados con componentes `<TepuiFilterPlot />`, duplicando el consumo de GPU.

### 5.2 Arquitectura de Streaming de Alta Eficiencia a 60 FPS

Se sustituye el sondeo HTTP por un canal de inserción directa (*push*) desde el bucle de la GUI en Rust:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        DAW AUDIO THREAD (Real-Time)                    │
│   Procesa buffer ──► Actualiza celdas atómicas en O(1)                 │
│                      peak_l.store(val), peak_r.store(val)              │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Atomic Read (Relaxed, < 5 ns)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      PLUGIN GUI TIMER (Rust 60 Hz)                     │
│   Lee celdas atómicas ──► Prepara buffer binario / compacto            │
│   webview.evaluate_script("window.__onMeterFrame(peakL, peakR)")       │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ IPC Push Directo (Zero HTTP / Zero Fetch)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        WEBVIEW V8 / JAVASCRIPT                         │
│   window.__onMeterFrame = (pL, pR) => {                                │
│       vuMeterSource.set({ levels: [pL, pR], peaks: [pL, pR] });        │
│   };                                                                   │
│   // @audio-ui/react actualiza el DOM directamente (Zero React Render) │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Evaluación y Decisión sobre Librería de Bloques DSP/Audio: Crate `dsp_core`

### 6.1 Justificación Técnica de la Extracción

En el repositorio actual, `crates/synth_core` contiene primitivas matemáticas de altísima calidad mezcladas con reglas exclusivas de TEPUI:
- En `crates/synth_core/src/fx.rs` (líneas 320–327), el retardo estéreo calcula tiempos basándose directamente en el enum folklórico:
  ```rust
  let (sec_l, sec_r) = match self.arp_mode {
      crate::arp::ArpMode::Joropo => (beat_sec * (1.0 / 3.0), beat_sec * (2.0 / 3.0)),
      crate::arp::ArpMode::Merengue => (beat_sec * 0.40, beat_sec * 0.60),
      _ => (beat_sec * 0.375, beat_sec * 0.525),
  };
  ```
- Ningún plugin de efectos o dinámica derivado puede utilizar `synth_core` sin arrastrar dependencias de ritmos tradicionales venezolanos y estructuras de sampler de 16 voces.

### 6.2 Arquitectura y Estructura del Crate `dsp_core`

Se extrae el crate independiente `crates/dsp_core` con la siguiente topología de módulos:

```
crates/dsp_core/
├── Cargo.toml                   # std / no_std, cero dependencias pesadas
└── src/
    ├── lib.rs
    ├── math/                    # Conversiones y optimizaciones numéricas
    │   ├── db.rs                # db_to_gain, gain_to_db, aproximaciones rápidas
    │   ├── pitch.rs             # midi_to_hz, hz_to_midi, detune_cents
    │   ├── interp.rs            # Interpolación lineal, Hermite 4-puntos, cúbica
    │   └── denormal.rs          # flush_denormal, anti-denormal DC bias
    ├── primitives/              # Estructuras de sincronización lock-free
    │   ├── smoother.rs          # OnePoleSmoother (eliminación de zipper noise)
    │   ├── seqlock.rs           # SeqLockArray<N> con alineación a 64 bytes
    │   └── ringbuf.rs           # Cola circular SPSC lock-free para audio
    ├── filters/                 # Topologías de filtros TPT ZDF
    │   ├── svf.rs               # Cytomic TPT State Variable Filter (LP/HP/BP/Notch)
    │   ├── ladder.rs            # Moog Ladder 24dB con saturación no lineal
    │   ├── comb.rs              # Filtro peine con amortiguación
    │   └── allpass.rs           # Difusores pasa-todo de 1er y 2do orden
    ├── modulation/              # Generadores de modulación
    │   ├── adsr.rs              # Envolvente ADSR con curvatura y anti-clic
    │   └── lfo.rs               # LFO polimórfico de banda limitada
    ├── dynamics/                # Procesamiento dinámico
    │   ├── detector.rs          # Detectores Peak, RMS y True-Peak
    │   ├── limiter.rs           # Limitador de pico lookahead brickwall
    │   └── compressor.rs        # Compresor feed-forward con codo suave (soft-knee)
    └── fx/                      # Efectos compuestos genéricos
        ├── delay.rs             # Retardo estéreo con interpolación fraccionaria
        ├── chorus.rs            # Chorus analógico en cuadratura
        └── reverb.rs            # Reverberador algorítmico (red de retardo con realimentación FDN)
```

### 6.3 Invariantes de Seguridad en Tiempo Real de `dsp_core`

1. **Cero Asignaciones en Tiempo de Proceso**: Todos los vectores, líneas de retardo y tablas de senos se inicializan en `initialize(sample_rate, max_buffer_size)`. Prohibido `Vec::new()`, `Box::new()` o re-dimensionamientos durante `process()`.
2. **Cero Primitivas Bloqueantes**: Prohibido el uso de `Mutex`, `RwLock` o llamadas a I/O del sistema operativo en el camino del audio.
3. **Complejidad Temporal Acotada ($O(1)$)**: Cada bloque de código garantiza un tiempo de ejecución constante e inmune a cargas patológicas de entrada.
4. **Protección Anti-Denormal Universal**: Todas las retroalimentaciones recursivas aplican la macro/función inline `flush_denormal(x)` para evitar caídas catastróficas de rendimiento en silencios.

---

## 7. Contratos de Interfaz en Código

### 7.1 Adaptador React en TypeScript (`@plugin-base/ui-bridge`)

```tsx
import React, { useCallback, useRef, useEffect } from 'react';
import { Knob, Meter } from '@audio-ui/react';
import type { KnobChangeEventDetails, KnobCommitEventDetails } from '@audio-ui/core/knob';
import { vuMeterSource } from '../state/telemetry';

export interface PluginKnobProps {
  paramId: number;
  label: string;
  min: number;
  max: number;
  defaultValue: number;
  scale?: 'linear' | 'log' | 'db';
  unit?: string;
  value: number;
  onChange: (value: number) => void;
}

/**
 * Adaptador Tier 2 de Perilla con demarcación dual de gestos DAW (VST3/CLAP).
 * 
 * Garantiza que toda modificación de parámetro esté estrictamente envuelta entre
 * `ParamGestureBegin` y `ParamGestureEnd`, tanto para arrastre de ratón/táctil,
 * navegación por teclado (Arrow keys, Home, End), pasos de rueda de ratón (con debounce de 200ms),
 * y restablecimiento por doble clic o Delete.
 */
export const PluginKnob: React.FC<PluginKnobProps> = ({
  paramId,
  label,
  min,
  max,
  defaultValue,
  scale = 'linear',
  unit = '',
  value,
  onChange,
}) => {
  const isGestureActiveRef = useRef<boolean>(false);
  const wheelDebounceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const beginGesture = useCallback(() => {
    if (!isGestureActiveRef.current) {
      isGestureActiveRef.current = true;
      window.ipc?.postMessage(JSON.stringify({
        cmd: 'ParamGestureBegin',
        data: { param_id: paramId }
      }));
    }
  }, [paramId]);

  const endGesture = useCallback(() => {
    if (wheelDebounceTimerRef.current) {
      clearTimeout(wheelDebounceTimerRef.current);
      wheelDebounceTimerRef.current = null;
    }
    if (isGestureActiveRef.current) {
      isGestureActiveRef.current = false;
      window.ipc?.postMessage(JSON.stringify({
        cmd: 'ParamGestureEnd',
        data: { param_id: paramId }
      }));
    }
  }, [paramId]);

  // Manejo de cambio continuo de valor (Drag, Keyboard, Wheel, Reset)
  const handleValueChange = useCallback((nextVal: number, details?: KnobChangeEventDetails) => {
    // Si no hay un gesto activo (ej. teclado o rueda que no disparan pointerdown),
    // abrir inmediatamente el gesto en el host DAW antes de emitir el valor.
    if (!isGestureActiveRef.current) {
      beginGesture();
    }

    onChange(nextVal);
    window.ipc?.postMessage(JSON.stringify({
      cmd: 'ParamSetValue',
      data: { param_id: paramId, value: nextVal }
    }));

    // Para la rueda de ratón (que no posee evento 'up'), aplicar debounce de 200ms
    // para agrupar ráfagas continuas de ticks en un único gesto de automatización DAW.
    if (details?.reason === 'wheel') {
      if (wheelDebounceTimerRef.current) {
        clearTimeout(wheelDebounceTimerRef.current);
      }
      wheelDebounceTimerRef.current = setTimeout(() => {
        endGesture();
      }, 200);
    }
  }, [paramId, onChange, beginGesture, endGesture]);

  // Cierre de gesto al confirmar interacción (soltar ratón, confirmación de tecla o reset)
  const handleValueCommitted = useCallback((_finalVal: number, details?: KnobCommitEventDetails) => {
    if (details?.reason !== 'wheel') {
      endGesture();
    }
  }, [endGesture]);

  // Red de seguridad al desmontar el componente
  useEffect(() => {
    return () => {
      if (wheelDebounceTimerRef.current) {
        clearTimeout(wheelDebounceTimerRef.current);
      }
      if (isGestureActiveRef.current) {
        endGesture();
      }
    };
  }, [endGesture]);

  return (
    <Knob.Root
      value={value}
      min={min}
      max={max}
      defaultValue={defaultValue}
      dragMode="vertical"
      onValueChange={handleValueChange}
      onValueCommitted={handleValueCommitted}
      onPointerDown={beginGesture}
      onPointerUp={endGesture}
      className="plugin-knob-root"
    >
      <Knob.Label className="plugin-knob-label">{label}</Knob.Label>
      <Knob.Control className="plugin-knob-control">
        <Knob.Track className="plugin-knob-track" />
        <Knob.Indicator className="plugin-knob-indicator" />
        <Knob.Thumb className="plugin-knob-thumb" />
      </Knob.Control>
      <Knob.Value className="plugin-knob-value" format={(v) => `${v.toFixed(1)}${unit}`} />
    </Knob.Root>
  );
};

export interface PluginLevelMeterProps {
  className?: string;
  orientation?: 'vertical' | 'horizontal';
  min?: number;
  max?: number;
  warnThreshold?: number;
  clipThreshold?: number;
}

/**
 * Adaptador Tier 2 de Medidor de Nivel Estéreo canónico con `@audio-ui/react`.
 *
 * Utiliza la jerarquía real de componentes de `@audio-ui/react/meter`:
 * `<Meter.Root>` -> `<Meter.Channels>` -> `<Meter.Channel>` -> `<Meter.Track>` -> `<Meter.Indicator>` & `<Meter.Peak>`.
 * Se alimenta de `vuMeterSource` para escritura atómica directa al DOM sin reconciliación VDOM a 60 FPS.
 */
export const PluginLevelMeter: React.FC<PluginLevelMeterProps> = ({
  className = 'plugin-meter-root',
  orientation = 'vertical',
  min = -60,
  max = 6,
  warnThreshold = -3,
  clipThreshold = 0,
}) => {
  return (
    <Meter.Root
      source={vuMeterSource}
      orientation={orientation}
      min={min}
      max={max}
      warnThreshold={warnThreshold}
      clipThreshold={clipThreshold}
      className={className}
    >
      <Meter.Channels>
        {(index) => {
          const isLeft = index === 0;
          const label = isLeft ? 'L' : 'R';
          return (
            <Meter.Channel
              key={index}
              index={index}
              className={`plugin-meter-channel ${isLeft ? 'plugin-meter-channel-l' : 'plugin-meter-channel-r'}`}
              aria-label={`Output Channel ${label}`}
            >
              <Meter.Track className="plugin-meter-track">
                <Meter.Indicator className="plugin-meter-indicator" />
                <Meter.Peak className="plugin-meter-peak" />
              </Meter.Track>
              <Meter.Label className="plugin-meter-label">{label}</Meter.Label>
            </Meter.Channel>
          );
        }}
      </Meter.Channels>
    </Meter.Root>
  );
};
```

### 7.2 Implementación del Filtro ZDF en Rust (`dsp_core::filters::svf`)

```rust
use crate::math::denormal::flush_denormal;

#[derive(Debug, Clone, Copy)]
pub struct StateVariableFilter {
    sample_rate: f32,
    cutoff_hz: f32,
    resonance: f32,
    ic1eq: f32,
    ic2eq: f32,
    g: f32,
    k: f32,
    a1: f32,
    a2: f32,
    a3: f32,
}

impl StateVariableFilter {
    pub fn new() -> Self {
        Self {
            sample_rate: 44100.0,
            cutoff_hz: 1000.0,
            resonance: 0.707,
            ic1eq: 0.0,
            ic2eq: 0.0,
            g: 0.0,
            k: 0.0,
            a1: 0.0,
            a2: 0.0,
            a3: 0.0,
        }
    }

    pub fn set_sample_rate(&mut self, sample_rate: f32) {
        self.sample_rate = sample_rate.max(1.0);
        self.recompute_coefficients();
    }

    pub fn set_params(&mut self, cutoff_hz: f32, resonance: f32) {
        self.cutoff_hz = cutoff_hz.clamp(10.0, self.sample_rate * 0.49);
        self.resonance = resonance.max(0.1);
        self.recompute_coefficients();
    }

    pub fn reset(&mut self) {
        self.ic1eq = 0.0;
        self.ic2eq = 0.0;
    }

    fn recompute_coefficients(&mut self) {
        let wd = 2.0 * std::f32::consts::PI * self.cutoff_hz;
        let t = 1.0 / self.sample_rate;
        let wa = (2.0 / t) * (wd * t * 0.5).tan();
        self.g = wa * t * 0.5;
        self.k = 1.0 / self.resonance;
        self.a1 = 1.0 / (1.0 + self.g * (self.g + self.k));
        self.a2 = self.g * self.a1;
        self.a3 = self.g * self.a2;
    }

    #[inline(always)]
    pub fn process_lowpass(&mut self, v0: f32) -> f32 {
        let v0_clean = flush_denormal(v0);
        let v3 = v0_clean - self.ic2eq;
        let v1 = self.a1 * self.ic1eq + self.a2 * v3;
        let v2 = self.ic2eq + self.a2 * self.ic1eq + self.a3 * v3;
        self.ic1eq = flush_denormal(2.0 * v1 - self.ic1eq);
        self.ic2eq = flush_denormal(2.0 * v2 - self.ic2eq);
        v2 // Salida Lowpass
    }
}
```

---

## 8. Hoja de Ruta de Migración y Desacoplamiento

La migración desde el monolito actual hacia el ecosistema desacoplado se ejecuta en cuatro fases consecutivas:

```
FASE 1: EXTRACCIÓN DE DSP_CORE
├── Mover OnePoleSmoother y SeqLockArray a crates/dsp_core/src/primitives/
├── Extraer StateVariableFilter, AdsrEnvelope y utilidades matemáticas
└── Reemplazar ArpMode::Joropo/Merengue en fx.rs por ratios de delay genéricos

FASE 2: CREACIÓN DE BASE_PLUGIN_CORE Y ADAPTADOR REACT
├── Publicar base_plugin_core con traits DspEngine, ParamRegistry, LiveParamSnapshot
└── Crear paquete packages/base-plugin-ui integrando @audio-ui/react y @audio-ui/core

FASE 3: OPTIMIZACIÓN DE IPC Y LIMPIEZA DE TELEMETRÍA
├── Eliminar la duplicación de lienzos canvas heredados en EurorackMatrix.tsx
├── Deprecar el script oledEngine.ts de 238 KB
└── Reemplazar el loop fetch('/api/telemetry') de 80ms por push a 60 FPS hacia createSource

FASE 4: AISLAMIENTO FINAL DE TEPUI_SYNTH
├── Configurar tepui_synth como consumidor final de base_plugin_core y dsp_core
└── Validar compilación aislada e independiente de la plantilla base
```

---

## 9. Conclusión

La adopción formal del modelo híbrido de 3 niveles para `@audio-ui/react` y `@audio-ui/core`, junto con la extracción del crate `dsp_core`, resuelve integralmente los requerimientos R1 y R2:
1. Elimina la necesidad de desarrollar controles de audio propietarios desde cero.
2. Evita la fragmentación de código asociada al copy-paste no administrado.
3. Resuelve el cuello de botella de telemetría elevando el refresco a 60 FPS reales sin sobrecarga de VDOM.
4. Desacopla las matemáticas de síntesis y efectos del dominio cultural de TEPUI, permitiendo la creación inmediata de nuevos plugins sobre una arquitectura estándar de la industria.
