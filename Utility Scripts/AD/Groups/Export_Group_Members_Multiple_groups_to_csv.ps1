#region 1 - Synopsis
<#
.SYNOPSIS
    Script to bulk export users of multiple groups to a CSV. Creates one CSV in $Home\Downloads

.DESCRIPTION
    In this script, we first specify the list of Active Directory group names in the $groupNames array. 
    Then, we iterate through each group, retrieve its members, and append them to the $allGroupMembers array. 
    Finally, all the group members are exported to a single CSV file.
#>

#region 2 - Variables
# Specify the list of Active Directory group names
$groupNames = @("")

# Create an empty array to store group members
$allGroupMembers = @()

#region 3 - Code
# Iterate through the list of group names
foreach ($groupName in $groupNames) {
    # Get the members of the current group
    $groupMembers = Get-ADGroupMember -Identity $groupName | Where-Object { $_.objectClass -eq 'user' }

    # Append the members to the array
    $allGroupMembers += $groupMembers
}

# Create a new CSV file name with the current date and time
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$csvFileName = "AllGroupMembers_${timestamp}.csv"

# Define the path where the CSV file will be saved in the $HOME\Downloads directory
$csvFilePath = Join-Path $HOME "Downloads\$csvFileName"

# Export all group members to the CSV file
$allGroupMembers | Select-Object SamAccountName, Name, UserPrincipalName, DistinguishedName |
    Export-Csv -Path $csvFilePath -NoTypeInformation

# Output a message to indicate the operation's completion
Write-Host "All group members have been exported to $csvFilePath"