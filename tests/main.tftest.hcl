run "test_complete_scenario" {
  command = plan

  variables {
    users = [
      { user_name = "john.cto", given_name = "John", family_name = "Smith", email = "john.smith@enterprise.com" },
      { user_name = "jane.lead", given_name = "Jane", family_name = "Doe", email = "jane.doe@enterprise.com" },
      { user_name = "mike.dev1", given_name = "Mike", family_name = "Johnson", email = "mike.johnson@enterprise.com" },
      { user_name = "sarah.dev2", given_name = "Sarah", family_name = "Wilson", email = "sarah.wilson@enterprise.com" },
      { user_name = "alex.ops", given_name = "Alex", family_name = "Brown", email = "alex.brown@enterprise.com" }
    ]
    groups = [
      {
        name = "C-Suite"
        description = "Executive leadership team"
        members = ["john.cto"]
        assignments = [
          { permission_set = "ExecutiveAccess", account_ids = ["111111111111", "222222222222", "333333333333", "444444444444"] }
        ]
      },
      {
        name = "Engineering-Leads"
        description = "Engineering team leads"
        members = ["jane.lead"]
        assignments = [
          { permission_set = "LeadDeveloperAccess", account_ids = ["222222222222", "333333333333"] },
          { permission_set = "ReadOnlyAccess", account_ids = ["111111111111", "444444444444"] }
        ]
      },
      {
        name = "Developers"
        description = "Software developers"
        members = ["mike.dev1", "sarah.dev2", "jane.lead"]
        assignments = [
          { permission_set = "DeveloperAccess", account_ids = ["333333333333"] },
          { permission_set = "ReadOnlyAccess", account_ids = ["222222222222"] }
        ]
      },
      {
        name = "Operations"
        description = "DevOps and infrastructure team"
        members = ["alex.ops"]
        assignments = [
          { permission_set = "OperationsAccess", account_ids = ["222222222222", "333333333333", "444444444444"] }
        ]
      }
    ]
    permission_sets = [
      {
        name = "ExecutiveAccess"
        description = "Full access for executives"
        managed_policies = ["arn:aws:iam::aws:policy/AdministratorAccess"]
        session_duration = "PT12H"
        tags = { Level = "Executive", Duration = "12h" }
        inline_policy = null
        relay_state = "https://console.aws.amazon.com"
        customer_managed_policy_attachments = []
      },
      {
        name = "LeadDeveloperAccess"
        description = "Lead developer access with team management"
        managed_policies = ["arn:aws:iam::aws:policy/PowerUserAccess"]
        session_duration = "PT10H"
        tags = { Level = "Lead", Duration = "10h" }
        inline_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"iam:ListRoles\",\"iam:PassRole\"],\"Resource\":\"*\"}]}"
        relay_state = null
        customer_managed_policy_attachments = [{ name = "TeamLeadPolicy", path = "/leads/" }]
      },
      {
        name = "DeveloperAccess"
        description = "Standard developer access"
        managed_policies = ["arn:aws:iam::aws:policy/PowerUserAccess"]
        session_duration = "PT8H"
        tags = { Level = "Developer", Duration = "8h" }
        inline_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Deny\",\"Action\":[\"iam:*\",\"organizations:*\"],\"Resource\":\"*\"}]}"
        relay_state = null
        customer_managed_policy_attachments = []
      },
      {
        name = "OperationsAccess"
        description = "DevOps and infrastructure access"
        managed_policies = ["arn:aws:iam::aws:policy/job-function/SystemAdministrator"]
        session_duration = "PT10H"
        tags = { Level = "Operations", Duration = "10h" }
        inline_policy = null
        relay_state = null
        customer_managed_policy_attachments = [
          { name = "InfrastructurePolicy", path = "/ops/" },
          { name = "MonitoringPolicy", path = "/ops/" }
        ]
      },
      {
        name = "ReadOnlyAccess"
        description = "Read-only access for visibility"
        managed_policies = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
        session_duration = "PT4H"
        tags = { Level = "ReadOnly", Duration = "4h" }
        inline_policy = null
        relay_state = null
        customer_managed_policy_attachments = []
      }
    ]
    instance_arn = "arn:aws:sso:::instance/ssoins-enterprise12345"
    identity_store_id = "d-enterprise67890"
  }

  # Validate enterprise-scale numbers
  assert {
    condition = length(aws_identitystore_user.users) == 5
    error_message = "Should create 5 enterprise users"
  }

  assert {
    condition = length(aws_identitystore_group.groups) == 4
    error_message = "Should create 4 enterprise groups"
  }

  assert {
    condition = length(aws_ssoadmin_permission_set.permissions) == 5
    error_message = "Should create 5 permission sets"
  }

  assert {
    condition = length(local.group_memberships) == 6
    error_message = "Should have 6 total group memberships in enterprise scenario"
  }

  assert {
    condition = length(local.account_assignments) == 13
    error_message = "Should have 13 total account assignments in enterprise scenario"
  }

  # Validate complex permission set configurations
  assert {
    condition = length(local.permission_sets_with_inline_policy_map) == 2
    error_message = "Should have 2 permission sets with inline policies (LeadDeveloper and Developer)"
  }

  assert {
    condition = length(local.customer_policy_attachments) == 3
    error_message = "Should have 3 customer managed policy attachments"
  }

  # Validate cross-membership (jane.lead in both Engineering-Leads and Developers)
  assert {
    condition = contains(keys(local.group_memberships_map), "Engineering-Leads-jane.lead")
    error_message = "Jane should be in Engineering-Leads group"
  }

  assert {
    condition = contains(keys(local.group_memberships_map), "Developers-jane.lead")
    error_message = "Jane should be in Developers group"
  }
}

