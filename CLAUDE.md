# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains PowerShell scripts designed to fix or undo problematic Windows 11 features and design decisions. Scripts are intended to be run either one-time or scheduled via Task Scheduler on Windows 11 systems.

## Common Commands

### Running Scripts on Windows
```powershell
# Run script with administrative privileges (required for most scripts)
powershell -ExecutionPolicy Bypass -File .\ScriptName.ps1

# Schedule script to run daily via Task Scheduler
schtasks /Create /TN "Block24H2" /TR "powershell -ExecutionPolicy Bypass -File C:\path\to\NO-24h2.ps1" /SC DAILY /RU SYSTEM
```

### Testing Scripts
```powershell
# Test script syntax without execution
powershell -NoProfile -NoLogo -Command "& { [System.Management.Automation.Language.Parser]::ParseFile('.\ScriptName.ps1', [ref]$null, [ref]$null) }"

# Run script in WhatIf mode (if supported)
powershell -ExecutionPolicy Bypass -File .\ScriptName.ps1 -WhatIf
```

## Architecture

### Script Structure
- Each script is self-contained and addresses a specific Windows 11 issue
- Scripts use Windows Registry modifications, Group Policy settings, and scheduled task management
- All scripts should include clear comments about what they fix/modify
- Scripts should be idempotent (safe to run multiple times)

### Key Patterns
- Registry modifications via `HKLM:\SOFTWARE\Policies\Microsoft\Windows\*`
- Scheduled task management via `Get-ScheduledTask` and `Disable-ScheduledTask`
- Optional use of PSWindowsUpdate module for Windows Update management

### Script Naming Convention
- Use descriptive names that indicate the fix/feature being addressed
- Use `.ps1` extension for all PowerShell scripts
- Include version targeting in filename when relevant (e.g., `NO-24h2.ps1`)

## Important Considerations
- All scripts require administrative privileges to modify system settings
- Scripts target Windows 11 systems specifically
- Consider impact on Windows Update and system security when creating new scripts
- Test scripts in a non-production environment first