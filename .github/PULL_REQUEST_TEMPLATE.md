## Resumen del Cambio

Describe brevemente qué resuelve o añade este Pull Request (ej. nuevo bloque DSP en `dsp_core`, mejora en `base_plugin_webview`, nuevo componente en `@plugin-base/ui-bridge` o documentación).

## Tipo de Cambio (Conventional Commits)

- [ ] `feat`: Nueva funcionalidad o módulo DSP/UI (incrementa versión `MINOR`)
- [ ] `fix`: Corrección de bug (incrementa versión `PATCH`)
- [ ] `perf`: Optimización de rendimiento DSP o telemetría 60 FPS (`PATCH`)
- [ ] `docs`: Documentación, `llms.txt` o recetas de Vibe Coding

## Lista de Verificación de las 4 Compuertas (`GATE-01` a `GATE-04`)

- [ ] **GATE-01 (Zero Domain Leaks)**: El código en `dsp_core`, `base_plugin_*` y `packages/base-plugin-ui` es 100 % genérico y reutilizable.
- [ ] **GATE-02 (Real-Time Safety)**: Cero asignaciones dinámicas (`Vec`, `Box`, `String`, `Mutex`) en `process()`.
- [ ] **GATE-03 (Clean DAG)**: La jerarquía de dependencias entre crates se mantiene limpia.
- [ ] **GATE-04 (Contract Proof)**: Todos los controles UI añadidos están cubiertos por `declare_plugin_contract!`.
- [ ] Ejecuté localmente `powershell -ExecutionPolicy Bypass -File scripts/audit_plugin_architecture.ps1` y obtuvo `TEMPLATE CERTIFIED GOLD`.
