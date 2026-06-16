# APIs y MCP de datos de ejercicio — investigación (junio 2026)

> Objetivo: conectar datos reales de ejercicio (Apple Watch, Strava, etc.) al proyecto,
> para verificar metas de forma automática (rama `mcp`).

## Comparación de fuentes de datos

| Fuente | ¿API de servidor? | Auth | Datos | Costo / estado (jun 2026) | Veredicto |
|---|---|---|---|---|---|
| **Strava** | ✅ Sí (REST v3) | OAuth2 (refresh tokens) | Actividades: distancia, tiempo, GPS, ritmo | ⚠️ **$11.99/mes** + suscripción Strava (nuevo desde 1-jun-2026) | ✅ **La mejor opción** |
| **Apple Watch / HealthKit** | ❌ **No hay API de servidor** | — | Solo en el iPhone | Requiere **app iOS nativa** que lea y empuje los datos | ❌ No directo (ver nota) |
| **Google Fit (REST)** | 🔻 Deprecada | OAuth2 | — | Fin de servicio **fines 2026**; sin altas nuevas desde may-2024 | ❌ Evitar |
| **Fitbit Web API** | ✅ Sí | OAuth2 + PKCE | Pasos, actividad, ritmo cardíaco | 🔻 Se apaga **sep-2026**; migra a Google Health API | ❌ No empezar |
| **Garmin Health API** | ✅ Sí | OAuth | Actividades, métricas de salud | 🔒 Requiere **aprobación** (días-semanas); hay **sandbox gratis** con datos sintéticos | 🟡 Solo con aprobación |

### Notas clave
- **Apple Watch NO se conecta directo**: Apple Health vive en el iPhone, sin API web ni OAuth. PERO el Apple Watch **sincroniza a Strava** automáticamente → así que se lee vía **Strava**. Strava funciona como **hub universal** (recibe datos de Apple Watch, Garmin, etc.).
- **Strava es la única opción REST realmente accesible** hoy; el resto está sin API de servidor, deprecado, o requiere aprobación.

## MCP servers para Strava (listos para usar)

Existen varios servidores MCP de Strava en GitHub que permiten que un LLM (como Claude) lea actividades de Strava:
- **kw510/strava-mcp** — con OAuth integrado, sobre Cloudflare Workers.
- **r-huijts/strava-mcp** — expone 25 herramientas de la API v3.
- **eddmann/strava-mcp**, **tomekkorbak/strava-mcp-server**, **gcoombe/strava-mcp**, etc.

Todos necesitan credenciales de la API de Strava (que ahora requieren el tier de pago).

## Cómo conectar los datos al contrato

1. **Vía IA + MCP (encaja con esta rama):** un servidor MCP de Strava le da a Claude acceso a tus actividades → la IA juzga si cumpliste la meta → podría llamar a `validar()` en el contrato. (Validación asistida por IA.)
2. **Vía oráculo (precedente real ChainRunners):** **Chainlink Functions** llama a la API de Strava, trae la distancia, y el contrato libera fondos según eso. Es la arquitectura "any-API" probada.
3. **Vía backend simple:** un servidor propio lee Strava y firma una transacción `validar()`.

## Recomendación

- **Strava es la opción clara** (única API REST accesible + tiene MCP servers + es el precedente probado con ChainRunners).
- **Camino Apple Watch:** sincronizar el reloj a Strava y leer Strava (no se accede al reloj directo).
- ⚠️ **Caveat de costo:** desde junio 2026 Strava cobra **$11.99/mes** por la API. Para un proyecto de curso, opciones:
  - Pagar 1 mes para construir/demostrar.
  - Usar el **sandbox gratis de Garmin** (datos sintéticos) para prototipar el flujo sin costo ni aprobación.
  - **Describir** la integración (con MCP server) en el informe sin pagar, dejando el validador manual como base.

## Fuentes

- Strava Developer Program 2026 — https://communityhub.strava.com/insider-journal-9/an-update-to-our-developer-program-13428
- Strava API v3 docs — https://developers.strava.com/docs/
- Strava 2026 changes (fees & MCP) — https://appsforstrava.com/blog/strava-developer-program-changes-2026/
- Strava MCP servers — https://github.com/r-huijts/strava-mcp · https://github.com/kw510/strava-mcp
- Apple HealthKit (sin API de servidor) — https://www.themomentum.ai/blog/what-you-can-and-cant-do-with-apple-healthkit-data
- Google Fit deprecation — https://developer.android.com/health-and-fitness/health-connect/migration/fit
- Fitbit Web API turndown (sep-2026) — https://community.fitbit.com/t5/Web-API-Development/Introducing-the-next-phase-of-the-Fitbit-Web-API/td-p/5821061
- Garmin Health API (partner program + sandbox) — https://developer.garmin.com/gc-developer-program/health-api/
- Chainlink Functions (conectar APIs al contrato) — https://chain.link/functions
- ChainRunners (Strava + Chainlink Functions) — https://devpost.com/software/holdingplace
