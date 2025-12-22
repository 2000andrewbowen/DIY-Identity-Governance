# Set the path to the CSV file containing the source of data to compare with
$csvInFilePath = "$home\Downloads\AD-Attribute-Sync.csv"

# Set the path to the CSV file containing the mismatched users output
$csvOutFilePath = "$home\Downloads\attribute_mismatches.csv"

# List of attributes to compare; 
# Key = AD attribute, value = csv column name
$attributesToCompareDictionary = @{
    "givenName" = "givenName"
    "sn" = "sn"
    "displayName" = "displayName"
    "mail" = "mail"
    "streetAddress" = "streetAddress"
    "st" = "st"
    "postalCode" = "postalCode"
    "title" = "title"
    "extensionAttribute1" = "extensionAttribute1"
    "employeeType" = "employeeType"
    "physicalDeliveryOfficeName" = "physicalDeliveryOfficeName"
    "l" = "l"
    "telephoneNumber" = "telephoneNumber"
    "sAMAccountName" = "sAMAccountName"
}

# ----- DON'T EDIT BELOW THIS LINE ------

# Import AD module
Import-Module ActiveDirectory

# Output list for mismatches
$mismatches = @()

# Get Attributes to compare
$attributesToCompare = $attributesToCompareDictionary.Keys
$adAttributes = $attributesToCompareDictionary.Keys | ForEach-Object { $_ }

# Import the CSV file and loop through each row
Import-Csv -Path $csvInFilePath | ForEach-Object {
    $employeeId = $_.EmployeeId
    $name = $_.Worker
    $type = $_.Type
    #Write-Host $employeeId

    if ([string]::IsNullOrWhiteSpace($employeeId)) {
        Write-Warning "Missing EmployeeId in row: $($_ | Out-String)"
        continue
    }

    # Get AD user with necessary properties
    $adUser = Get-ADUser -Filter "EmployeeId -eq '$employeeId'" -Properties $adAttributes

    if (-not $adUser) {
        # AD user not found
        $mismatches += [PSCustomObject]@{
            EmployeeId = $employeeId
            Name = $name
            Type = $type
            Attribute  = "UserNotFound"
            AD_Value   = $null
            CSV_Value  = "Exists in CSV"
        }
    } else{
        foreach ($attribute in $attributesToCompare) {
            $csvColumn = $attributesToCompareDictionary[$attribute]
            $csvValue = $_.$csvColumn
            $adValue  = $adUser.$attribute
            #Write-Host "Col: $csvColumn, CSV Value: $csvValue, AD Value: $adValue"
            
            if($attribute -eq "distinguishedName" -and $csvColumn -eq "Cost Center - ID"){
                $dn = $adUser.distinguishedName

                # Use regex to extract the first OU
                if ($dn -match 'OU=([^,]+)') {
                    $firstOU = $matches[1]

                    if ($firstOU -match '^(\S+)') {
                        $costCenterCode = $matches[1]
                        if (-not [string]::IsNullOrWhiteSpace($costCenterCode) -and -not [string]::IsNullOrWhiteSpace($csvValue)) {
                            if ($csvValue -ne $costCenterCode) {
                                #Write-Host "Col: $csvColumn, CSV Value: $csvValue, AD Value: $adValue"
                                $mismatches += [PSCustomObject]@{
                                    EmployeeId = $employeeId
                                    Name = $name
                                    Type = $type
                                    Attribute  = "CostCenterCode"
                                    AD_Value   = $costCenterCode
                                    CSV_Value  = $csvValue
                                }
                            }
                        } elseif ([string]::IsNullOrWhiteSpace($csvValue) -and -not [string]::IsNullOrWhiteSpace($adValue)) {
                            $mismatches += [PSCustomObject]@{
                                EmployeeId = $employeeId
                                Name = $name
                                Type = $type
                                Attribute  = "CostCenterCode"
                                AD_Value   = $costCenterCode
                                CSV_Value  = "Missing in CSV"
                            }
                        }
                    }
                }
            }elseif ($attribute -eq "extensionAttribute1" -and $csvColumn -eq "Cost Center - ID"){
                $dn = $adUser.distinguishedName

                # Use regex to extract the first OU
                if ($dn -match 'OU=([^,]+)') {
                    $firstOU = $matches[1]

                    if ($firstOU -match '^(\S+)') {
                        $costCenterCode = $matches[1]

                        if (-not [string]::IsNullOrWhiteSpace($costCenterCode) -and -not [string]::IsNullOrWhiteSpace($adValue)) {
                            if ($costCenterCode -ne $adValue) {
                                #Write-Host "Col: $csvColumn, CSV Value: $csvValue, AD Value: $adValue"
                                $mismatches += [PSCustomObject]@{
                                    EmployeeId = $employeeId
                                    Name = $name
                                    Type = $type
                                    Attribute  = $attribute
                                    AD_Value   = $adValue
                                    CSV_Value  = $csvValue
                                }
                            }
                        } elseif ([string]::IsNullOrWhiteSpace($csvValue) -and -not [string]::IsNullOrWhiteSpace($adValue)) {
                            $mismatches += [PSCustomObject]@{
                                EmployeeId = $employeeId
                                Name = $name
                                Type = $type
                                Attribute  = $attribute
                                AD_Value   = $adValue
                                CSV_Value  = "Missing in CSV"
                            }
                        } elseif (-not [string]::IsNullOrWhiteSpace($csvValue) -and [string]::IsNullOrWhiteSpace($adValue)){
                            $mismatches += [PSCustomObject]@{
                                EmployeeId = $employeeId
                                Name = $name
                                Type = $type
                                Attribute  = $attribute
                                AD_Value   = "Missing in AD"
                                CSV_Value  = $csvValue
                            }
                        }
                    }
                }
            }else {
                if (-not [string]::IsNullOrWhiteSpace($csvValue) -and -not [string]::IsNullOrWhiteSpace($adValue)) {
                    if ($csvValue -ne $adValue) {
                        #Write-Host "Col: $csvColumn, CSV Value: $csvValue, AD Value: $adValue"
                        $mismatches += [PSCustomObject]@{
                            EmployeeId = $employeeId
                            Name = $name
                            Type = $type
                            Attribute  = $attribute
                            AD_Value   = $adValue
                            CSV_Value  = $csvValue
                        }
                    }
                } elseif ([string]::IsNullOrWhiteSpace($csvValue) -and -not [string]::IsNullOrWhiteSpace($adValue)) {
                    $mismatches += [PSCustomObject]@{
                        EmployeeId = $employeeId
                        Name = $name
                        Type = $type
                        Attribute  = $attribute
                        AD_Value   = $adValue
                        CSV_Value  = "Missing in CSV"
                    }
                } elseif (-not [string]::IsNullOrWhiteSpace($csvValue) -and [string]::IsNullOrWhiteSpace($adValue)){
                    $mismatches += [PSCustomObject]@{
                        EmployeeId = $employeeId
                        Name = $name
                        Type = $type
                        Attribute  = $attribute
                        AD_Value   = "Missing in AD"
                        CSV_Value  = $csvValue
                    }
                }
            }            
        }
    }
}

if ($mismatches.Count -gt 0) {
    # Export mismatches to CSV
    $mismatches | Export-Csv -Path $csvOutFilePath -NoTypeInformation

    Write-Host "The list of mismatch attributes for users has been saved to $csvOutFilePath"
}