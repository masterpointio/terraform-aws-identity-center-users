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
    assignments = list(object({
      permission_set = string
      account_ids    = list(string)
    }))
  }))
}

variable "permission_sets" {
  description = "List of SSO permission sets"
  type = list(object({
    name             = string
    description      = string
    session_duration = string
    managed_policies = list(string)
  }))
}
