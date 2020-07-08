data azurerm_subscription primary {}

locals {
  policy_set_name = var.management_group_name == null ? substr("${var.env}-${var.userDefinedString} deny public ip initiative", 0, 64) : "Deploy-Deny-PublicIP-Initiative"
  subscriptionID  = data.azurerm_subscription.primary.subscription_id
  policies_json   = var.deploy ? file("${path.module}/policies/all-PublicIP-Policies.json") : "[]"
  policies = {
    for policy in jsondecode(local.policies_json) :
    policy.Name => {
      name        = policy.Name
      description = try(policy.Properties.description, "")
      policyRule  = policy.Properties.policyRule
    }
  }
  policy_assignment = [
    for policy in jsondecode(local.policies_json) :
    {
      "parameters" : {},
      "policyDefinitionId" : "${var.management_group_name == null ? "/subscriptions/${local.subscriptionID}/providers/Microsoft.Authorization/policyDefinitions/${policy.Name}" : "/providers/Microsoft.Management/managementGroups/${var.management_group_name}/providers/Microsoft.Authorization/policyDefinitions/${policy.Name}"}"
    }
  ]
}

resource "azurerm_policy_definition" "policy_definition" {
  for_each = local.policies
  # No need for count since we handle the the local.policies content at the local file read time
  name                  = each.value.name
  policy_type           = "Custom"
  mode                  = "All"
  display_name          = each.value.name
  description           = each.value.description
  management_group_name = var.management_group_name == null ? null : var.management_group_name
  policy_rule           = jsonencode(each.value.policyRule)
}

resource "azurerm_policy_set_definition" "policy_set_definition" {
  depends_on            = [azurerm_policy_definition.policy_definition]
  count                 = var.deploy ? 1 : 0
  name                  = local.policy_set_name
  policy_type           = "Custom"
  display_name          = local.policy_set_name
  description           = "This initiative deny the deployment of resources with PublicIP."
  management_group_name = var.management_group_name == null ? null : var.management_group_name
  policy_definitions    = jsonencode(local.policy_assignment)
}
