# Verificación de ejercicio en una app de "compromiso por uno mismo" sobre blockchain

> Investigación para el proyecto **Compromiso Saludable** (curso TICS0870).
> Pregunta: ¿cómo verificar de forma confiable y resistente a trampas que un usuario
> cumplió una meta de **ejercicio físico**, para que el contrato libere los fondos?

## Hallazgo central (la idea que ordena todo)

Una blockchain **no puede leer datos del mundo real por sí sola** (es una red aislada): este
es **"el problema del oráculo"**. Por lo tanto, un contrato Solidity de apuesta-por-uno-mismo
**necesita obligatoriamente un oráculo** (alguien o algo que le diga "sí se ejercitó"), y ese
oráculo es justo donde se concentra el riesgo de trampa y de confianza.

**El límite que ningún método elimina:** probar de *dónde viene* un dato (su origen/integridad)
**no es lo mismo** que probar que el ejercicio *realmente ocurrió*. La trampa entra *aguas arriba*,
en el sensor del teléfono, antes de llegar a cualquier API. El GPS civil **no está autenticado**
y se puede falsear con hardware de **~US$200**; a nivel app, el "mock location" del teléfono es
aún más fácil. → *"garbage in, garbage out"* (basura entra, basura sale).

Incluso los proyectos serios de "move-to-earn" (STEPN, Sweatcoin) resuelven el anti-trampa con
**modelos de Machine Learning centralizados y fuera de la cadena (off-chain), operados por una
sola empresa**. La verificación robusta de fitness es difícil de descentralizar.

## El abanico de opciones (de más simple a más robusta)

| Opción | Cómo funciona | Confianza | ¿Resiste trampa? | Complejidad |
|---|---|---|---|---|
| **(a) Validador único** | Un admin/árbitro confirma a mano | Total en 1 persona (punto único de fallo) | Depende del árbitro; no frena spoofing | **Muy baja** ✅ |
| **(b) Oráculo a API de fitness** | Chainlink Functions llama a Strava/Google Fit y trae el dato | En la API + el oráculo | **No** por sí solo: GPS/GPX falseable | Media-alta |
| **(c) Validación social/distribuida** | Votación de pares / múltiples validadores / disputa con staking (estilo Kleros/UMA) | Repartida en varios | Mejor vs. 1 árbitro, pero vulnerable a colusión/sybil | Media |
| **(d) Pruebas criptográficas (zkTLS)** | Reclaim/DECO prueban que el dato vino íntegro de la API, verificable on-chain en Solidity | En los "attestors" del protocolo | Prueba **origen, no veracidad** del ejercicio | Alta |
| **(e) Híbrido** | IA detecta anomalías de movimiento + respaldo humano de disputa | Mixta | La defensa más práctica (varias señales) | Alta |

## Precedentes reales (citables)

- **ChainRunners** — ⭐ casi idéntico a nuestro proyecto: los usuarios **apuestan ETH en un
  contrato Solidity** para competencias de running, y los fondos se liberan **según la distancia**;
  verifica el ejercicio con **Chainlink Functions → API de Strava**. Construido para el hackathon
  Chainlink Constellation (2023). **Sus propios autores admiten** que *"el sistema confía en el
  input sin un mecanismo robusto para prevenir trampas"*. Es prototipo temprano, replicable en Sepolia.
- **STEPN (anti-cheat SMAC-7)** — no confía en GPS crudo; usa ML (autoencoders) sobre GPS +
  sensores de movimiento + datos de salud para detectar "carreras anómalas". Clasifica
  **"GPS Spoofing" y "Motion Simulation"** como la categoría de máxima severidad (ban inmediato).
  Es **centralizado, propietario, no auditado**, con falsos positivos documentados.
- **Sweatcoin** — algoritmo propietario que filtra "sacudidas" del teléfono (solo ~65% de los
  pasos cuentan); detección de fraude **off-chain, un solo validador (SweatCo Ltd)**;
  descentralización = plan futuro.
