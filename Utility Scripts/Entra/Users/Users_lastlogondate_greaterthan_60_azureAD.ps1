# Set the path to the CSV file
$csvPath = ""

# Set the path and name for the output CSV file
$outputFolderPath = Split-Path -Path $csvPath -Parent
$outputFileName = "UserList_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$outputFilePath = Join-Path -Path $outputFolderPath -ChildPath $outputFileName

# Get the current date and subtract 60 days
$thresholdDate = (Get-Date).AddDays(-60)

# Import the users from the CSV file and check if they have authenticated in the last 60 days
$users = Import-Csv $csvPath | ForEach-Object {
    $user = Get-AzureADUser -Filter "UserPrincipalName eq '$($_.Column2)'" -ErrorAction SilentlyContinue
    if ($user -ne $null) {
        $lastSignInDateTime = [DateTime]::Parse($user.LastSignInDateTime)
        $loggedOnRecently = $lastSignInDateTime -ge $thresholdDate
        [PSCustomObject]@{
            UserPrincipalName = $user.UserPrincipalName
            DisplayName = $user.DisplayName
            LastLogonDate = $lastSignInDateTime.ToString("yyyy-MM-dd HH:mm:ss")
            LoggedOnRecently = $loggedOnRecently
        }
    } else {
        [PSCustomObject]@{
            UserPrincipalName = $_.Column2
            DisplayName = ""
            LastLogonDate = ""
            LoggedOnRecently = $false
        }
    }
}

# Export the user list to a CSV file
$users | Export-Csv $outputFilePath -NoTypeInformation
