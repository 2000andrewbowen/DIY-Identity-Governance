#region 1 - Synopsis
<#
.DESCRIPTION
    Move users to their correct OU based on adminDescription on the OUs and
    an OU number stored in a configurable user attribute.
    Supports WhatIf (dry-run) mode.
#>

#region 2 - Variables
# Define the source OU
$sourceOU = ""

# Define which AD attribute contains the OU number
$ouNumberAttribute = "extensionAttribute1"

# Enable / disable WhatIf (dry-run) mode
$WhatIfMode = $true   # <-- set to $false to actually move users

#region 3 - Code
$timestamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$reportPath = "$HOME\Downloads\UserMoveReport_$timestamp.csv"
$report     = @()

# Get users with the configured attribute
$users = Get-ADUser `
    -SearchBase $sourceOU `
    -SearchScope Subtree `
    -Filter * `
    -Properties $ouNumberAttribute

# Get all OUs with adminDescription set
$allOUs = Get-ADOrganizationalUnit `
    -Filter * `
    -Properties adminDescription |
    Where-Object { $_.adminDescription }

foreach ($user in $users) {

    $username  = $user.SamAccountName
    $ouNumber  = $user.$ouNumberAttribute
    $currentDN = $user.DistinguishedName
    $targetOU  = $null
    $status    = "Success"
    $message   = ""

    if ([string]::IsNullOrWhiteSpace($ouNumber)) {
        $status  = "Failed"
        $message = "$ouNumberAttribute is empty"
    }
    else {
        $targetOU = $allOUs | Where-Object {
            $_.adminDescription -eq $ouNumber
        }

        if ($targetOU) {
            try {
                if ($WhatIfMode) {
                    $message = "WHATIF: Would move to OU: $($targetOU.DistinguishedName)"
                }
                else {
                    Move-ADObject `
                        -Identity $currentDN `
                        -TargetPath $targetOU.DistinguishedName `
                        -ErrorAction Stop

                    $message = "Moved to OU: $($targetOU.DistinguishedName)"
                }
            }
            catch {
                $status  = "Failed"
                $message = "Move failed: $($_.Exception.Message)"
            }
        }
        else {
            $status  = "Failed"
            $message = "No OU found with adminDescription: $ouNumber"
        }
    }

    $report += [pscustomobject]@{
        SamAccountName = $username
        AttributeUsed = $ouNumberAttribute
        AttributeValue = $ouNumber
        WhatIfMode = $WhatIfMode
        Status = $status
        SourceDN = $currentDN
        Message = $message
    }
}

$report | Export-Csv -Path $reportPath -NoTypeInformation -Encoding UTF8

Write-Output "User move operation completed."
Write-Output "WhatIf mode: $WhatIfMode"
Write-Output "Report saved to: $reportPath"