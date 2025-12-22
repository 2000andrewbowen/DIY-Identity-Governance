#region 1 - Synopsis
<#
.DESCRIPTION
    Get all OUs managed by the target group with ACL/Delegate Control in AD

    Useful for migrating Delegated Control from AD into Admin Units in Entra
#>

#region 2 - Variables
# Target group name
$targetGroupName = ""

# Output file path ($outputFolder\$targetGroupName.csv)
$outputFolder = "$home\Downloads\Users"

#region 3 - Code

# Import AD module
Import-Module ActiveDirectory

$outputFileName = "$outputFolder\$targetGroupName" + ".csv"

# Get the group SID (to avoid name resolution issues in ACLs)
#$targetGroupSID = (Get-ADGroup -Identity $targetGroupName).SID.Value

# Get all OUs
$OUs = Get-ADOrganizationalUnit -Filter * -Properties DistinguishedName

# Prepare results array
$matchedOUs = @()

foreach ($ou in $OUs) {
    # Get the security descriptor (ACL) of the OU
    $acl = Get-Acl -Path ("AD:\" + $ou.DistinguishedName)
    #$acl | Format-Table -AutoSize
    # Check each access rule
    foreach ($access in $acl.Access) {
        #$access
        if ($access.IdentityReference -match $targetGroupName) {
            # Found a match
            $matchedOUs += [PSCustomObject]@{
                OUName = $ou.Name
                DistinguishedName = $ou.DistinguishedName
                IdentityReference = $access.IdentityReference
                AccessControlType = $access.AccessControlType
                ActiveDirectoryRights = $access.ActiveDirectoryRights
            }
            break
        }
    }
}

# Output results
$matchedOUs |  Export-Csv -Path $outputFileName -NoTypeInformation