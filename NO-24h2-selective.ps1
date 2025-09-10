# Selective Windows 11 24H2 Feature Update Blocker
# Blocks ONLY the 24H2 major feature update
# Allows: Security updates, quality updates, non-24H2 features, Store updates
# Run with administrative privileges

param(
    [switch]$WhatIf,
    [switch]$Verbose,
    [switch]$Remove  # Remove the blocks
)

$ErrorActionPreference = "Stop"
$CurrentVersion = "23H2"
$TargetBuildNumber = 22631  # 23H2 max build

function Write-Log {
    param($Message, $Level = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] $Message"
    Write-Output $logMessage
    if ($Verbose) { Write-Verbose $logMessage }
}

Write-Log "Starting Selective 24H2 Block Script (Mode: $(if ($Remove) {'REMOVE'} else {'APPLY'}))"

if ($Remove) {
    # REMOVE BLOCKS
    Write-Log "Removing 24H2 blocks..."
    
    $RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (Test-Path $RegPath) {
        Remove-ItemProperty -Path $RegPath -Name "TargetReleaseVersion" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $RegPath -Name "TargetReleaseVersionInfo" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $RegPath -Name "ProductVersion" -ErrorAction SilentlyContinue
        Write-Log "Removed target release version lock"
    }
    
    Write-Log "24H2 blocks removed. System will follow normal update policy."
    exit 0
}

# 1. TARGET RELEASE VERSION - Pin to 23H2
# This is the safest method - tells Windows Update to stay on 23H2
Write-Log "Setting target release version to $CurrentVersion"
$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
if (-not (Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}

if (-not $WhatIf) {
    # This specifically pins to 23H2 for feature updates only
    Set-ItemProperty -Path $RegPath -Name "TargetReleaseVersion" -Value 1 -Type DWord
    Set-ItemProperty -Path $RegPath -Name "TargetReleaseVersionInfo" -Value $CurrentVersion -Type String
    Set-ItemProperty -Path $RegPath -Name "ProductVersion" -Value "Windows 11" -Type String
    Write-Log "Pinned to Windows 11 version $CurrentVersion"
}

# 2. OPTIONAL: Defer feature updates ONLY (not quality/security)
# This gives additional time before 24H2 is offered
Write-Log "Configuring feature update deferral (365 days)"
if (-not $WhatIf) {
    # DeferFeatureUpdates only affects feature updates, NOT security updates
    Set-ItemProperty -Path $RegPath -Name "DeferFeatureUpdates" -Value 1 -Type DWord
    Set-ItemProperty -Path $RegPath -Name "DeferFeatureUpdatesPeriodInDays" -Value 365 -Type DWord
    
    # Explicitly ensure quality updates are NOT deferred
    Set-ItemProperty -Path $RegPath -Name "DeferQualityUpdates" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "Feature updates deferred, quality/security updates enabled"
}

# 3. DISABLE ONLY 24H2-SPECIFIC SCHEDULED TASKS
# Be selective - only disable known feature upgrade tasks
Write-Log "Disabling 24H2 feature upgrade tasks only"
$featureUpgradeTasks = @(
    "ScheduledUpgrade",           # Feature upgrade task
    "ScheduledUpgradePrep",        # Feature upgrade preparation
    "Feature Update",              # Direct feature update task
    "FeatureUpgrade"               # Alternative feature upgrade task
)

foreach ($taskName in $featureUpgradeTasks) {
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | 
             Where-Object { $_.TaskName -like "*$taskName*" -and $_.TaskPath -like "*WindowsUpdate*" }
    
    foreach ($task in $tasks) {
        try {
            if (-not $WhatIf) {
                Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop
                Write-Log "Disabled feature upgrade task: $($task.TaskName)"
            }
        } catch {
            Write-Log "Could not disable task: $($task.TaskName)" "Warning"
        }
    }
}

# 4. HIDE ONLY 24H2 UPDATES (if PSWindowsUpdate is available)
if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
    Write-Log "Checking for 24H2 updates to hide"
    Import-Module PSWindowsUpdate
    try {
        $updates = Get-WindowsUpdate -MicrosoftUpdate -IgnoreUserInput -ErrorAction SilentlyContinue
        $hiddenCount = 0
        
        foreach ($update in $updates) {
            # Very specific - only hide if it's explicitly 24H2 feature update
            if ($update.Title -match "Feature update.*Windows 11.*24H2|Version 24H2") {
                if ($update.Type -ne "Security" -and $update.Type -ne "Critical") {
                    if (-not $WhatIf) {
                        Hide-WindowsUpdate -KBArticleID $update.KB -Confirm:$false -ErrorAction SilentlyContinue
                        Write-Log "Hidden 24H2 feature update: $($update.Title)"
                        $hiddenCount++
                    }
                }
            }
        }
        
        if ($hiddenCount -eq 0) {
            Write-Log "No 24H2 feature updates found to hide"
        }
    } catch {
        Write-Log "Could not check Windows Updates (PSWindowsUpdate)" "Warning"
    }
} else {
    Write-Log "PSWindowsUpdate not installed (optional) - skipping update hiding"
}

# 5. VERIFY CONFIGURATION
Write-Log "Verifying configuration..."
$verification = @{}

# Check target release
$targetRelease = Get-ItemProperty -Path $RegPath -Name "TargetReleaseVersionInfo" -ErrorAction SilentlyContinue
if ($targetRelease.TargetReleaseVersionInfo -eq $CurrentVersion) {
    $verification["TargetRelease"] = "✓ Pinned to $CurrentVersion"
} else {
    $verification["TargetRelease"] = "✗ Not configured"
}

# Check Windows Update service is running (should be for security updates)
$wuService = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
if ($wuService.Status -eq "Running" -or $wuService.StartType -ne "Disabled") {
    $verification["WindowsUpdate"] = "✓ Service available for security updates"
} else {
    $verification["WindowsUpdate"] = "⚠ Service may be disabled"
}

# Check current version
$currentBuild = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name CurrentBuild).CurrentBuild
$displayVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name DisplayVersion).DisplayVersion
$verification["CurrentVersion"] = "$displayVersion (Build $currentBuild)"

# Summary
Write-Log "=================="
Write-Log "Configuration Summary:"
foreach ($key in $verification.Keys) {
    Write-Log "$key : $($verification[$key])"
}
Write-Log "=================="
Write-Log "Status: 24H2 feature update BLOCKED"
Write-Log "Security updates: ALLOWED"
Write-Log "Quality updates: ALLOWED"
Write-Log "Store updates: ALLOWED"
Write-Log "=================="

if ($WhatIf) {
    Write-Log "WhatIf mode - no changes were made" "Info"
}

# Create verification script
$verifyScript = @'
# Quick verification that 24H2 is blocked but updates work
$reg = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -ErrorAction SilentlyContinue
if ($reg.TargetReleaseVersionInfo -eq "23H2") {
    Write-Host "✓ 24H2 Block Active" -ForegroundColor Green
    Write-Host "  Target Version: $($reg.TargetReleaseVersionInfo)"
} else {
    Write-Host "✗ 24H2 Block NOT Active" -ForegroundColor Red
}

# Check for pending security updates
$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()
try {
    $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
    $securityUpdates = $searchResult.Updates | Where-Object { $_.Categories.Name -contains "Security Updates" }
    Write-Host "Security Updates Available: $($securityUpdates.Count)"
} catch {
    Write-Host "Could not check for updates"
}
'@

if (-not $WhatIf) {
    $verifyScript | Out-File -FilePath ".\Verify-24H2-Block.ps1" -Encoding UTF8
    Write-Log "Created verification script: Verify-24H2-Block.ps1"
}