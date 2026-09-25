# pipeline-security

## Purpose

Eliminar toda exposición de secretos en el repositorio y en logs/procesos, aplicando credenciales Jenkins enmascaradas y hardening de scripts BAT y PowerShell según PSScriptAnalyzer.

## ADDED Requirements

### Requirement: Cero secretos en repo

El repositorio SHALL NOT contener `ApplicationKey`, passwords, hosts internos ni rutas absolutas sensibles; `ApplicationKey` SHALL vivir en la credential `genexus-app-key` (secret text) y referenciarse solo vía `credentials()`/`withCredentials`.

#### Scenario: grep no encuentra secretos

WHEN se ejecuta `grep -rE "ApplicationKey|password\s*=" --include="*.groovy" --include="Jenkinsfile" .` (excluyendo docs) THEN no hay coincidencias con valores literales.

### Requirement: Masking en logs

Todo uso de credenciales SHALL pasar por `withCredentials` + `maskPasswords` (o equivalente) de modo que Jenkins enmascare `****` cualquier ocurrencia en consola.

#### Scenario: password no fuga en consola

WHEN el deploy imprime el comando msdeploy THEN la consola muestra `****` en lugar del password.

### Requirement: BAT sin password en argv

El script `DeployFileOnIISServer.bat` SHALL NOT recibir el password como argumento de línea de comandos; SHALL leerlo de variable de entorno (`MSDEPLOY_PASSWORD`) y validar los 5 args restantes, con rutas entrecomilladas.

#### Scenario: invocación sin env falla seguro

WHEN `MSDEPLOY_PASSWORD` está vacía THEN el BAT aborta con exit 1 sin invocar msdeploy.

### Requirement: PS1 endurecido

Los scripts `Start/StopAppPool.ps1` SHALL usar `[CmdletBinding()]`, parámetros `Mandatory` + `ValidateNotNullOrEmpty`, `$ErrorActionPreference='Stop'`, `try/catch` con exit codes, y SHALL pasar `PSScriptAnalyzer` sin `Error`.

#### Scenario: parámetro vacío es rechazado

WHEN se invoca `StopAppPool.ps1 -RemoteServerHost ""` THEN PowerShell rechaza el binding antes de abrir sesión remota.
