# ✂️ 08 — Text Processing

> Logs are text. Configs are text. APIs return text. The Unix toolset turns text into answers in one pipe.

## Why this matters

Half of operations work is "find the lines that say X, extract field Y, count by Z." `grep | awk | sort | uniq -c | sort -rn` is one of the most useful one-liners ever written.

## 🔗 The pipeline mindset

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/01-linux-08-text-processing-README-1-d13c5088.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
    LOG[("access.log")] --> GREP["grep 500"]
    GREP --> AWK["awk print field 7"]
    AWK --> SORT["sort"]
    SORT --> UNIQ["uniq -c"]
    UNIQ --> SORT2["sort -rn"]
    SORT2 --> HEAD["head -10"]
    HEAD --> OUT(["Top 10 URLs<br/>returning 500"])
```

</details>
## Quick reference

=== ":material-lightbulb-outline: Concept"
    Unix text tools (`grep`, `cut`, `sort`, `uniq`, `sed`, `awk`, `jq`) compose through pipes: each one transforms a stream and hands it off. The classic `grep | awk | sort | uniq -c | sort -rn` pipeline answers most "find the lines, count by field" questions in seconds.

=== ":material-file-code-outline: Snippet"
    ```bash
    # Sample nginx access log line
    10.0.0.1 - - [26/Apr/2026:10:00:01 +0000] "GET /api/users HTTP/1.1" 200 1532
    ```

=== ":material-console: Command"
    ```bash
    awk '{print $1}' /tmp/access.log | sort | uniq -c | sort -rn
    awk '$9==500 {print $7}' /tmp/access.log | sort | uniq -c | sort -rn | head -5
    grep -c 'HTTP/2' /tmp/access.log
    echo '{"items":[{"id":2,"name":"b"}]}' | jq -r '.items[].name'
    ```

=== ":material-text-box-outline: Expected output"
    ```text
       3 10.0.0.1
       2 10.0.0.2
       1 10.0.0.3
       3 /api/orders
    b
    ```

## Concepts

- **stdin / stdout / stderr** — fd 0, 1, 2. `2>&1` merges err into out.
- **Pipe `|`** — wires stdout of A into stdin of B.
- **Regex flavors** — basic (BRE), extended (ERE, `grep -E`), Perl (PCRE, `grep -P`).
- **Greedy vs lazy** matching, anchors `^ $`, classes `[:alpha:]`.
- **awk** — field-oriented mini-language. Default field separator = whitespace.
- **sed** — stream editor. Mostly for substitution: `s/old/new/g`.
- **jq** — sed/awk for JSON. Path expressions like `.users[].name`.

## Commands

```bash
# Reading
cat file               # whole file (small only)
less file              # pager (q quit, / search, n next)
head -n 20 file        # first 20 lines
tail -n 50 file        # last 50
tail -f file           # follow appends (logs)

# Searching — grep
grep ERROR app.log
grep -i error app.log              # case-insensitive
grep -v DEBUG app.log              # invert match
grep -c ERROR app.log              # count matches
grep -n ERROR app.log              # line numbers
grep -r 'TODO' src/                # recursive
grep -E 'ERROR|WARN' app.log       # extended regex (alternation)
grep -P '\d{3}-\d{4}' file         # Perl regex
grep -A2 -B1 ERROR app.log         # 2 after, 1 before context
grep -l 'pattern' *.log            # files that match (just names)

# Cutting columns
cut -d: -f1 /etc/passwd            # field 1, : delimiter → usernames
cut -c1-10 file                    # chars 1-10
echo "a,b,c,d" | cut -d, -f2,4     # → b,d

# Sorting & dedup
sort file
sort -n file                       # numeric
sort -r file                       # reverse
sort -k2 -t, file                  # sort by field 2, comma delim
sort -u file                       # unique lines (also: sort | uniq)
uniq -c file                       # count consecutive (pair with sort first)
sort | uniq -c | sort -rn          # frequency table

# sed — substitution
sed 's/foo/bar/' file              # first per line
sed 's/foo/bar/g' file             # all per line
sed -i 's/foo/bar/g' file          # in-place (BSD: sed -i '' on macOS)
sed -n '5,10p' file                # print lines 5-10
sed '/^#/d' file                   # delete comment lines
sed 's/[[:space:]]\+$//' file      # strip trailing whitespace

# awk — field processing
awk '{print $1}' file              # first field
awk -F: '{print $1, $7}' /etc/passwd
awk '$3 > 1000' /etc/passwd        # rows where field 3 > 1000
awk '{sum += $1} END {print sum}'  # sum first column
awk 'NR==1 || /ERROR/' file        # header + errors
awk 'BEGIN{FS=","; OFS="|"} {print $1, $3}' csv

# tr — char translation
tr 'a-z' 'A-Z' < file              # upcase
tr -d '\r' < dos.txt > unix.txt    # strip CRs
tr -s ' ' < file                   # squeeze repeats

# wc — counts
wc -l file                         # lines
wc -w file                         # words
wc -c file                         # bytes

