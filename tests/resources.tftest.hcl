variables {
  users = [
    {
      user_name   = "alice.admin"
      given_name  = "Alice"
      family_name = "Administrator"
      email       = "alice.admin@company.com"
    },
    {
      user_name   = "bob.dev"
      given_name  = "Bob"
      family_name = "Developer"
      email       = "bob.dev@company.com"
    }
  ]
  groups = [
    {
      name = "Administrators"
      description = "Full administrative access group"
      members = ["alice.admin"]
      assignments = [
        {
          permission_set = "AdminAccess"
          account_ids = ["111111111111", "222222222222"]
        }
      ]
    },
    {
      name = "Developers"
      description = "Development team access"
      members = ["bob.dev", "alice.admin"]
      assignments = [
        {
          permission_set = "DevAccess"
          account_ids = ["222222222222"]
        }
      ]
    }
  ]
  permission_sets = [
    {
      name = "AdminAccess"
      description = "Full admin access"
      managed_policies = ["arn:aws:iam::aws:policy/AdministratorAccess"]
      session_duration = "PT8H"
      inline_policy = null
      relay_state = "https://console.aws.amazon.com"
      tags = { Environment = "test", Team = "platform" }
      customer_managed_policy_attachments = []
    },
    {
      name = "DevAccess"
      description = "Developer access"
      managed_policies = ["arn:aws:iam::aws:policy/PowerUserAccess"]
      session_duration = "PT10H"
      inline_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"s3:GetObject\",\"Resource\":\"*\"}]}"
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

run "test_permission_set_resources" {
  command = plan

  assert {
    condition = length(aws_ssoadmin_permission_set.permissions) == 2
    error_message = "Should create 2 permission sets"
  }

  assert {
    condition = aws_ssoadmin_permission_set.permissions["AdminAccess"].name == "AdminAccess"
    error_message = "AdminAccess permission set should have correct name"
  }

  assert {
    condition = aws_ssoadmin_permission_set.permissions["AdminAccess"].session_duration == "PT8H"
    error_message = "AdminAccess should have 8 hour session duration"
  }

  assert {
    condition = aws_ssoadmin_permission_set.permissions["AdminAccess"].relay_state == "https://console.aws.amazon.com"
    error_message = "AdminAccess should have correct relay state"
  }

  assert {
    condition = aws_ssoadmin_permission_set.permissions["AdminAccess"].tags["Environment"] == "test"
    error_message = "AdminAccess should have Environment tag"
  }

  assert {
    condition = length(aws_ssoadmin_permission_set_inline_policy.inline_policies) == 1
    error_message = "Should create 1 inline policy (for DevAccess)"
  }

  assert {
    condition = contains(keys(aws_ssoadmin_permission_set_inline_policy.inline_policies), "DevAccess")
    error_message = "Inline policy should be created for DevAccess permission set"
  }
}

run "test_user_resources" {
  command = plan

  assert {
    condition = length(aws_identitystore_user.users) == 2
    error_message = "Should create 2 users"
  }

  assert {
    condition = aws_identitystore_user.users["alice.admin"].user_name == "alice.admin"
    error_message = "alice.admin user should have correct username"
  }

  assert {
    condition = aws_identitystore_user.users["alice.admin"].display_name == "Alice Administrator"
    error_message = "alice.admin user should have correct display name"
  }

  assert {
    condition = aws_identitystore_user.users["bob.dev"].emails[0].value == "bob.dev@company.com"
    error_message = "bob.dev user should have correct email"
  }

  assert {
    condition = aws_identitystore_user.users["bob.dev"].emails[0].primary == true
    error_message = "User email should be marked as primary"
  }

  assert {
    condition = aws_identitystore_user.users["alice.admin"].name[0].given_name == "Alice"
    error_message = "alice.admin should have correct given name"
  }

  assert {
    condition = aws_identitystore_user.users["alice.admin"].name[0].family_name == "Administrator"
    error_message = "alice.admin should have correct family name"
  }
}

run "test_group_resources" {
  command = plan

  assert {
    condition = length(aws_identitystore_group.groups) == 2
    error_message = "Should create 2 groups"
  }

  assert {
    condition = aws_identitystore_group.groups["Administrators"].display_name == "Administrators"
    error_message = "Administrators group should have correct display name"
  }

  assert {
    condition = aws_identitystore_group.groups["Administrators"].description == "Full administrative access group"
    error_message = "Administrators group should have correct description"
  }

  assert {
    condition = aws_identitystore_group.groups["Developers"].display_name == "Developers"
    error_message = "Developers group should have correct display name"
  }
}

run "test_group_membership_resources" {
  command = plan

  assert {
    condition = length(aws_identitystore_group_membership.memberships) == 3
    error_message = "Should create 3 group memberships"
  }

  # Test specific membership resource configurations (attributes available during plan)
  # Note: group_id and member_id cannot be tested with command=plan because they are computed 
  # attributes only available after AWS resources are created (during apply phase).
  # We validate the relationship logic through the local transformation tests instead.
  assert {
    condition = aws_identitystore_group_membership.memberships["Administrators-alice.admin"].identity_store_id == "d-1234567890"
    error_message = "Administrators-alice.admin membership should have correct identity_store_id"
  }

  assert {
    condition = aws_identitystore_group_membership.memberships["Developers-bob.dev"].identity_store_id == "d-1234567890"
    error_message = "Developers-bob.dev membership should have correct identity_store_id"
  }

  assert {
    condition = aws_identitystore_group_membership.memberships["Developers-alice.admin"].identity_store_id == "d-1234567890"
    error_message = "Developers-alice.admin membership should have correct identity_store_id"
  }

  # Verify all expected membership keys exist
  assert {
    condition = contains(keys(aws_identitystore_group_membership.memberships), "Administrators-alice.admin")
    error_message = "Should have Administrators-alice.admin membership"
  }

  assert {
    condition = contains(keys(aws_identitystore_group_membership.memberships), "Developers-bob.dev")
    error_message = "Should have Developers-bob.dev membership"
  }

  assert {
    condition = contains(keys(aws_identitystore_group_membership.memberships), "Developers-alice.admin")
    error_message = "Should have Developers-alice.admin membership"
  }
}

run "test_managed_policy_attachment_resources" {
  command = plan

  assert {
    condition = length(aws_ssoadmin_managed_policy_attachment.policies) == 2
    error_message = "Should create 2 managed policy attachments"
  }

  # Test specific managed policy attachment configurations
  assert {
    condition = aws_ssoadmin_managed_policy_attachment.policies["AdminAccess-arn:aws:iam::aws:policy/AdministratorAccess"].instance_arn == "arn:aws:sso:::instance/ssoins-1234567890abcdef"
    error_message = "AdminAccess attachment should have correct instance_arn"
  }

  assert {
    condition = aws_ssoadmin_managed_policy_attachment.policies["AdminAccess-arn:aws:iam::aws:policy/AdministratorAccess"].managed_policy_arn == "arn:aws:iam::aws:policy/AdministratorAccess"
    error_message = "AdminAccess attachment should have correct managed_policy_arn"
  }

  assert {
    condition = aws_ssoadmin_managed_policy_attachment.policies["DevAccess-arn:aws:iam::aws:policy/PowerUserAccess"].managed_policy_arn == "arn:aws:iam::aws:policy/PowerUserAccess"
    error_message = "DevAccess attachment should have correct managed_policy_arn"
  }
}

run "test_customer_managed_policy_attachment_resources" {
  command = plan

  assert {
    condition = length(aws_ssoadmin_customer_managed_policy_attachment.customer_policies) == 1
    error_message = "Should create 1 customer managed policy attachment"
  }

  # Test specific customer managed policy attachment configurations
  assert {
    condition = aws_ssoadmin_customer_managed_policy_attachment.customer_policies["DevAccess-CustomDevPolicy"].instance_arn == "arn:aws:sso:::instance/ssoins-1234567890abcdef"
    error_message = "CustomDevPolicy attachment should have correct instance_arn"
  }

  assert {
    condition = aws_ssoadmin_customer_managed_policy_attachment.customer_policies["DevAccess-CustomDevPolicy"].customer_managed_policy_reference[0].name == "CustomDevPolicy"
    error_message = "CustomDevPolicy attachment should have correct policy name"
  }

  assert {
    condition = aws_ssoadmin_customer_managed_policy_attachment.customer_policies["DevAccess-CustomDevPolicy"].customer_managed_policy_reference[0].path == "/developers/"
    error_message = "CustomDevPolicy attachment should have correct policy path"
  }

  assert {
    condition = contains(keys(aws_ssoadmin_customer_managed_policy_attachment.customer_policies), "DevAccess-CustomDevPolicy")
    error_message = "Should have DevAccess-CustomDevPolicy attachment"
  }
}

run "test_account_assignment_resources" {
  command = plan

  assert {
    condition = length(aws_ssoadmin_account_assignment.assignments) == 3
    error_message = "Should create 3 account assignments"
  }

  # Test specific account assignment resource configurations (attributes available during plan)
  assert {
    condition = aws_ssoadmin_account_assignment.assignments["Administrators-AdminAccess-111111111111"].instance_arn == "arn:aws:sso:::instance/ssoins-1234567890abcdef"
    error_message = "Administrators-AdminAccess-111111111111 assignment should have correct instance_arn"
  }

  assert {
    condition = aws_ssoadmin_account_assignment.assignments["Administrators-AdminAccess-111111111111"].principal_type == "GROUP"
    error_message = "Administrators-AdminAccess-111111111111 assignment should have principal_type GROUP"
  }

  assert {
    condition = aws_ssoadmin_account_assignment.assignments["Administrators-AdminAccess-111111111111"].target_id == "111111111111"
    error_message = "Administrators-AdminAccess-111111111111 assignment should have correct target_id"
  }

  assert {
    condition = aws_ssoadmin_account_assignment.assignments["Administrators-AdminAccess-111111111111"].target_type == "AWS_ACCOUNT"
    error_message = "Administrators-AdminAccess-111111111111 assignment should have target_type AWS_ACCOUNT"
  }

  assert {
    condition = aws_ssoadmin_account_assignment.assignments["Administrators-AdminAccess-222222222222"].target_id == "222222222222"
    error_message = "Administrators-AdminAccess-222222222222 assignment should have correct target_id"
  }

  assert {
    condition = aws_ssoadmin_account_assignment.assignments["Developers-DevAccess-222222222222"].target_id == "222222222222"
    error_message = "Developers-DevAccess-222222222222 assignment should have correct target_id"
  }

  assert {
    condition = aws_ssoadmin_account_assignment.assignments["Developers-DevAccess-222222222222"].principal_type == "GROUP"
    error_message = "Developers-DevAccess-222222222222 assignment should have principal_type GROUP"
  }
}
