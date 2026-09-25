<#
.SYNOPSIS
    Detiene un Application Pool de IIS en un servidor remoto via WinRM.
.DESCRIPTION
    Usa Invoke-Command con autenticacion Kerberos (evita downgrade a NTLM).
    Parametros obligatorios validados; cualquier error aborta con exit != 0
    para que Jenkins lo detecte via $LASTEXITCODE.
    Purpose: detener el AppPool antes del deploy para evitar file locks.
.NOTES
    Author: SDD implementer (REQ-002 pipeline-security)
    Usage: StopAppPool.ps1 -RemoteServerHost <host> -AppPoolName <pool>
    Dependencies: WinRM habilitado; modulo WebAdministration en el destino
    Output / Exit codes: 0 AppPool detenido o ya detenido; 1 fallo
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

        if ($appPool.Value -ne "Stopped") {
            # Stop the application pool if it is running
            Stop-WebAppPool -Name $InnerAppPoolName
            Write-Host "Application Pool stopped."
        } else {
            # Application pool was already stopped
            Write-Host "Application Pool was already stopped."
        }
    } -ArgumentList $AppPoolName
    exit 0
}
catch {
    Write-Error "StopAppPool failed on '${RemoteServerHost}' pool '${AppPoolName}': $_"
    exit 1
}
