<#
.SYNOPSIS
    Arranca un Application Pool de IIS en un servidor remoto via WinRM.
.DESCRIPTION
    Usa Invoke-Command con autenticacion Kerberos (evita downgrade a NTLM).
    Parametros obligatorios validados; cualquier error aborta con exit != 0
    para que Jenkins lo detecte via $LASTEXITCODE.
.NOTES
    Author: SDD implementer (REQ-002 pipeline-security)
    Usage: StartAppPool.ps1 -RemoteServerHost <host> -AppPoolName <pool>
    Dependencies: WinRM habilitado; modulo WebAdministration en el destino
    Output / Exit codes: 0 AppPool arrancado o ya en marcha; 1 fallo
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RemoteServerHost,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AppPoolName
)

$ErrorActionPreference = 'Stop'

try {
    Invoke-Command -ComputerName $RemoteServerHost -Authentication Kerberos -ScriptBlock {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$InnerAppPoolName
        )

        $ErrorActionPreference = 'Stop'
        Import-Module WebAdministration

        # Get the current state of the application pool
        $appPool = Get-WebAppPoolState -Name $InnerAppPoolName

        if ($appPool.Value -ne "Started") {
            # Start the application pool if it is not running
            Start-WebAppPool -Name $InnerAppPoolName
            Write-Host "Application Pool started."
        } else {
            # Application pool was already running
            Write-Host "Application Pool was already started."
        }
    } -ArgumentList $AppPoolName
    exit 0
}
catch {
    Write-Error "StartAppPool failed on '${RemoteServerHost}' pool '${AppPoolName}': $_"
    exit 1
}
