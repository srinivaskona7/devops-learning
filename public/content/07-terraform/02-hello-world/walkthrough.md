# Walkthrough: hello-world `main.tf`

## Block 1 — `terraform { ... }`
Top-level settings for the **configuration itself** (not for any resource):
- `required_version` — pins the minimum Terraform CLI version.
- `required_providers` — declares which providers (and which versions) this config uses. Terraform downloads these during `init`.

Pinning prevents "works on my machine" — your team gets the exact same plugin versions.

## Block 2 — `resource "random_pet" "name" { ... }`
- `random_pet` — the **resource type** (defined by the `random` provider).
- `name` — your **local label** for this resource. Used to reference it elsewhere as `random_pet.name`.
- `length`, `separator` — arguments specific to this resource type.

Every resource has a unique `id`. For `random_pet`, the `id` is the generated name.

## Block 3 — `resource "local_file" "hello" { ... }`
- Interpolation: `${random_pet.name.id}` reads the output of the previous resource. Terraform uses these references to build a **dependency graph** — `local_file` will always be created *after* `random_pet`.

## Block 4 — `output { ... }`
Outputs surface values to the CLI and to other configs (when used as a module). Run `terraform output` to view them after apply.

## Lifecycle on each command
| Command | Effect |
|---|---|
| `init` | Downloads `hashicorp/random` and `hashicorp/local` plugins into `.terraform/`, writes `.terraform.lock.hcl`. |
| `plan` | Builds DAG, computes diff. First run: `2 to add, 0 to change, 0 to destroy`. |
| `apply` | Executes the plan. `random_pet` first → its output flows into `local_file`. State written. |
| `apply` (again, no changes) | `0 to add` — Terraform is idempotent. |
| Edit `length = 3`, `apply` | `random_pet` is **replaced** (regenerates name) → `local_file` updates with new content. |
| `destroy` | Deletes `hello.txt`, removes both resources from state. |

## Try this
1. Change `length = 2` to `length = 4`. Run `plan` — note the `~` (in-place) vs `-/+` (replace) markers.
2. Add a second `local_file` resource that writes the name in uppercase: `content = upper(random_pet.name.id)`.
3. Run `terraform graph | dot -Tsvg > graph.svg` to visualize the dependency graph.
