#region 1 - Synopsis
<#
.DESCRIPTION
    Import OU structure from a copy
#>

#region 2 - Variables
# Path to the exported CSV
$InputCSV = "$HOME\Downloads\OU_Structure_Export_*.csv"

# Base OU to build structure under
$BaseOU = ""

#region 3 - Code
# Load and sort by path depth (shallowest first)
$OUList = Import-Csv -Path (Get-Item $InputCSV).FullName | Sort-Object {
    ($_.RelativePath -split ",").Count
}

foreach ($ou in $OUList) {
    # Build the full DN: just add RelativePath under BaseOU
    $relativeDN = if ($ou.RelativePath) { "$($ou.RelativePath),$BaseOU" } else { $BaseOU }

    # Full DN of the OU to create
    $ouDN = "$relativeDN"

    # Check if OU already exists
    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$ouDN)" -ErrorAction SilentlyContinue)) {
        try {
            # Extract parent path and OU name
            $dnParts = $ouDN -split ","
            $ouName = ($dnParts[0] -replace "^OU=")
            $parentPath = ($dnParts[1..($dnParts.Length - 1)] -join ",")

            # Create OU
            New-ADOrganizationalUnit -Name $ouName -Path $parentPath
            Write-Host "Created: $ouDN"
        } catch {
            Write-Warning "Failed to create $ouDN - $_"
        }
    } else {
        Write-Host "Already exists: $ouDN"
    }
}
