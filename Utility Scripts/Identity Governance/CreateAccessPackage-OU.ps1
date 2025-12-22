# Create new Access Packages from CSV list using default values for OU Access Packages
# Created by christianfrohn <https://www.christianfrohn.dk/2025/01/09/create-access-packages-in-entra-id-governance-with-powershell/>
# <CSV Format> Company,Type,Name,FilterOU,AutoAssignmentPolicyFilter

$csvFilePathComputer = "$HOME\Downloads\access-packages-to-create-ou.csv"

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
$AutoPolicyDescription = "Policy for OU based auto assignment for"
$GracePeriodBeforeAccessRemoval = "P7D"

# Edit constants above, don't edit below this line #
#___________________________________________________________________________________

Import-Module Microsoft.Graph.Identity.Governance

Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All"

Import-Csv -Path $csvFilePathComputer | ForEach-Object {
	$dateTime = Get-Date -Format "MM/dd/yyyy hh:mm tt"

	#Build Name and Description based on standards using CSV inputs
	#Name (Location is optional): 	$Company-$Type-$Name
	#Description: 					Created on: DATE/TIME; Updated on: DATE/TIME
	$company = $_.Company
	$type = $_.Type #Region, Branch, Department, OU
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