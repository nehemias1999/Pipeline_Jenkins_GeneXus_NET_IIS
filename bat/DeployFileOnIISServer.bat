@echo off
setlocal

REM ===============================================
REM Script: DeployFileOnIISServer.bat
REM Description: Deploy a file to an IIS server.
REM ===============================================

REM ==============================
REM Parameters
REM ==============================

set MSdeployEXEPath=%1
set ZIPFilePath=%2
set DestinationWebAppPath=%3
set TargetComputerName=%4
set Username=%5
set Password=%6

REM ==============================
REM Script
REM ==============================

echo Deploying the application to IIS...

%MSdeployEXEPath% -verb:sync -source:package=%ZIPFilePath% -dest:contentPath=%DestinationWebAppPath%,computername=%TargetComputerName%,username=%Username%,password=%Password% -useChecksum -enableRule:DoNotDeleteRule -disableLink:AppPoolExtension

REM Check the command result
if %ERRORLEVEL% neq 0 (
    echo Error: Deployment failed.
    exit /B %ERRORLEVEL%
) else (
    echo Deployment completed successfully.
)

endlocal
