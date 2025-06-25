variable "users" {
  description = "List of SSO users"
  type = list(object({
    user_name   = string
    given_name  = string
    family_name = string
    email       = string
  }))
}

variable "groups" {
  description = "List of SSO groups"
  type = list(object({
    name        = string
    description = string
    members     = list(string)
    assignments = optional(list(object({
      permission_set = string
      account_ids    = list(string)
    })), [])
  }))
}

variable "permission_sets" {
  description = "List of permission sets"
  type = list(object({
    name             = string
    description      = string
    managed_policies = optional(list(string), [])
    session_duration = optional(string, "PT12H")
    inline_policy    = optional(string, null)
    relay_state      = optional(string, null)
    tags             = optional(map(string), {})
    customer_managed_policy_attachments = optional(list(object({
      name = string
      path = optional(string, "/")
    })), [])
  }))
}

variable "instance_arn" {
  description = "SSO instance ARN"
  type        = string
}

variable "identity_store_id" {
  description = "Identity store ID"
  type        = string
}
