# Windows 11 24H2 Update Blocker - Consolidated Version
# Blocks Windows 11 24H2 feature update with multiple protection levels
# Supports both interactive TUI and non-interactive CLI modes

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("Basic", "Enhanced", "Selective", "Remove")]
    [string]$Mode,
    
    [Parameter()]
    [switch]$Silent,
    
    [Parameter()]
    [switch]$WhatIf,
    
    [Parameter()]
    [switch]$ScheduleTask,
    
    [Parameter()]
    [ValidateSet("Daily", "Weekly", "OnBoot")]
    [string]$Schedule = "Daily",
    
    [Parameter()]
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$script:CurrentVersion = "23H2"
$script:BuildNumber = 22631
$script:LogPath = "$env:ProgramData\ftfy-no-means-no\logs"
$script:ScriptPath = "$env:ProgramData\ftfy-no-means-no\Block-24H2.ps1"
$script:LogFile = "$script:LogPath\Block-24H2-$(Get-Date -Format 'yyyy-MM').log"

# Help text
if ($Help) {
    Write-Host @"
Block-24H2.ps1 - Windows 11 24H2 Update Blocker

USAGE:
    .\Block-24H2.ps1 [-Mode <mode>] [-Silent] [-WhatIf] [-ScheduleTask] [-Schedule <schedule>]

PARAMETERS:
    -Mode           Protection level: Basic, Enhanced, Selective, Remove
    -Silent         Run without prompts (non-interactive)
    -WhatIf         Test mode - show what would be done without making changes
    -ScheduleTask   Create a scheduled task to run this script
    -Schedule       Schedule frequency: Daily, Weekly, OnBoot (default: Daily)
    -Help           Show this help message
    
COMMON PARAMETERS (automatically available):
    -Verbose        Show detailed output
    -Debug          Show debug output

MODES:
    Basic           Simple registry-based blocking (minimal)
    Enhanced        Multiple blocking methods (comprehensive)
    Selective       Block 24H2 only, allow all security updates (recommended)
    Remove          Remove all blocks and restore defaults

EXAMPLES:
    # Interactive mode with TUI
    .\Block-24H2.ps1
    
    # Non-interactive selective blocking
    .\Block-24H2.ps1 -Mode Selective -Silent
    
    # Test what enhanced mode would do
    .\Block-24H2.ps1 -Mode Enhanced -WhatIf
    
    # Schedule daily selective blocking
    .\Block-24H2.ps1 -Mode Selective -ScheduleTask -Schedule Daily

"@
    exit 0
}

# Initialize logging
function Initialize-Logging {
    if (-not (Test-Path $script:LogPath)) {
        New-Item -Path $script:LogPath -ItemType Directory -Force | Out-Null
    }
}

# Logging function
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    $color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
        default   { "White" }
    }
    
    # Console output
    if (-not $Silent) {
        Write-Host "[$timestamp] $Message" -ForegroundColor $color
    }
    
    if ($Verbose) {
        Write-Verbose "[$Level] $Message"
    }
    
    # File logging
    try {
        Initialize-Logging
        Add-Content -Path $script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
    } catch {
        # Silent fail for logging - don't break the main functionality
    }
}

