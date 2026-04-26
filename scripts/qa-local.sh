#!/usr/bin/env bash
# qa-local.sh — mirror the CI QA workflow locally.
# macOS + Linux compatible (bash 3.2+).

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0
SKIP=0
RESULTS=()

c_red()   { printf "\033[0;31m%s\033[0m" "$*"; }
c_grn()   { printf "\033[0;32m%s\033[0m" "$*"; }
c_ylw()   { printf "\033[0;33m%s\033[0m" "$*"; }
c_bold()  { printf "\033[1m%s\033[0m"   "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

run_check() {
  local name="$1"; shift
  printf "\n%s %s\n" "$(c_bold "==>")" "$(c_bold "$name")"
  if "$@"; then
    PASS=$((PASS+1)); RESULTS+=("PASS  $name")
    printf "    %s\n" "$(c_grn "PASS")"
  else
    FAIL=$((FAIL+1)); RESULTS+=("FAIL  $name")
    printf "    %s\n" "$(c_red "FAIL")"
  fi
}

skip_check() {
  local name="$1" reason="${2:-not installed}"
  SKIP=$((SKIP+1)); RESULTS+=("SKIP  $name ($reason)")
  printf "\n%s %s  %s\n    %s\n" "$(c_bold "==>")" "$(c_bold "$name")" "$(c_ylw "[skipped: $reason]")" "-"
}

# 1. mkdocs --strict
if have mkdocs; then
  run_check "mkdocs build --strict" mkdocs build --strict
else
  skip_check "mkdocs build --strict" "mkdocs not installed (pip install -r requirements.txt)"
fi

# 2. markdownlint
if have markdownlint-cli2; then
  run_check "markdownlint" markdownlint-cli2 "**/*.md" "#node_modules" "#site"
elif have npx; then
  run_check "markdownlint (npx)" npx -y markdownlint-cli2@0.13.0 "**/*.md" "#node_modules" "#site"
else
  skip_check "markdownlint" "markdownlint-cli2/npx not installed"
fi

# 3. lychee
if have lychee; then
  run_check "lychee link check" lychee --no-progress --exclude-mail --accept 200,206,429 './**/*.md'
else
  skip_check "lychee link check" "lychee not installed (brew install lychee)"
fi

# 4. kubeconform
if have kubeconform; then
  manifests=()
  while IFS= read -r f; do manifests+=("$f"); done < <(
    find 03-kubernetes 04-helm 08-projects -type f \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null \
      | grep -Ev '/(templates|charts|crds)/' \
      | grep -Ev '/kustomize/(bases|overlays)/' || true
  )
  if [ "${#manifests[@]}" -eq 0 ]; then
    skip_check "kubeconform" "no manifests found"
  else
    run_check "kubeconform (k8s 1.30)" kubeconform \
      -kubernetes-version 1.30.0 -summary -strict -ignore-missing-schemas \
      "${manifests[@]}"
  fi
else
  skip_check "kubeconform" "kubeconform not installed"
fi

# 5. helm lint
if have helm; then
  charts=()
  while IFS= read -r f; do charts+=("$f"); done < <(
    find . -name Chart.yaml -not -path '*/charts/*' 2>/dev/null || true
  )
  if [ "${#charts[@]}" -eq 0 ]; then
    skip_check "helm lint" "no Chart.yaml files"
  else
    helm_ok=0
    for c in "${charts[@]}"; do
      dir="$(dirname "$c")"
      helm dependency update "$dir" >/dev/null 2>&1 || true
      if ! helm lint "$dir"; then helm_ok=1; fi
    done
    if [ $helm_ok -eq 0 ]; then
      PASS=$((PASS+1)); RESULTS+=("PASS  helm lint")
      printf "    %s\n" "$(c_grn "PASS")"
    else
      FAIL=$((FAIL+1)); RESULTS+=("FAIL  helm lint")
      printf "    %s\n" "$(c_red "FAIL")"
    fi
  fi
else
  skip_check "helm lint" "helm not installed"
fi

# 6. terraform fmt
if have terraform; then
  run_check "terraform fmt -check -recursive" terraform fmt -check -recursive
else
  skip_check "terraform fmt" "terraform not installed"
fi

# Summary
echo
echo "------------------------------------------------------------"
for line in "${RESULTS[@]}"; do
  case "$line" in
    PASS*) printf "  %s  %s\n" "$(c_grn  "[PASS]")" "${line#PASS  }" ;;
    FAIL*) printf "  %s  %s\n" "$(c_red  "[FAIL]")" "${line#FAIL  }" ;;
    SKIP*) printf "  %s  %s\n" "$(c_ylw  "[SKIP]")" "${line#SKIP  }" ;;
  esac
done
echo "------------------------------------------------------------"
printf "%s passed \xc2\xb7 %s failed \xc2\xb7 %s skipped\n" \
  "$(c_grn "$PASS")" "$(c_red "$FAIL")" "$(c_ylw "$SKIP")"

if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