- **DietBet** — verificación humana/social; reconoce el **riesgo de colusión** validador-usuario
  y lo mitiga *socialmente*: *"no juegues en un juego cuyo organizador no conoces ni en quien confías"*.

## Diseño recomendado para el proyecto + hoja de ruta

**Empezar simple (lo que ya tenemos / lo inmediato):**
1. **V1 — Validador único (hecho):** el dueño confirma. Simple y funciona; **asumimos
   explícitamente** esa confianza (esto es honesto y se declara en el informe).
2. **V2 — Validación de pares / grupal (confianza repartida):** que el grupo se confirme entre sí
   (varios ojos, no uno). Resuelve la crítica de "depender de una sola persona" sin gran complejidad.

**Subir de nivel (trabajo futuro):**
3. **Oráculo any-API** a Strava/Google Fit vía Chainlink Functions (precedente: ChainRunners).
4. **Verificación optimista** con período de disputa + **detección de anomalías de movimiento**
   estilo STEPN.
5. **Pruebas criptográficas zkTLS** (Reclaim/DECO) verificadas on-chain en Solidity.

## Análisis crítico (para la rúbrica) — limitaciones y trabajo futuro

- **Límite estructural:** ningún método elimina el *spoofing* de GPS/sensores aguas arriba.
  Todas las técnicas prueban *origen/forma* del dato, no que el ejercicio real haya ocurrido.
- **Validador único:** punto único de fallo (caída, hackeo, soborno/colusión).
- **Oráculo a API:** hereda la falsificabilidad del sensor; añade dependencia de la API y del oráculo.
- **Validación social:** vulnerable a colusión y a ataques *sybil* (cuentas falsas).
- **zkTLS:** "garbage in, garbage out" + supuesto de confianza en los *attestors*.
- **Defensa práctica realista:** combinar múltiples señales (sensores fusionados) + límites
  económicos + disputa humana, en vez de buscar una prueba perfecta que no existe.

## Fuentes citables

1. The Blockchain Oracle Problem — Chainlink — https://chain.link/education-hub/oracle-problem
2. A Study of Blockchain Oracles (arXiv 2004.07140) — https://arxiv.org/abs/2004.07140
3. ChainRunners (Devpost) — https://devpost.com/software/holdingplace
4. ChainRunners (GitHub) — https://github.com/Ahmedborwin/ChainRunners
5. STEPN — Anti-Cheating System (whitepaper) — https://whitepaper.stepn.com/running-module/anti-cheating-system
6. STEPN — SMAC (Medium) — https://stepnofficial.medium.com/smac-stepn-model-for-anti-cheating-a36bc1d6ecb0
7. Sweatcoin — Step Verification & Fraud Detection — https://medium.com/sweat-economy/step-verification-and-fraud-detection-a2f0f8947f3c
8. DietBet — How DietBet Prevents Cheating — https://www.dietbet.com/how-dietbet-prevents-cheating
9. GPS spoofing (~US$200) — USENIX Security '21, "Stars Can Tell" — https://gangw.cs.illinois.edu/security21-a.pdf
10. GPS spoofing de navegación — USENIX Security '18, Zeng et al. — https://www.usenix.org/conference/usenixsecurity18/presentation/zeng
11. Reclaim Protocol (zkTLS) — https://docs.reclaimprotocol.org/
12. Reclaim Solidity SDK — https://github.com/reclaimprotocol/reclaim-solidity-sdk
13. DECO (arXiv 1909.00938, ACM CCS 2020) — https://arxiv.org/abs/1909.00938
14. Kleros vs UMA (oráculos por punto de Schelling) — https://blog.kleros.io/kleros-and-uma-a-comparison-of-schelling-point-based-blockchain-oracles/

> Nota de transparencia: las fuentes [1][2] de Chainlink son de un *vendor* de oráculos
> (corroboradas por fuentes académicas neutrales); las descripciones de STEPN/Sweatcoin vienen de
> sus propias empresas (sistemas cerrados, no auditados) → citar como "afirman/diseñan", no como
> eficacia probada.