# Check for admin privileges
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Attempt to elevate privileges
function Request-Elevation {
    param([string]$Mode)
    
    Write-Log "Attempting to elevate privileges..." "Warning"
    
    # Get current script path
    $scriptPath = if ($MyInvocation.MyCommand.Path) { 
        $MyInvocation.MyCommand.Path 
    } elseif ($PSCommandPath) { 
        $PSCommandPath 
    } else { 
        (Get-Location).Path + "\Block-24H2.ps1" 
    }
    
    # Try gsudo first (preferred)
    if (Get-Command gsudo -ErrorAction SilentlyContinue) {
        Write-Log "Found gsudo, attempting elevation..." "Info"
        try {
            if ($Mode) {
                gsudo powershell.exe -ExecutionPolicy Bypass -NoProfile -File "`"$scriptPath`"" -Mode $Mode -Silent
            } else {
                gsudo powershell.exe -ExecutionPolicy Bypass -NoProfile -File "`"$scriptPath`""
            }
            return $true
        } catch {
            Write-Log "gsudo elevation failed: $($_.Exception.Message)" "Warning"
        }
    }
    
    # Try sudo (if available)
    if (Get-Command sudo -ErrorAction SilentlyContinue) {
        Write-Log "Found sudo, attempting elevation..." "Info"
        try {
            if ($Mode) {
                sudo powershell.exe -ExecutionPolicy Bypass -NoProfile -File "`"$scriptPath`"" -Mode $Mode -Silent
            } else {
                sudo powershell.exe -ExecutionPolicy Bypass -NoProfile -File "`"$scriptPath`""
            }
            return $true
        } catch {
            Write-Log "sudo elevation failed: $($_.Exception.Message)" "Warning"
        }
    }
    
    # Fallback: UAC elevation
    try {
        Write-Log "Attempting UAC elevation..." "Info"
        if ($Mode) {
            Start-Process powershell.exe -ArgumentList "-ExecutionPolicy", "Bypass", "-NoProfile", "-File", "`"$scriptPath`"", "-Mode", $Mode, "-Silent" -Verb RunAs
        } else {
            Start-Process powershell.exe -ArgumentList "-ExecutionPolicy", "Bypass", "-NoProfile", "-File", "`"$scriptPath`"" -Verb RunAs
        }
        return $true
    } catch {
        Write-Log "UAC elevation failed: $($_.Exception.Message)" "Warning"
        return $false
    }
}

# Show admin instructions
function Show-AdminInstructions {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "              ADMINISTRATOR PRIVILEGES REQUIRED               " -ForegroundColor Red
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Write-Host "This script requires Administrator privileges to modify Windows Update settings." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please run this script as Administrator using one of these methods:" -ForegroundColor White
    Write-Host ""
    Write-Host "Method 1: Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Cyan
    Write-Host "Method 2: Use gsudo (if installed): gsudo powershell -File Block-24H2.ps1" -ForegroundColor Cyan
    Write-Host "Method 3: Use Windows Terminal as Admin" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Then run: .\Block-24H2.ps1" -ForegroundColor Green
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Red
}

# Copy script to persistence location
function Copy-ScriptToPersistentLocation {
    Write-Log "Copying script to persistent location..." "Info"
    
    # Get current script path with fallback methods
    $currentScriptPath = $null
    if ($MyInvocation.MyCommand.Path) {
        $currentScriptPath = $MyInvocation.MyCommand.Path
    } elseif ($PSCommandPath) {
        $currentScriptPath = $PSCommandPath
    } elseif ($script:MyInvocation.MyCommand.Path) {
        $currentScriptPath = $script:MyInvocation.MyCommand.Path
    } else {
        # Last resort - try to find the script in current directory
        $currentScriptPath = Join-Path (Get-Location) "Block-24H2.ps1"
        if (-not (Test-Path $currentScriptPath)) {
            throw "Cannot determine current script location for copying"
        }
    }
    
    Write-Log "Current script path: $currentScriptPath" "Info"
    
    $destDir = Split-Path $script:ScriptPath -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        Write-Log "Created directory: $destDir" "Success"
    }
    
    # Copy current script to persistent location
    Copy-Item -Path $currentScriptPath -Destination $script:ScriptPath -Force
    Write-Log "Script copied to: $script:ScriptPath" "Success"
    
    return $script:ScriptPath
}

# Enhanced scheduled task creation
function New-ScheduledBlockTask {
    param(
        [string]$SelectedMode,
        [string]$ScriptLocation = $script:ScriptPath
    )
    
    Write-Log "Creating scheduled task for $SelectedMode mode..." "Info"
    
    $taskName = "Block-Windows11-24H2-$SelectedMode"
    $description = "Prevents Windows 11 24H2 feature update using $SelectedMode protection mode"
    
    # Remove existing task if it exists
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    } catch { }
    
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `\"$ScriptLocation`\" -Mode $SelectedMode -Silent"
    
    $trigger = New-ScheduledTaskTrigger -Daily -At "3:00 AM"
    
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable:$false `
        -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 5)
    
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    try {
        Register-ScheduledTask -TaskName $taskName -Description $description -Action $action -Trigger $trigger `
            -Settings $settings -Principal $principal -Force | Out-Null
        
        Write-Log "Created scheduled task: $taskName" "Success"
        Write-Log "Task will run daily at 3:00 AM with $SelectedMode protection" "Info"
        return $true
    } catch {
        Write-Log "Failed to create scheduled task: $($_.Exception.Message)" "Error"
        return $false
    }
}

