variables {
  users = [
    {
      user_name   = "john.doe"
      given_name  = "John"
      family_name = "Doe"
      email       = "john.doe@example.com"
    },
    {
      user_name   = "jane.smith"
      given_name  = "Jane"
      family_name = "Smith"
      email       = "jane.smith@example.com"
    },
    {
      user_name   = "bob.jones"
      given_name  = "Bob"
      family_name = "Jones"
      email       = "bob.jones@example.com"
    }
  ]
  groups = [
    {
      name = "Administrators"
      description = "Admin group"
      members = ["john.doe", "jane.smith"]
      assignments = [
        {
          permission_set = "AdminAccess"
          account_ids = ["123456789012", "234567890123"]
        },
        {
          permission_set = "ReadOnly"
          account_ids = ["345678901234"]
        }
      ]
    },
    {
      name = "Developers"
      description = "Dev group"
      members = ["jane.smith", "bob.jones"]
      assignments = [
        {
          permission_set = "DevAccess"
          account_ids = ["123456789012"]
        }
      ]
    }
  ]
  permission_sets = [
    {
      name = "AdminAccess"
      description = "Full admin access"
      managed_policies = [
        "arn:aws:iam::aws:policy/AdministratorAccess",
        "arn:aws:iam::aws:policy/IAMFullAccess"
      ]
      session_duration = "PT8H"
      inline_policy = null
      relay_state = null
      tags = { Environment = "test" }
      customer_managed_policy_attachments = []
    },
    {
      name = "ReadOnly"
      description = "Read only access"
      managed_policies = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
      session_duration = "PT4H"
      inline_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
      relay_state = "https://example.com"
      tags = {}
      customer_managed_policy_attachments = []
    },
    {
      name = "DevAccess"
      description = "Developer access"
      managed_policies = []
      session_duration = "PT6H"
      inline_policy = null
      relay_state = null
      tags = {}
      customer_managed_policy_attachments = [
        {
          name = "CustomDevPolicy"
          path = "/developers/"
        }
      ]
    }
  ]
  instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
  identity_store_id = "d-1234567890"
}

run "test_users_map_transformation" {
  command = plan

  assert {
    condition = length(local.users_map) == 3
    error_message = "users_map should contain 3 users"
  }

  assert {
    condition = local.users_map["john.doe"].given_name == "John"
    error_message = "john.doe should have given_name John"
  }

  assert {
    condition = local.users_map["jane.smith"].family_name == "Smith"
    error_message = "jane.smith should have family_name Smith"
  }
}

run "test_groups_map_transformation" {
  command = plan

  assert {
    condition = length(local.groups_map) == 2
    error_message = "groups_map should contain 2 groups"
  }

  assert {
    condition = local.groups_map["Administrators"].description == "Admin group"
    error_message = "Administrators group should have correct description"
  }

  assert {
    condition = length(local.groups_map["Developers"].members) == 2
    error_message = "Developers group should have 2 members"
  }
}

run "test_permission_sets_map_transformation" {
  command = plan

  assert {
    condition = length(local.permission_sets_map) == 3
    error_message = "permission_sets_map should contain 3 permission sets"
  }

  assert {
    condition = local.permission_sets_map["AdminAccess"].session_duration == "PT8H"
    error_message = "AdminAccess should have 8 hour session duration"
  }

  assert {
    condition = length(local.permission_sets_with_inline_policy_map) == 1
    error_message = "Only ReadOnly should have inline policy"
  }

  assert {
    condition = local.permission_sets_with_inline_policy_map["ReadOnly"].inline_policy != null
    error_message = "ReadOnly should have non-null inline policy"
  }
}

run "test_group_memberships_flattening" {
  command = plan

  assert {
    condition = length(local.group_memberships) == 4
    error_message = "Should have 4 total group memberships"
  }

  assert {
    condition = length(local.group_memberships_map) == 4
    error_message = "group_memberships_map should have 4 entries"
  }

  # Test specific membership structures
  assert {
    condition = local.group_memberships[0].group_name == "Administrators" && local.group_memberships[0].user_name == "john.doe"
    error_message = "First membership should be Administrators-john.doe"
  }

  assert {
    condition = local.group_memberships[1].group_name == "Administrators" && local.group_memberships[1].user_name == "jane.smith"
    error_message = "Second membership should be Administrators-jane.smith"
  }

  assert {
    condition = local.group_memberships[2].group_name == "Developers" && local.group_memberships[2].user_name == "jane.smith"
    error_message = "Third membership should be Developers-jane.smith"
  }

  assert {
    condition = local.group_memberships[3].group_name == "Developers" && local.group_memberships[3].user_name == "bob.jones"
    error_message = "Fourth membership should be Developers-bob.jones"
  }
}