# xargs — turn stdin into args
find . -name '*.tmp' | xargs rm
find . -name '*.tmp' -print0 | xargs -0 rm     # safe with spaces
echo "a b c" | xargs -n1 echo                  # one arg per call

# jq — JSON
echo '{"a":1,"b":[2,3]}' | jq .
jq '.users[] | .name' data.json
jq -r '.items[] | "\(.id),\(.name)"' data.json # raw output, format string
curl -s api/x | jq '. | length'
```

## 🧪 Lab — Parse a real-ish access log

```bash
docker run -it --rm ubuntu:22.04 bash
apt-get update && apt-get install -y jq curl >/dev/null
```

**Step 1.** Generate a sample nginx-style log.

```bash
cat > /tmp/access.log <<'EOF'
10.0.0.1 - - [26/Apr/2026:10:00:01 +0000] "GET /api/users HTTP/1.1" 200 1532
10.0.0.2 - - [26/Apr/2026:10:00:02 +0000] "GET /api/orders HTTP/1.1" 500 0
10.0.0.1 - - [26/Apr/2026:10:00:03 +0000] "POST /api/login HTTP/1.1" 200 87
10.0.0.3 - - [26/Apr/2026:10:00:04 +0000] "GET /api/users HTTP/1.1" 200 1532
10.0.0.2 - - [26/Apr/2026:10:00:05 +0000] "GET /api/orders HTTP/1.1" 500 0
10.0.0.4 - - [26/Apr/2026:10:00:06 +0000] "GET /healthz HTTP/1.1" 200 2
10.0.0.1 - - [26/Apr/2026:10:00:07 +0000] "GET /api/orders HTTP/1.1" 500 0
EOF
```

**Step 2.** Count requests per IP.

```bash
awk '{print $1}' /tmp/access.log | sort | uniq -c | sort -rn
# →   3 10.0.0.1
# →   2 10.0.0.2
# →   1 10.0.0.3
# →   1 10.0.0.4
```

**Step 3.** Top 5 URLs returning 500.

```bash
awk '$9==500 {print $7}' /tmp/access.log | sort | uniq -c | sort -rn | head -5
# →   3 /api/orders
```

**Step 4.** HTTP status code distribution.

```bash
awk '{print $9}' /tmp/access.log | sort | uniq -c | sort -rn
# →   4 200
# →   3 500
```

**Step 5.** Strip dates and emit CSV.

```bash
awk '{
  gsub(/[\[\]"]/, "")
  print $1","$6","$7","$9
}' /tmp/access.log | head -3
# → 10.0.0.1,GET,/api/users,200
# → 10.0.0.2,GET,/api/orders,500
# → 10.0.0.1,POST,/api/login,200
```

**Step 6.** sed in-place edit.

```bash
sed -i 's/HTTP\/1\.1/HTTP\/2/g' /tmp/access.log
grep -c 'HTTP/2' /tmp/access.log    # → 7
```

**Step 7.** Pipe a JSON API through jq.

```bash
echo '{"items":[{"id":1,"name":"a","price":10},{"id":2,"name":"b","price":25}]}' \
  | jq -r '.items[] | select(.price > 15) | "\(.id),\(.name)"'
# → 2,b
```

**Step 8.** Combine — find files containing TODO, list with line numbers.

```bash
mkdir -p /tmp/code && echo "TODO: fix" > /tmp/code/a.py && echo "ok" > /tmp/code/b.py
grep -rn TODO /tmp/code/
# → /tmp/code/a.py:1:TODO: fix
```

## ⚠️ Gotchas

> ⚠️ `cat file | grep x` is the canonical "useless use of cat." Just `grep x file`. (Acceptable when chaining with other transforms.)
>
> ⚠️ `sort | uniq -c` requires the input be sorted first; `uniq` only collapses **consecutive** duplicates.
>
> ⚠️ macOS `sed` requires `-i ''` (empty backup suffix). GNU `sed -i` works without. Scripts need `#!/usr/bin/env bash` + a portable wrapper.
>
> ⚠️ `awk` field indices are 1-based; `$0` is the whole line.
>
> ⚠️ Always pair `find -print0` with `xargs -0` to handle filenames with spaces / newlines safely.
>
> ⚠️ Regex special chars `. * + ? ( ) [ ] { } | ^ $ \\` must be escaped in BRE, but `( ) { } |` are unescaped in ERE (`grep -E`). Inconsistency bites.
>
> ⚠️ `jq` exits non-zero when a filter produces no matches — check exit code before assuming "no data."
>
> ⚠️ Locale affects sort order. `LC_ALL=C sort` is faster and predictable for ASCII data.

## 📖 Further reading

- `man 1 grep` · `man 1 sed` · `man 1 awk` · `man 1 jq` · `man 1 xargs`
- [GNU coreutils manual](https://www.gnu.org/software/coreutils/manual/coreutils.html)
- [GNU awk manual (gawk)](https://www.gnu.org/software/gawk/manual/gawk.html)
- [sed one-liners (canonical)](http://sed.sourceforge.net/sed1line.txt)
- [jq manual](https://stedolan.github.io/jq/manual/)
- [regex101.com](https://regex101.com/) — interactive tester
