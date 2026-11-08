# Política de Seguridad (`SECURITY.md`)

## Versiones Soportadas

| Versión del SDK / Plantilla | Soporte de Seguridad |
| :--- | :--- |
| `1.x.x` (`main`) | :white_check_mark: Soportada activamente |
| `< 1.0.0` | :x: No soportada |

## Arquitectura de Seguridad Incorporada

Los plugins de audio se ejecutan dentro del espacio de memoria del DAW del usuario (Ableton Live, Reaper, FL Studio, Logic, Bitwig). Por ello, `base_plugin_webview` y `base_plugin_core` implementan defensas estrictas por diseño:

1. **Cero Puertos TCP Abiertos (100 % Serverless)**:
   * La interfaz WebView jamás levanta servidores HTTP/WebSocket en `127.0.0.1` que puedan ser sondeados por otros procesos locales o páginas web mediante CSRF. Todo el tráfico viaja en memoria vía protocolo personalizado `app://localhost/`.
2. **Aislamiento de Perfil WebView2 por Proveedor, Plugin y Proceso Host**:
   * `resolve_isolated_webview_profile_dir()` segrega el `User Data Folder` en `%LOCALAPPDATA%/AudioPlugins/<Vendor>/<Plugin>/WebViewProfile_<host_exe>`, evitando colisiones SQLite, corrupción de caché o fugas de estado entre plugins de distintos fabricantes.
3. **Política de Seguridad de Contenido (`HARDENED_CSP_HEADER`)**:
   * El contenedor restringe orígenes externos (`object-src 'none'; frame-ancestors 'none'`) para impedir inyección remota de scripts.
4. **Sanitización Numérica en Frontera IPC y DSP**:
   * `AtomicParamBank::store_normalized` y `SeqLockArray::write_slice` descartan valores `NaN` o `±Infinity` antes de que lleguen al hilo de audio, protegiendo los oídos y monitores de estudio del usuario.

## Cómo Reportar una Vulnerabilidad

Si descubres una vulnerabilidad de seguridad (por ejemplo, escape de CSP en `base_plugin_webview`, corrupción de memoria en FFI VST3/CLAP o denegación de servicio en el hilo de audio), por favor repórtala abriendo un Advisory privado en la pestaña **Security -> Report a vulnerability** de este repositorio en GitHub.
