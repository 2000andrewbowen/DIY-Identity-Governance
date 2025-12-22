# Connect to Active Directory
#Import-Module ActiveDirectory

# Find all user accounts
$users = Get-ADUser -Filter * -Properties UserPrincipalName, SamAccountName, Enabled, Employeeid, created, lastlogondate

# Create an empty array to store mismatched users
$mismatchedUsers = @()

# Loop through each user account
foreach ($user in $users) {
    # Initialize variables
    $upnPrefix = $null

    # Check if UserPrincipalName exists
    if ($user.UserPrincipalName) {
        # Get the user's UPN prefix
        $upnPrefix = $user.UserPrincipalName.Split("@")[0]
    }

    # Check if UPN prefix and SamAccountName match
    if ($upnPrefix -ne $user.SamAccountName) {
        # Add the user account to the mismatched users array
        $mismatchedUsers += [PSCustomObject] @{
            Name = $user.Name
            UserPrincipalName = $user.UserPrincipalName
            SamAccountName = $user.SamAccountName
            Enabled = $user.Enabled
            Employeeid = $user.Employeeid
            Created = $user.Created
            LastLogon = $user.LastLogonDate
        }
    }
}

# Get the current date and time
$dateTime = Get-Date -Format "yyyy-MM-dd-HHmmss"

# Write the mismatched users to a CSV file with the current date and time in the filename
$mismatchedUsers | Export-Csv -Path "$($env:USERPROFILE)\Downloads\ADMismatchedUsers_$dateTime.csv" -NoTypeInformation
