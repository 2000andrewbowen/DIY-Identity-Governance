<#
.DESCRIPTION
    Clear adminDescription for all OUs
#>

# Cleanup Script: Clear adminDescription in all sub-OUs
Import-Module ActiveDirectory

# Set this to the top-level OU you're cleaning (e.g., the root region OU)
$CleanupBaseOU = ""  # <== CHANGE THIS

# Get all OUs under the target and clear adminDescription
$OUsToClean = Get-ADOrganizationalUnit -Filter * -SearchBase $CleanupBaseOU -SearchScope Subtree -Properties adminDescription

foreach ($ou in $OUsToClean) {
    if ($ou.adminDescription) {
        try {
            Set-ADOrganizationalUnit -Identity $ou.DistinguishedName -Clear adminDescription
            Write-Host "Cleared adminDescription on: $($ou.DistinguishedName)"
        } catch {
            Write-Warning "Failed to clear adminDescription on $($ou.DistinguishedName) - $_"
        }
    }
}
