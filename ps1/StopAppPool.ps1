param(
    [string]$RemoteServerHost,
    [string]$AppPoolName
)

Invoke-Command -ComputerName $RemoteServerHost -ScriptBlock {
    param($AppPoolName)

    Import-Module WebAdministration

    # Get the current state of the application pool
    $appPool = Get-WebAppPoolState -Name $AppPoolName

    if ($appPool.Value -ne "Stopped") {
        # Stop the application pool if it is running
        Stop-WebAppPool -Name $AppPoolName
        Write-Host "Application Pool stopped."
    } else {
        # Application pool was already stopped
        Write-Host "Application Pool was already stopped."
    }
} -ArgumentList $AppPoolName
