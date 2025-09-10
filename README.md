# Windows 11 24H2 Update Blocker

PowerShell scripts to prevent automatic Windows 11 24H2 feature updates while maintaining security updates.

## Quick Start

### Interactive Mode (TUI)
```powershell
# Run with menu interface (will auto-elevate if needed)
.\Block-24H2.ps1
```

### Non-Interactive Mode (CLI)
```powershell
# Recommended: Block 24H2 only, allow security updates
.\Block-24H2.ps1 -Mode Selective -Silent

# Basic blocking
.\Block-24H2.ps1 -Mode Basic -Silent

# Enhanced protection (multiple methods)
.\Block-24H2.ps1 -Mode Enhanced -Silent

# Remove all blocks
.\Block-24H2.ps1 -Mode Remove -Silent
```

### Auto-Elevation
The script automatically attempts to elevate privileges using:
1. **gsudo** (if installed) - preferred method
2. **sudo** (if available) 
3. **UAC elevation** - Windows built-in
4. **Manual instructions** - if auto-elevation fails

## Protection Modes

### 🟢 Selective (Recommended)
- Blocks ONLY Windows 11 24H2 feature update
- Allows all security updates
- Allows quality updates
- Allows Microsoft Store updates
- Minimal system impact

### 🟡 Basic
- Simple registry-based blocking
- Disables upgrade scheduled tasks
- Lightweight approach

### 🔴 Enhanced
- Multiple blocking methods
- Disables update services
- Blocks specific KBs
- Maximum protection (may affect other updates)

## Command Line Options

| Parameter | Description | Values |
|-----------|-------------|--------|
| `-Mode` | Protection level | `Basic`, `Enhanced`, `Selective`, `Remove` |
| `-Silent` | Run without prompts | Switch |
| `-WhatIf` | Test mode - show changes without applying | Switch |
| `-Verbose` | Show detailed output | Switch |
| `-ScheduleTask` | Create scheduled task | Switch |
| `-Schedule` | Task frequency | `Daily`, `Weekly`, `OnBoot` |
| `-Help` | Show help message | Switch |

## Schedule Automatic Protection

### Interactive Setup (Recommended)
Run any protection mode and you'll be prompted to install a scheduled task:
```powershell
.\Block-24H2.ps1
# Choose protection mode → Script asks about scheduled task → Done!
```

### Command Line Setup
```powershell
# Run selective mode daily at 3 AM
.\Block-24H2.ps1 -Mode Selective -ScheduleTask -Schedule Daily

# Run on system boot
.\Block-24H2.ps1 -Mode Selective -ScheduleTask -Schedule OnBoot
```

**What happens when you install a scheduled task:**
- Script copies itself to `C:\ProgramData\ftfy-no-means-no\`
- Creates daily task running at 3:00 AM with SYSTEM privileges
- Maintains protection even after Windows updates
- Logs activity to `C:\ProgramData\ftfy-no-means-no\logs\`

## Verify Protection Status

```powershell
# Interactive mode - choose option 5
.\Block-24H2.ps1

# Or check manually
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" | Select TargetReleaseVersionInfo
```

## Requirements

- Windows 11
- PowerShell 5.1 or higher
- Administrator privileges (script will auto-elevate)

## Logging

Activity is automatically logged to:
- **Location**: `C:\ProgramData\ftfy-no-means-no\logs\`
- **Format**: Monthly log files (`Block-24H2-YYYY-MM.log`)
- **Contents**: All script actions, errors, and status updates

## What Gets Blocked vs Allowed

### ❌ Blocked
- Windows 11 version 24H2 feature update
- Feature update enablement packages

### ✅ Allowed
- Monthly security updates
- Quality updates
- Microsoft Defender updates
- Driver updates
- Microsoft Store app updates
- .NET Framework updates

## Files Included

- `Block-24H2.ps1` - Consolidated script with TUI and CLI support
- `NO-24h2-selective.ps1` - Standalone selective blocker
- `NO-24h2-enhanced.ps1` - Standalone enhanced blocker
- `NO-24h2.ps1` - Original basic blocker

## Uninstalling

To remove all blocks and restore default Windows Update behavior:

```powershell
.\Block-24H2.ps1 -Mode Remove -Silent
```

## License

Public domain - use at your own risk.

## Support

This is a community tool. For issues or suggestions, please use the GitHub Issues page.