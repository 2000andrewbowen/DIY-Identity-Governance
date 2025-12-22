<#
.SYNOPSIS
    Export a complete inventory of all Service Principals in Microsoft Entra ID.

.DESCRIPTION
    Lists all Service Principals (including Enterprise Apps, Managed Identities, Microsoft apps)
    and includes:
      - Type
      - Assignment required?
      - Visible to users?
      - SSO configuration
      - Provisioning (SCIM) status
      - Assigned users/groups
      - Last sign-in date (if available)

.OUTPUTS
    CSV file: $HOME\Downloads\EntraServicePrincipals_Full.csv
#>

# Connect to Graph with required permissions
Connect-MgGraph

# Prepare export path
$exportPath = Join-Path $HOME "Downloads\EntraServicePrincipals_Full.csv"

# Get all service principals
Write-Host "Retrieving all Service Principals..." -ForegroundColor Cyan
$servicePrincipals = Get-MgServicePrincipal -All
$results = @()

foreach ($sp in $servicePrincipals) {
    Write-Host "Processing: $($sp.DisplayName)" -ForegroundColor Cyan

    # --- Core attributes ---
    $spType = if ($sp.ServicePrincipalType) { $sp.ServicePrincipalType } else { "Unknown" }
    $assignmentRequired = $sp.AppRoleAssignmentRequired
    $visibleToUsers = if ($sp.Tags -contains "HideApp") { $false } else { $true }
    $ssoMode = if ($sp.PreferredSingleSignOnMode) { $sp.PreferredSingleSignOnMode } else { "None" }

    # --- Provisioning Check ---
    $provisioning = "Not Configured"
    try {
        $sync = Get-MgServicePrincipalSynchronization -ServicePrincipalId $sp.Id -ErrorAction Stop
        if ($sync) { $provisioning = "Enabled" }
    } catch {}

    # --- Last Sign-in Date ---
    $lastSignIn = $null
    try {
        $signIns = Get-MgAuditLogSignIn -Filter "servicePrincipalId eq '$($sp.Id)'" -Top 1 -Orderby "createdDateTime desc" -ErrorAction SilentlyContinue
        if ($signIns) {
            $lastSignIn = $signIns[0].CreatedDateTime
        }
    } catch {}

    # --- App Assignments ---
    $assignments = @()
    try {
        $assignments = Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $sp.Id -All -ErrorAction SilentlyContinue
    } catch {}

    if ($assignments.Count -eq 0) {
        $results += [pscustomobject]@{
            ApplicationName    = $sp.DisplayName
            ApplicationId      = $sp.AppId
            ServicePrincipalId = $sp.Id
            ServicePrincipalType = $spType
            AssignmentRequired = $assignmentRequired
            VisibleToUsers     = $visibleToUsers
            SSOConfigured      = $ssoMode
            Provisioning       = $provisioning
            LastSignInDate     = $lastSignIn
            PrincipalType      = ""
            PrincipalName      = ""
        }
        continue
    }

    foreach ($a in $assignments) {
        $principalType = $a.PrincipalType
        $principalName = ""

        if ($principalType -eq "User") {
            $user = Get-MgUser -UserId $a.PrincipalId -ErrorAction SilentlyContinue
            $principalName = $user.DisplayName
        }
        elseif ($principalType -eq "Group") {
            $group = Get-MgGroup -GroupId $a.PrincipalId -ErrorAction SilentlyContinue
            $principalName = $group.DisplayName
        }

        $results += [pscustomobject]@{
            ApplicationName    = $sp.DisplayName
            ApplicationId      = $sp.AppId
            ServicePrincipalId = $sp.Id
            ServicePrincipalType = $spType
            AssignmentRequired = $assignmentRequired
            VisibleToUsers     = $visibleToUsers
            SSOConfigured      = $ssoMode
            Provisioning       = $provisioning
            LastSignInDate     = $lastSignIn
            PrincipalType      = $principalType
            PrincipalName      = $principalName
        }
    }
}

# Export results
$results | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8
Write-Host "Export complete: $exportPath" -ForegroundColor Green
