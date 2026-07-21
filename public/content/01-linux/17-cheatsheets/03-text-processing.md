# Text Processing — sed / awk / grep / cut / sort / uniq / jq

> Logs aren't data until you shape them. These six tools are your lathe.

```bash
   ┌──────────┬────────────────────────────────────────────────┐
   │  TOOL    │  USE WHEN...                                   │
   ├──────────┼────────────────────────────────────────────────┤
   │  grep    │  match / filter lines                          │
   │  cut     │  carve fixed columns by delimiter or position  │
   │  awk     │  match + extract + compute on columns          │
   │  sed     │  in-line substitute / delete / insert          │
   │  sort    │  order lines (numeric / by key)                │
   │  uniq    │  collapse repeats; -c counts; needs sort first │
   │  jq      │  the awk of JSON                               │
   └──────────┴────────────────────────────────────────────────┘
```

---

## 1. grep — find lines

```bash
grep -i      "error"   file        # case-insensitive
grep -v      "DEBUG"   file        # invert match
grep -n      "TODO"    *.py        # show line numbers
grep -c      "ERROR"   /var/log/*  # count per file
grep -l      "panic"   *           # files-with-matches only
grep -L      "panic"   *           # files-WITHOUT-matches
grep -r      "TODO"    src/        # recursive
grep -E      "ERR(OR)?" file       # extended regex (no need to backslash)
grep -P      '(?<=user=)\w+' file  # PCRE — lookbehind, etc.
grep -A 5 -B 2 "panic" /var/log/syslog   # context: 2 before, 5 after
grep -o      'foo[0-9]+' file      # print only the matching chunk
grep -F      "1.2.3"   file        # fixed string (no regex)
grep --include='*.py' -r "import os" .   # filter by filename
```

**Speed tip:** `LC_ALL=C grep ...` is up to 10x faster on ASCII because it skips Unicode collation.

## 2. cut — fast column carving

```bash
cut -d: -f1     /etc/passwd            # 1st field, : delimited
cut -d: -f1,3,7 /etc/passwd            # multiple fields
cut -d, -f2-    file.csv               # field 2 to end
cut -c1-10      file                   # bytes 1..10 of each line
cut -d$'\t' -f3 tabbed.tsv             # tab delimiter (bash quoting)
```

`cut` cannot handle multi-character or whitespace-collapsed delimiters. Use `awk` for those.

## 3. awk — the swiss army chainsaw

```bash
awk '{print $1, $NF}'  file              # first and last field
awk -F: '$3 >= 1000 {print $1}' /etc/passwd   # human users only
awk '/ERROR/ {n++} END{print n}' /var/log/app.log

# Sum a column
awk '{s+=$3} END{printf "%.2f\n", s}' file

# Group-by-and-count (the awk hammer)
awk '{c[$1]++} END{for(k in c) print c[k], k}' access.log | sort -rn | head

# Top 10 IPs from an nginx log
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head

# Print lines between two patterns
awk '/BEGIN/,/END/' file

# CSV-aware (handles quoted commas if you use --csv in gawk 5.1+)
awk -F, '$2 == "active" {print $1,$3}' users.csv
```

### Useful built-ins

| Var | Meaning |
|-----|---------|
| `$0` | Whole line |
| `$1..$NF` | Fields |
| `NF` | Number of fields on this line |
| `NR` | Line number across all files |
| `FNR` | Line number in current file |
| `FS` / `OFS` | Input / output field separator |
| `RS` / `ORS` | Input / output record separator |

## 4. sed — substitute / delete / insert

