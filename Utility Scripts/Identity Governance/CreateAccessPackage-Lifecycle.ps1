# Create new Access Packages from CSV list that is used for Lifecycle Workflows
# Created by christianfrohn <https://www.christianfrohn.dk/2025/01/09/create-access-packages-in-entra-id-governance-with-powershell/>
# <CSV Format> AccessPackageDisplayName, AccessPackageDescription

$csvFilePathComputer = "$HOME\Downloads\access-packages-to-create.csv"

### 		Constants based on standards approved by IGA Project Team, don't change without approval 		###

# Access package constants
$AccessPackageCatalogId = "" # Sample: "00000000-0000-0000-0000-000000000000"

# Manual Request policy constants
$ManualPolicyName = "Manual Assignment Policy"
$ManualPolicyDescription = "Policy for manual assigment of users for exceptions for"
$ManualMembershipRule = "notSpecified" # "allMemberUsers", "specificAllowedTargets", "allConfiguredConnectedOrganizationUsers", "notSpecified" (admin assignment only)
$ManualPolicyExpirationType = "noExpiration" # "notSpecified", "noExpiration", "afterDateTime", "afterDuration"

# Edit constants above, don't edit below this line #
#___________________________________________________________________________________

Import-Module Microsoft.Graph.Identity.Governance

Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All"

Import-Csv -Path $csvFilePathComputer | ForEach-Object {
	# Creating the access package
	$AccessPackageParameters = @{
		displayName = $_.AccessPackageDisplayName 
		description = $_.AccessPackageDescription
		isHidden = $false
		catalog = @{
			id = $AccessPackageCatalogId
		}
	}
	$accessPackageName = $_.AccessPackageDisplayName
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
}