# Prompt for scheduled task installation
function Request-ScheduledTaskInstallation {
    param([string]$SelectedMode)
    
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                 Scheduled Task Setup                      ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "Would you like to install a scheduled task to automatically" -ForegroundColor Yellow
    Write-Host "maintain 24H2 protection using the $SelectedMode mode?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This will:" -ForegroundColor White
    Write-Host "  • Copy the script to a secure system location" -ForegroundColor Gray
    Write-Host "  • Create a daily scheduled task (3:00 AM)" -ForegroundColor Gray
    Write-Host "  • Run with SYSTEM privileges" -ForegroundColor Gray
    Write-Host "  • Maintain protection even after Windows updates" -ForegroundColor Gray
    Write-Host ""
    
    do {
        $response = Read-Host "Install scheduled task? (Y/N)"
        $response = $response.ToUpper()
    } while ($response -ne "Y" -and $response -ne "N")
    
    if ($response -eq "Y") {
        Write-Host ""
        Write-Log "Installing scheduled task..." "Info"
        
        # Copy script to persistent location
        $persistentScript = Copy-ScriptToPersistentLocation
        
        # Create scheduled task
        if (New-ScheduledBlockTask -SelectedMode $SelectedMode -ScriptLocation $persistentScript) {
            Write-Host ""
            Write-Host "✓ Scheduled task installed successfully!" -ForegroundColor Green
            Write-Host "  Task Name: Block-Windows11-24H2-$SelectedMode" -ForegroundColor Gray
            Write-Host "  Schedule: Daily at 3:00 AM" -ForegroundColor Gray
            Write-Host "  Script Location: $persistentScript" -ForegroundColor Gray
            Write-Host "  Log Location: $script:LogPath" -ForegroundColor Gray
        } else {
            Write-Host ""
            Write-Host "✗ Failed to install scheduled task" -ForegroundColor Red
        }
    } else {
        Write-Host ""
        Write-Host "Scheduled task installation skipped." -ForegroundColor Yellow
        Write-Host "You can run this script manually as needed." -ForegroundColor Gray
    }
}

# TUI Menu Function
function Show-Menu {
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          Windows 11 24H2 Update Blocker                   ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Current System: " -NoNewline
    $currentBuild = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name CurrentBuild).CurrentBuild
    $displayVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name DisplayVersion -ErrorAction SilentlyContinue).DisplayVersion
    Write-Host "$displayVersion (Build $currentBuild)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Select Protection Mode:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] Basic" -ForegroundColor White
    Write-Host "      └─ Simple registry-based blocking" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [2] Enhanced" -ForegroundColor White
    Write-Host "      └─ Multiple blocking methods for maximum protection" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [3] Selective" -ForegroundColor Green
    Write-Host "      └─ Block 24H2 only, allow security updates (RECOMMENDED)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [4] Remove Blocks" -ForegroundColor Red
    Write-Host "      └─ Remove all blocks and restore defaults" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [5] Verify Status" -ForegroundColor Cyan
    Write-Host "      └─ Check current blocking status" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [Q] Quit" -ForegroundColor White
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

