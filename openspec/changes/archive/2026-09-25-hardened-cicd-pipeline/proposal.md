# Proposal — hardened-cicd-pipeline

## Why

El `Jenkinsfile` actual despliega una app GeneXus .NET a IIS con secretos en texto plano (`ApplicationKey`), sin multientorno, sin `post`/`options`, sin versionado ni rollback: un fallo deja el AppPool detenido y sin trazabilidad. Hay que endurecerlo antes de llevarlo a TEST/PROD.

## What Changes

- Parametrización multientorno DEV/TEST/PROD (servidor, AppPool, KB, rutas, credenciales por entorno) + `parameters`, `options` (timestamps, timeout, buildDiscarder, disableConcurrentBuilds) y `post` (always/cleanup/notifications).
- Seguridad máxima: cero secretos en repo (`ApplicationKey` y passwords a Jenkins credentials + `maskPasswords`), BAT sin password en línea de comandos, PS1 con `CmdletBinding`/validación/`ErrorAction Stop`/`try-catch`, validación `PSScriptAnalyzer`.
- Trazabilidad y versionado SemVer + Git tag automático (`v<major>.<minor>.<BUILD_NUMBER>+<sha>`), `archiveArtifacts` + `fingerprint` del ZIP, `changelog` y build description con SHA/versión.
- Resiliencia: backup pre-deploy, rollback automático en fallo, `AppPool` garantizado con `post/always` + `try-finally`, healthcheck HTTP con retry, gates manuales (`input`) TEST→PROD.
- Calidad: lint/validación del Jenkinsfile (declarative linter), `.gitignore` Windows/Jenkins, headers `code-doc-standard` en todos los scripts, `README.md` actualizado al flujo real de 5 stages.

## Capabilities

### New Capabilities

- `multienv-pipeline`: pipeline declarativo parametrizado DEV/TEST/PROD con options/post y gates de promoción.
- `pipeline-security`: gestión segura de secretos, masking, hardening BAT/PS1.
- `traceability-versioning`: versionado SemVer + tag git + artefactos trazables por build.
- `resilient-deploy`: backup/rollback, AppPool always-on, healthcheck con retry.
- `pipeline-quality`: validación, docs y estándares de repo CI/CD.

### Modified Capabilities

(none — repo sin specs previas)

## Impact

- Afecta: `Jenkinsfile`, `bat/DeployFileOnIISServer.bat`, `ps1/StartAppPool.ps1`, `ps1/StopAppPool.ps1`, `README.md`, nuevo `.gitignore`.
- Sistemas: Jenkins controller + agente `SERVER_1`, GeneXus 17U10/MSBuild, servidor IIS remoto (WinRM + MSDeploy).
- **BREAKING**: `ApplicationKey` deja de estar en el repo (pasa a credential `genexus-app-key`); el deploy requiere parámetros de entorno y credenciales `credential_jenkins` + nuevas; el BAT cambia su interfaz (ya no acepta password en argv).
