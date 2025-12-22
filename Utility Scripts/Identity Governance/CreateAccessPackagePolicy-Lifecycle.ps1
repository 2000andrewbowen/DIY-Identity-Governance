# Create new Access Packages Policies from CSV list that is used for Lifecycle Workflows; One policy for each Lifecylce Workflow
# Created by christianfrohn <https://www.christianfrohn.dk/2025/01/09/create-access-packages-in-entra-id-governance-with-powershell/>
# <CSV Format> AccessPackageID, LifeCycleWorkflowDisplayName

$csvFilePathComputer = "$HOME\Downloads\access-package-policy-to-create.csv"

### 		Constants based on standards approved by IGA Project Team, don't change without approval 		###


# Manual Request policy constants
$ManualPolicyName = ""
$ManualPolicyDescription = ""
$ManualMembershipRule = "" # "allMemberUsers", "specificAllowedTargets", "allConfiguredConnectedOrganizationUsers", "notSpecified" (admin assignment only)
$ManualPolicyExpirationType = "" # "notSpecified", "noExpiration", "afterDateTime", "afterDuration"

# Edit constants above, don't edit below this line #
#___________________________________________________________________________________

Import-Module Microsoft.Graph.Identity.Governance

Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All"

Import-Csv -Path $csvFilePathComputer | ForEach-Object {

	$AccessPackage = Get-MgEntitlementManagementAccessPackage -AccessPackageId $_.AccessPackageID
	$lifecycleDisplayName = $_.LifeCycleWorkflowDisplayName

	# Creating the manual request policy
	$RequestPolicyNameParameters = @{
		displayName = "$ManualPolicyName [$lifecycleDisplayName]"
		description = "$ManualPolicyDescription $lifecycleDisplayName"
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
			id = $AccessPackage.Id
		}
	}

	New-MgEntitlementManagementAssignmentPolicy -BodyParameter $RequestPolicyNameParameters 
}