# 💪 Compromiso Saludable

**Proyecto final — TICS0870 (Blockchain)**
Grupo **Los HF** · Benjamín Hurtado · Alfonso Rojas Franulich

Contratos inteligentes de **compromiso para hábitos de bienestar**: el usuario respalda una meta
(ej. "correr 3 veces esta semana") con un depósito. Si la cumple dentro del plazo, lo recupera;
si no, su depósito pasa a un **pozo solidario**. Las reglas las ejecuta un contrato en la
blockchain, sin intermediarios.

## 🔗 Contrato desplegado (Sepolia)

`0x84D3D28F7f7fC1Ba6C10C1206A51B3E2917bB3aD`
[Ver en Etherscan](https://sepolia.etherscan.io/address/0x84D3D28F7f7fC1Ba6C10C1206A51B3E2917bB3aD)

## 📂 Estructura del repo

| Carpeta / archivo | Qué es |
|---|---|
| `src/CompromisoSaludable.sol` | Contrato **V1** (crear / validar / reclamar / pozo) |
| `src/CompromisoSaludableV2.sol` | Contrato **V2**: desafíos grupales con **reparto del pozo** entre quienes cumplen |
| `test/` | Pruebas automáticas (**14/14 ✅**: 5 de la V1 + 9 de la V2) |
| `web/index.html` | dApp: panel + crear/validar/reclamar con MetaMask |
| `web/conectar.html` | Página para conectar Strava (verificación automática) |
| `verificador/` | Verificador que decide el cumplimiento con datos reales de Strava |
| `backend/conectar_strava.py` | Backend que canjea el OAuth de Strava y baja actividades |
| `docs/` | Investigación de verificación, APIs de fitness y registro de despliegue |

## ▶️ Cómo correrlo

```bash
# Requisitos: Foundry (forge, cast) — https://getfoundry.sh
forge build      # compilar los contratos
forge test       # correr las 14 pruebas (V1 + V2)

# Abrir la interfaz web
python3 -m http.server 8000 --directory web   # luego: http://localhost:8000
```

Desplegar en Sepolia:
```bash
forge create src/CompromisoSaludable.sol:CompromisoSaludable \
  --rpc-url $RPC_URL --account <tu_cuenta> --broadcast
```

## 🧠 ¿Cómo funciona? (en una frase)

La web prepara el pedido → **MetaMask** lo firma y lo envía → la **red Sepolia** ejecuta el
contrato y graba el resultado → la web lee la blockchain y muestra todo actualizado.

## 👥 Para el equipo

Traer la última versión:
```bash
git clone --recurse-submodules https://github.com/benjahurtado88-creator/compromiso-saludable.git
# o, si ya lo clonaste:
git pull
```

> Hecho con la asistencia de Claude Code (declarado en el informe del proyecto, sección 8).
