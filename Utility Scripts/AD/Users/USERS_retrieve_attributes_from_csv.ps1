# Configurable Parameters
$inputCsvPath = "$HOME\Downloads\user_input.csv"  # Input CSV file
# Change to 'displayName', 'userPrincipalName', etc. to change what ad attribute the script uses in AD to lookup users
# Make sure the lookup attribute matches the column name (row 1) on the input csv
$lookupAttribute = 'sAMAccountName'               
$outputAttributes = @('sAMAccountName','enabled','displayName', 'mail', 'title', 'department','employeeType','employeeID','manager','l','whencreated')  # Add more if needed

# Output CSV file with timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputCsvPath = "$HOME\Downloads\AD_User_Report_$timestamp.csv"

# Import CSV
$users = Import-Csv -Path $inputCsvPath

# Results array
$results = @()

foreach ($user in $users) {
    $lookupValue = $user.$lookupAttribute

    if (-not $lookupValue) {
        Write-Warning "Missing value for $lookupAttribute in input row: $($user | Out-String)"
        continue
    }

    try {
        $adUser = Get-ADUser -Filter "$lookupAttribute -eq '$lookupValue'" -Properties $outputAttributes

        if ($adUser) {
            $result = @{}
            foreach ($attr in $outputAttributes) {
                $result[$attr] = $adUser.$attr
            }
            $results += [PSCustomObject]$result
        } else {
            $results += [PSCustomObject]@{ $lookupAttribute = $lookupValue; Error = 'User Not Found' }
        }
    } catch {
        $results += [PSCustomObject]@{ $lookupAttribute = $lookupValue; Error = $_.Exception.Message }
    }
}

# Export results to CSV
$results | Export-Csv -Path $outputCsvPath -NoTypeInformation
Write-Host "Output saved to: $outputCsvPath"
