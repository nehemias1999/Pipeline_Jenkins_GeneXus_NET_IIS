# multienv-pipeline Specification

## Purpose
Parametrizar el pipeline Jenkins para operar en DEV, TEST y PROD con opciones declarativas y bloques post deterministas, permitiendo promoción controlada entre entornos sin duplicar código.

## Requirements

### Requirement: Parámetros por entorno

El pipeline SHALL exponer `choice TARGET_ENV (DEV/TEST/PROD)` y resolver servidor, AppPool, KB, rutas y credential IDs desde un mapa por entorno, sin valores hardcodeados fuera del mapa.

#### Scenario: build en TEST resuelve host TEST

WHEN se ejecuta con `TARGET_ENV=TEST` THEN el deploy usa el host/AppPool/paths de TEST y nunca los de DEV.

### Requirement: Options declarativas

El pipeline SHALL definir `options { timestamps(), timeout(60), buildDiscarder(logRotator(30,10)), disableConcurrentBuilds(), skipDefaultCheckout(false) }`.

#### Scenario: timeout aborta build colgado

WHEN un stage excede 60 min THEN Jenkins aborta el build y lo marca FAILURE.

### Requirement: Post determinista

El pipeline SHALL definir `post { always { AppPool start + limpieza workspace parcial }, success { notificación }, failure { notificación + rollback trigger }, unstable { notificación } }`.

#### Scenario: fallo garantiza AppPool arrancado

WHEN el stage Deploy falla THEN el bloque `always` intenta arrancar el AppPool y el build termina FAILURE (no SUCCESS).

### Requirement: Gates de promoción

El pipeline SHALL exigir `input "Promote to TEST/PROD?"` con `submitter` restringido antes de deployar a TEST y PROD.

#### Scenario: sin aprobación no hay deploy a PROD

WHEN no se aprueba el `input` THEN el stage de PROD nunca ejecuta MSDeploy.
