# Block Windows 11 24H2 Upgrade
# Run this daily via Task Scheduler with highest privileges

$CurrentVersion = "23H2"
$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

# --- Lock system to current release ---
If (-Not (Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}
Set-ItemProperty -Path $RegPath -Name "TargetReleaseVersion" -Value 1 -Type DWord
Set-ItemProperty -Path $RegPath -Name "TargetReleaseVersionInfo" -Value $CurrentVersion -Type String

# --- Disable upgrade-related scheduled tasks ---
$Patterns = @("Schedule*Upgrade*", "Update*")
foreach ($pattern in $Patterns) {
    $tasks = Get-ScheduledTask | Where-Object { $_.TaskName -like $pattern }
    foreach ($t in $tasks) {
        Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue
    }
}

# --- Hide 24H2 update if it shows up ---
# Requires PSWindowsUpdate module: Install-Module PSWindowsUpdate
Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
$updates = Get-WindowsUpdate -MicrosoftUpdate -IgnoreUserInput -ErrorAction SilentlyContinue
if ($updates) {
    foreach ($u in $updates) {
        if ($u.Title -match "24H2") {
            Hide-WindowsUpdate -KBArticleID $u.KB -Confirm:$false -ErrorAction SilentlyContinue
            Write-Output "Hidden update: $($u.Title)"
        }
    }
}

Write-Output "24H2 block enforced. System pinned to $CurrentVersion."
