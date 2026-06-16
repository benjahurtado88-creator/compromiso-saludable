# Verificador automático con datos de Strava (rama `mcp`)

Conecta **datos reales de ejercicio** (de Strava) con la validación del contrato
`CompromisoSaludable`. En vez de que un humano confirme "sí cumplió", lo decide
automáticamente el dato de Strava.

## Qué hay acá

- **`actividades_strava.json`** — actividades reales de ejercicio extraídas de Strava
  (provenientes del repo `kaihv/wellness-hackathon`), **ya sin datos sensibles**
  (se quitaron GPS, ubicación e ID de atleta; se dejó tipo, distancia, duración y fecha).
- **`verificar.py`** — lee esas actividades y decide si una meta se cumplió.

## Cómo funciona

```
Datos de Strava (JSON)  →  verificar.py  →  veredicto True/False  →  validar(id, veredicto)
```

El script filtra las actividades por **tipo** (Ride/Run/...), **período** (el plazo del
compromiso) y exige una **cantidad de sesiones** y/o una **distancia mínima**. Devuelve
`True`/`False`, que es justo lo que recibe la función `validar()` del contrato.

## Cómo correrlo

```bash
python3 verificador/verificar.py
```

## Nota honesta sobre "sin pagar"

Los datos **ya estaban extraídos** en el repo del hackathon, así que los usamos **gratis y
sin conectarnos a Strava**. El script de OAuth de Strava (en ese repo) usa la API oficial,
que desde junio 2026 requiere acceso pago — por eso acá trabajamos sobre el JSON ya extraído.

## Próximos pasos (mejoras futuras)

1. **Que llame solo a `validar()`**: con una clave de "validador", el script firma y envía
   la transacción automáticamente (oráculo/backend).
2. **Capa de IA (MCP)**: un servidor MCP de Strava + Claude que lea la meta en texto libre
   ("correr 3 veces") y la actividad, y juzgue — validación asistida por IA.
3. **Datos en vivo**: conectar la API de Strava real (con credenciales) o el sandbox de Garmin.
4. **Anti-trampa**: detección de anomalías de movimiento (estilo STEPN) sobre los datos.

> Límite a declarar en el informe: verificar el dato de Strava prueba *que existe la actividad*,
> no que el GPS no se haya falseado. Ver `docs/investigacion-verificacion-ejercicio.md`.
