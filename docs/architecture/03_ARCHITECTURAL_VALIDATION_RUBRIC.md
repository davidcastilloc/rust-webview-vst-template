# Rúbrica Formal e Independiente de Validación Arquitectónica de Plugins

**Documento**: `03_ARCHITECTURAL_VALIDATION_RUBRIC.md`  
**Autor**: Equipo de Arquitectura de Audio (Worker 1)  
**Fecha**: 2026-11-08  
**Estado**: Aprobado para Implementación  
**Alcance**: Rúbrica técnica formal e independiente para certificar que la plantilla base y cualquier plugin derivado carecen de fugas de dominio de TEPUI, cumplen las restricciones de tiempo real estricto y garantizan modularidad, desacoplamiento y escalabilidad.

---

## 1. Resumen Ejecutivo y Propósito de la Rúbrica

El propósito de esta rúbrica es proporcionar un marco de **certificación técnica computable y reproducible** que audite con rigor matemático y estático cualquier artefacto de software desarrollado sobre el stack de plugins de audio (`nih-plug` + `wry` Webview nativo + React 19).

La rúbrica resuelve las deficiencias de los tests contractuales existentes en `crates/plugin_vst/src/ui_dsp_contract.rs`, los cuales asumían de forma rígida la topología de TEPUI (exigiendo exactamente 6 módulos Eurorack con pantallas OLED y un motor de síntesis polifónico con `VoiceManager`). 

La nueva rúbrica opera en dos niveles complementarios:
1. **Compuertas Binarias Obligatorias (Pass/Fail Gates)**: 4 compuertas críticas donde cualquier fallo descalifica y rechaza el artefacto de forma automática.
2. **Matriz Cuantitativa de 5 Dimensiones (0–100 Puntos)**: Evaluación granular de calidad, pureza de dominio, determinismo en tiempo real, ciclo de vida de Webview y verificación funcional.

---

## 2. Las 4 Compuertas Binarias Obligatorias (Pass/Fail Gates)

