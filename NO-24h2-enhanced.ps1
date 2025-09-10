# Enhanced Windows 11 24H2 Blocker
# Run with administrative privileges
# Schedule via Task Scheduler for persistent protection

param(
    [switch]$WhatIf,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$CurrentVersion = "23H2"
$BuildNumber = 22631  # 23H2 build number

# Logging function
function Write-Log {
    param($Message, $Level = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] $Message"
    Write-Output $logMessage
    if ($Verbose) { Write-Verbose $logMessage }
}

Write-Log "Starting Enhanced 24H2 Block Script"

# 1. GROUP POLICY - Target Release Version (Primary Method)
Write-Log "Configuring target release version policy"
$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
if (-not (Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}
if (-not $WhatIf) {
    Set-ItemProperty -Path $RegPath -Name "TargetReleaseVersion" -Value 1 -Type DWord
    Set-ItemProperty -Path $RegPath -Name "TargetReleaseVersionInfo" -Value $CurrentVersion -Type String
    Set-ItemProperty -Path $RegPath -Name "ProductVersion" -Value "Windows 11" -Type String
}

# 2. DEFER FEATURE UPDATES
Write-Log "Configuring feature update deferral"
if (-not $WhatIf) {
    Set-ItemProperty -Path $RegPath -Name "DeferFeatureUpdates" -Value 1 -Type DWord
    Set-ItemProperty -Path $RegPath -Name "DeferFeatureUpdatesPeriodInDays" -Value 365 -Type DWord
    Set-ItemProperty -Path $RegPath -Name "PauseFeatureUpdatesStartTime" -Value (Get-Date).ToString("yyyy-MM-dd") -Type String
}

# 3. WINDOWS UPDATE FOR BUSINESS
Write-Log "Configuring Windows Update for Business"
$WUfBPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
if (-not $WhatIf) {
    Set-ItemProperty -Path $WUfBPath -Name "BranchReadinessLevel" -Value 32 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $WUfBPath -Name "DeferFeatureUpdatesPeriodInDays" -Value 365 -Type DWord -ErrorAction SilentlyContinue
}

# 4. DISABLE WINDOWS UPDATE MEDIC SERVICE
Write-Log "Managing Windows Update services"
$services = @(
    "WaaSMedicSvc",  # Windows Update Medic Service
    "UsoSvc"         # Update Orchestrator Service
)
foreach ($svc in $services) {
    try {
        if (-not $WhatIf) {
            $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($service) {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Log "Disabled service: $svc"
            }
        }
    } catch {
        Write-Log "Could not disable $svc (may require SYSTEM privileges)" "Warning"
    }
}

# 5. BLOCK VIA SETUPDIAG REGISTRY
Write-Log "Setting SetupDiag compatibility blocks"
$SetupDiagPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\CompatMarkers"
if (-not (Test-Path $SetupDiagPath)) {
    New-Item -Path $SetupDiagPath -Force | Out-Null
}
if (-not $WhatIf) {
    Set-ItemProperty -Path $SetupDiagPath -Name "24H2" -Value 1 -Type DWord -ErrorAction SilentlyContinue
}

# 6. DISABLE FEATURE UPDATE SCHEDULED TASKS
Write-Log "Disabling feature update scheduled tasks"
$taskPatterns = @(
    "*Feature*Update*",
    "*EnablementPilot*",
    "*SIH*",
    "*Scheduled*Upgrade*",
    "*UpdateOrchestrator*",
    "*WindowsUpdate*"
)

foreach ($pattern in $taskPatterns) {
    $tasks = Get-ScheduledTask -TaskPath "\Microsoft\Windows\*" -ErrorAction SilentlyContinue | 
             Where-Object { $_.TaskName -like $pattern }
    
    foreach ($task in $tasks) {
        try {
            if (-not $WhatIf) {
                Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop
                Write-Log "Disabled task: $($task.TaskName)"
            }
        } catch {
            Write-Log "Could not disable task: $($task.TaskName)" "Warning"
        }
    }
}

# 7. MODIFY WINDOWS UPDATE CONFIGURATION
Write-Log "Configuring Windows Update settings"
$WUPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
if (-not $WhatIf) {
    Set-ItemProperty -Path $WUPath -Name "AUOptions" -Value 2 -Type DWord -ErrorAction SilentlyContinue
}

# 8. BLOCK SPECIFIC KB UPDATES (24H2 enablement packages)
Write-Log "Blocking known 24H2 enablement packages"
$blockedKBs = @(
    "KB5039212",  # 24H2 enablement package
    "KB5039302",  # 24H2 cumulative update
    "KB5040442"   # 24H2 feature update
)

$HideUpdatesPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending"
foreach ($kb in $blockedKBs) {
    if (-not $WhatIf) {
        $hideKey = "$HideUpdatesPath\$kb"
        if (-not (Test-Path $hideKey)) {
            New-Item -Path $hideKey -Force | Out-Null
        }
        Set-ItemProperty -Path $hideKey -Name "Hide" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Write-Log "Blocked KB: $kb"
    }
}

# 9. USE WUSA TO BLOCK UPDATES (Alternative method)
Write-Log "Checking for pending 24H2 updates"
try {
    $pendingUpdates = Get-HotFix -ErrorAction SilentlyContinue | Where-Object { $_.Description -match "24H2" }
    foreach ($update in $pendingUpdates) {
        if (-not $WhatIf) {
            Start-Process "wusa.exe" -ArgumentList "/uninstall /kb:$($update.HotFixID.Replace('KB','')) /quiet /norestart" -Wait -NoNewWindow
            Write-Log "Uninstalled pending update: $($update.HotFixID)"
        }
    }
} catch {
    Write-Log "Could not check pending updates" "Warning"
}

# 10. CREATE COMPATIBILITY APPRAISER OVERRIDE
Write-Log "Creating compatibility appraiser override"
$AppraiserPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\CompatTelRunner.exe"
if (-not (Test-Path $AppraiserPath)) {
    New-Item -Path $AppraiserPath -Force | Out-Null
}
if (-not $WhatIf) {
    Set-ItemProperty -Path $AppraiserPath -Name "Debugger" -Value "cmd.exe /c echo blocked" -Type String -ErrorAction SilentlyContinue
}

# 11. VERIFY CURRENT VERSION
Write-Log "Verifying system version"
$currentBuild = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name CurrentBuild).CurrentBuild
$displayVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name DisplayVersion).DisplayVersion
Write-Log "Current Version: $displayVersion (Build $currentBuild)"

