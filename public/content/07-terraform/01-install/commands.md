# Install Terraform — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# macOS via Homebrew
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Linux (Debian/Ubuntu)
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Windows
choco install terraform

# OpenTofu (drop-in replacement)
brew install opentofu
```

## Init / plan / apply

```bash
# Nothing to init at this stage — chapter 02 covers that.
# But verify the binary is executable:
terraform -help
terraform -help plan
```

## State operations

```bash
# No state yet at install stage. Once you start a project:
terraform state list      # comes later in chapter 06
```

## Inspect / verify

```bash
terraform -version
terraform version          # same thing, both forms valid
terraform -help

# tfenv version manager
tfenv list-remote          # show installable versions
tfenv install 1.9.8
tfenv install latest
tfenv use 1.9.8
tfenv list                 # show installed versions

# Pin per-project (drop in repo root)
echo "1.9.8" > .terraform-version

# OpenTofu sanity check
tofu version
```

## Cleanup (destroy)

```bash
# Remove tfenv-managed version
tfenv uninstall 1.9.8

# Uninstall the binary
brew uninstall hashicorp/tap/terraform     # macOS
sudo apt remove terraform                  # Debian/Ubuntu
choco uninstall terraform                  # Windows
```

## One-liners worth memorising

```bash
# Print version, OS, arch in one line
terraform -version | head -1

# Switch TF version on the fly
tfenv use 1.6.6 && terraform -version

# Confirm tfenv is shimming the right binary
which terraform
type terraform

# Compare Terraform vs OpenTofu side-by-side
terraform version; tofu version

# Re-source PATH after install (zsh)
exec zsh -l
```