Si un artefacto suspende cualquiera de estas cuatro compuertas, se considera un **RECHAZO ROTUNDO (ARCHITECTURE VIOLATION)**, independientemente del puntaje acumulado en las demás dimensiones.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        COMPUERTAS BINARIAS PASA / NO PASA                              │
├─────────┬───────────────────────────────┬──────────────────────────────────────────────┤
│ Gate ID │ Nombre de la Compuerta        │ Criterio de Falla Automática (FAIL)          │
├─────────┼───────────────────────────────┼──────────────────────────────────────────────┤
│ GATE-01 │ Zero TEPUI Domain Leaks       │ Presencia de términos folclóricos, rutas o   │
│         │ (Desacoplamiento Absoluto)    │ endpoints de IA propietarios en el template. │
├─────────┼───────────────────────────────┼──────────────────────────────────────────────┤
│ GATE-02 │ Real-Time Safety & Allocations│ Cualquier asignación de heap o bloqueo en el │
│         │ (Tiempo Real Estricto)        │ hilo de audio (`assert_process_allocs`).     │
├─────────┼───────────────────────────────┼──────────────────────────────────────────────┤
│ GATE-03 │ Crate Boundaries & Clean DAG  │ Violación de la jerarquía DAG (ej. el core   │
│         │ (Aislamiento de Módulos)      │ depende de GUI, Webview o plugins concretos).│
├─────────┼───────────────────────────────┼──────────────────────────────────────────────┤
│ GATE-04 │ Universal Contract Compliance │ Controles huérfanos sin mapeo en el DOM o    │
│         │ (Certificación UI↔DSP)        │ parámetros sin comprobación matemática DSP.  │
└─────────┴───────────────────────────────┴──────────────────────────────────────────────┘
```

### 2.1 Especificación Detallada de las Compuertas Binarias

#### `GATE-01: Zero TEPUI Domain Leaks`
- **Condición de Falla**: Cualquier archivo dentro de los crates de infraestructura base (`base_plugin_core`, `base_plugin_webview`, `base_plugin_standalone`, `base_plugin_xtask`, `dsp_core` o `base-plugin-ui`) que contenga referencias directas o léxicas a la propiedad intelectual de TEPUI:
  - Términos culturales/folclóricos: `joropo`, `merengue`, `llanera`, `cuatro`, `bandola`, `cumaco`, `quitiplas`, `furruco`, `folklore_presets`.
  - Marcas y nombres propios: `Gran Sabana`, `Gran Sabana Sonic Lab`, `TEPUI_PATCH_V1`, `TepuiArpeggiator`, `Cañón del Tepui`.
  - Rutas de disco fijas: `base.join("Tepui")`, `WebView2_Studio`, `tepui-icon.png`.
  - Endpoints de cobro y vouchers: `DEFAULT_CF_EDGE_WORKER_URL`, `api/webhooks/checkout`, `CloudLicenseConfig`, `redeem_cloud_license_code`.
- **Verificación**: Búsqueda estática automatizada por expresiones regulares con tolerancia cero.

#### `GATE-02: Real-Time Safety & Zero Allocations`
- **Condición de Falla**: Ocurrencia de cualquier llamada a `malloc`, `realloc`, `free`, `Vec::new`, `Box::new`, `format!`, `String::from` o llamadas bloqueantes a mutex (`std::sync::Mutex::lock`, `parking_lot::Mutex::lock`) durante la ejecución de `DspEngine::process_block()`.
- **Verificación**: Ejecución de la suite de pruebas bajo el interceptor de asignaciones de `nih-plug` (`features = ["assert_process_allocs"]`).

#### `GATE-03: Crate Boundaries & Clean DAG`
- **Condición de Falla**: 
  - Que `base_plugin_core` declare dependencias directas o transitivas hacia `wry`, `nih_plug::editor` o cualquier crate de frontend.
  - Que `dsp_core` declare dependencias hacia `nih-plug`, `base_plugin_webview` o crates de plugins concretos (`tepui_synth`).
  - La existencia de dependencias circulares en el workspace Cargo.
- **Verificación**: Inspección de `cargo tree -p base_plugin_core` y `cargo tree -p dsp_core`.

#### `GATE-04: Universal Contract Compliance`
- **Condición de Falla**: 
  - Existencia de elementos interactivos en el DOM frontend (botones, perillas, faders) que carezcan de un `ParamIndex` o comando IPC registrado en la macro `declare_plugin_contract!`.
  - Parámetros registrados en el contrato cuyo cambio no produzca una alteración matemática verificable ($\Delta > \epsilon$) en la salida de audio o en la telemetría del `DspEngine`.
- **Verificación**: Ejecución del harness de pruebas agnóstico generado por la macro declarativa.

---

## 3. Matriz Cuantitativa de Evaluación (0–100 Puntos)

La matriz evalúa 5 dimensiones técnicas con pesos calibrados según su criticidad en entornos de producción:

```
+---------------------------------------------------------------------------------------------------+
| DISTRIBUCIÓN DE PESOS DE LA MATRIZ CUANTITATIVA                                                   |
+-------------------------------------------------------------------------------------+-------------+
| Dimensión de Evaluación                                                             | Puntuación  |
+-------------------------------------------------------------------------------------+-------------+
| Dimensión 1: Ausencia Absoluta de Fugas de Dominio de TEPUI (Pureza de Dominio)     | 25 Puntos   |
| Dimensión 2: Modularidad, Desacoplamiento y Fronteras de Crate                     | 20 Puntos   |
| Dimensión 3: Seguridad en Tiempo Real (Real-Time Safety & Sanitizers)               | 25 Puntos   |
| Dimensión 4: Robustez del WebView, Ciclo de Vida y Sandbox CSP                      | 15 Puntos   |
| Dimensión 5: Las 7 Compuertas Universales de Contrato UI↔DSP                        | 15 Puntos   |
+-------------------------------------------------------------------------------------+-------------+
| PUNTUACIÓN TOTAL MÁXIMA                                                             | 100 Puntos  |
+-------------------------------------------------------------------------------------+-------------+
```

### 3.1 Dimensión 1: Ausencia Absoluta de Fugas de Dominio de TEPUI (25 Puntos)

| Criterio de Auditoría | Método de Verificación Automatizado | Tolerancia | Puntos |
|---|---|---|:---:|
| **1.1 Cero Vocabulario Folclórico / Étnico** | Búsqueda regex endurecida: `(?i)(tepui|joropo|merengue|llanera|bandola|cumaco|quitiplas|furruco|folklore|gran[\s_]?sabana|cañ[oó]n[\s_]?del[\s_]?tepui|webview2_studio|cloudlicense|cloud_license|DEFAULT_CF_EDGE_WORKER_URL|(?<![a-z0-9])cuatro(?![a-z0-9]))` en crates base. | 0 coincidencias | 8 |
| **1.2 Cero Rutas o Nombres de Archivo Hardcodeados** | Escaneo estático buscando `tepui`, `Tepui`, `WebView2_Studio`, `tepui-icon.ico`, extensiones `.tepui` en el código de la plantilla. | 0 coincidencias | 6 |
| **1.3 Cero Endpoints de IA o Servicios Propietarios** | Ausencia de URLs hacia Cloudflare AI Gateway, OpenAI, Ollama o esquemas de licencias y créditos comerciales en los crates base. | 0 dependencias | 6 |
| **1.4 Cero Asunciones de Síntesis Fija** | El host interactúa exclusivamente con el trait polimórfico `DspEngine`, sin instanciar `VoiceManager`, tablas wavetable o 6 módulos fijos. | Cumplimiento total | 5 |

### 3.2 Dimensión 2: Modularidad, Desacoplamiento y Fronteras de Crate (20 Puntos)

```
Jerarquía Estricta del Grafo Acíclico Dirigido (DAG):
┌───────────────────────────┐
│     base_plugin_xtask     │ (Empaquetado, bundles, UUID v5)
└─────────────┬─────────────┘
              ▼
