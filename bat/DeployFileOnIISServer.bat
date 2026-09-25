@echo off
setlocal

REM ==============================================================================
REM Description: Despliega un paquete ZIP en IIS via MSDeploy (verb:sync).
REM   No recibe el password por argv; lo lee de la variable de entorno
REM   MSDEPLOY_PASSWORD (inyectada por Jenkins withCredentials). Aborta con
REM   exit 1 sin invocar msdeploy si falta un argumento o el env esta vacio.
REM Author: SDD implementer (REQ-002 pipeline-security)
REM Usage: DeployFileOnIISServer.bat "<msdeploy-exe>" "<zip>" "<webpath>" "<host>" "<user>"
REM Env Vars: MSDEPLOY_PASSWORD (requerida; nunca pasar por argv ni echo)
REM Dependencies: MSDeploy V3 (msdeploy.exe) en el agente Jenkins
REM Output / Exit codes: 0 despliegue OK; 1 args/env invalidos o fallo de msdeploy
REM ==============================================================================

REM ==============================
REM Parameters (5 args; el password va por env, nunca en argv)
REM ==============================

if "%~5"=="" (
    1>&2 echo Error: se requieren 5 argumentos: "<msdeploy-exe>" "<zip>" "<webpath>" "<host>" "<user>" ^(password por env MSDEPLOY_PASSWORD^).
    exit /B 1
)

set "MSdeployEXEPath=%~1"
set "ZIPFilePath=%~2"
set "DestinationWebAppPath=%~3"
set "TargetComputerName=%~4"
set "Username=%~5"

if not defined MSDEPLOY_PASSWORD (
    1>&2 echo Error: MSDEPLOY_PASSWORD no definida; abortando sin invocar msdeploy.
    exit /B 1
)

REM ==============================
REM Script (rutas entrecomilladas; el password nunca se imprime)
REM ==============================

echo Deploying the application to IIS...

"%MSdeployEXEPath%" -verb:sync -source:package="%ZIPFilePath%" -dest:contentPath="%DestinationWebAppPath%",computername="%TargetComputerName%",username="%Username%",password="%MSDEPLOY_PASSWORD%" -useChecksum -enableRule:DoNotDeleteRule -disableLink:AppPoolExtension

REM Check the command result
if %ERRORLEVEL% neq 0 (
    echo Error: Deployment failed.
    exit /B %ERRORLEVEL%
) else (
    echo Deployment completed successfully.
)

endlocal
