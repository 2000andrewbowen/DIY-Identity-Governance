#region 1 - Synopsis
<#
.DESCRIPTION
    Get all groups managed by the target group with ACL/Delegate Control in AD

    Useful for migrating Delegated Control from AD into Admin Units in Entra
#>

#region 2 - Variables
# Target group name
$targetGroupName = ""

#region 3 - Code
# Import AD module
Import-Module ActiveDirectory

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

# Initialize list to hold all found groups
$allGroups = @()

# Loop through each matching OU and get the groups within
foreach ($ou in $matchedOUs) {
    $groups = Get-ADGroup -Filter * -SearchBase $ou.DistinguishedName
    foreach ($group in $groups) {
        # Add custom object to list
        $allGroups += [PSCustomObject]@{
            GroupName          = $group.Name
            GroupDN            = $group.DistinguishedName
            OUName             = $targetOUName
            OUPath             = $ou.DistinguishedName
        }
    }
}

$allGroups | Export-Csv -Path "$home\Downloads\GroupDelegationOutput.csv" -NoTypeInformation