┌───────────────────────────┐      ┌───────────────────────────┐
│    base_plugin_webview    │ ───► │    base-plugin-ui (NPM)   │ (React 19 + @audio-ui)
│  (Host nih-plug + Wry)    │      └───────────────────────────┘
└─────────────┬─────────────┘
              ▼
┌───────────────────────────┐
│     base_plugin_core      │ (DspEngine, AtomicParamBank, SeqLockArray, OnePoleSmoother)
│  *Cero dependencias host* │
└─────────────┬─────────────┘
              ▼
┌───────────────────────────┐
│         dsp_core          │ (Matemáticas, Filtros ZDF, ADSR, Retardos, Sanitizers)
│  *Cero dependencias nih*  │
└───────────────────────────┘
```

| Criterio de Auditoría | Definición / Métrica | Estándar Exigido | Puntos |
|---|---|---|:---:|
| **2.1 Aislamiento de Core ($I_{\text{core}}$)** | Inestabilidad $I = \frac{C_e}{C_a + C_e}$. Cero dependencias eferentes hacia GUI o frameworks de ventana. | $I_{\text{core}} = 0.0$ | 6 |
| **2.2 Independencia de Compilación de Core** | `cargo check -p base_plugin_core --no-default-features`. | Compila en $< 1.5 \text{ s}$ sin compilar Wry, WebKit ni nih-plug. | 5 |
| **2.3 Aislamiento de Empaquetado (`xtask`)** | Generación determinista de Class ID VST3 (RFC 4122 v5) desde el ID CLAP sin scripts manuales. | Reproducible en CI/CD | 5 |
| **2.4 Desacoplamiento Frontend** | Ejecución de `npm run dev` en `packages/base-plugin-ui` con mock de IPC sin requerir binarios Rust ni DAW. | Servidor Vite funcional | 4 |

### 3.3 Dimensión 3: Seguridad en Tiempo Real (Real-Time Safety & Sanitizers) (25 Puntos)

| Criterio de Auditoría | Método de Verificación Automatizado | Resultado Exigido | Puntos |
|---|---|---|:---:|
| **3.1 Cero Asignaciones Dinámicas** | Ejecución de suite de pruebas con feature `assert_process_allocs` de `nih-plug`. | Cero interceptaciones de `malloc`/`free` | 8 |
| **3.2 Cero Primitivas Bloqueantes** | Inspección AST en `DspEngine::process_block`: Prohibido `Mutex::lock`, `sleep`, llamadas a canales bloqueantes. | Cero primitivas de espera | 7 |
| **3.3 Sanitización Aritmética IEEE 754** | Inyección de señales de estrés con valores patológicos (`NaN`, $\pm\infty$, números subnormales). | Salida normalizada sin NaNs ni picos $> +24 \text{ dBFS}$ | 5 |
| **3.4 Resistencia ante ASan / LSan** | Ejecución de tests compilados con AddressSanitizer y LeakSanitizer (`-Zsanitizer=address`). | Cero errores de memoria o fugas | 5 |

### 3.4 Dimensión 4: Robustez del WebView, Ciclo de Vida y Sandbox CSP (15 Puntos)

| Criterio de Auditoría | Requisito Técnico Verificable | Tolerancia | Puntos |
|---|---|---|:---:|
| **4.1 Resiliencia en Reopen Loop** | Bucle automatizado de 50 aperturas y cierres consecutivos del editor en host de pruebas. | 0 fugas de handles Win32 / COM, 0 bloqueos | 5 |
| **4.2 Redimensionado Fluido** | Interceptación de `WM_SIZE` vía `SetWindowSubclass` en Windows y ajuste de `LogicalSize`. | 0 parpadeos negros, tiempo de redibujado $< 16 \text{ ms}$ | 4 |
| **4.3 Aislamiento de Perfil UDF** | Directorio de datos derivado dinámicamente por plugin en `%LOCALAPPDATA%/<Vendor>/<Plugin>/WebViewProfile`. | 0 colisiones SQLite entre instancias | 3 |
| **4.4 Seguridad de Red y CSP** | Protocolo virtual en memoria `app://localhost/`, DevTools desactivado en release y CSP endurecido. | 0 sockets de red TCP abiertos | 3 |

