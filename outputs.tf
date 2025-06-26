output "users" {
  description = "Map of users."
  value       = local.users_map
}

output "groups" {
  description = "Map of groups."
  value       = local.groups_map
}

output "group_memberships" {
  description = "List of group memberships."
  value       = local.group_memberships
}

output "account_assignments" {
  description = "List of account assignments."
  value       = local.account_assignments
}

output "permission_sets" {
  description = "Map of permission sets."
  value       = local.permission_sets_map
}
