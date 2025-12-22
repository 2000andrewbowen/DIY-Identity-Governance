# Created by christianfrohn <https://www.christianfrohn.dk/2024/08/28/start-lifecycle-workflow-in-entra-id-governance-with-powershell/>

# Import module and Connect to Microsoft Graph
Import-Module Microsoft.Graph.Identity.Governance
Connect-MgGraph -Scopes "LifecycleWorkflows.ReadWrite.All"

# Initialize Lifecycle Workflow
$LifeCycleWorkflowID = "" # ID of the Lifecycle Workflow

Import-Csv -Path $csvFilePathComputer | ForEach-Object {

    # Search for the user and retrieve their object ID
    $user = Get-MgUser -Filter "userPrincipalName eq '$_.userPrincipalName'"

    $LifeCycleWorkflowParameters = @{
        subjects = @(
            @{
                id = $User.Id
            }
        )
    }

    Initialize-MgIdentityGovernanceLifecycleWorkflow -WorkflowId $LifeCycleWorkflowID -BodyParameter $LifeCycleWorkflowParameters
}
