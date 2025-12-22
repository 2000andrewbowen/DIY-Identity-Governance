<#
.SYNOPSIS
    Interactive compare & restore AD user attributes from backup CSV.

.DESCRIPTION
    For a single user:
      - Compares backup CSV attributes with live AD attributes.
      - Shows differences.
      - Prompts which attributes (if any) to restore.
      - Restores selected attributes.
      - Logs actions to a CSV audit log.
#>

param (
    [switch]$DryRun
)

Import-Module ActiveDirectory

# Prompt for inputs
$backupFile = Read-Host "Enter the path to the backup CSV (from backup script)"
$userIdentifier = Read-Host "Enter the user identifier (sAMAccountName, UPN, or EmployeeID)"

if (-not (Test-Path $backupFile)) {
    Write-Host "Backup CSV file not found. Exiting." -ForegroundColor Red
    exit
}

# Prepare log file
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile   = ".\UserRestoreAudit_$timestamp.csv"
$log = @()

# Load backup CSV
$backupData = Import-Csv $backupFile

# Try to find the AD user
$adUser = Get-ADUser -Identity $userIdentifier -Properties * -ErrorAction SilentlyContinue
if (-not $adUser) {
    Write-Host "User $userIdentifier not found in AD. Exiting." -ForegroundColor Red
    exit
}

# Find backup data for this user
$backupEntry = $backupData | Where-Object { $_.sAMAccountName -eq $adUser.sAMAccountName }
if (-not $backupEntry) {
    Write-Host "No backup data found for $userIdentifier. Exiting." -ForegroundColor Red
    exit
}

Write-Host "Comparing backup vs. current for user $($adUser.sAMAccountName)" -ForegroundColor Cyan

# Compare attributes
$differences = @()
foreach ($col in $backupEntry.PSObject.Properties.Name) {
    if ($col -in @("DistinguishedName","ObjectGUID","SID","CanonicalName")) { continue }

    $backupValue  = $backupEntry.$col
    $currentValue = $adUser.$col

    if ($currentValue -is [array]) { $currentValue = ($currentValue -join ";") }

    if ($backupValue -ne $currentValue) {
        $differences += [PSCustomObject]@{
            Attribute    = $col
            BackupValue  = $backupValue
            CurrentValue = $currentValue
        }
    }
}

if (-not $differences) {
    Write-Host "No differences found. Nothing to restore." -ForegroundColor Green
    exit
}

# Show differences
$differences | Format-Table -AutoSize

# Ask which attributes to restore
$attrChoice = Read-Host "Enter attributes to restore (comma-separated, or 'all' to restore everything, or press Enter to skip)"

if ([string]::IsNullOrWhiteSpace($attrChoice)) {
    Write-Host "No attributes selected for restore. Exiting." -ForegroundColor Yellow
    exit
}

$propsToRestore = @{}
if ($attrChoice -eq "all") {
    foreach ($diff in $differences) {
        $propsToRestore[$diff.Attribute] = $diff.BackupValue
    }
}
else {
    $attrs = $attrChoice -split "," | ForEach-Object { $_.Trim() }
    foreach ($a in $attrs) {
        $diff = $differences | Where-Object { $_.Attribute -eq $a }
        if ($diff) {
            $propsToRestore[$a] = $diff.BackupValue
        }
        else {
            Write-Host "Attribute $a not found in differences list" -ForegroundColor Yellow
        }
    }
}

# Perform restore
$logEntry = [ordered]@{
    Timestamp   = (Get-Date)
    User        = $adUser.sAMAccountName
    Attributes  = ($propsToRestore.Keys -join ", ")
    Status      = ""
    Message     = ""
}

if ($propsToRestore.Count -gt 0) {
    if ($DryRun) {
        Write-Host "[DRY-RUN] Would restore attributes for $($adUser.sAMAccountName): $($propsToRestore.Keys -join ', ')" -ForegroundColor Cyan
        $logEntry.Status  = "DryRun"
        $logEntry.Message = "Would restore: " + ($propsToRestore.Keys -join ", ")
    }
    else {
        try {
            Set-ADUser -Identity $adUser -Replace $propsToRestore
            Write-Host "Restored attributes for $($adUser.sAMAccountName): $($propsToRestore.Keys -join ', ')" -ForegroundColor Green
            $logEntry.Status  = "Success"
            $logEntry.Message = "Restored: " + ($propsToRestore.Keys -join ", ")
        }
        catch {
            Write-Host "Failed to restore attributes for $($adUser.sAMAccountName). $_" -ForegroundColor Red
            $logEntry.Status  = "Error"
            $logEntry.Message = "Failed: $_"
        }
    }
}

$log += New-Object PSObject -Property $logEntry

# Write audit log
$log | Export-Csv -Path $logFile -NoTypeInformation -Encoding UTF8
Write-Host "Audit log saved to $logFile" -ForegroundColor Green
