# Pipeline_Jenkins_GeneXus_NET_IIS

Pipeline declarativo Jenkins para desplegar la aplicacion GeneXus .NET sobre IIS remoto con promocion controlada DEV -> TEST -> PROD.

## Background

Automatiza el ciclo completo GeneXus 17 U10 + MSBuild + MSDeploy + WinRM: sincroniza la KB desde GXServer, compila, genera el ZIP de deploy, respalda el sitio remoto, despliega con stop/start del AppPool (rollback automatico) y verifica con health-check. Fuente de verdad de requirements: `openspec/`.

### Tecnologias

Jenkins (declarative), GeneXus 17 U10, MSBuild 2019, MSDeploy V3, IIS, PowerShell/WinRM, Batch.

### Flujo (5 stages reales)

1. **Update Commits** — sincroniza la KB (`gxserver changelog/poll`) al workspace del agente.
2. **Build KB** — compila con `TeamDev.msbuild` (credenciales `GXServer17` via `withCredentials`).
3. **Create ZIP** — genera el deploy con `Deploy.msbuild` (ApplicationKey desde `genexus-app-key`) y archiva `**/*.zip` con fingerprint + SHA256 en log.
4. **Backup+Deploy** — `Backup Current Site` genera `Backup-<APP_VERSION>.zip` (retencion 5) y `Deploy ZIP File on IIS server` ejecuta stop -> sync -> start con rollback auto (`ROLLBACK_OK`/`ROLLBACK_FAILED`); gates `Promote to TEST` / `Promote to PROD` (`input`) protegen TEST/PROD; `Tag Release` crea el tag `v<version>` en `main`.
5. **Verify** — `Verify Deploy (HealthCheck)` hace GET a `HealthCheckUrl` (3 intentos x 15 s, timeout 10 s; solo 2xx es SUCCESS) y restaura el Backup si falla; `post.always` re-arranca el AppPool.

## Matriz DEV/TEST/PROD

`TARGET_ENV` selecciona la entrada de `ENV_CONFIG` (unica fuente de verdad; ningun stage hardcodea entorno):

| TARGET_ENV | Host | AppPool | WebPath | credentialsId |
|---|---|---|---|---|
| DEV | SERVER_1.deploy.local | NET_Application_AppPool | E:\inetpup\wwwroot\NET_APPLICATION_DEV | credential_jenkins |
| TEST | SERVER_2.deploy.local | NET_Application_AppPool_TEST | E:\inetpup\wwwroot\NET_APPLICATION_TEST | credential_jenkins_test |
| PROD | SERVER_3.deploy.local | NET_Application_AppPool_PROD | E:\inetpup\wwwroot\NET_APPLICATION_PROD | credential_jenkins_prod |

## Install

Prerrequisitos: agente Windows con GeneXus 17 U10, MSBuild 2019, MSDeploy V3, plugin `gxserver`, WinRM habilitado en los IIS destino, variable global `GXServer17URL`.

Crear en Jenkins > Credentials estas 3+ credenciales antes de correr:

- `GXServer17` (username/password) — acceso a GXServer.
- `genexus-app-key` (secret text) — ApplicationKey GeneXus, inyectada como `GX_APP_KEY` solo en el stage Create ZIP.
- `credential_jenkins` (+ `credential_jenkins_test`, `credential_jenkins_prod` para la matriz) (username/password) — acceso MSDeploy/WinRM al IIS destino; el password viaja por env `MSDEPLOY_PASSWORD`, nunca en argv.
- `git-credentials` (username/password) — push del tag `v<APP_VERSION>` en `main` (stage Tag Release, idempotente).

## Usage

Happy path (solo con este README): crear las credenciales de arriba, luego Jenkins > Build with Parameters: `TARGET_ENV=DEV`, `APP_MAJOR=1`, `APP_MINOR=0`, `HealthCheckUrl=https://dev.ejemplo/health`. Para TEST/PROD aprobar los gates `Promote to TEST` / `Promote to PROD` (submitters `release-managers,admins`).

## Contributing

Verificacion sin Jenkins (REQ-005):

```powershell
# PS1: cero errores
Invoke-ScriptAnalyzer -Path ps1 -Severity Error
# ZIP ignorado por git (no debe listarse)
git status --porcelain
```

```bat
REM BAT: chequeo de sintaxis documentado (cmd /c exit code 0)
cmd /c bat\DeployFileOnIISServer.bat
```

```sh
# Jenkinsfile: parse Groovy / declarative linter
groovy Jenkinsfile
# Headers code-doc-standard presentes
grep -c Purpose Jenkinsfile bat/*.bat ps1/*.ps1
# Spec valida
openspec validate --strict
```

Convencion de commits: Conventional Commits (`feat:`, `fix:`).

## License

Uso interno del equipo de despliegue; sin licencia publica declarada.