# Verify current status
function Get-BlockStatus {
    Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    Current Status                         ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $status = @{}
    
    # Check target release
    if (Test-Path $regPath) {
        $targetRelease = Get-ItemProperty -Path $regPath -Name "TargetReleaseVersionInfo" -ErrorAction SilentlyContinue
        if ($targetRelease.TargetReleaseVersionInfo) {
            Write-Host "✓ Target Release: " -NoNewline -ForegroundColor Green
            Write-Host "$($targetRelease.TargetReleaseVersionInfo)" -ForegroundColor White
            $status.TargetRelease = $true
        } else {
            Write-Host "✗ Target Release: " -NoNewline -ForegroundColor Red
            Write-Host "Not configured" -ForegroundColor Gray
            $status.TargetRelease = $false
        }
        
        # Check deferrals
        $deferral = Get-ItemProperty -Path $regPath -Name "DeferFeatureUpdates" -ErrorAction SilentlyContinue
        if ($deferral.DeferFeatureUpdates -eq 1) {
            Write-Host "✓ Feature Updates: " -NoNewline -ForegroundColor Green
            Write-Host "Deferred" -ForegroundColor White
            $status.Deferred = $true
        } else {
            Write-Host "✗ Feature Updates: " -NoNewline -ForegroundColor Yellow
            Write-Host "Not deferred" -ForegroundColor Gray
            $status.Deferred = $false
        }
    } else {
        Write-Host "✗ Windows Update Policy: " -NoNewline -ForegroundColor Red
        Write-Host "Not configured" -ForegroundColor Gray
        $status.Configured = $false
    }
    
    # Check Windows Update service
    $wuService = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
    if ($wuService) {
        if ($wuService.Status -eq "Running" -or $wuService.StartType -ne "Disabled") {
            Write-Host "✓ Windows Update Service: " -NoNewline -ForegroundColor Green
            Write-Host "Available for security updates" -ForegroundColor White
        } else {
            Write-Host "⚠ Windows Update Service: " -NoNewline -ForegroundColor Yellow
            Write-Host "May be disabled" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    return $status
}

# Basic blocking mode
function Set-BasicBlock {
    Write-Log "Applying Basic protection mode..." "Info"
    
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (-not (Test-Path $regPath)) {
        if (-not $WhatIf) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Write-Log "Created registry path" "Success"
    }
    
    if (-not $WhatIf) {
        Set-ItemProperty -Path $regPath -Name "TargetReleaseVersion" -Value 1 -Type DWord
        Set-ItemProperty -Path $regPath -Name "TargetReleaseVersionInfo" -Value $script:CurrentVersion -Type String
    }
    Write-Log "Set target release to $script:CurrentVersion" "Success"
    
    # Disable basic upgrade tasks
    $patterns = @("Schedule*Upgrade*", "Update*")
    foreach ($pattern in $patterns) {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like $pattern }
        foreach ($task in $tasks) {
            if (-not $WhatIf) {
                Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue
            }
            Write-Log "Disabled task: $($task.TaskName)" "Success"
        }
    }
    
    Write-Log "Basic protection applied" "Success"
}

# Enhanced blocking mode
function Set-EnhancedBlock {
    Write-Log "Applying Enhanced protection mode..." "Info"
    
    # Start with basic
    Set-BasicBlock
    
    # Add feature deferrals
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (-not $WhatIf) {
        Set-ItemProperty -Path $regPath -Name "DeferFeatureUpdates" -Value 1 -Type DWord
        Set-ItemProperty -Path $regPath -Name "DeferFeatureUpdatesPeriodInDays" -Value 365 -Type DWord
        Set-ItemProperty -Path $regPath -Name "ProductVersion" -Value "Windows 11" -Type String
    }
    Write-Log "Set feature update deferral to 365 days" "Success"
    
    # Windows Update for Business
    $wufbPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    if (-not $WhatIf) {
        Set-ItemProperty -Path $wufbPath -Name "BranchReadinessLevel" -Value 32 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $wufbPath -Name "DeferFeatureUpdatesPeriodInDays" -Value 365 -Type DWord -ErrorAction SilentlyContinue
    }
    Write-Log "Configured Windows Update for Business" "Success"
    
    # Disable update services
    $services = @("WaaSMedicSvc", "UsoSvc")
    foreach ($svc in $services) {
        try {
            if (-not $WhatIf) {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            }
            Write-Log "Disabled service: $svc" "Success"
        } catch {
            Write-Log "Could not disable $svc (requires SYSTEM)" "Warning"
        }
    }
    
    # SetupDiag compatibility blocks
    $setupDiagPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\CompatMarkers"
    if (-not (Test-Path $setupDiagPath)) {
        if (-not $WhatIf) {
            New-Item -Path $setupDiagPath -Force | Out-Null
        }
    }
    if (-not $WhatIf) {
        Set-ItemProperty -Path $setupDiagPath -Name "24H2" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    }
    Write-Log "Set compatibility markers" "Success"
    
    # Block specific KBs
    $blockedKBs = @("KB5039212", "KB5039302", "KB5040442")
    foreach ($kb in $blockedKBs) {
        $hideKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending\$kb"
        if (-not (Test-Path $hideKey)) {
            if (-not $WhatIf) {
                New-Item -Path $hideKey -Force | Out-Null
            }
        }
        if (-not $WhatIf) {
            Set-ItemProperty -Path $hideKey -Name "Hide" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        }
        Write-Log "Blocked $kb" "Success"
    }
    
    # Compatibility appraiser override
    $appraiserPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\CompatTelRunner.exe"
    if (-not (Test-Path $appraiserPath)) {
        if (-not $WhatIf) {
            New-Item -Path $appraiserPath -Force | Out-Null
        }
    }
    if (-not $WhatIf) {
        Set-ItemProperty -Path $appraiserPath -Name "Debugger" -Value "cmd.exe /c echo blocked" -Type String -ErrorAction SilentlyContinue
    }
    Write-Log "Blocked compatibility appraiser" "Success"
    
    Write-Log "Enhanced protection applied" "Success"
}

# Selective blocking mode (recommended)
function Set-SelectiveBlock {
    Write-Log "Applying Selective protection mode (recommended)..." "Info"
    
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (-not (Test-Path $regPath)) {
        if (-not $WhatIf) {
            New-Item -Path $regPath -Force | Out-Null
        }
    }
    
    # Pin to 23H2 for feature updates only
    if (-not $WhatIf) {
        Set-ItemProperty -Path $regPath -Name "TargetReleaseVersion" -Value 1 -Type DWord
        Set-ItemProperty -Path $regPath -Name "TargetReleaseVersionInfo" -Value $script:CurrentVersion -Type String
        Set-ItemProperty -Path $regPath -Name "ProductVersion" -Value "Windows 11" -Type String
    }
    Write-Log "Pinned to Windows 11 $script:CurrentVersion" "Success"
    
    # Defer feature updates only
    if (-not $WhatIf) {
        Set-ItemProperty -Path $regPath -Name "DeferFeatureUpdates" -Value 1 -Type DWord
        Set-ItemProperty -Path $regPath -Name "DeferFeatureUpdatesPeriodInDays" -Value 365 -Type DWord
        # Explicitly allow quality updates
        Set-ItemProperty -Path $regPath -Name "DeferQualityUpdates" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }
    Write-Log "Feature updates deferred, security updates enabled" "Success"
    
    # Only disable feature upgrade tasks
    $featureUpgradeTasks = @("ScheduledUpgrade", "ScheduledUpgradePrep", "Feature Update", "FeatureUpgrade")
    foreach ($taskName in $featureUpgradeTasks) {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | 
                 Where-Object { $_.TaskName -like "*$taskName*" -and $_.TaskPath -like "*WindowsUpdate*" }
        
        foreach ($task in $tasks) {
            if (-not $WhatIf) {
                Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue
            }
            Write-Log "Disabled feature task: $($task.TaskName)" "Success"
        }
    }
    
    Write-Log "Selective protection applied - 24H2 blocked, security updates allowed" "Success"
}

# Remove all blocks
function Remove-Blocks {
    Write-Log "Removing all 24H2 blocks..." "Warning"
    
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (Test-Path $regPath) {
        if (-not $WhatIf) {
            Remove-ItemProperty -Path $regPath -Name "TargetReleaseVersion" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $regPath -Name "TargetReleaseVersionInfo" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $regPath -Name "ProductVersion" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $regPath -Name "DeferFeatureUpdates" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $regPath -Name "DeferFeatureUpdatesPeriodInDays" -ErrorAction SilentlyContinue
        }
        Write-Log "Removed Windows Update policy settings" "Success"
    }
    
    # Re-enable services
    $services = @("WaaSMedicSvc", "UsoSvc")
    foreach ($svc in $services) {
        try {
            if (-not $WhatIf) {
                Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue
                Start-Service -Name $svc -ErrorAction SilentlyContinue
            }
            Write-Log "Re-enabled service: $svc" "Success"
        } catch {
            Write-Log "Could not re-enable $svc" "Warning"
        }
    }
    
    # Remove compatibility blocks
    $setupDiagPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\CompatMarkers"
    if (Test-Path $setupDiagPath) {
        if (-not $WhatIf) {
            Remove-ItemProperty -Path $setupDiagPath -Name "24H2" -ErrorAction SilentlyContinue
        }
    }
    
    # Remove appraiser block
    $appraiserPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\CompatTelRunner.exe"
    if (Test-Path $appraiserPath) {
        if (-not $WhatIf) {
            Remove-Item -Path $appraiserPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-Log "All blocks removed - system will follow normal update policy" "Success"
}


# Main execution
function Main {
    # Initialize logging first
    try {
        Initialize-Logging
        Write-Log "Block-24H2 script started" "Info"
    } catch {
        # Continue if logging fails
    }
    
    # Check admin rights
    if (-not (Test-Administrator)) {
        Write-Log "Script requires Administrator privileges" "Warning"
        
        # In non-interactive mode, try elevation
        if ($Mode -or $Silent) {
            Write-Log "Attempting automatic elevation for non-interactive mode" "Info"
            if (Request-Elevation -Mode $Mode) {
                Write-Log "Elevation successful, exiting this instance" "Info"
                exit 0
            } else {
                Write-Log "Elevation failed" "Error"
                Show-AdminInstructions
                exit 1
            }
        } else {
            # Interactive mode - ask user
            Write-Host ""
            $elevate = Read-Host "Attempt to elevate privileges automatically? (Y/N)"
            if ($elevate -eq "Y" -or $elevate -eq "y") {
                if (Request-Elevation) {
                    Write-Log "Elevation successful, exiting this instance" "Info"
                    exit 0
                } else {
                    Write-Log "Automatic elevation failed" "Warning"
                    Show-AdminInstructions
                    exit 1
                }
            } else {
                Show-AdminInstructions
                exit 1
            }
        }
    }
    
    Write-Log "Running with Administrator privileges" "Success"
    
    # Non-interactive mode
    if ($Mode -or $Silent) {
        if (-not $Mode) {
            Write-Log "Mode parameter required for non-interactive execution" "Error"
            exit 1
        }
        
        Write-Log "Running in non-interactive mode: $Mode" "Info"
        
        switch ($Mode) {
            "Basic"     { Set-BasicBlock }
            "Enhanced"  { Set-EnhancedBlock }
            "Selective" { Set-SelectiveBlock }
            "Remove"    { Remove-Blocks }
            default {
                Write-Log "Invalid mode: $Mode" "Error"
                exit 1
            }
        }
        
        if ($ScheduleTask -and $Mode -ne "Remove") {
            $persistentScript = Copy-ScriptToPersistentLocation
            New-ScheduledBlockTask -SelectedMode $Mode -ScriptLocation $persistentScript
        }
        
        if ($WhatIf) {
            Write-Log "WhatIf mode - no changes were made" "Info"
        }
        
        exit 0
    }
    
    # Interactive TUI mode
    do {
        Show-Menu
        $choice = Read-Host "Enter your choice"
        
        switch ($choice) {
            "1" {
                Write-Host ""
                Set-BasicBlock
                Request-ScheduledTaskInstallation -SelectedMode "Basic"
                Write-Host "`nPress any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "2" {
                Write-Host ""
                Set-EnhancedBlock
                Request-ScheduledTaskInstallation -SelectedMode "Enhanced"
                Write-Host "`nPress any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "3" {
                Write-Host ""
                Set-SelectiveBlock
                Request-ScheduledTaskInstallation -SelectedMode "Selective"
                Write-Host "`nPress any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "4" {
                Write-Host ""
                $confirm = Read-Host "Are you sure you want to remove all blocks? (Y/N)"
                if ($confirm -eq "Y" -or $confirm -eq "y") {
                    Remove-Blocks
                }
                Write-Host "`nPress any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "5" {
                Get-BlockStatus
                Write-Host "`nPress any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "Q" { 
                Write-Host "`nExiting..." -ForegroundColor Green
                exit 0
            }
            "q" { 
                Write-Host "`nExiting..." -ForegroundColor Green
                exit 0
            }
            default {
                Write-Host "Invalid choice. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    } while ($true)
}

# Run main
Main

# If we're in an elevated session and interactive mode, pause before exit
if (-not $Silent -and -not $Mode) {
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}