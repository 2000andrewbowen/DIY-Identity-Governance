#region 1 - Synopsis
<#
.DESCRIPTION
    Script to bulk import users to an AD group from a CSV. Matches based on samAccountName
    as Username. 

#>

#region 2 - Variables
# Set the path to the CSV file containing the list of users to add - first row must be "username"
$csvFilePath = ""

# Set the name of the AD group to which users will be added
$groupName = ""

# Create an empty array to store the list of users that had errors
$errorUsers = @()

#region 3 - Code
# Import the CSV file and loop through each row
Import-Csv -Path $csvFilePath | ForEach-Object {

    # Get the user's samAccountName from the "Username" column in the CSV file
    $username = $_.Username

    # Try to add the user to the AD group
    Try {
        Add-ADGroupMember -Identity $groupName -Members $username -ErrorAction Stop
    }
    Catch {
        # If an error occurs, add the username to the $errorUsers array
        $errorUsers += $username
    }
}

# If there were any errors, save the list of users that had errors to a CSV file in the $HOME\Downloads folder
if ($errorUsers.Count -gt 0) {
    # Set the path to the output CSV file
    $outputFilePath = "$HOME\Downloads\FailedUsers_$((Get-Date).ToString('yyyyMMdd_HHmmss')).csv"
    
    # Create a custom object for each user that had an error, with a "Username" property
    $failedUsersObjects = $errorUsers | ForEach-Object {
        [PSCustomObject]@{
            Username = $_
        }
    }
    
    # Export the failed users to a CSV file
    $failedUsersObjects | Export-Csv -Path $outputFilePath -NoTypeInformation
    
    Write-Host "The list of failed users has been saved to $outputFilePath"
}