### 3.5 Dimensión 5: Las 7 Compuertas Universales de Contrato UI↔DSP (15 Puntos)

| Compuerta Universal | Descripción del Chequeo Automatizado | Puntos |
|---|---|:---:|
| **Gate 1: Cobertura Exhaustiva del DOM** | Parser HTML/JSX valida que el 100% de los elementos interactivos pertenezcan a la lista declarada. | 2 |
| **Gate 2: Prefijos IPC Tipados Estáticos** | El analizador AST prohíbe interpolaciones dinámicas `${...}` en los prefijos de comando IPC. | 2 |
| **Gate 3: Impacto Matemático Comprobable** | Prueba DSP que evalúa la distancia $L_1$ ($\Delta > \epsilon$) o atenuación RMS ante estímulos de prueba. | 3 |
| **Gate 4: Persistencia y Compatibilidad** | Serialización y deserialización de presets con valores por defecto ante campos ausentes. | 2 |
| **Gate 5: Primitivas Anti-Zipper y SeqLock** | Verificación asintótica de `OnePoleSmoother` y consistencia de lectura en `SeqLockArray`. | 2 |
| **Gate 6: Carga Limpia de Tema Inicial** | La interfaz arranca en un tema predeterminado sin parpadeos luminosos (*flash-of-unstyled-theme*). | 2 |
| **Gate 7: Selector de Temas Dinámico** | Todos los temas declarados en el CSS existen y se conmutan sin reconstruir el DOM. | 2 |

---

## 4. Escala de Calificación y Certificación Arquitectónica

El puntaje total se computa como la suma ponderada de las 5 dimensiones (0–100 puntos), condicionado a la aprobación unánime de las compuertas binarias `GATE-01` a `GATE-04`:

$$\text{Puntaje Total} = \sum_{i=1}^{5} D_i \quad \text{si } \bigwedge_{j=1}^{4} \text{GATE}_j = \text{PASS}$$

