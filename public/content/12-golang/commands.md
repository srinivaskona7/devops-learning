# Go DevOps · commands quick-pick

> One-liners ordered by "what do I need when I'm paged at 03:00."

---

## Go toolchain

```bash
# Bootstrap a new module
go mod init github.com/yourorg/yourrepo

# Add all missing imports, remove unused
go mod tidy

# Build for Linux (static binary, no CGO)
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/app ./cmd/app

# Run tests with race detector
go test -race ./...

# Run a single test with verbose output
go test -v -run TestReconciler ./pkg/controller/...

# Vet (catches suspicious constructs before CI does)
go vet ./...

# Format all files
gofmt -w .
# or
goimports -w .

# Check for dependency vulnerabilities
govulncheck ./...

# Build and run in one step (dev only)
go run ./cmd/app/main.go

# Cross-compile ARM64 for Raspberry Pi / ARM K8s node
GOOS=linux GOARCH=arm64 go build -o bin/app-arm64 ./cmd/app
```

---

## Go module management

```bash
# Show module graph
go mod graph | head -20

# Download all deps to local cache
go mod download

# Vendor deps (for air-gapped builds)
go mod vendor

# Upgrade a specific dependency
go get k8s.io/client-go@v0.29.2

# Upgrade all deps to latest patch
go get -u=patch ./...

# Show why a dep is required
go mod why k8s.io/client-go
```

---

## client-go scaffold

```bash
# Install code-generator tools
go install k8s.io/code-generator/cmd/...@latest

# Required go.mod entries for client-go (copy-paste)
cat <<'EOF'
require (
    k8s.io/api                  v0.29.2
    k8s.io/apimachinery         v0.29.2
    k8s.io/client-go            v0.29.2
    sigs.k8s.io/controller-runtime v0.17.2
)
EOF

# List all pods (quick test of cluster access)
go run ./cmd/listpods/main.go

# Apply a manifest using dynamic client
go run ./cmd/apply/main.go --file ./manifests/deployment.yaml
```

---

## kubebuilder commands

```bash
# Install kubebuilder
curl -L -o kubebuilder "https://go.kubebuilder.io/dl/latest/$(go env GOOS)/$(go env GOARCH)"
chmod +x kubebuilder && sudo mv kubebuilder /usr/local/bin/

# Init a new operator project
kubebuilder init --domain mycompany.io --repo github.com/mycompany/my-operator

# Create a new API (CRD + controller scaffolded)
kubebuilder create api --group apps --version v1alpha1 --kind BackupJob

# Generate CRD manifests from Go types
make manifests

# Generate DeepCopy methods
make generate

# Install CRDs into cluster
make install

# Run controller locally (against current kubeconfig context)
make run

# Build and push operator image
make docker-build docker-push IMG=registry.io/mycompany/my-operator:v0.1.0

# Deploy operator to cluster
make deploy IMG=registry.io/mycompany/my-operator:v0.1.0

# Undeploy
make undeploy
```

---

## Docker SDK setup

```bash
# Add Docker SDK to your module
go get github.com/docker/docker/client@latest
go get github.com/docker/docker/api/types@latest

# Required go.mod entries
cat <<'EOF'
require (
    github.com/docker/docker         v25.0.5+incompatible
    github.com/docker/distribution   v2.8.3+incompatible
    github.com/opencontainers/image-spec v1.1.0
)
EOF

# Test Docker socket access
go run ./cmd/listcontainers/main.go

# Build Docker image via SDK
go run ./cmd/buildimage/main.go --dockerfile ./Dockerfile --tag myapp:latest

# Stream container logs
go run ./cmd/streamlogs/main.go --container myapp-container
```

---

## kubectl plugin install via krew

```bash
# Install krew (plugin manager)
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/arm.*$/arm/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Install a custom plugin binary
# Binary must be named kubectl-<name> and placed in PATH
cp bin/kubectl-podrestart ~/.krew/bin/kubectl-podrestart

# Test plugin discovery
kubectl plugin list

# Run custom plugin
kubectl podrestart --namespace production --selector app=api

# Publish to krew index (requires PR to https://github.com/kubernetes-sigs/krew-index)
kubectl krew install krew
```

---

## Common Go patterns (one-liners)

```bash
# Pretty-print any struct as JSON
import "encoding/json"
b, _ := json.MarshalIndent(obj, "", "  "); fmt.Println(string(b))

# Retry with exponential backoff (using k8s wait)
import "k8s.io/apimachinery/pkg/util/wait"
wait.ExponentialBackoff(wait.Backoff{Duration: time.Second, Factor: 2, Steps: 5}, func() (bool, error) { ... })

# Check if a context is cancelled
select {
case <-ctx.Done():
    return ctx.Err()
default:
}

# Merge two maps safely
for k, v := range src { dst[k] = v }

# Parse kubeconfig from default locations
loadingRules := clientcmd.NewDefaultClientConfigLoadingRules()
config, err := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(loadingRules, nil).ClientConfig()

# Create in-cluster config with fallback to kubeconfig
config, err := rest.InClusterConfig()
if err != nil {
    config, err = clientcmd.BuildConfigFromFlags("", filepath.Join(os.Getenv("HOME"), ".kube", "config"))
}
```

---

## go.mod reference — full DevOps operator

```go
module github.com/myorg/devops-operator

go 1.22

require (
    k8s.io/api                          v0.29.2
    k8s.io/apimachinery                 v0.29.2
    k8s.io/client-go                    v0.29.2
    sigs.k8s.io/controller-runtime      v0.17.2
    github.com/docker/docker            v25.0.5+incompatible
    github.com/docker/distribution      v2.8.3+incompatible
    github.com/opencontainers/image-spec v1.1.0
    github.com/spf13/cobra              v1.8.0
    github.com/spf13/viper              v1.18.2
    golang.org/x/time                   v0.5.0
    go.uber.org/zap                     v1.27.0
    github.com/stretchr/testify         v1.9.0
    sigs.k8s.io/envtest                 v0.17.2
)
```
