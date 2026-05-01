# Bash & Readline Shortcuts — Cheatsheet

> Your hands should keep up with your brain. If they don't, you're typing too much.

```bash
 +------------------------------------------------------------+
 |  CURSOR        EDIT          HISTORY        PROCESS        |
 |  ------        ----          -------        -------        |
 |  ^A start      ^W del-word   ^R search      ^C interrupt   |
 |  ^E end        ^U del-line   ^P prev        ^Z suspend     |
 |  M-b back-w    ^K kill-eol   ^N next        ^D EOF/exit    |
 |  M-f fwd-w     ^Y yank       !!  prev cmd   ^L clear       |
 |  ^F char       M-d kill-w    !$  last arg   ^S/^Q stop/go  |
 |  ^B back       ^_ undo       ^old^new sub                  |
 +------------------------------------------------------------+
```

(`^X` = Ctrl+X. `M-x` = Meta+X = Alt+X, or Esc then X on macOS.)

---

## 1. Cursor movement (readline)

| Keys | Action | Mnemonic |
|------|--------|----------|
| `Ctrl+A` | Beginning of line | **A**lpha |
| `Ctrl+E` | End of line | **E**nd |
| `Ctrl+F` | Forward one char | **F**orward |
| `Ctrl+B` | Backward one char | **B**ack |
| `Alt+F` | Forward one **word** | Forward-word |
| `Alt+B` | Backward one **word** | Back-word |
| `Ctrl+XX` | Toggle between cursor pos and line start | (rare but useful) |

## 2. Edit / kill-ring

| Keys | Action |
|------|--------|
| `Ctrl+W` | Delete word **before** cursor (whitespace-bounded) |
| `Alt+D`  | Delete word **after** cursor (readline-bounded) |
| `Ctrl+U` | Delete from cursor to **start** of line |
| `Ctrl+K` | Delete from cursor to **end** of line ("kill") |
| `Ctrl+Y` | "Yank" — paste last killed text |
| `Alt+Y`  | Cycle through kill-ring after a yank |
| `Ctrl+T` | Transpose two chars (e.g. fix `teh` → `the`) |
| `Alt+T`  | Transpose two words |
| `Alt+U`  | Uppercase word from cursor |
| `Alt+L`  | Lowercase word from cursor |
| `Alt+C`  | Capitalize word |
| `Ctrl+_` | **Undo** the last edit |

## 3. History

| Keys / token | Action |
|--------------|--------|
| `Ctrl+R` | Reverse-incremental history search. Press again for older match. |
| `Ctrl+S` | Forward search (often blocked by terminal flow control — see Tip 3) |
| `Ctrl+G` | Abort search |
| `Ctrl+P` / `Ctrl+N` | Previous / next history entry |
| `!!` | The entire previous command |
| `!$` | Last **argument** of previous command |
| `!^` | First argument of previous command |
| `!*` | All arguments of previous command |
| `!-2` | Two commands ago |
| `!ssh` | Most recent command starting with `ssh` |
| `!?foo?` | Most recent command containing `foo` |
| `^old^new` | Re-run previous command, substituting `old` → `new` |
| `!!:gs/old/new/` | Same, but **all** occurrences |
| `<Esc> .` or `Alt+.` | Insert last argument of previous command (repeat to walk back) |

### History config worth knowing

```bash
export HISTSIZE=100000           # in-memory entries
export HISTFILESIZE=200000       # on-disk entries
export HISTCONTROL=ignoredups:erasedups
export HISTTIMEFORMAT='%F %T '   # timestamps in `history` output
shopt -s histappend              # don't clobber on multi-shell
```

## 4. Directory stack — `pushd` / `popd`

```bash
pushd /var/log        # cd there, push old cwd onto stack
pushd /etc/nginx      # cd there, push /var/log
dirs -v               # show stack with indices
#  0  /etc/nginx
#  1  /var/log
#  2  ~
popd                  # back to /var/log
pushd +2              # rotate to ~ (index 2)
cd -                  # toggle between $PWD and $OLDPWD (simpler alt)
```

## 5. Brace, tilde, and process expansion

| Pattern | Example | Result |
|---------|---------|--------|
| Brace lists | `cp file.{conf,conf.bak}` | two files |
| Brace ranges | `mkdir part-{01..10}` | 10 dirs |
| Brace nested | `echo {a,b}{1,2}` | a1 a2 b1 b2 |
| Tilde | `~user` | that user's home |
| Tilde-plus | `~+` / `~-` | `$PWD` / `$OLDPWD` |
| Process sub | `diff <(cmd1) <(cmd2)` | compare two outputs |
| Here-string | `grep foo <<<"$var"` | feed string as stdin |

## 6. Quoting rules (the one most people get wrong)

| Quoting | Variable expansion | Command substitution | Globbing |
|---------|:-:|:-:|:-:|
| `'single'` | NO | NO | NO |
| `"double"` | YES | YES | NO |
| `\escape` | depends | depends | NO |
| (none) | YES | YES | YES |

**Rule of thumb:** double-quote every variable unless you have a reason not to. `"$var"` not `$var`.

## 7. Zsh equivalents (mostly identical, plus extras)

| Bash | Zsh extra |
|------|-----------|
| `Ctrl+R` | Same; with `zsh-autosuggestions` plus arrow-right to accept |
| `!!`, `!$` | Work, but you must enable `setopt BANG_HIST` |
| `cd -` | Zsh autocompletes the dir stack with `cd -<TAB>` |
| `**/*.log` | Recursive glob is **native** (bash needs `shopt -s globstar`) |
| `=ls` | Expands to `/bin/ls` (path of command) |
| `^old^new` | Use `r old=new` (`fc` shortcut) |

## 8. Tips that change your life

1. **`Alt+.` is the highest-ROI keystroke in Unix.** Last argument of previous command. Hit it twice → second-to-last command's last arg.
2. **Re-edit a long pipeline:** `fc` opens it in `$EDITOR`, then runs it on save.
3. **`Ctrl+S` freezes the terminal.** If you ever paste-bombed and "the shell froze," hit `Ctrl+Q`. Disable with `stty -ixon`.
4. **`set -o vi`** — readline in vi mode. Press `Esc` then `k` to walk history with vim keys.
5. **`script -t timing.log session.log`** — record an entire shell session with timestamps. Replay with `scriptreplay`.

---

## ★ If you remember nothing else ★

```text
1.  Ctrl+R                — search history. always.
2.  Alt+.                 — last arg of previous command.
3.  Ctrl+A / Ctrl+E       — start / end of line.
4.  Ctrl+W / Ctrl+U / Ctrl+K  — kill word / line-back / line-fwd.
5.  ^old^new              — fix a typo and re-run.
```
