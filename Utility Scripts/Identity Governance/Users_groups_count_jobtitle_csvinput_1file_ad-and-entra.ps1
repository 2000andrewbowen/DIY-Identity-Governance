<#
.SYNOPSIS
Analyzes AD group assignments for enabled users across multiple job titles
and exports all results into a single Excel workbook.

.DESCRIPTION
Imports a CSV from the user's Downloads folder with a 'JobTitle' column.
For each job title:
  - Finds enabled AD users matching the given Title
  - Collects all group memberships
  - Calculates user counts and group percentages
  - Combines all data into a single Excel workbook with multiple sheets:
      1. Summary (by job title)
      2. Details (user-to-group mapping)
      3. FullyMatchedGroups (100% matched groups)
#>

Import-Module ActiveDirectory
Import-Module ImportExcel

# --- Input and output paths ---
$JobTitleCsvPath = "$HOME\Downloads\JobTitles.csv"
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$ExcelOutputPath = "$HOME\Downloads\RBAC_GroupAnalysis_Titles_$Timestamp.xlsx"

Write-Host "`nLooking for job title list at: $JobTitleCsvPath" -ForegroundColor Cyan

if (-not (Test-Path $JobTitleCsvPath)) {
    Write-Host "CSV file not found at: $JobTitleCsvPath" -ForegroundColor Red
    exit
}

# --- Import job titles from CSV ---
$JobTitles = Import-Csv -Path $JobTitleCsvPath | Select-Object -ExpandProperty JobTitle -Unique

if (-not $JobTitles) {
    Write-Host "No job titles found in the CSV. Ensure the file has a 'JobTitle' column." -ForegroundColor Yellow
    exit
}

Write-Host "`nFound $($JobTitles.Count) job titles to analyze." -ForegroundColor Green

Connect-MgGraph -Scopes "Group.Read.All","User.Read.All"

# --- Initialize result collections ---
$AllSummary = @()
$AllDetails = @()
$FullyMatched = @()

# --- Process each title ---
foreach ($JobTitle in $JobTitles) {
    Write-Host "`n=== Processing Job Title: $JobTitle ===" -ForegroundColor Cyan

    # Pull enabled users by Title
    $Users = Get-ADUser -Filter { Title -eq $JobTitle -and Enabled -eq $true } `
        -Properties MemberOf, SamAccountName, DisplayName, Title, Enabled

    if (-not $Users) {
        Write-Host "No enabled users found for job title '$JobTitle'." -ForegroundColor Yellow
        continue
    }

    $Users = @($Users)
    $TotalUsers = $Users.Count
    Write-Host "Found $TotalUsers enabled users with Title = '$JobTitle'." -ForegroundColor Green

    # ---------------------------
    # Initialize tracking tables
    # ---------------------------
    $GroupCount = @{}
    $GroupMembershipMap = @{}
    $ADGroups = @{}
    $EntraGroups = @{}
    $GroupSource = @{}   # NEW → tracks AD or Entra source

    # --- Gather group data ---
    foreach ($User in $Users) {
        #
        # AD GROUPS
        #
        foreach ($GroupDN in $User.MemberOf) {
            try {
                $Group = Get-ADGroup $GroupDN -ErrorAction Stop
                $GroupName = $Group.Name
                $ADGroups[$GroupName] = $true
                $GroupSource[$GroupName] = "AD"     # mark source
            }
            catch {
                Write-Warning "Could not resolve AD group: $GroupDN"
                continue
            }

            # Count & map the group
            if ($GroupCount.ContainsKey($GroupName)) { $GroupCount[$GroupName]++ }
            else { $GroupCount[$GroupName] = 1 }

            if (-not $GroupMembershipMap.ContainsKey($GroupName)) {
                $GroupMembershipMap[$GroupName] = @()
            }
            $GroupMembershipMap[$GroupName] += $User.SamAccountName
        }

        #
        # ENTRA GROUPS (Microsoft Graph)
        #

        try {
            $Groups = Get-MgUserMemberOf -UserId $User.UserPrincipalName -All -ErrorAction Stop

            $UserEntraGroups = $Groups |
                Where-Object { $_.AdditionalProperties.displayName } |
                Select-Object -ExpandProperty AdditionalProperties |
                ForEach-Object { $_.displayName }
        }
        catch {
            Write-Warning "Could not fetch Entra groups"
        }

        foreach ($EG in $UserEntraGroups) {
            if(!($ADGroups.ContainsKey($EG))){
                $EntraGroups[$EG] = $true
                $GroupSource[$EG] = "Entra"   # mark source

                if ($GroupCount.ContainsKey($EG)) { $GroupCount[$EG]++ }
                else { $GroupCount[$EG] = 1 }

                if (-not $GroupMembershipMap.ContainsKey($EG)) {
                    $GroupMembershipMap[$EG] = @()
                }
                $GroupMembershipMap[$EG] += $User.SamAccountName
            }
            
        }
    }

    # ---------------------------
    # Build SUMMARY output
    # ---------------------------

        $AllSummary += $GroupCount.GetEnumerator() |
            Sort-Object Value -Descending |
            Select-Object `
                @{N='JobTitle';E={$JobTitle}},
                @{N='GroupName';E={$_.Key}},
                @{N='UserCount';E={$_.Value}},
                @{N='TotalCount';E={$TotalUsers}},
                @{N='PercentOfJobTitle';E={[math]::Round(($_.Value / $TotalUsers * 100),2)}},
                @{N='GroupSource';E={$GroupSource[$_.Key]}}
 


    # ---------------------------
    # Build DETAIL output
    # ---------------------------
    $AllDetails += foreach ($Group in $GroupMembershipMap.Keys | Sort-Object) {
        foreach ($User in $GroupMembershipMap[$Group]) {
            [PSCustomObject]@{
                JobTitle        = $JobTitle
                GroupName      = $Group
                GroupSource    = $GroupSource[$Group]
                UserSamAccount = $User
            }
        }
    }
}

# --- Export all to single Excel ---
Write-Host "`nExporting results to $ExcelOutputPath..." -ForegroundColor Cyan

$AllSummary | Export-Excel -Path $ExcelOutputPath -WorksheetName 'Summary' -AutoSize -BoldTopRow
$AllDetails | Export-Excel -Path $ExcelOutputPath -WorksheetName 'Details' -AutoSize -BoldTopRow -Append

Write-Host "`nAll job titles processed successfully!" -ForegroundColor Green
Write-Host "Excel workbook created at: $ExcelOutputPath" -ForegroundColor Cyan
