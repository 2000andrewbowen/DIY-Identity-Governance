# Create an Entitlement Management Assignment Policy with approval settings for an Access Package
# Created by christianfrohn <https://www.christianfrohn.dk/2025/01/09/create-access-packages-in-entra-id-governance-with-powershell/>
# Reference:  <https://learn.microsoft.com/en-us/graph/api/resources/accesspackage?view=graph-rest-1.0/>

Import-Module Microsoft.Graph.Identity.Governance

Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All"

# Access package parameters
$AccessPackageDisplayName = "" # Sample: "Department X"
$AccessPackageDescription = "" # Sample: "Department X Access Package"
$AccessPackageCatalogId = "" # Sample: "00000000-0000-0000-0000-000000000000"

# Request policy parameters
$RequestPolicyName = "" # Sample: "Request policy"
$PolicyDescription = "" # Sample: "Request policy for Department X"
$membershipRule = "" # "allMemberUsers", "specificAllowedTargets", "allConfiguredConnectedOrganizationUsers", "notSpecified"
$Approver = "" # Object ID of the group in Entra ID

# Auto assignment policy parameters
$AutoPolicyName = "" # Sample: "Auto policy"
$AutoPolicyDescription = "" # Sample: "Auto policy for department X"
$AutoAssignmentPolicyFilter = '' # Sample: '(user.department -eq "Department X")' 

# Creating the access package

$AccessPackageParameters = @{
	displayName = $AccessPackageDisplayName 
	description = $AccessPackageDescription
	isHidden = $false
	catalog = @{
		id = $AccessPackageCatalogId
	}
}

New-MgEntitlementManagementAccessPackage -BodyParameter $AccessPackageParameters
$NewAccessPackage = Get-MgEntitlementManagementAccessPackage -Filter "displayName eq '$AccessPackageDisplayName'"

# Creating the default manual request policy

$RequestPolicyNameParameters = @{
	displayName = $RequestPolicyName
	description = $PolicyDescription
    allowedTargetScope = $membershipRule
 
    expiration = @{
        type = "noExpiration"
    }
    requestorSettings = @{
        enableTargetsToSelfAddAccess = $true
        enableTargetsToSelfUpdateAccess = $false
        enableTargetsToSelfRemoveAccess = $true
        allowCustomAssignmentSchedule = $false
        enableOnBehalfRequestorsToAddAccess = $false
        enableOnBehalfRequestorsToUpdateAccess = $false
        enableOnBehalfRequestorsToRemoveAccess = $false
        onBehalfRequestors = @(
        )
    }
	requestApprovalSettings = @{
		isApprovalRequiredForAdd = "false"
		isApprovalRequiredForUpdate = "false"
		stages = @(
		)
    }
    accessPackage = @{
        id = $NewAccessPackage.Id
    }
}

New-MgEntitlementManagementAssignmentPolicy -BodyParameter $RequestPolicyNameParameters 

# Creating the auto assignment policy, presence of AutomaticRequestSettings parameter sets policy as Auto

$AutoPolicyParameters = @{
	DisplayName = $AutoPolicyName
	Description = $AutoPolicyDescription
	AllowedTargetScope = "specificDirectoryUsers"
	SpecificAllowedTargets = @(
		@{
			"@odata.type" = "#microsoft.graph.attributeRuleMembers"
			description = $PolicyDescription
			membershipRule = $AutoAssignmentPolicyFilter
		}
	)
	AutomaticRequestSettings = @{
		RequestAccessForAllowedTargets = $true #When set to true, uses membershipRule as auto request query
		RemoveAccessWhenTargetLeavesAllowedTargets = $true
  		gracePeriodBeforeAccessRemoval = "P7D"
	}
	AccessPackage = @{
		Id = $NewAccessPackage.Id
	}
}

New-MgEntitlementManagementAssignmentPolicy -BodyParameter $AutoPolicyParameters