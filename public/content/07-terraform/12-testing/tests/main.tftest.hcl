# Built-in Terraform tests (requires Terraform >= 1.6).
# Run from the directory containing your main.tf:
#   terraform init
#   terraform test
#
# This example assumes the hello-world config from chapter 02 is in the
# same directory. Copy 02-hello-world/main.tf next to this folder, or
# adjust `module` blocks below to point at your code.

variables {
  # Override variable defaults for the test run if needed.
}

# ---------------------------------------------------------------------------
# Test 1 — plan-only: cheap, just check the diff is sane.
# ---------------------------------------------------------------------------
run "plan_creates_two_resources" {
  command = plan

  assert {
    condition     = length(local_file.hello.content) > 0
    error_message = "local_file.hello.content must not be empty"
  }
}

# ---------------------------------------------------------------------------
# Test 2 — apply: actually create resources, assert, then auto-destroy.
# ---------------------------------------------------------------------------
run "apply_writes_file" {
  command = apply

  assert {
    condition     = fileexists(local_file.hello.filename)
    error_message = "hello.txt was not created on disk"
  }

  assert {
    condition     = can(regex("^Hello from [a-z-]+", local_file.hello.content))
    error_message = "file content does not match expected pattern"
  }
}

# ---------------------------------------------------------------------------
# Test 3 — variable validation should reject bad input.
# ---------------------------------------------------------------------------
# Uncomment when you have a variable with validation:
#
# run "rejects_invalid_env" {
#   command = plan
#   variables { env = "production" }   # not in allowed list
#   expect_failures = [var.env]
# }
