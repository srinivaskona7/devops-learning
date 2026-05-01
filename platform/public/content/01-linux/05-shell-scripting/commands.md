# Bash Shell Scripting — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Throwaway shell with vim, tar, shellcheck
docker run -it --rm ubuntu:22.04 bash
apt-get update && apt-get install -y vim tar gzip shellcheck >/dev/null
```

## Core commands

```bash
# Strict-mode boilerplate — paste at top of every script
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
```

```bash
# Variable assignment (NO spaces around =) and immutable var
NAME="alice"
readonly NAME
```

```bash
# Arithmetic — $(( )) for substitution, (( )) for boolean test
i=$(( COUNT + 1 ))
(( i > 3 )) && echo "big"
```

```bash
# Default-if-unset / error-if-unset parameter expansion
echo "${VAR:-default}"
echo "${VAR:?must be set}"
```

```bash
# String ops: uppercase, substring, replace
echo "${NAME^^}"; echo "${NAME:0:2}"; echo "${NAME/a/A}"
```

```bash
# Arrays — define, index, length, iterate
fruits=(apple banana cherry)
echo "${fruits[1]}"; echo "${#fruits[@]}"
for f in "${fruits[@]}"; do echo "$f"; done
```

```bash
# File-test conditional (preferred bash form)
if [[ -f /etc/hosts ]]; then echo "exists"; fi
```

```bash
# Multi-branch with case
case "$1" in
  start) echo "starting" ;;
  stop)  echo "stopping" ;;
  *)     echo "usage: $0 {start|stop}"; exit 1 ;;
esac
```

```bash
# Brace-expansion for loop
for i in {1..5}; do echo "$i"; done
```

```bash
# Read a file line by line (always use -r)
while read -r line; do echo "L: $line"; done < /etc/hosts
```

```bash
# Function with required positional arg
greet() {
  local who="${1:?who?}"
  echo "hello, $who"
}
out=$(greet world)
```

```bash
# Cleanup trap — runs on EXIT or signal
cleanup() { rm -f /tmp/work.$$; }
trap cleanup EXIT INT TERM
```

```bash
# Make a script executable + run it
chmod +x script.sh && ./script.sh
```

```bash
# Lint a script (catches the bugs you'd learn the hard way)
shellcheck script.sh
```

```bash
# Safe temp dir — never use /tmp/myfile.$$
TMP="$(mktemp -d)"
```

## Inspection / verification

```bash
# Exit status of last command (0 = success)
echo $?
```

```bash
# Trace every command as it runs (great for debugging)
bash -x script.sh
```

```bash
# Syntax check without execution
bash -n script.sh
```

```bash
# Confirm trap fired and tmp cleaned up
ls /tmp | grep -E '^tmp\.' || echo "clean"
```

## Cleanup

```bash
# Remove a script and its tmp working dir
rm -f /usr/local/bin/backup.sh
rm -rf "$TMP"
```

## One-liners worth memorising

```bash
# Strict mode in one line
set -euo pipefail; IFS=$'\n\t'
```

```bash
# Timestamped logger to stderr
log() { printf '[%s] %s\n' "$(date +%T)" "$*" >&2; }
```

```bash
# Fail-fast helper
fail() { echo "ERROR: $*" >&2; exit 1; }
```

```bash
# Idempotent mkdir — won't error if exists
mkdir -p /path/to/dir
```

```bash
# Loop over multiple inputs into a function/script
for d in /etc /data; do backup.sh "$d" /backups; done
```

```bash
# Capture both stdout and stderr to a file
./script.sh >out.log 2>&1
```
