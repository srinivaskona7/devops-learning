# Text Processing — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Throwaway shell with jq + curl
docker run -it --rm ubuntu:22.04 bash
apt-get update && apt-get install -y jq curl >/dev/null
```

## Core commands

```bash
# Read whole file (small only) / pager / first / last N lines
cat file
less file
head -n 20 file
tail -n 50 file
```

```bash
# Follow log appends (use -F for rotating logs)
tail -f file
```

```bash
# Case-insensitive grep
grep -i error app.log
```

```bash
# Invert match — lines that do NOT contain DEBUG
grep -v DEBUG app.log
```

```bash
# Count + line numbers
grep -c ERROR app.log
grep -n ERROR app.log
```

```bash
# Recursive search across a tree
grep -r 'TODO' src/
```

```bash
# Extended regex with alternation
grep -E 'ERROR|WARN' app.log
```

```bash
# Perl regex (lookarounds, \d, etc.)
grep -P '\d{3}-\d{4}' file
```

```bash
# 2 lines after, 1 line before context
grep -A2 -B1 ERROR app.log
```

```bash
# Cut field 1 with : delimiter (e.g. usernames from /etc/passwd)
cut -d: -f1 /etc/passwd
```

```bash
# Sort numerically / reverse / by field
sort -n file
sort -r file
sort -k2 -t, file
```

```bash
# Frequency table (the canonical pipeline)
sort | uniq -c | sort -rn
```

```bash
# sed substitution — first per line vs all per line
sed 's/foo/bar/'  file
sed 's/foo/bar/g' file
```

```bash
# In-place edit (GNU); macOS needs: sed -i ''
sed -i 's/foo/bar/g' file
```

```bash
# Print a line range / delete comment lines
sed -n '5,10p' file
sed '/^#/d' file
```

```bash
# awk — print field, filter rows, sum a column
awk '{print $1}' file
awk '$3 > 1000' /etc/passwd
awk '{sum += $1} END {print sum}' file
```

```bash
# awk with custom in/out separators
awk 'BEGIN{FS=","; OFS="|"} {print $1, $3}' csv
```

```bash
# tr — translate / delete / squeeze characters
tr 'a-z' 'A-Z' < file
tr -d '\r' < dos.txt > unix.txt
tr -s ' ' < file
```

```bash
# wc — line / word / byte counts
wc -l file
```

```bash
# xargs — turn stdin into args (use -0 with -print0 for safety)
find . -name '*.tmp' -print0 | xargs -0 rm
```

```bash
# jq — parse + filter JSON, raw string output
jq '.users[] | .name' data.json
jq -r '.items[] | "\(.id),\(.name)"' data.json
```

## Inspection / verification

```bash
# How many matches did jq produce
jq '.items | length' data.json
```

```bash
# Recursive grep with file:line:match output
grep -rn TODO /tmp/code/
```

```bash
# List only files that contain a pattern
grep -l 'pattern' *.log
```

```bash
# Verify substitution succeeded
grep -c 'HTTP/2' /tmp/access.log
```

## Cleanup

```bash
# Strip trailing whitespace from a file in place
sed -i 's/[[:space:]]\+$//' file
```

```bash
# Convert DOS line endings to Unix
tr -d '\r' < dos.txt > unix.txt && mv unix.txt dos.txt
```

## One-liners worth memorising

```bash
# Top 10 IPs hitting an access log
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head
```

```bash
# Top URLs returning HTTP 500
awk '$9==500 {print $7}' access.log | sort | uniq -c | sort -rn | head
```

```bash
# HTTP status code distribution
awk '{print $9}' access.log | sort | uniq -c | sort -rn
```

```bash
# Faster, ASCII-deterministic sorting
LC_ALL=C sort bigfile | uniq -c | sort -rn
```

```bash
# Filter JSON array by field then format each row
jq -r '.items[] | select(.price > 15) | "\(.id),\(.name)"' data.json
```

```bash
# Recursive find + delete safely (handles spaces)
find . -name '*.tmp' -print0 | xargs -0 rm
```