run "test_groups_with_no_assignments" {
  command = plan

  variables {
    users = [
      {
        user_name = "john.doe"
        given_name = "John"
        family_name = "Doe"
        email = "john.doe@example.com"
      }
    ]
    groups = [
      {
        name = "EmptyGroup"
        description = "Group with no assignments"
        members = ["john.doe"]
        assignments = []
      }
    ]
    permission_sets = []
    instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
    identity_store_id = "d-1234567890"
  }

  assert {
    condition = length(local.account_assignments) == 0
    error_message = "Groups with no assignments should not create account assignments"
  }

  assert {
    condition = length(aws_identitystore_group_membership.memberships) == 1
    error_message = "Should still create group membership even without assignments"
  }
}

run "test_groups_with_no_members" {
  command = plan

  variables {
    users = []
    groups = [
      {
        name = "EmptyMembersGroup"
        description = "Group with no members"
        members = []
        assignments = [
          {
            permission_set = "AdminAccess"
            account_ids = ["123456789012"]
          }
        ]
      }
    ]
    permission_sets = [
      {
        name = "AdminAccess"
        description = "Admin access"
        managed_policies = ["arn:aws:iam::aws:policy/AdministratorAccess"]
        session_duration = "PT8H"
        inline_policy = null
        relay_state = null
        tags = {}
        customer_managed_policy_attachments = []
      }
    ]
    instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
    identity_store_id = "d-1234567890"
  }

  assert {
    condition = length(local.group_memberships) == 0
    error_message = "Groups with no members should not create memberships"
  }

  assert {
    condition = length(local.account_assignments) == 1
    error_message = "Should still create account assignments even without members"
  }

  assert {
    condition = length(aws_identitystore_group.groups) == 1
    error_message = "Should create the group even without members"
  }
}

run "test_permission_sets_with_no_policies" {
  command = plan

  variables {
    users = []
    groups = []
    permission_sets = [
      {
        name = "EmptyPermissionSet"
        description = "Permission set with no policies"
        managed_policies = []
        session_duration = "PT12H"
        inline_policy = null
        relay_state = null
        tags = {}
        customer_managed_policy_attachments = []
      }
    ]
    instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
    identity_store_id = "d-1234567890"
  }

  assert {
    condition = length(aws_ssoadmin_permission_set.permissions) == 1
    error_message = "Should create permission set even without policies"
  }

  assert {
    condition = length(local.policy_attachments) == 0
    error_message = "Should not create policy attachments for empty managed_policies"
  }

  assert {
    condition = length(local.customer_policy_attachments) == 0
    error_message = "Should not create customer policy attachments"
  }

  assert {
    condition = length(aws_ssoadmin_permission_set_inline_policy.inline_policies) == 0
    error_message = "Should not create inline policies when null"
  }
}

