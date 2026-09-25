# Design — hardened-cicd-pipeline

## Context

Jenkins declarativo sobre agente Windows `SERVER_1` con GeneXus 17U10 + MSBuild 2019, deploy remoto vía WinRM (`Invoke-Command`) + MSDeploy `sync`. Sin librerías compartidas ni Vault externo: todo con credentials nativas Jenkins. Ver proposal.md (Why) y `specs/*` para requisitos.

## Goals / Non-Goals

- Goals: un solo `Jenkinsfile` multientorno; cero secretos en repo/logs; deploy atómico aparente (backup+rollback); verificación HTTP.
- Non-Goals: migrar a Shared Library; introducir HashiCorp Vault/Ansible; blue-green con 2 sitios (se deja como evolución); tests de la app GeneXus (fuera de alcance).

## Decisions

1. **Mapa de entornos en `environment` + `parameters`, no `matrix`**: `TARGET_ENV` choice + maps Groovy (`ENV_CONFIG = [DEV:[...], TEST:[...], PROD:[...]]`). Rationale: matrix duplica agentes Windows escasos; mapa mantiene un executor. Alternativa `matrix` descartada por costo de agentes.
2. **`ApplicationKey` → `string` credential `genexus-app-key`**: se inyecta vía `withCredentials([string(...)])` solo en el stage Create-ZIP. Alternativa `usernamePassword` descartada (es un token, no user/pass).
3. **BAT sin password en argv**: nuevo contrato de 5 args + `MSDEPLOY_PASSWORD` por env (inyectada por `withCredentials`). Rationale: `argv` es visible en `ps/list`; env solo en el proceso. Se entrecomillan todas las rutas (`"%~1"`).
4. **PS1 con `Invoke-Command -Authentication Kerberos` + try/catch + exit codes**: fija auth (evita NTLM downgrade) y hace el fallo observable por Jenkins (`$LASTEXITCODE`). `PSScriptAnalyzer` como gate.
5. **Backup como `msdeploy -verb:sync -source:contentPath -dest:package`**: reutiliza la misma herramienta (sin nuevos binarios en el agente). Retención: `keep last 5` por limpieza Groovy.
6. **Healthcheck con `Invoke-WebRequest` + retry Groovy (3×15s)**: simple, sin plugins extra. URL por entorno (`HealthCheckUrl` param). Alternativa plugin `httpRequest` descartada (requiere instalar plugin en controller).
7. **Tag git solo en `main` + `TAG_OK` idempotente**: `git tag -a` + `push --tags` con `sshagent`/credential; si existe se omite. Evita builds duplicados en PRs.

## Risks / Trade-offs

- [WinRM Kerberos requiere SPN/delegación] → Mitigación: documentar prerequisito en README + mensaje de error accionable en PS1.
- [Env var `MSDEPLOY_PASSWORD` visible en `env` del proceso hijo] → Mitigación: `maskPasswords`, `setlocal`, nunca `echo`; vida corta (solo stage Deploy).
- [`archiveArtifacts` crece en disco] → Mitigación: `buildDiscarder(30,10)` + política de borrado de backups (5).
- [GeneXus plugin `gxserver` sin mock local] → Mitigación: verificación = `groovy` parse + `yamllint`-style review + checklist manual contra Jenkins linter (`/pipeline-model-converter/validate`).

## Migration Plan

1. Crear en Jenkins: `genexus-app-key` (secret text), `credential_jenkins` (user/pass ya existe → rotar), `git-credentials` (para tags), `GXServer17` (existe).
2. Mergear PR por requisito (5 PRs); cada merge deploya solo DEV (TEST/PROD con `input`).
3. Borrar `ApplicationKey` del historial si se requiere (`BFG` — coordinar porque reescribe SHA).
4. Rollback: re-ejecutar build con `TARGET_ENV` + tag anterior, o `msdeploy` manual del `Backup-<ver>.zip`.

## Open Questions

- Ninguna que bloquee specs/diseño: el SPN exacto de WinRM y la URL de health por entorno se confirman al parametrizar (valores por defecto en el mapa, override por `params`).
