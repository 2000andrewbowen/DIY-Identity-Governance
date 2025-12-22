<#
.SYNOPSIS
    Backup AD user attributes to CSV based on EmployeeIDs or OU adminDescription lookup (including child OUs).
#>

Import-Module ActiveDirectory

# Prompt user for input method
$choice = Read-Host "Do you want to select users by (1) EmployeeID, (2) OU AdminDescription, or (3) OU DN? Enter 1, 2, or 3"

if ($choice -eq "1") {
    # Get list of EmployeeIDs
    $employeeIDs = Read-Host "Enter a comma-separated list of EmployeeIDs" | ForEach-Object { $_.Split(",") } | ForEach-Object { $_.Trim() }

    $users = foreach ($id in $employeeIDs) {
        Get-ADUser -Filter "EmployeeID -eq '$id'" -Properties * -ErrorAction SilentlyContinue
    }
}
elseif ($choice -eq "2") {
    # Get list of numbers (adminDescription values)
    $ouNumbers = Read-Host "Enter a comma-separated list of OU numbers (from adminDescription)" | ForEach-Object { $_.Split(",") } | ForEach-Object { $_.Trim() }

    $ous = foreach ($num in $ouNumbers) {
        Get-ADOrganizationalUnit -Filter "adminDescription -eq '$num'" -Properties adminDescription -ErrorAction SilentlyContinue
    }

    if ($ous) {
        $users = foreach ($ou in $ous) {
            # Include users in the OU and all child OUs
            Get-ADUser -SearchBase $ou.DistinguishedName -SearchScope Subtree -Filter * -Properties * -ErrorAction SilentlyContinue
        }
    }
    else {
        Write-Host "No OUs found with the provided adminDescription values." -ForegroundColor Yellow
        exit
    }
}
elseif ($choice -eq "3") {
    # --- Option 3: Direct OU Path ---
    $ouPaths = Read-Host "Enter a colon-separated list of OU distinguished names (DNs)" |
        ForEach-Object { $_.Split(":") } | ForEach-Object { $_.Trim() }

    $validOUs = @()
    foreach ($path in $ouPaths) {
        try {
            $ou = Get-ADOrganizationalUnit -Identity $path -ErrorAction Stop
            $validOUs += $ou
        }
        catch {
            Write-Host "OU not found or invalid path: $path" -ForegroundColor Yellow
        }
    }

    if ($validOUs.Count -eq 0) {
        Write-Host "No valid OUs found from the provided paths." -ForegroundColor Yellow
        exit
    }

    $users = foreach ($ou in $validOUs) {
        # Include users in the OU and all child OUs
        Get-ADUser -SearchBase $ou.DistinguishedName -SearchScope Subtree -Filter * -Properties * -ErrorAction SilentlyContinue
    }
}
else {
    Write-Host "Invalid choice. Exiting." -ForegroundColor Red
    exit
}

if (-not $users) {
    Write-Host "No users found with the provided input." -ForegroundColor Yellow
    exit
}

# Prepare output path
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = ".\ADUserBackup_$timestamp.csv"

# Export all attributes
$users | ForEach-Object {
    $hash = @{}
    foreach ($prop in $_.psobject.Properties) {
        $hash[$prop.Name] = $prop.Value -join ";"
    }
    New-Object PSObject -Property $hash
} | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8

Write-Host "Backup complete. File saved to $outputFile" -ForegroundColor Green
