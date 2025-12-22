<#
.DESCRIPTION
    Get all OUs and their adminDescription attribute
#>

# Import AD module (if not already loaded)
Import-Module ActiveDirectory

# Get current timestamp for output file
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$outputPath = "$HOME\Downloads\AD_OUs_AdminDescription_$timestamp.csv"

# Get all OUs and select DistinguishedName and adminDescription
$ous = Get-ADOrganizationalUnit -Filter * -Properties adminDescription |
    Select-Object DistinguishedName, @{Name='AdminDescription';Expression={$_.adminDescription}}

# Export results to CSV
$ous | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8

Write-Host "Export complete. File saved to: $outputPath"