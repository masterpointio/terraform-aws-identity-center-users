locals {
  # Convert lists to maps for resource creation
  users_map           = { for user in var.users : user.user_name => user }
  groups_map          = { for group in var.groups : group.name => group }
  permission_sets_map = { for ps in var.permission_sets : ps.name => ps }

  permission_sets_with_inline_policy_map = { for name, ps in local.permission_sets_map : name => ps if lookup(ps, "inline_policy", null) != null }

  # Flatten the group memberships for easier iteration
  group_memberships = flatten([
    for group in var.groups : [
      for member_username in group.members : {
        group_name = group.name
        user_name  = member_username
      }
    ]
  ])

  # Flatten the managed policy attachments for easier iteration
  policy_attachments = flatten([
    for ps in var.permission_sets : [
      for policy_arn in ps.managed_policies : {
        ps_name    = ps.name
        policy_arn = policy_arn
      }
    ]
  ])

  # Flatten the customer managed policy attachments for easier iteration
  customer_policy_attachments = flatten([
    for ps in var.permission_sets : [
      for policy in lookup(ps, "customer_managed_policy_attachments", []) : {
        ps_name     = ps.name
        policy_name = policy.name
        policy_path = lookup(policy, "path", "/")
      }
    ]
  ])

  # Flatten assignments from the structure
  account_assignments = flatten([
    for group in var.groups : [
      for assignment in lookup(group, "assignments", []) : [
        for account_id in assignment.account_ids : {
          group          = group.name
          permission_set = assignment.permission_set
          account_id     = account_id
        }
      ]
    ]
  ])

  # Create maps for resource creation with unique keys to iterate over
  policy_attachments_map = {
    for attachment in local.policy_attachments : "${attachment.ps_name}-${attachment.policy_arn}" => attachment
  }

  customer_policy_attachments_map = {
    for attachment in local.customer_policy_attachments : "${attachment.ps_name}-${attachment.policy_arn}" => attachment
  }

  group_memberships_map = {
    for membership in local.group_memberships : "${membership.group_name}-${membership.user_name}" => membership
  }

  account_assignments_map = {
    for assignment in local.account_assignments : "${assignment.group}-${assignment.permission_set}-${assignment.account_id}" => assignment
  }
}

# Permission Sets
resource "aws_ssoadmin_permission_set" "permissions" {
  for_each         = local.permission_sets_map
  name             = each.value.name
  description      = each.value.description
  instance_arn     = var.instance_arn
  session_duration = each.value.session_duration
  relay_state      = lookup(each.value, "relay_state", null)
  tags             = lookup(each.value, "tags", {})
}

# Inline Policies
resource "aws_ssoadmin_permission_set_inline_policy" "inline_policies" {
  for_each           = local.permission_sets_with_inline_policy_map
  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.permissions[each.key].arn
  inline_policy      = each.value.inline_policy
}

# Managed Policy Attachments
resource "aws_ssoadmin_managed_policy_attachment" "policies" {
  for_each           = local.policy_attachments_map
  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.permissions[each.value.ps_name].arn
  managed_policy_arn = each.value.policy_arn
}

# Customer Managed Policy Attachments
resource "aws_ssoadmin_customer_managed_policy_attachment" "customer_policies" {
  for_each           = local.customer_policy_attachments_map
  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.permissions[each.value.ps_name].arn

  customer_managed_policy_reference {
    name = each.value.policy_name
    path = coalesce(each.value.policy_path, "/")
  }
}

# Identity Store Users
resource "aws_identitystore_user" "users" {
  for_each          = local.users_map
  identity_store_id = var.identity_store_id
  display_name      = "${each.value.given_name} ${each.value.family_name}"
  user_name         = each.value.user_name

  name {
    given_name  = each.value.given_name
    family_name = each.value.family_name
  }

  emails {
    value   = each.value.email
    primary = true
  }
}

# Identity Store Groups
resource "aws_identitystore_group" "groups" {
  for_each          = local.groups_map
  identity_store_id = var.identity_store_id
  display_name      = each.value.name
  description       = each.value.description
}

# Group Memberships
resource "aws_identitystore_group_membership" "memberships" {
  for_each          = local.group_memberships_map
  identity_store_id = var.identity_store_id
  group_id          = aws_identitystore_group.groups[each.value.group_name].group_id
  member_id         = aws_identitystore_user.users[each.value.user_name].user_id
}

# Account Assignments
resource "aws_ssoadmin_account_assignment" "assignments" {
  for_each           = local.account_assignments_map
  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.permissions[each.value.permission_set].arn
  principal_id       = aws_identitystore_group.groups[each.value.group].group_id
  principal_type     = "GROUP"
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"

  # When destroying, there is often a race condition where the account assignments
  # are being attempted to be created/destroyed before the permission sets are fully ready.
  # This is because in the dependency graph, there's no explicit dependency on the additional
  # permission set attachments like the ones below.
  depends_on = [
    aws_ssoadmin_managed_policy_attachment.policies,
    aws_ssoadmin_customer_managed_policy_attachment.customer_policies,
    aws_ssoadmin_permission_set_inline_policy.inline_policies
  ]
}
