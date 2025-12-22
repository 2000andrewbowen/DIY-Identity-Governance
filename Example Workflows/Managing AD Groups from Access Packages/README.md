# Manage AD Groups from Access Packages

Entra Identity Governance can only manage Entra resources. If you can easily migrate a group, there is the option to use Group Writeback. However, for groups you can delete or nest, you will want a way to handle AD groups. To overcome this limitation, we can use custom extensions or other scripts.

Solutions:

- Sync between Entra group and AD group using scheduled script
- Run custom extension using Group-membership change Lifecycle
- Run custom extension when assignment is granted or removed on an access package

## Our Method

We went the route of running a custom extension triggered on the state of the access package assignment. When an user is added to an access package with an AD group, it runs an on-premise runbook through Hybrid worker to add the user to the group(s). Same thing for removal.

To determine what group needs assigned for each access package, we added JSON to the end of the access package description containing the list of groups. The description is set to the logic app when the custom extension triggers, along with the target, requestor and other information. This allows for no additional lookups and everything is managed through the Entra console still.

For a different method check out Christian Frohn, who used a lookup JSON stored in Github ([A Way to Manage On-Prem AD Group Memberships Using Entra ID Governance by Christian Frohn](https://www.christianfrohn.dk/2025/04/23/a-way-to-manage-on-prem-ad-group-memberships-using-entra-id-governance/))

## Requirements

- Automation Account with a Hybrid Worker machine connected to your AD domain (To run Powershell commands against AD)
