"""
Verificador de metas de bienestar con datos REALES de Strava.

Idea: lee las actividades de ejercicio (extraídas de Strava, archivo
`actividades_strava.json`) y decide automáticamente si una meta se cumplió.
Ese veredicto (True/False) es lo que alimentaría la función `validar()` del
contrato CompromisoSaludable — o sea, reemplaza al validador humano por una
verificación automática basada en datos reales.

Es la base de la "validación asistida": en vez de que una persona diga
"sí cumplió", lo decide el dato de Strava.

Uso:  python3 verificador/verificar.py
"""

import json
from datetime import datetime
from pathlib import Path

# Archivo con las actividades (ya limpias, sin datos sensibles).
ARCHIVO = Path(__file__).parent / "actividades_strava.json"


def cargar_actividades():
    """Lee el JSON de actividades y lo devuelve como lista de diccionarios."""
    return json.loads(ARCHIVO.read_text())


def verificar_meta(actividades, *, tipo=None, veces_min=0, km_min=0.0, desde=None, hasta=None):
    """
    Revisa si se cumplió una meta dentro de un período.

    - tipo:      tipo de actividad de Strava ("Ride", "Run", "WeightTraining", ...)
                 o None para aceptar cualquiera.
    - veces_min: cantidad mínima de sesiones requeridas.
    - km_min:    distancia total mínima requerida (en km).
    - desde/hasta: rango de fechas (objetos datetime). El plazo del compromiso.

    Devuelve (cumplio, detalle) donde detalle trae los números encontrados.
    """
    seleccion = []
    for a in actividades:
        # Filtro por tipo de ejercicio
        if tipo and a.get("type") != tipo:
            continue
        # Filtro por fecha (dentro del plazo del compromiso)
        fecha = datetime.fromisoformat(a["start_date_local"][:10])
        if desde and fecha < desde:
            continue
        if hasta and fecha > hasta:
            continue
        seleccion.append(a)

    veces = len(seleccion)
    km_total = round(sum(a["distance"] for a in seleccion) / 1000, 1)

    # Se cumple si alcanza tanto la cantidad de veces como los km exigidos.
    cumplio = (veces >= veces_min) and (km_total >= km_min)

    detalle = {"veces": veces, "km_total": km_total, "actividades": seleccion}
    return cumplio, detalle


def mostrar(nombre_meta, cumplio, detalle, exigido):
    """Imprime el resultado de una meta de forma legible."""
    print(f"\n📋 Meta: {nombre_meta}")
    print(f"   Exigido: {exigido}")
    print(f"   Encontrado en Strava: {detalle['veces']} sesión(es), {detalle['km_total']} km en total")
    for a in detalle["actividades"]:
        km = round(a["distance"] / 1000, 1)
        mins = round(a["moving_time"] / 60)
        print(f"      • {a['start_date_local'][:10]}  {a['type']:14} {km} km  {mins} min")
    veredicto = "✅ CUMPLIDA" if cumplio else "❌ NO CUMPLIDA"
    print(f"   → Veredicto: {veredicto}")
    print(f"   → Esto llamaría a:  validar(idCompromiso, {str(cumplio).lower()})")


if __name__ == "__main__":
    actividades = cargar_actividades()
    print("=" * 64)
    print(f"VERIFICADOR DE METAS — {len(actividades)} actividades reales de Strava")
    print("=" * 64)

    # --- Ejemplo 1: meta CUMPLIDA ---
    # "Andar en bici al menos 3 veces entre el 31-mar y el 7-abr de 2026"
    cumplio, detalle = verificar_meta(
        actividades,
        tipo="Ride",
        veces_min=3,
        desde=datetime(2026, 3, 31),
        hasta=datetime(2026, 4, 7),
    )
    mostrar(
        "Andar en bici 3 veces (31-mar a 7-abr 2026)",
        cumplio, detalle,
        exigido="≥ 3 sesiones de tipo Ride en el período",
    )

    # --- Ejemplo 2: meta NO CUMPLIDA (no hay carreras en los datos) ---
    cumplio, detalle = verificar_meta(
        actividades,
        tipo="Run",
        veces_min=1,
        desde=datetime(2026, 4, 1),
        hasta=datetime(2026, 4, 30),
    )
    mostrar(
        "Salir a correr al menos 1 vez (abril 2026)",
        cumplio, detalle,
        exigido="≥ 1 sesión de tipo Run en el período",
    )

    # --- Ejemplo 3: meta por distancia ---
    cumplio, detalle = verificar_meta(
        actividades,
        tipo="Ride",
        km_min=100,
        desde=datetime(2026, 3, 31),
        hasta=datetime(2026, 4, 7),
    )
    mostrar(
        "Pedalear 100 km en total (31-mar a 7-abr 2026)",
        cumplio, detalle,
        exigido="≥ 100 km sumados de tipo Ride",
    )

    print("\n" + "=" * 64)
    print("El veredicto (True/False) es lo que el contrato usaría en validar().")
    print("=" * 64)