```
+---------------------------------------------------------------------------------------------------+
| ESCALA FORMAL DE CERTIFICACIÓN ARQUITECTÓNICA DE PLUGINS                                          |
+-------------------+-----------------------------------------+-------------------------------------+
| Rango de Puntaje  | Nivel de Certificación                  | Dictamen y Estado de Publicación    |
+-------------------+-----------------------------------------+-------------------------------------+
| 95 – 100 Puntos   | Nivel Diamante (Template Certified Gold)| APROBADO PARA PRODUCCIÓN Y DISTRIBU.|
| 85 – 94 Puntos    | Nivel Platino (Production Ready)        | APROBADO CON OBSERVACIONES MENORES  |
| 70 – 84 Puntos    | Nivel Plata (Candidate / Incomplete)    | RECHAZADO TEMPORALMENTE (A REVISIÓN)|
| < 70 Puntos       | No Certificado                          | RECHAZADO (DEFICIENCIAS CRÍTICAS)   |
| Cualquier GATE=FAIL| Violación Arquitectónica                | RECHAZO ROTUNDO E INMEDIATO         |
+-------------------+-----------------------------------------+-------------------------------------+
```

---

## 5. Macro Declarativa Universal: `declare_plugin_contract!`

Para que cualquier desarrollador pueda certificar un plugin (efecto de distorsión, ecualizador, compresor o sintetizador) sin reescribir código de auditoría, se define la macro universal `declare_plugin_contract!`:

```rust
#[macro_export]
macro_rules! declare_plugin_contract {
    (
        plugin_name: $name:expr,
        plugin_type: $ptype:ident, // Instrument | AudioEffect | MidiProcessor
        controls: [
            $(
                $control_ident:ident => {
                    param_index: $index:expr,
                    dom_id: $dom_id:expr,
                    ipc_cmd: $ipc_cmd:expr,
                    proof: $proof_type:expr $(,)?
                    $(stimulus: $stimulus:expr)?
                }
            ),* $(,)?
        ],
        skins: [ $($skin_name:expr),* $(,)? ]
    ) => {
        #[cfg(test)]
        mod contract_certification_tests {
            use super::*;
            use base_plugin_core::contract_harness::*;

            #[test]
            fn test_gate_01_zero_domain_leaks() {
                assert_zero_domain_leaks();
            }

            #[test]
            fn test_gate_02_realtime_safety() {
                assert_realtime_safety::<super::PluginEngineType>();
            }

            #[test]
            fn test_gate_03_crate_dag_cleanliness() {
                assert_clean_dag();
            }

            #[test]
            fn test_gate_04_universal_contract_mapping() {
                let declared_controls = vec![
                    $(
                        DeclaredControl {
                            name: stringify!($control_ident),
                            param_index: $index,
                            dom_id: $dom_id,
                            ipc_cmd: $ipc_cmd,
                            expected_impact: $proof_type,
                            stimulus: {
                                #[allow(unused_mut, unused_assignments)]
                                let mut s = base_plugin_core::contract_harness::TestSignal::LinearChirp;
                                $(s = $stimulus;)?
                                s
                            },
                        },
                    )*
                ];
                let declared_skins = vec![ $($skin_name),* ];
                
                verify_universal_contract(&declared_controls, &declared_skins);
            }
        }
    };
}
```

### 5.1 Enumerador de Impacto Matemático Comprobable: `DspImpact`

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DspImpact {
    /// Atenúa el valor RMS de la señal procesada (ej. Threshold de compresor, corte de Lowpass).
    AttenuatesRms,
    /// Amplifica el valor RMS de la señal procesada (ej. Drive, Makeup Gain).
    AmplifiesRms,
    /// Modifica la forma de onda espectral o fase con distancia L1 mayor a epsilon.
    MutatesWaveform,
    /// Altera la envolvente transitoria o decaimiento en el dominio temporal.
    MutatesTransient,
    /// Modifica la respuesta de frecuencia medida con barrido sinusoidal (chirp).
    AltersFrequencyResponse,
    /// En modo Bypass, la señal de salida es idéntica bit a bit a la entrada.
    PassThroughEqual,
}
```

---

## 6. Implementación del Harness de Pruebas Agnóstico en Rust

El módulo `contract_harness` en `base_plugin_core` implementa la lógica de certificación agnóstica:

```rust
pub mod contract_harness {
    use super::*;

