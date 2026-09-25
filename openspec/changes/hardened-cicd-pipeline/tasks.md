# Tasks — hardened-cicd-pipeline

## 1. REQ-001 multienv-pipeline (archivos: Jenkinsfile)

- [ ] 1.1 Agregar `parameters { choice TARGET_ENV; string APP_MAJOR/MINOR; string HealthCheckUrl }` + mapa ENV_CONFIG DEV/TEST/PROD y verificar con `grep -c TARGET_ENV Jenkinsfile` ≥ 3
- [ ] 1.2 Agregar `options { timestamps, timeout(60), buildDiscarder(30,10), disableConcurrentBuilds }` y verificar parse Groovy OK (`groovy -e` o Jenkins linter sin error de sintaxis)
- [ ] 1.3 Agregar `post { always { start AppPool + cleanWs parcial }, success/failure/unstable { echo notificación } }` y verificar que `grep -c "post" Jenkinsfile` ≥ 1 y AppPool aparece en `always`
- [ ] 1.4 Agregar `input "Promote to TEST/PROD?"` before deploy TEST/PROD y verificar texto presente vía `grep -c "input" Jenkinsfile` ≥ 2

## 2. REQ-002 pipeline-security (archivos: Jenkinsfile, bat/DeployFileOnIISServer.bat, ps1/*.ps1)

- [ ] 2.1 Eliminar `ApplicationKey` literal → `withCredentials([string(credentialsId:'genexus-app-key',variable:'GX_APP_KEY')])` y verificar `grep -r DE6F1DCA . --exclude-dir=.git` vacío
- [ ] 2.2 Envolver credenciales con `maskPasswords`/`withCredentials` y verificar `grep -c withCredentials Jenkinsfile` ≥ 3 y ninguna `echo` de variable de secreto
- [ ] 2.3 Reescribir BAT a 5 args + `MSDEPLOY_PASSWORD` env, rutas entrecomilladas, validación de args, y verificar ejecución en seco documentada + `grep -c MSDEPLOY_PASSWORD bat/*.bat` ≥ 2
- [ ] 2.4 Endurecer PS1 (`[CmdletBinding()]`, Mandatory, ErrorAction Stop, try/catch, Kerberos) y verificar `Invoke-ScriptAnalyzer -Severity Error` cero errores (o revisión checklist si no hay Windows)

## 3. REQ-003 traceability-versioning (archivos: Jenkinsfile)

- [ ] 3.1 Computar `APP_VERSION=<major>.<minor>.<BUILD_NUMBER>+<sha7>` + `currentBuild.description` y verificar `grep -c APP_VERSION Jenkinsfile` ≥ 2
- [ ] 3.2 Tag git `v<version>` solo en `main`/SUCCESS con `sshagent`, idempotente, y verificar bloque `when { branch 'main' }` presente
- [ ] 3.3 `archiveArtifacts '**/*.zip', fingerprint:true` + `sha256sum` en log y verificar texto presente vía `grep -c archiveArtifacts Jenkinsfile` ≥ 1

## 4. REQ-004 resilient-deploy (archivos: Jenkinsfile, ps1/*.ps1)

- [ ] 4.1 Backup `msdeploy contentPath→package Backup-<ver>.zip` + retención 5 y verificar comando `Backup` presente vía grep
- [ ] 4.2 Rollback auto (restore backup + start pool, marca ROLLBACK_OK/FAILED) en `catch`/`post.failure` y verificar bloque `ROLLBACK` presente
- [ ] 4.3 Stage `Verify` con `Invoke-WebRequest <HealthCheckUrl>` retry 3×15s y verificar `grep -c HealthCheck Jenkinsfile` ≥ 2
- [ ] 4.4 `try/finally` stop→deploy→start en stage Deploy + `post.always` start pool y verificar ambos presentes

## 5. REQ-005 pipeline-quality (archivos: .gitignore, Jenkinsfile, bat, ps1, README.md)

- [ ] 5.1 Crear `.gitignore` (Windows/Jenkins/GeneXus outputs, `*.zip`, backups) y verificar `git status --porcelain` no lista ZIP tras `touch test.zip`
- [ ] 5.2 Headers `code-doc-standard` en Jenkinsfile/bat/ps1 y verificar `grep -c "Purpose:"` en cada archivo ≥ 1
- [ ] 5.3 Reescribir README (5 stages, matriz entornos, credenciales, verificación) y verificar que menciona las 3 credenciales y los 5 stages
- [ ] 5.4 Validación global `openspec validate` en STRICT pasa sin errores
