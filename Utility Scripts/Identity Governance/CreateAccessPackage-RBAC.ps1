# Create new Access Packages from CSV list using default values for RBAC Access Packages
# Created by christianfrohn <https://www.christianfrohn.dk/2025/01/09/create-access-packages-in-entra-id-governance-with-powershell/>
# <CSV Format> Company,Division,OfficeField,RoleName,Location,JobCode,Approver,AutoAssignmentPolicyFilter

$csvFilePathComputer = "$HOME\Downloads\access-packages-to-create.csv"

### 		Constants based on standards approved by IGA Project Team, don't change without approval 		###

# Access package constants
$AccessPackageCatalogId = "" # Sample: "00000000-0000-0000-0000-000000000000"

# Manual Request policy constants
$ManualPolicyName = "Manual Assignment Policy"
$ManualPolicyDescription = "Policy for manual assigment of users for exceptions for"
$ManualMembershipRule = "notSpecified" # "allMemberUsers", "specificAllowedTargets", "allConfiguredConnectedOrganizationUsers", "notSpecified" (admin assignment only)
$ManualPolicyExpirationType = "noExpiration" # "notSpecified", "noExpiration", "afterDateTime", "afterDuration"

# Auto assignment policy constants
$AutoPolicyName = "Auto Assignment Policy"
$AutoPolicyDescription = "Policy for attribute based auto assignment for Role Based Access Control for"
$GracePeriodBeforeAccessRemoval = "P7D"

# Edit constants above, don't edit below this line #
#___________________________________________________________________________________

Import-Module Microsoft.Graph.Identity.Governance

Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All"

Import-Csv -Path $csvFilePathComputer | ForEach-Object {
	$dateTime = Get-Date -Format "MM/dd/yyyy hh:mm tt"

	#Build Name and Description based on standards using CSV inputs
	#Name (Location is optional): 	$Company-$Division-$OfficeField-$RoleName-$Location
	#Description: 					$JobCode; Approved by $Approver; Created on: DATE/TIME; Updated on: DATE/TIME
	$company = $_.Company
	$division = $_.Division
	$officeField = $_.OfficeField
	$roleName = $_.RoleName

	$accessPackageName = "$company-$division-$officeField-$roleName"
	if($_.Location -ne ""){
		$location = $_.Location
		$accessPackageName = $accessPackageName + "-$location"
	}
	$jobCode = $_.JobCode
	$approver = $_.Approver

	$accessPackageDescription = "In Progress; Job Code: $jobCode; Approved by $approver; Created on: $dateTime; Updated on: $dateTime"
	
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
		DisplayName = $AutoPolicyName
		Description = "$AutoPolicyDescription $accessPackageName"
		AllowedTargetScope = "specificDirectoryUsers"
		SpecificAllowedTargets = @(
			@{
				"@odata.type" = "#microsoft.graph.attributeRuleMembers"
				description = "$AutoPolicyDescription $accessPackageName"
				membershipRule = "($autoFilter) -and (user.accountEnabled -eq True)"
			}
		)
		AutomaticRequestSettings = @{
			RequestAccessForAllowedTargets = $true #When set to true, uses membershipRule as auto request query
			RemoveAccessWhenTargetLeavesAllowedTargets = $true
  			gracePeriodBeforeAccessRemoval = $GracePeriodBeforeAccessRemoval
		}
		AccessPackage = @{
			Id = $NewAccessPackage.Id
		}
	}

	New-MgEntitlementManagementAssignmentPolicy -BodyParameter $AutoPolicyParameters
}