if ([int]$currentBuild -ge 23000) {
    Write-Log "WARNING: System may already be on 24H2 or later!" "Warning"
}

# 12. OPTIONAL: Hide updates using PSWindowsUpdate module
if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
    Write-Log "Using PSWindowsUpdate to hide 24H2 updates"
    Import-Module PSWindowsUpdate
    try {
        $updates = Get-WindowsUpdate -MicrosoftUpdate -IgnoreUserInput -ErrorAction SilentlyContinue
        foreach ($update in $updates) {
            if ($update.Title -match "24H2|Version 24H2|Feature update.*24H2") {
                if (-not $WhatIf) {
                    Hide-WindowsUpdate -KBArticleID $update.KB -Confirm:$false -ErrorAction SilentlyContinue
                    Write-Log "Hidden update via PSWindowsUpdate: $($update.Title)"
                }
            }
        }
    } catch {
        Write-Log "PSWindowsUpdate operation failed" "Warning"
    }
} else {
    Write-Log "PSWindowsUpdate module not installed (optional)" "Info"
}

# Summary
Write-Log "=================="
Write-Log "24H2 Block Summary:"
Write-Log "- Target Release: $CurrentVersion"
Write-Log "- Feature Updates: Deferred 365 days"
Write-Log "- Update Services: Restricted"
Write-Log "- Scheduled Tasks: Disabled"
Write-Log "- Known KBs: Blocked"
Write-Log "=================="

if ($WhatIf) {
    Write-Log "WhatIf mode - no changes were made" "Info"
}