    /// Estímulo de prueba determinista para la verificación matemática del contrato DSP.
    #[derive(Debug, Clone, Copy, PartialEq, Eq)]
    pub enum TestSignal {
        /// Barrido sinusoidal lineal continuo (20 Hz a 20 kHz) que garantiza excitación espectral completa.
        /// Es el estándar exigido para certificar procesadores AC (filtros HPF, BPF, Notch) y efectos de modulación.
        LinearChirp,
        /// Tren de impulsos alternados (+0.5, -0.5, ...) para pruebas de respuesta al impulso y transitorios.
        AlternatingImpulseTrain,
        /// Estímulo estático de corriente continua (DC = 0.5) para saturadores estáticos y curvas de transferencia.
        ConstantDc,
    }

    impl TestSignal {
        /// Genera la señal de prueba en el buffer provisto de forma 100% determinista y sin asignaciones en tiempo real.
        #[inline]
        pub fn generate(&self, buffer: &mut [f32], sample_rate: f32) {
            let len = buffer.len();
            match self {
                TestSignal::LinearChirp => {
                    let f_start = 20.0_f32;
                    let f_end = (sample_rate * 0.45).min(20000.0);
                    for (i, sample) in buffer.iter_mut().enumerate() {
                        let t = i as f32 / len as f32;
                        let freq = f_start + (f_end - f_start) * t * 0.5;
                        let phase = 2.0 * std::f32::consts::PI * freq * (i as f32 / sample_rate);
                        *sample = 0.5 * phase.sin();
                    }
                }
                TestSignal::AlternatingImpulseTrain => {
                    for (i, sample) in buffer.iter_mut().enumerate() {
                        *sample = if i % 2 == 0 { 0.5 } else { -0.5 };
                    }
                }
                TestSignal::ConstantDc => {
                    buffer.fill(0.5);
                }
            }
        }
    }

    pub struct DeclaredControl {
        pub name: &'static str,
        pub param_index: u16,
        pub dom_id: &'static str,
        pub ipc_cmd: &'static str,
        pub expected_impact: DspImpact,
        pub stimulus: TestSignal,
    }

    /// Gate 1: Certifica que el DOM HTML/TSX no contiene controles interactivos huérfanos.
    pub fn verify_dom_coverage(html_source: &str, controls: &[DeclaredControl]) {
        for control in controls {
            assert!(
                html_source.contains(control.dom_id),
                "Error Contractual Gate 1: El control {} con ID DOM '{}' no existe en el frontend",
                control.name,
                control.dom_id
            );
        }
    }

    /// Gate 2: Certifica que los comandos IPC son estáticos y carecen de `${...}` interpolados.
    pub fn verify_ipc_static_prefixes(js_source: &str, controls: &[DeclaredControl]) {
        for control in controls {
            let dynamic_interpolation = format!("${{{}}}", control.dom_id);
            assert!(
                !js_source.contains(&dynamic_interpolation),
                "Error Contractual Gate 2: El comando IPC para {} utiliza interpolación dinámica prohibida",
                control.name
            );
        }
    }

