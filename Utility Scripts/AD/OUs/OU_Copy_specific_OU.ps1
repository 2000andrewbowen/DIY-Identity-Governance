#region 1 - Synopsis
<#
.DESCRIPTION
    Copy structure of a OU in AD
#>

#region 2 - Variables
# Set the source OU you want to start exporting from
$SourceOU = ""

# Output CSV path
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputCsv = "$HOME\Downloads\Exported_OUs_Relative_$timestamp.csv"

#region 3 - Code
# Get all child OUs recursively under the source OU (including the root itself)
$ous = Get-ADOrganizationalUnit -Filter * -SearchBase $SourceOU -SearchScope Subtree

# Prepare export list
$exportList = @()

foreach ($ou in $ous) {
    $dn = $ou.DistinguishedName

    # Strip the base source OU from the full DN to get the relative DN
    if ($dn -eq $SourceOU) {
        $relativeDN = "OU=$($ou.Name)"  # just the name of the root
    } else {
        $relativeDN = $dn -replace [regex]::Escape(",$SourceOU"), ""
    }

    $exportList += [PSCustomObject]@{
        Name         = $ou.Name
        RelativePath = $relativeDN
    }
}

# Sort to ensure parent OUs come first
$exportList = $exportList | Sort-Object { ($_.RelativePath -split ',').Count }

# Save to CSV
$exportList | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8
Write-Host "Export complete: $outputCsv" -ForegroundColor Green