run "test_multiple_account_assignments_same_group" {
  command = plan

  variables {
    users = []
    groups = [
      {
        name = "MultiAssignmentGroup"
        description = "Group with multiple assignments"
        members = []
        assignments = [
          {
            permission_set = "AdminAccess"
            account_ids = ["123456789012", "234567890123", "345678901234"]
          },
          {
            permission_set = "ReadOnly"
            account_ids = ["123456789012", "456789012345"]
          }
        ]
      }
    ]
    permission_sets = [
      {
        name = "AdminAccess"
        description = "Admin access"
        managed_policies = []
        session_duration = "PT8H"
        inline_policy = null
        relay_state = null
        tags = {}
        customer_managed_policy_attachments = []
      },
      {
        name = "ReadOnly"
        description = "Read only access"
        managed_policies = []
        session_duration = "PT4H"
        inline_policy = null
        relay_state = null
        tags = {}
        customer_managed_policy_attachments = []
      }
    ]
    instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
    identity_store_id = "d-1234567890"
  }

  assert {
    condition = length(local.account_assignments) == 5
    error_message = "Should create 5 account assignments (3 + 2)"
  }

  assert {
    condition = length(local.account_assignments_map) == 5
    error_message = "account_assignments_map should have 5 unique entries"
  }

  assert {
    condition = contains(keys(local.account_assignments_map), "MultiAssignmentGroup-AdminAccess-123456789012")
    error_message = "Should contain AdminAccess assignment for account 123456789012"
  }

  assert {
    condition = contains(keys(local.account_assignments_map), "MultiAssignmentGroup-ReadOnly-123456789012")
    error_message = "Should contain ReadOnly assignment for account 123456789012"
  }
}

run "test_user_in_multiple_groups" {
  command = plan

  variables {
    users = [
      {
        user_name = "multi.user"
        given_name = "Multi"
        family_name = "User"
        email = "multi.user@example.com"
      }
    ]
    groups = [
      {
        name = "Group1"
        description = "First group"
        members = ["multi.user"]
        assignments = []
      },
      {
        name = "Group2"
        description = "Second group"
        members = ["multi.user"]
        assignments = []
      },
      {
        name = "Group3"
        description = "Third group"
        members = ["multi.user"]
        assignments = []
      }
    ]
    permission_sets = []
    instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
    identity_store_id = "d-1234567890"
  }

  assert {
    condition = length(local.group_memberships) == 3
    error_message = "User should have 3 group memberships"
  }

  assert {
    condition = length(aws_identitystore_user.users) == 1
    error_message = "Should only create 1 user"
  }

  assert {
    condition = length(aws_identitystore_group.groups) == 3
    error_message = "Should create 3 groups"
  }

  assert {
    condition = contains(keys(local.group_memberships_map), "Group1-multi.user")
    error_message = "Should have Group1-multi.user membership"
  }

  assert {
    condition = contains(keys(local.group_memberships_map), "Group2-multi.user")
    error_message = "Should have Group2-multi.user membership"
  }

  assert {
    condition = contains(keys(local.group_memberships_map), "Group3-multi.user")
    error_message = "Should have Group3-multi.user membership"
  }
}

run "test_customer_policy_path_handling" {
  command = plan

  variables {
    users = []
    groups = []
    permission_sets = [
      {
        name = "PathTestPermissionSet"
        description = "Testing customer policy paths"
        managed_policies = []
        session_duration = "PT8H"
        inline_policy = null
        relay_state = null
        tags = {}
        customer_managed_policy_attachments = [
          {
            name = "PolicyWithCustomPath"
            path = "/custom/path/"
          },
          {
            name = "PolicyWithDefaultPath"
            path = "/"
          },
          {
            name = "PolicyWithoutPath"
          }
        ]
      }
    ]
    instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
    identity_store_id = "d-1234567890"
  }

  assert {
    condition = length(local.customer_policy_attachments) == 3
    error_message = "Should have 3 customer policy attachments"
  }

  assert {
    condition = local.customer_policy_attachments[0].policy_path == "/custom/path/"
    error_message = "First policy should have custom path"
  }

  assert {
    condition = local.customer_policy_attachments[1].policy_path == "/"
    error_message = "Second policy should have root path"
  }

  assert {
    condition = local.customer_policy_attachments[2].policy_path == "/"
    error_message = "Third policy should default to root path when not specified"
  }
}