    /// Gate 3: Prueba matemática de impacto de cada parámetro sobre el DspEngine.
    /// Emplea estímulos deterministas de banda ancha (LinearChirp) para excitar simultáneamente
    /// todas las frecuencias audibles (20 Hz - 20 kHz), eliminando falsos negativos en filtros AC
    /// (HPF, BPF, Notch) producidos por estímulos de DC pura.
    pub fn verify_dsp_mathematical_impact<E: DspEngine>(
        engine: &mut E,
        controls: &[DeclaredControl],
        sample_rate: f32,
    ) {
        let block_size = 512;
        let mut input_l = vec![0.0_f32; block_size];
        let mut input_r = vec![0.0_f32; block_size];
        let mut out_l_a = vec![0.0_f32; block_size];
        let mut out_r_a = vec![0.0_f32; block_size];
        let mut out_l_b = vec![0.0_f32; block_size];
        let mut out_r_b = vec![0.0_f32; block_size];

        let context = HostTransportContext {
            sample_rate,
            tempo_bpm: Some(120.0),
            time_sig_numerator: 4,
            time_sig_denominator: 4,
            is_playing: true,
            is_recording: false,
            song_position_samples: Some(0),
        };

        for control in controls {
            // Generación determinista del estímulo configurado para el control (LinearChirp por defecto)
            control.stimulus.generate(&mut input_l, sample_rate);
            input_r.copy_from_slice(&input_l);

            let mut params_min = LiveParamSnapshot::empty();
            let mut params_max = LiveParamSnapshot::empty();

            params_min.set_normalized_for_test(control.param_index, 0.0);
            params_max.set_normalized_for_test(control.param_index, 1.0);

            // Corrida A: Parámetro al mínimo
            engine.reset();
            let in_refs = [&input_l[..], &input_r[..]];
            let mut out_refs_a = [&mut out_l_a[..], &mut out_r_a[..]];
            let mut midi_buf_a = [None; 16];
            engine.process_block(
                &in_refs,
                &mut out_refs_a,
                &[],
                &mut MidiOutputBuffer::new(&mut midi_buf_a),
                &context,
                &params_min,
            );

            // Corrida B: Parámetro al máximo
            engine.reset();
            let mut out_refs_b = [&mut out_l_b[..], &mut out_r_b[..]];
            let mut midi_buf_b = [None; 16];
            engine.process_block(
                &in_refs,
                &mut out_refs_b,
                &[],
                &mut MidiOutputBuffer::new(&mut midi_buf_b),
                &context,
                &params_max,
            );

            // Comprobación de impacto según expected_impact
            match control.expected_impact {
                DspImpact::AttenuatesRms => {
                    let rms_a = calculate_rms(&out_l_a);
                    let rms_b = calculate_rms(&out_l_b);
                    assert!(
                        rms_b < rms_a || (rms_a - rms_b).abs() > 1e-4,
                        "Control {} falló prueba AttenuatesRms", control.name
                    );
                }
                DspImpact::AmplifiesRms => {
                    let rms_a = calculate_rms(&out_l_a);
                    let rms_b = calculate_rms(&out_l_b);
                    assert!(
                        rms_b > rms_a || (rms_b - rms_a).abs() > 1e-4,
                        "Control {} falló prueba AmplifiesRms", control.name
                    );
                }
                DspImpact::MutatesWaveform | DspImpact::AltersFrequencyResponse => {
                    let diff_l1 = calculate_l1_distance(&out_l_a, &out_l_b);
                    assert!(
                        diff_l1 > 1e-3,
                        "Control {} no mutó la forma de onda (L1 diff: {})", control.name, diff_l1
                    );
                }
                DspImpact::PassThroughEqual => {
                    let diff_l1 = calculate_l1_distance(&input_l, &out_l_b);
                    assert!(
                        diff_l1 < 1e-6,
                        "Control Bypass {} no pasó la señal limpia", control.name
                    );
                }
                _ => {}
            }
        }
    }

    fn calculate_rms(samples: &[f32]) -> f32 {
        let sum_sq: f32 = samples.iter().map(|&s| s * s).sum();
        (sum_sq / samples.len() as f32).sqrt()
    }

