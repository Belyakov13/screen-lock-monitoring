# Script for installing PC lock time tracker
# Run as administrator

# Check for administrator rights
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script must be run as administrator!" -ForegroundColor Red
    exit 1
}

# Installation paths
$zabbixPath = "C:\Program Files\Zabbix Agent"
$scriptsPath = "$zabbixPath\scripts"
$confPath = "$zabbixPath\zabbix_agentd.conf.d"

# Create directories if they don't exist
if (-not (Test-Path $scriptsPath)) {
    New-Item -Path $scriptsPath -ItemType Directory -Force | Out-Null
    Write-Host "Created scripts directory: $scriptsPath" -ForegroundColor Green
}

if (-not (Test-Path $confPath)) {
    New-Item -Path $confPath -ItemType Directory -Force | Out-Null
    Write-Host "Created configuration directory: $confPath" -ForegroundColor Green
}

# Copy files
$scriptSource = "$PSScriptRoot\lock_time_tracker.ps1"
$scriptDest = "$scriptsPath\lock_time_tracker.ps1"
Copy-Item -Path $scriptSource -Destination $scriptDest -Force
Write-Host "Copied file: $scriptDest" -ForegroundColor Green

$confSource = "$PSScriptRoot\userparameter_lock_time_tracker.conf"
$confDest = "$confPath\userparameter_lock_time_tracker.conf"
Copy-Item -Path $confSource -Destination $confDest -Force
Write-Host "Copied file: $confDest" -ForegroundColor Green

# Create scheduled task to run at startup
$taskName = "PC_Lock_Time_Tracker"
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($taskExists) {
    # Remove existing task
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Removed existing scheduled task: $taskName" -ForegroundColor Yellow
}

# Create new task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptDest`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden -RunOnlyIfNetworkAvailable:$false -StartWhenAvailable

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -User "SYSTEM" -RunLevel Highest -Force
Write-Host "Created scheduled task: $taskName" -ForegroundColor Green

# Restart Zabbix Agent service
$zabbixService = Get-Service -Name "Zabbix Agent" -ErrorAction SilentlyContinue
if ($zabbixService) {
    Restart-Service -Name "Zabbix Agent" -Force
    Write-Host "Restarted Zabbix Agent service" -ForegroundColor Green
} else {
    Write-Host "Warning: Zabbix Agent service not found" -ForegroundColor Yellow
}

# Start script now
Write-Host "`nStarting lock time tracking script..." -ForegroundColor Yellow
Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptDest`"" -WindowStyle Hidden
Write-Host "Lock time tracking script started in background" -ForegroundColor Green

Write-Host "`nPC lock time tracker installation complete!" -ForegroundColor Cyan
Write-Host "Script will automatically start at system startup and run in the background." -ForegroundColor Cyan
Write-Host "Logs and lock time data are saved in directory: C:\ProgramData\PC_Lock_Monitor\" -ForegroundColor Cyan
Write-Host "To test the script, lock and unlock your PC (Win+L), then check the files:" -ForegroundColor Cyan
Write-Host "- C:\ProgramData\PC_Lock_Monitor\lock_time_tracker.log" -ForegroundColor Yellow
Write-Host "- C:\ProgramData\PC_Lock_Monitor\lock_history.csv" -ForegroundColor Yellow
Write-Host "- C:\ProgramData\PC_Lock_Monitor\total_lock_time.txt" -ForegroundColor Yellow
Write-Host "- C:\ProgramData\PC_Lock_Monitor\daily_lock_time.txt" -ForegroundColor Yellow
