# Script for tracking total PC lock time
# Runs as a background service or scheduled task

# Define paths to files
$logDir = "C:\ProgramData\PC_Lock_Monitor"
$logFile = "$logDir\lock_time_tracker.log"
$statusFile = "$logDir\lock_status.txt"
$lastLockTimeFile = "$logDir\last_lock_time.txt"
$lastUnlockTimeFile = "$logDir\last_unlock_time.txt"
$lastDurationFile = "$logDir\last_lock_duration.txt"
$totalLockTimeFile = "$logDir\total_lock_time.txt"
$dailyLockTimeFile = "$logDir\daily_lock_time.txt"
$lockHistoryFile = "$logDir\lock_history.csv"

# Create directory if it doesn't exist
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Initialize total lock time if file doesn't exist
if (-not (Test-Path $totalLockTimeFile)) {
    "0" | Out-File -FilePath $totalLockTimeFile -Force
}

# Initialize daily lock time if file doesn't exist
if (-not (Test-Path $dailyLockTimeFile)) {
    "0" | Out-File -FilePath $dailyLockTimeFile -Force
}

# Initialize lock history file if it doesn't exist
if (-not (Test-Path $lockHistoryFile)) {
    "LockTime,UnlockTime,Duration" | Out-File -FilePath $lockHistoryFile -Force
}

# Function to write to log
function Write-Log {
    param (
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage
}

# Function to determine lock status
function Get-LockStatus {
    try {
        # Method 1: Check using quser
        $quserOutput = quser 2>$null
        if ($quserOutput -match "disconnected") {
            return 1 # Locked
        }
    } catch {
        # Ignore quser errors
    }

    try {
        # Method 2: Check using WMI
        $session = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($null -eq $session.UserName) {
            return 1 # Locked or user not logged in
        }
    } catch {
        # Ignore WMI errors
    }

    try {
        # Method 3: Check for LogonUI process
        $logonUI = Get-Process -Name "LogonUI" -ErrorAction SilentlyContinue
        if ($logonUI) {
            return 1 # Locked
        }
    } catch {
        # Ignore process errors
    }

    # If we got to this point, consider the session unlocked
    return 0
}

# Function to get total lock time
function Get-TotalLockTime {
    if (Test-Path $totalLockTimeFile) {
        $totalTime = [int](Get-Content -Path $totalLockTimeFile)
        return $totalTime
    }
    return 0
}

# Function to get daily lock time
function Get-DailyLockTime {
    if (Test-Path $dailyLockTimeFile) {
        $dailyTime = [int](Get-Content -Path $dailyLockTimeFile)
        return $dailyTime
    }
    return 0
}

# Function to update total lock time
function Update-TotalLockTime {
    param (
        [int]$Duration
    )
    
    $totalTime = Get-TotalLockTime
    $totalTime += $Duration
    $totalTime | Out-File -FilePath $totalLockTimeFile -Force
    
    # Update daily lock time
    $dailyTime = Get-DailyLockTime
    $dailyTime += $Duration
    $dailyTime | Out-File -FilePath $dailyLockTimeFile -Force
    
    Write-Log "Updated total lock time: $totalTime seconds"
    Write-Log "Updated daily lock time: $dailyTime seconds"
}

# Function to reset daily lock time at midnight
function Reset-DailyLockTime {
    $currentDate = Get-Date -Format "yyyy-MM-dd"
    $lastResetFile = "$logDir\last_daily_reset.txt"
    
    # Check if reset file exists
    if (Test-Path $lastResetFile) {
        $lastResetDate = Get-Content -Path $lastResetFile
        
        # If date changed, reset daily counter
        if ($lastResetDate -ne $currentDate) {
            "0" | Out-File -FilePath $dailyLockTimeFile -Force
            $currentDate | Out-File -FilePath $lastResetFile -Force
            Write-Log "Reset daily lock time counter (new day: $currentDate)"
        }
    } else {
        # Create reset file with current date
        $currentDate | Out-File -FilePath $lastResetFile -Force
    }
}

# Write initial message to log
Write-Log "Starting PC lock time tracking"

# Get initial status
$previousStatus = Get-LockStatus
$statusText = if ($previousStatus -eq 1) { "LOCKED" } else { "UNLOCKED" }
Write-Log "Initial status: $statusText"

# Save initial status
$previousStatus | Out-File -FilePath $statusFile -Force

# Initialize lock time variable
$lockStartTime = $null

# Infinite loop for monitoring
try {
    while ($true) {
        # Reset daily counter if needed
        Reset-DailyLockTime
        
        # Get current status
        $currentStatus = Get-LockStatus
        
        # If status changed
        if ($currentStatus -ne $previousStatus) {
            $timestamp = Get-Date
            $timestampString = $timestamp.ToString("yyyy-MM-dd HH:mm:ss")
            
            if ($currentStatus -eq 1) {
                # PC locked
                $statusText = "LOCKED"
                Write-Log "Status changed: $statusText"
                $timestampString | Out-File -FilePath $lastLockTimeFile -Force
                
                # Store lock start time
                $lockStartTime = $timestamp
            } else {
                # PC unlocked
                $statusText = "UNLOCKED"
                Write-Log "Status changed: $statusText"
                $timestampString | Out-File -FilePath $lastUnlockTimeFile -Force
                
                # Calculate lock duration if we have a lock start time
                if ($null -ne $lockStartTime) {
                    $duration = [math]::Round(($timestamp - $lockStartTime).TotalSeconds)
                    
                    # Save duration
                    $duration | Out-File -FilePath $lastDurationFile -Force
                    Write-Log "Lock duration: $duration seconds"
                    
                    # Update total lock time
                    Update-TotalLockTime -Duration $duration
                    
                    # Add to history
                    $lockTimeStr = $lockStartTime.ToString("yyyy-MM-dd HH:mm:ss")
                    $unlockTimeStr = $timestamp.ToString("yyyy-MM-dd HH:mm:ss")
                    "$lockTimeStr,$unlockTimeStr,$duration" | Add-Content -Path $lockHistoryFile
                    
                    # Reset lock start time
                    $lockStartTime = $null
                }
            }
            
            # Update status
            $currentStatus | Out-File -FilePath $statusFile -Force
            $previousStatus = $currentStatus
        }
        
        # Pause before next check (5 seconds)
        Start-Sleep -Seconds 5
    }
} catch {
    Write-Log "Error during monitoring: $_"
} finally {
    Write-Log "PC lock time tracking stopped"
}
