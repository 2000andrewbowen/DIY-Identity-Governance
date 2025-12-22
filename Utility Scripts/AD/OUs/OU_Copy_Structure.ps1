# EXPORT SCRIPT - Run in PROD domain
Import-Module ActiveDirectory

# Root DN of the prod domain (adjust if needed)
$ProdRootDN = (Get-ADDomain).DistinguishedName

# Output path
$OutputCSV = "$HOME\Downloads\OU_Structure_Export_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

# Get all OUs, sorted for parent-child order
$OUs = Get-ADOrganizationalUnit -Filter * | Sort-Object DistinguishedName

$export = foreach ($ou in $OUs) {
    $relativePath = $ou.DistinguishedName -replace ",?$ProdRootDN$", ""
    [PSCustomObject]@{
        Name         = $ou.Name
        RelativePath = $relativePath
    }
}

$export | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8
Write-Host "OU structure exported to $OutputCSV"