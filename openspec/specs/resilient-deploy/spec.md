# resilient-deploy Specification

## Purpose
Garantizar que un despliegue fallido nunca deje el sitio caído: respaldo previo, rollback automático, AppPool siempre arrancado y verificación HTTP antes de declarar éxito.

## Requirements

### Requirement: Backup pre-deploy

Antes de MSDeploy el pipeline SHALL generar un backup versionado del `contentPath` remoto (`Backup-<APP_VERSION>.zip`) y conservar los últimos 5.

#### Scenario: backup existe antes de sync

WHEN inicia el sync THEN existe `Backup-<APP_VERSION>.zip` accesible para rollback.

### Requirement: Rollback automático

Si MSDeploy o el healthcheck fallan, el pipeline SHALL re-sincronizar el backup y re-arrancar el AppPool, marcando el build FAILURE con causa `ROLLBACK_OK` o `ROLLBACK_FAILED`.

#### Scenario: fallo de health dispara restore

WHEN el healthcheck falla 3 veces THEN se restaura el backup y el log muestra `ROLLBACK_OK`.

### Requirement: AppPool always-on

El AppPool SHALL arrancarse en `post.always` (además del flujo normal stop→deploy→start con `try/finally` en el stage), de modo que ningún camino deje el pool detenido.

#### Scenario: abort manual igual arranca pool

WHEN el build es abortado THEN `post.always` ejecuta `StartAppPool.ps1`.

### Requirement: Healthcheck con retry

Tras arrancar el pool el pipeline SHALL hacer `GET <HealthCheckUrl>` hasta 3 intentos (15s entre ellos, timeout 10s); solo 2xx es SUCCESS.

#### Scenario: app responde 200

WHEN el endpoint devuelve 200 en el 2.º intento THEN el stage pasa sin rollback.
