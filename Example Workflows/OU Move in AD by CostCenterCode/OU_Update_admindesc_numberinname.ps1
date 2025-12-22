<#
.DESCRIPTION
    Set the adminDescription of OUs based on the number at the start of an OU name
#>

# Load Active Directory module 
Import-Module ActiveDirectory

# Base OU to search from (adjust for your environment)
$SearchBase = ""  #

# Where to save the report
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$exportPath = "$HOME\Downloads\OU_AdminDescription_Update_$timestamp.csv"

# Prepare list for logging
$log = @()

# Get all OUs under the base
$OUs = Get-ADOrganizationalUnit -Filter * -SearchBase $SearchBase -Properties adminDescription -SearchScope Subtree

foreach ($ou in $OUs) {
    # Extract the OU name
    if ($ou.DistinguishedName -match "^OU=([^,]+),") {
        $ouName = $Matches[1]

        # Skip if adminDescription already exists
        if ($ou.adminDescription) {
            $log += [PSCustomObject]@{
                OUName             = $ouName
                DistinguishedName  = $ou.DistinguishedName
                OldAdminDescription = $ou.adminDescription
                NewAdminDescription = ""
                Status             = "Skipped (has existing value)"
            }
            continue
        }

        $number = $null

        # Check for starting number
        if ($ouName -match "^(\d+)\s") {
            $number = $Matches[1]
        }
        # Check for trailing -0000 pattern
        elseif ($ouName -match "-(\d{4})$") {
            $number = $Matches[1]
        }

        if ($number) {
            try {
                # Update the attribute
                Set-ADOrganizationalUnit -Identity $ou.DistinguishedName -Replace @{adminDescription = $number}
                Write-Host "Set adminDescription for '$ouName' to '$number'"

                $log += [PSCustomObject]@{
                    OUName             = $ouName
                    DistinguishedName  = $ou.DistinguishedName
                    OldAdminDescription = ""
                    NewAdminDescription = $number
                    Status             = "Updated"
                }
            } catch {
                Write-Warning "Failed to update $ouName - $_"
            }
        } else {
            $log += [PSCustomObject]@{
                OUName             = $ouName
                DistinguishedName  = $ou.DistinguishedName
                OldAdminDescription = ""
                NewAdminDescription = ""
                Status             = "Skipped (no match)"
            }
        }
    }
}

# Export the log
$log | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8
Write-Host "`nLog exported to:`n$exportPath" -ForegroundColor Green