```bash
sed 's/foo/bar/'         file       # first match per line
sed 's/foo/bar/g'        file       # all matches
sed -i.bak 's/foo/bar/g' file       # edit in place, keep .bak
sed -E 's/[0-9]+/N/g'    file       # extended regex
sed -n '5,10p'           file       # print lines 5..10 (suppress others)
sed '/^#/d'              file       # delete comment lines
sed '/^$/d'              file       # delete blank lines
sed '/PATTERN/d'         file       # delete matching lines
sed '5a\
new line after 5'        file       # append after line 5
sed 's|/old/path|/new/path|g' file  # use | as delimiter when path has /

# Use & to refer to the whole match
echo "hello" | sed 's/.*/<&>/'      # <hello>

# Use \1, \2 for capture groups (with -E)
sed -E 's/^(.*) (.*)$/\2 \1/' file  # swap two fields
```

**Trap:** `sed -i` syntax differs between GNU and BSD/macOS. GNU: `sed -i 's/a/b/' f`. macOS: `sed -i '' 's/a/b/' f`.

## 5. sort & uniq — count things

```bash
sort           file               # plain ASCII sort
sort -n        file               # numeric
sort -h        file               # human-numeric (10K, 1M, 1G)
sort -r        file               # reverse
sort -u        file               # unique (skip the uniq pipe)
sort -k 3      file               # by 3rd field
sort -t: -k3 -n /etc/passwd       # by UID
sort -k1,1 -k2,2n file            # primary key 1 ASCII, secondary 2 numeric

uniq           file               # collapse adjacent duplicates (sort first!)
uniq -c        file               # prefix with count
uniq -d        file               # only the duplicates
uniq -u        file               # only the non-duplicates
sort file | uniq -c | sort -rn    # the canonical "top N" pipeline
```

## 6. jq — JSON processing

```bash
jq .                       # pretty-print
jq -r .name                # raw output (no quotes)
jq '.items[].name'         # walk an array
jq '.items | length'       # array length
jq '.[] | select(.age>30)' # filter
jq '.[] | {name, age}'     # project fields
jq -s 'add'                # slurp many objects into one array, then sum
jq -c '.[] | {x:.y}'       # compact one-per-line output
jq '.[] | .age // 0'       # default values

# Real example: parse kubectl pod JSON, top by restarts
kubectl get pods -o json | jq -r '.items
   | sort_by(.status.containerStatuses[0].restartCount) | reverse
   | .[0:5] | .[] | "\(.metadata.name)\t\(.status.containerStatuses[0].restartCount)"'

# Convert JSON to CSV (header + rows)
jq -r '(.[0] | keys_unsorted), (.[] | [.[]]) | @csv' data.json
```

## 7. Realistic scenario recipes

### Top URLs by 5xx count from nginx

```bash
awk '$9 ~ /^5/ {print $7}' /var/log/nginx/access.log \
  | sort | uniq -c | sort -rn | head -20
```

### Slowest 20 requests (custom log: `... rt=0.123 ...`)

```bash
grep -oP 'rt=\K[0-9.]+' /var/log/nginx/access.log \
  | sort -rn | head -20
```

### Find the user with most failed SSH attempts

```bash
grep "Failed password" /var/log/auth.log \
  | awk '{for(i=1;i<=NF;i++) if($i=="for") print $(i+1)}' \
  | sort | uniq -c | sort -rn | head
```

### Diff two files but ignore order

```bash
diff <(sort a) <(sort b)
```

### Extract pod images from kubectl

```bash
kubectl get pods -A -o json \
  | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name)\t\(.spec.containers[].image)"'
```

### Convert CSV column to upper case (in place)

```bash
awk -F, 'BEGIN{OFS=","} {$2=toupper($2); print}' data.csv > tmp && mv tmp data.csv
```

---

## ★ If you remember nothing else ★

```bash
1.  sort | uniq -c | sort -rn | head    is the top-N pipeline.  Memorize it.
2.  awk '{print $N}'  beats every cut hack the moment fields aren't fixed.
3.  grep -oP '...\K\S+'   extracts JUST the captured part (no lookahead clutter).
4.  sed -i.bak  saves your career.  ALWAYS keep the .bak.
5.  jq -r  turns "json blob" into "shell-pipeline-friendly text".
```
