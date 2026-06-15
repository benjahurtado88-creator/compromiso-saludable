# Registro de despliegue — CompromisoSaludable V1

**Fecha:** 14 de junio de 2026
**Red:** Sepolia (testnet de Ethereum, chainId 11155111)

| Dato | Valor |
|---|---|
| **Dirección del contrato** | `0x84D3D28F7f7fC1Ba6C10C1206A51B3E2917bB3aD` |
| **Desplegado por (owner/validador)** | `0xAA0BeDee411eCCCE1cECE15F2d0Df85954Cbb3DF` |
| **Transaction hash** | `0xc390c568c9609e0eb481eccb8ff45d0b5f1ae7eae405d1d5a42ea86df8ffa61f` |
| **Bloque** | 11061137 |
| **Gas usado** | 1.576.315 |
| **Estado** | success (1) |

**Estado inicial verificado on-chain:** `owner` = wallet desplegadora, `totalCompromisos` = 0, `pozoSolidario` = 0.

## Cómo se desplegó (reproducible)

```bash
cd /Users/benjamin/Documents/code/blochain
forge create src/CompromisoSaludable.sol:CompromisoSaludable \
  --rpc-url $RPC_URL \
  --account cursoblock \
  --broadcast
```

## Ver el contrato en el explorador

https://sepolia.etherscan.io/address/0x84D3D28F7f7fC1Ba6C10C1206A51B3E2917bB3aD

## Cómo interactuar (lectura, gratis)

```bash
# Ver el dueño/validador
cast call 0x84D3D28F7f7fC1Ba6C10C1206A51B3E2917bB3aD "owner()(address)" --rpc-url $RPC_URL

# Ver cuántos compromisos hay
cast call 0x84D3D28F7f7fC1Ba6C10C1206A51B3E2917bB3aD "totalCompromisos()(uint256)" --rpc-url $RPC_URL
```
