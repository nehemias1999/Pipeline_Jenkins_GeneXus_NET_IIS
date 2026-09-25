# pipeline-quality Specification

## Purpose
Mantener el pipeline verificable localmente y documentado, con lint automatizable, estándares de documentación en scripts y un README fiel al flujo real.

## Requirements

### Requirement: Validación estática

El repo SHALL proveer verificación sin Jenkins: `Jenkinsfile` validable con declarative linter (o `groovy` parse), `BAT` con chequeo de sintaxis documentado y `PS1` con `PSScriptAnalyzer` (cero `Error`).

#### Scenario: CI local detecta error de sintaxis

WHEN un PS1 introduce `Write-Host` con variable indefinida grave THEN `Invoke-ScriptAnalyzer -Severity Error` lo reporta.

### Requirement: Estándares de repo

El repo SHALL incluir `.gitignore` (Windows, Jenkins, GeneXus build outputs, `*.zip`, backups) y headers `code-doc-standard` en `Jenkinsfile`, `*.bat` y `*.ps1` (propósito, uso, perfiles de verificación).

#### Scenario: build no commitea artefactos

WHEN se genera el ZIP local THEN `git status --porcelain` no lo lista (ignorado).

### Requirement: README fiel

El `README.md` SHALL describir los 5 stages reales (Update Commits, Build KB, Create ZIP, Backup+Deploy, Verify), la matriz DEV/TEST/PROD, las credenciales requeridas y los comandos de verificación.

#### Scenario: nuevo operador despliega solo con README

WHEN un operador sigue el README THEN crea las 3 credenciales y ejecuta el pipeline sin leer el Jenkinsfile.
