data "aws_ssoadmin_instances" "sso" {}

locals {
  sso_config = jsondecode(file("./sso-config.json"))

  instance_arn      = tolist(data.aws_ssoadmin_instances.sso.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.sso.identity_store_ids)[0]
}

module "aws_sso" {
  source = "../.."

  users             = local.sso_config.users
  groups            = local.sso_config.groups
  permission_sets   = local.sso_config.permission_sets
  instance_arn      = local.instance_arn
  identity_store_id = local.identity_store_id
}
