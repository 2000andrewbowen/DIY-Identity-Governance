# Set the path to the CSV file containing the source of data to compare with
$backupFile = "$home\Downloads\AD-Attribute-Sync.csv"

<#
.SYNOPSIS
    Compare AD user attributes with backup CSV.

.DESCRIPTION
    Reads a backup CSV of AD user attributes and compares them to the current AD state.
    Outputs differences (or matches) to a CSV audit log.
#>

Import-Module ActiveDirectory


if (-not (Test-Path $backupFile)) {
    Write-Host "Backup CSV file not found. Exiting." -ForegroundColor Red
    exit
}

# Load backup data
$backupData = Import-Csv $backupFile

# Prepare log file
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile   = "$home\Downloads\CompareADUsers_$timestamp.csv"
$log = @()

foreach ($b in $backupData) {
    $userIdentifier = $b.sAMAccountName
    $adUser = Get-ADUser -Identity $userIdentifier -Properties * -ErrorAction SilentlyContinue

    if (-not $adUser) {
        # User missing in AD
        $log += [PSCustomObject]@{
            User        = $userIdentifier
            Attribute   = "User"
            BackupValue = "Exists in Backup"
            CurrentValue = "Not found in AD"
            Status      = "Missing in AD"
        }
        continue
    }

    # Compare each attribute in backup
    # Build union of properties (backup + AD)
    $allProps = @(
        $b.PSObject.Properties.Name +
        $adUser.PSObject.Properties.Name
    ) | Sort-Object -Unique

    # Compare each attribute
    foreach ($col in $allProps) {
        if ($col -in @("DistinguishedName","ObjectGUID","SID","CanonicalName", "thumbnailPhoto")) { continue }

        $backupValue  = $b.$col
        $currentValue = $adUser.$col

        if ($currentValue -is [array]) { $currentValue = ($currentValue -join ";") }
        if ($backupValue -is [array]) { $backupValue = ($backupValue -join ";") }

        if ([string]::IsNullOrWhiteSpace($backupValue)) { $backupValue = "" }
        if ([string]::IsNullOrWhiteSpace($currentValue)) { $currentValue = "" }

        $status = if ($backupValue -eq $currentValue) { "Match" } else { "Mismatch" }

        $log += [PSCustomObject]@{
            User        = $userIdentifier
            Attribute   = $col
            BackupValue = $backupValue
            CurrentValue= $currentValue
            Status      = $status
        }
    }
}

# Save log file
$log | Export-Csv -Path $logFile -NoTypeInformation -Encoding UTF8
Write-Host "Comparison complete. Log saved to $logFile" -ForegroundColor Green
