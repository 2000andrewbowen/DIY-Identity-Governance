# Create new Access Packages from CSV list using default values for all types of access packages
# Based off of christianfrohn <https://www.christianfrohn.dk/2025/01/09/create-access-packages-in-entra-id-governance-with-powershell/>
# <CSV Format> Type,Company,Division,OfficeField,Name,Location,JobCode,FilterOU,Approver,AutoAssignmentPolicyFilter

$csvFilePathComputer = "$HOME\Downloads\access-packages-to-create.csv"

### 		Constants based on standards approved by IGA Project Team, don't change without approval 		###

# Access package constants
$AccessPackageCatalogId = "" # Sample: "00000000-0000-0000-0000-000000000000"

# Manual Request policy constants
$ManualPolicyName = "Manual Assignment Policy"
$ManualPolicyDescription = "Policy for manual assigment of users for exceptions for"
$ManualMembershipRule = "notSpecified" # "allMemberUsers", "specificAllowedTargets", "allConfiguredConnectedOrganizationUsers", "notSpecified" (admin assignment only)
$ManualPolicyExpirationType = "noExpiration" # "notSpecified", "noExpiration", "afterDateTime", "afterDuration"

# Auto assignment policy constants for RBAC packages
$AutoPolicyNameRBAC = "Auto Assignment Policy"
$AutoPolicyDescriptionRBAC = "Policy for attribute based auto assignment for Role Based Access Control for"
$GracePeriodBeforeAccessRemovalRBAC = "P7D"

# Auto assignment policy constants for OU packages
$AutoPolicyNameOU = "Auto Assignment Policy"
$AutoPolicyDescriptionOU = "Policy for OU based auto assignment for"
$GracePeriodBeforeAccessRemovalOU = "P7D"

# Group standards for Auto Assignment Policy groups
$AutoPolicyGroupNamePrefix = "IGA-AP-"
#               Description: Auto assignment group for $AccessPackageName access package; $AccessPackageID

# Edit constants above, don't edit below this line #
#___________________________________________________________________________________

Import-Module Microsoft.Graph.Identity.Governance

Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All", "Group.ReadWrite.All"