run "test_policy_attachments_flattening" {
  command = plan

  assert {
    condition = length(local.policy_attachments) == 3
    error_message = "Should have 3 total policy attachments"
  }

  assert {
    condition = length(local.policy_attachments_map) == 3
    error_message = "policy_attachments_map should have 3 entries"
  }

  # Test specific map entries
  assert {
    condition = local.policy_attachments_map["AdminAccess-arn:aws:iam::aws:policy/AdministratorAccess"].ps_name == "AdminAccess"
    error_message = "AdminAccess-AdministratorAccess map entry should have correct ps_name"
  }

  assert {
    condition = local.policy_attachments_map["AdminAccess-arn:aws:iam::aws:policy/AdministratorAccess"].policy_arn == "arn:aws:iam::aws:policy/AdministratorAccess"
    error_message = "AdminAccess-AdministratorAccess map entry should have correct policy_arn"
  }

  assert {
    condition = local.policy_attachments_map["ReadOnly-arn:aws:iam::aws:policy/ReadOnlyAccess"].ps_name == "ReadOnly"
    error_message = "ReadOnly-ReadOnlyAccess map entry should have correct ps_name"
  }

  assert {
    condition = local.policy_attachments_map["ReadOnly-arn:aws:iam::aws:policy/ReadOnlyAccess"].policy_arn == "arn:aws:iam::aws:policy/ReadOnlyAccess"
    error_message = "ReadOnly-ReadOnlyAccess map entry should have correct policy_arn"
  }
}

run "test_customer_policy_attachments_flattening" {
  command = plan

  assert {
    condition = length(local.customer_policy_attachments) == 1
    error_message = "Should have 1 customer policy attachment"
  }

  assert {
    condition = length(local.customer_policy_attachments_map) == 1
    error_message = "customer_policy_attachments_map should have 1 entry"
  }

  # Test specific map entry
  assert {
    condition = local.customer_policy_attachments_map["DevAccess-CustomDevPolicy"].ps_name == "DevAccess"
    error_message = "DevAccess-CustomDevPolicy map entry should have correct ps_name"
  }

  assert {
    condition = local.customer_policy_attachments_map["DevAccess-CustomDevPolicy"].policy_name == "CustomDevPolicy"
    error_message = "DevAccess-CustomDevPolicy map entry should have correct policy_name"
  }

  assert {
    condition = local.customer_policy_attachments_map["DevAccess-CustomDevPolicy"].policy_path == "/developers/"
    error_message = "DevAccess-CustomDevPolicy map entry should have correct policy_path"
  }
}

run "test_account_assignments_flattening" {
  command = plan

  assert {
    condition = length(local.account_assignments) == 4
    error_message = "Should have 4 total account assignments"
  }

  assert {
    condition = length(local.account_assignments_map) == 4
    error_message = "account_assignments_map should have 4 entries"
  }

  # Test specific map entries
  assert {
    condition = local.account_assignments_map["Administrators-AdminAccess-123456789012"].group == "Administrators"
    error_message = "Administrators-AdminAccess-123456789012 map entry should have correct group"
  }

  assert {
    condition = local.account_assignments_map["Administrators-AdminAccess-123456789012"].permission_set == "AdminAccess"
    error_message = "Administrators-AdminAccess-123456789012 map entry should have correct permission_set"
  }

  assert {
    condition = local.account_assignments_map["Administrators-AdminAccess-123456789012"].account_id == "123456789012"
    error_message = "Administrators-AdminAccess-123456789012 map entry should have correct account_id"
  }

  assert {
    condition = local.account_assignments_map["Developers-DevAccess-123456789012"].group == "Developers"
    error_message = "Developers-DevAccess-123456789012 map entry should have correct group"
  }

  assert {
    condition = local.account_assignments_map["Developers-DevAccess-123456789012"].permission_set == "DevAccess"
    error_message = "Developers-DevAccess-123456789012 map entry should have correct permission_set"
  }

  assert {
    condition = local.account_assignments_map["Developers-DevAccess-123456789012"].account_id == "123456789012"
    error_message = "Developers-DevAccess-123456789012 map entry should have correct account_id"
  }
}

run "test_empty_inputs" {
  command = plan

  variables {
    users = []
    groups = []
    permission_sets = []
    instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
    identity_store_id = "d-1234567890"
  }

  assert {
    condition = length(local.users_map) == 0
    error_message = "users_map should be empty"
  }

  assert {
    condition = length(local.groups_map) == 0
    error_message = "groups_map should be empty"
  }

  assert {
    condition = length(local.permission_sets_map) == 0
    error_message = "permission_sets_map should be empty"
  }

  assert {
    condition = length(local.group_memberships) == 0
    error_message = "group_memberships should be empty"
  }

  assert {
    condition = length(local.account_assignments) == 0
    error_message = "account_assignments should be empty"
  }
}