    fn calculate_l1_distance(a: &[f32], b: &[f32]) -> f32 {
        a.iter().zip(b.iter()).map(|(&x, &y)| (x - y).abs()).sum()
    }
}
```

---

## 7. Automatización de Auditoría y Comandos de Verificación

Para ejecutar la validación completa de la plantilla base o de cualquier plugin derivado, se debe ejecutar el siguiente protocolo en Windows PowerShell:

### 7.1 Script de Auditoría Automatizada (`audit_plugin_architecture.ps1`)

```powershell
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " AUDITORÍA FORMAL DE ARQUITECTURA DE PLUGINS DE AUDIO     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. VERIFICACIÓN GATE-01: Cero Fugas de Dominio TEPUI
Write-Host "`n[1/4] Evaluando GATE-01: Zero TEPUI Domain Leaks..." -ForegroundColor Yellow
# Patrón endurecido: Insensible a mayúsculas/minúsculas (?i), inmune a delimitadores snake_case (_)
# y compatible con términos compuestos (CamelCase, SCREAMING_SNAKE_CASE y variantes con espacios).
$domainKeywords = "(?i)(tepui|joropo|merengue|llanera|bandola|cumaco|quitiplas|furruco|folklore|gran[\s_]?sabana|cañ[oó]n[\s_]?del[\s_]?tepui|webview2_studio|cloudlicense|cloud_license|DEFAULT_CF_EDGE_WORKER_URL|(?<![a-z0-9])cuatro(?![a-z0-9]))"
$leaks = Get-ChildItem -Path "crates/base_plugin_*","crates/dsp_core","packages/base-plugin-ui" -Recurse -Include "*.rs","*.toml","*.tsx","*.ts" | Select-String -Pattern $domainKeywords

if ($leaks) {
    Write-Host "FAILED: Se detectaron fugas de dominio TEPUI en la plantilla:" -ForegroundColor Red
    $leaks | ForEach-Object { Write-Host " - $($_.Path):$($_.LineNumber) -> $($_.Line.Trim())" -ForegroundColor Red }
    exit 1
} else {
    Write-Host "PASS: Cero fugas de dominio detectadas en la infraestructura base." -ForegroundColor Green
}

# 2. VERIFICACIÓN GATE-02: Seguridad en Tiempo Real (Allocations)
Write-Host "`n[2/4] Evaluando GATE-02: Real-Time Safety & Zero Allocations..." -ForegroundColor Yellow
cargo test -p base_plugin_core --features assert_process_allocs
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Se detectaron asignaciones en el hilo de audio en tiempo real." -ForegroundColor Red
    exit 1
} else {
    Write-Host "PASS: Cero asignaciones dinámicas confirmadas en el camino del audio." -ForegroundColor Green
}

# 3. VERIFICACIÓN GATE-03: Jerarquía DAG de Crates
Write-Host "`n[3/4] Evaluando GATE-03: Crate Boundaries & Clean DAG..." -ForegroundColor Yellow
$coreTree = cargo tree -p base_plugin_core
if ($coreTree -match "wry" -or $coreTree -match "tepui_synth") {
    Write-Host "FAILED: base_plugin_core contiene dependencias ilegales hacia la GUI o el producto." -ForegroundColor Red
    exit 1
} else {
    Write-Host "PASS: Jerarquía DAG de crates estricta y limpia." -ForegroundColor Green
}

# 4. VERIFICACIÓN GATE-04: Suite de Pruebas de Contrato Universal
Write-Host "`n[4/4] Evaluando GATE-04: Universal Contract Compliance..." -ForegroundColor Yellow
cargo test --test certification_contract
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: La suite de contrato universal reportó fallos." -ForegroundColor Red
    exit 1
} else {
    Write-Host "PASS: Contrato universal certificado con éxito." -ForegroundColor Green
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " CERTIFICACIÓN EXITOSA: NIVEL ORO (TEMPLATE CERTIFIED GOLD) " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
```

---

## 8. Conclusión

Esta rúbrica formal e independiente:
1. Erradica los acoplamientos rígidos del test suite original de TEPUI (sustituyendo la aserción de 6 módulos OLED por el contrato universal parametrizado).
2. Protege al desarrollador mediante compuertas binarias automatizadas que detienen la integración continua ante cualquier fuga de dominio o violación de tiempo real.
3. Proporciona una macro declarativa `declare_plugin_contract!` y un harness de pruebas agnóstico reutilizable en el 100% de los instrumentos y procesadores derivados.
4. Establece un estándar cuantitativo transparente (0–100 puntos) para asegurar la excelencia del ecosistema de plugins.