Import-Csv -Path $csvFilePathComputer | ForEach-Object {
    $dateTime = Get-Date -Format "MM-dd-yyyy hh:mm tt"
    $type = $_.Type #BirthRight, Region, Branch, Department, OU, Role-based

    if($type -eq "Role-based"){
        #Build Name and Description based on standards using CSV inputs
        #Name (Location is optional): 	$Company-$Division-$OfficeField-$Name-$Location
        #Description: 					$JobCode; Approved by: $Approver; Created on: DATE/TIME; Updated on: DATE/TIME
        $company = $_.Company
        $division = $_.Division
        $officeField = $_.OfficeField
        $roleName = $_.Name

        $accessPackageName = "$company-$division-$officeField-$roleName"
        if($_.Location -ne ""){
            $location = $_.Location
            $accessPackageName = $accessPackageName + "-$location"
        }
        $jobCode = $_.JobCode
        $approver = $_.Approver

        $accessPackageDescription = "In Progress; Job Code: $jobCode; Approved by: $approver; Created on: $dateTime; Updated on: $dateTime"
        
        # Creating the access package
        $AccessPackageParameters = @{
            displayName = $accessPackageName
            description = $accessPackageDescription
            isHidden = $false
            catalog = @{
                id = $AccessPackageCatalogId
            }
        }
        $_.AccessPackageDisplayName
        New-MgEntitlementManagementAccessPackage -BodyParameter $AccessPackageParameters
        $NewAccessPackage = Get-MgEntitlementManagementAccessPackage -Filter "displayName eq '$accessPackageName'"

        # Creating the default manual request policy
        $RequestPolicyNameParameters = @{
            displayName = $ManualPolicyName
            description = "$ManualPolicyDescription $accessPackageName"
            allowedTargetScope = $ManualMembershipRule
        
            expiration = @{
                type = $ManualPolicyExpirationType
            }
            requestorSettings = @{
                enableTargetsToSelfAddAccess = $true #Enables policy
                enableTargetsToSelfUpdateAccess = $true
                enableTargetsToSelfRemoveAccess = $false
                allowCustomAssignmentSchedule = $true
                enableOnBehalfRequestorsToAddAccess = $false
                enableOnBehalfRequestorsToUpdateAccess = $false
                enableOnBehalfRequestorsToRemoveAccess = $false
                onBehalfRequestors = @(
                )
            }
            requestApprovalSettings = @{
                isApprovalRequiredForAdd = $false
                isApprovalRequiredForUpdate = $false
                stages = @(
                )
            }
            accessPackage = @{
                id = $NewAccessPackage.Id
            }
        }

        New-MgEntitlementManagementAssignmentPolicy -BodyParameter $RequestPolicyNameParameters 

        # Build auto assignment filter, use JobCode if nothing in AutoAssignmentPolicyFilter
        if($_.AutoAssignmentPolicyFilter -ne ""){
            $autoFilter = $_.AutoAssignmentPolicyFilter
        } else {
            $jobCode = $jobCode -replace " ", ""
            $jobCodes = $jobCode -split ','
            $autoFilter = "(user.extensionAttribute8 -eq `""

            $autoFilter = $autoFilter + ($jobCodes -join "`") -or (user.extensionAttribute8 -eq `"")

            $autoFilter = $autoFilter + "`")"
        }
        

        # Creating the auto assignment policy, presence of AutomaticRequestSettings parameter sets policy as Auto
        $AutoPolicyParameters = @{
            DisplayName = $AutoPolicyNameRBAC
            Description = "$AutoPolicyDescriptionRBAC $accessPackageName"
            AllowedTargetScope = "specificDirectoryUsers"
            SpecificAllowedTargets = @(
                @{
                    "@odata.type" = "#microsoft.graph.attributeRuleMembers"
                    description = "$AutoPolicyDescriptionRBAC $accessPackageName"
                    membershipRule = "($autoFilter) -and (user.accountEnabled -eq True)"
                }
            )
            AutomaticRequestSettings = @{
                RequestAccessForAllowedTargets = $true #When set to true, uses membershipRule as auto request query
                RemoveAccessWhenTargetLeavesAllowedTargets = $true
                gracePeriodBeforeAccessRemoval = $GracePeriodBeforeAccessRemovalRBAC
            }
            AccessPackage = @{
                Id = $NewAccessPackage.Id
            }
        }

        New-MgEntitlementManagementAssignmentPolicy -BodyParameter $AutoPolicyParameters
    }else{
        #Build Name and Description based on standards using CSV inputs
        #Name (Location is optional): 	$Company-$Type-$Name
        #Description: 					Created on: DATE/TIME; Updated on: DATE/TIME
        $company = $_.Company
        $name = $_.Name

        $accessPackageName = "$company-$type-$name"

        $ou = $_.FilterOU

        if($type -eq "Region"){
            $accessPackageDescription = "In Progress; Region starting with $ou; Created on: $dateTime; Updated on: $dateTime"
        }elseif ($type -eq "Branch") {
            $accessPackageDescription = "In Progress; Branch starting with $ou; Created on: $dateTime; Updated on: $dateTime"
        }elseif ($type -eq "Department") {
            $accessPackageDescription = "In Progress; Department OU starting with $ou; Created on: $dateTime; Updated on: $dateTime"
        }elseif ($type -eq "OU") {
            $accessPackageDescription = "In Progress; OU(s): $ou; Created on: $dateTime; Updated on: $dateTime"
        }
        
        # Creating the access package
        $AccessPackageParameters = @{
            displayName = $accessPackageName
            description = $accessPackageDescription
            isHidden = $false
            catalog = @{
                id = $AccessPackageCatalogId
            }
        }
        $_.AccessPackageDisplayName
        New-MgEntitlementManagementAccessPackage -BodyParameter $AccessPackageParameters
        $NewAccessPackage = Get-MgEntitlementManagementAccessPackage -Filter "displayName eq '$accessPackageName'"

        # Creating the default manual request policy
        $RequestPolicyNameParameters = @{
            displayName = $ManualPolicyName
            description = "$ManualPolicyDescription $accessPackageName"
            allowedTargetScope = $ManualMembershipRule
        
            expiration = @{
                type = $ManualPolicyExpirationType
            }
            requestorSettings = @{
                enableTargetsToSelfAddAccess = $true #Enables policy
                enableTargetsToSelfUpdateAccess = $true
                enableTargetsToSelfRemoveAccess = $false
                allowCustomAssignmentSchedule = $true
                enableOnBehalfRequestorsToAddAccess = $false
                enableOnBehalfRequestorsToUpdateAccess = $false
                enableOnBehalfRequestorsToRemoveAccess = $false
                onBehalfRequestors = @(
                )
            }
            requestApprovalSettings = @{
                isApprovalRequiredForAdd = $false
                isApprovalRequiredForUpdate = $false
                stages = @(
                )
            }
            accessPackage = @{
                id = $NewAccessPackage.Id
            }
        }

        New-MgEntitlementManagementAssignmentPolicy -BodyParameter $RequestPolicyNameParameters 

        # Build auto assignment filter, use FilterOU if nothing in AutoAssignmentPolicyFilter
        if($_.AutoAssignmentPolicyFilter -ne ""){
            $autoFilter = $_.AutoAssignmentPolicyFilter
        } else {
            if ($type -eq "OU") {
                $ou = $ou -replace " ", ""
                $OUs = $ou -split ','
                $autoFilter = "(user.extensionAttribute1 -eq `""

                $autoFilter = $autoFilter + ($OUs -join "`") -or (user.extensionAttribute1 -eq `"")

                $autoFilter = $autoFilter + "`")"
            }else{
                $autoFilter = "(user.extensionAttribute1 -startsWith `""
                $autoFilter = $autoFilter + $ou
                $autoFilter = $autoFilter + "`")"
            }
        }
        
        # Creating the auto assignment policy, presence of AutomaticRequestSettings parameter sets policy as Auto
        $AutoPolicyParameters = @{
            DisplayName = $AutoPolicyNameOU
            Description = "$AutoPolicyDescriptionOU $accessPackageName"
            AllowedTargetScope = "specificDirectoryUsers"
            SpecificAllowedTargets = @(
                @{
                    "@odata.type" = "#microsoft.graph.attributeRuleMembers"
                    description = "$AutoPolicyDescriptionOU $accessPackageName"
                    membershipRule = "($autoFilter) -and (user.accountEnabled -eq True)"
                }
            )
            AutomaticRequestSettings = @{
                RequestAccessForAllowedTargets = $true #When set to true, uses membershipRule as auto request query
                RemoveAccessWhenTargetLeavesAllowedTargets = $true
                gracePeriodBeforeAccessRemoval = $GracePeriodBeforeAccessRemovalOU
            }
            AccessPackage = @{
                Id = $NewAccessPackage.Id
            }
        }

        New-MgEntitlementManagementAssignmentPolicy -BodyParameter $AutoPolicyParameters
    }
    # Add delay to allow time for auto assignment group to be created
    Start-Sleep -Seconds 15

    # Rename Auto Assignment Policy group
    $newID = $NewAccessPackage.Id
    $newGroupName = $AutoPolicyGroupNamePrefix + $accessPackageName
    $newGroupDescription = "Auto assignment group for $accessPackageName access package; $newID"
    $dynamicGroup = Get-MgGroup -Filter "startswith(displayName,'AutoAssignment_') and groupTypes/any(c:c eq 'DynamicMembership')" | Select-Object -First 1

    if ($dynamicGroup) {
        Update-MgGroup -GroupId $dynamicGroup.Id -BodyParameter @{
            displayName = $newGroupName
            description = $newGroupDescription
        }
    }
}