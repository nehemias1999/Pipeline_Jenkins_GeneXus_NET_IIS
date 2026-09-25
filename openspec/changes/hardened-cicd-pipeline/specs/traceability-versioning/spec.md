# traceability-versioning

## Purpose

Dar a cada ejecución una versión única y auditable que vincule código, artefacto y despliegue, permitiendo saber qué commit está corriendo en cada entorno.

## ADDED Requirements

### Requirement: Versión SemVer por build

Cada build SHALL computar `APP_VERSION = <major>.<minor>.<BUILD_NUMBER>+<shortSHA>` (major/minor por parámetro, default 1.0) y exponerla como variable de entorno y `currentBuild.description`.

#### Scenario: description contiene versión y SHA

WHEN termina el stage Init THEN `currentBuild.description` incluye `v1.0.<N>+<sha7>`.

### Requirement: Tag git automático

En builds `SUCCESS` de la rama `main` el pipeline SHALL crear y pushear el tag `v<version>` (con credencial git), sin duplicar tags existentes.

#### Scenario: tag creado una sola vez

WHEN el tag `v1.0.5` ya existe THEN el push se omite (no falla el build).

### Requirement: Artefacto archivado y fingerprinted

El ZIP generado SHALL archivarse con `archiveArtifacts(artifacts: '**/*.zip', fingerprint: true, onlyIfSuccessful: false)` y registrar su SHA256 en el log.

#### Scenario: artefacto descargable desde Jenkins

WHEN el build termina THEN la página del build lista el ZIP con fingerprint consultable.
