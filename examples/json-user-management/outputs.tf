output "users" {
  value = module.aws_sso.users
}

output "groups" {
  value = module.aws_sso.groups
}

output "group_memberships" {
  value = module.aws_sso.group_memberships
}

output "account_assignments" {
  value = module.aws_sso.account_assignments
}

output "permission_sets" {
  value = module.aws_sso.permission_sets
}
