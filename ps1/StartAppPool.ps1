param(
    [string]$RemoteServerHost,
    [string]$AppPoolName
)

Invoke-Command -ComputerName $RemoteServerHost -ScriptBlock {
    param($AppPoolName)

    Import-Module WebAdministration

    # Get the current state of the application pool
    $appPool = Get-WebAppPoolState -Name $AppPoolName

    if ($appPool.Value -ne "Started") {
        # Start the application pool if it is not running
        Start-WebAppPool -Name $AppPoolName
        Write-Host "Application Pool started."
    } else {
        # Application pool was already running
        Write-Host "Application Pool was already started."
    }
} -ArgumentList $AppPoolName
