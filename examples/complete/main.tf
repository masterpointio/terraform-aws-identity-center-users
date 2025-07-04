data "aws_ssoadmin_instances" "sso" {}

locals {
  instance_arn      = tolist(data.aws_ssoadmin_instances.sso.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.sso.identity_store_ids)[0]
}

module "aws_sso" {
  source = "../.."

  users             = var.users
  groups            = var.groups
  permission_sets   = var.permission_sets
  instance_arn      = local.instance_arn
  identity_store_id = local.identity_store_id
}
