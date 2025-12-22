#region 1 - Synopsis
<#
.SYNOPSIS
Exports members of an AD group into a CSV file formatted for Entra ID bulk import.

.DESCRIPTION
Creates a CSV file with Entra ID’s required header rows:
  Member object ID or user principal name [memberObjectIdOrUpn] Required
Followed by one UPN per line starting at row 3.

Optionally, add -IncludeBackupColumns to also create a secondary backup CSV
with full member details for reference. Useful for group mitragtions.
#>

#region 2 - Variables
param(
    [string]$GroupName = '',
    [switch]$IncludeBackupColumns
)

#region 3 - Code
# Get members (user objects only)
$groupMembers = Get-ADGroupMember -Identity $GroupName | Where-Object { $_.objectClass -eq 'user' }

# Get full user details to retrieve UPNs
$userDetails = $groupMembers | ForEach-Object {
    Get-ADUser $_.SamAccountName -Properties UserPrincipalName, Name, Title, Enabled, DistinguishedName
}

# Prepare timestamp and file paths
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$baseFileName = "GroupMembers_${GroupName}_${timestamp}"
$downloadPath = Join-Path $HOME "Downloads"
$csvFilePath = Join-Path $downloadPath "$baseFileName.csv"

# --- Write Entra ID import CSV ---
# Create the first required line
"Member object ID or user principal name [memberObjectIdOrUpn] Required" | Out-File -FilePath $csvFilePath -Encoding UTF8 -Append

# Append each user's UPN starting from row 3
$userDetails | ForEach-Object {
    $_.UserPrincipalName
} | Out-File -FilePath $csvFilePath -Encoding UTF8 -Append

Write-Host "Entra ID import CSV created:"
Write-Host "   $csvFilePath`n"

# --- Optional: create a full backup export ---
if ($IncludeBackupColumns) {
    $backupPath = Join-Path $downloadPath "${baseFileName}_Backup.csv"
    $userDetails | Select-Object UserPrincipalName, SamAccountName, Name, Title, Enabled, DistinguishedName |
        Export-Csv -Path $backupPath -NoTypeInformation
    Write-Host "    Backup CSV created:"
    Write-Host "   $backupPath`n"
}
