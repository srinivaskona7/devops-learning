# Processes & Signals — Cheatsheet

> A "stuck process" usually isn't stuck. It's blocked, sleeping, zombied, or waiting for something you forgot exists.

```
   ┌──────────────────────────────────────────────────────────────┐
   │  PROCESS STATES   (from /proc/PID/status,  ps -o state)      │
   ├──────────────────────────────────────────────────────────────┤
   │  R   running or runnable (on a CPU or in run queue)          │
   │  S   interruptible sleep (waiting; will wake on signal)      │
   │  D   uninterruptible sleep — usually disk/IO. CANNOT be      │
   │      killed. Long D = something is wrong with storage.       │
   │  T   stopped (Ctrl+Z, SIGSTOP, or under a debugger)          │
   │  t   stopped by debugger (traced)                            │
   │  Z   zombie — exited, parent hasn't reaped exit status       │
   │  X   dead (rare, transient)                                  │
   │  I   idle kernel thread                                      │
   │                                                              │
   │  Modifiers:  <  high prio    N  low prio (niced)             │
   │              s  session ldr  l  multi-threaded  +  fg group  │
   └──────────────────────────────────────────────────────────────┘
```

---

## 1. The signal table (the ones that matter)

| Num | Name | Default | Catchable? | When to use |
|----:|------|---------|:-:|--|
| 1 | `HUP` | term | yes | "Reload config" — most daemons re-read config |
| 2 | `INT` | term | yes | Ctrl+C; "polite stop" |
| 3 | `QUIT` | core | yes | Like INT but dump core (Java: full thread dump) |
| 9 | `KILL` | term | **NO** | Last resort. Cannot be caught, blocked, or ignored. |
| 11 | `SEGV` | core | yes | Segfault — process bug |
| 13 | `PIPE` | term | yes | Wrote to closed pipe (`head` cuts off) |
| 15 | `TERM` | term | yes | Polite "please shut down" — DEFAULT for `kill` |
| 17 | `CHLD` | ignore | yes | Child changed state — parents reap with `wait()` |
| 18 | `CONT` | continue | yes | Resume a stopped process |
| 19 | `STOP` | stop | **NO** | Pause a process (cannot be caught) |
| 20 | `TSTP` | stop | yes | Ctrl+Z |
| 28 | `WINCH` | ignore | yes | Terminal resized — apps redraw |
| 31 | `SYS` | core | yes | Bad syscall (seccomp violation often) |
|    | `USR1`/`USR2` | term | yes | App-defined — many use for log rotate, dump stats |

> **Numbers are not portable.** `SIGRTMIN+N` and offsets vary. Always use names: `kill -HUP`, not `kill -1`.

```bash
kill -l                          # list all signals on this system
kill -l HUP                      # name → number
kill -l 9                        # number → name
```

## 2. Sending signals

```bash
kill PID                         # default = SIGTERM
kill -HUP PID                    # by name
kill -9 PID                      # SIGKILL (after TERM didn't work)

kill -- -PGID                    # send to entire process GROUP (note --)
kill 0                           # to my own process group

killall nginx                    # by exact name
killall -HUP rsyslogd
killall -u alice                 # all of alice's processes
killall -o 1h firefox            # processes OLDER than 1h
killall -y 5m sleep              # processes YOUNGER than 5m
killall -i nginx                 # interactive: ask before each

pkill nginx                      # by name (shorter)
pkill -f 'python myapp.py'       # match against full cmdline (-f)
pkill -u alice                   # by user
pkill -P 1234                    # all CHILDREN of PID 1234
pkill -SIGHUP -f myapp           # signal by name + cmdline match

# Look up before killing
pgrep -a nginx                   # show pid + cmdline
pgrep -fla 'java.*myservice'
```

## 3. The polite-then-firm pattern

```bash
# Send TERM, wait, then KILL if still alive
kill -TERM "$pid"
for i in 1 2 3 4 5; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
done
kill -0 "$pid" 2>/dev/null && kill -KILL "$pid"
```

`kill -0 PID` sends "the null signal" — checks existence + permission **without** delivering anything.

## 4. Why `kill -9` "doesn't work"

| Situation | Why even `KILL` fails to remove the process |
|---|---|
| Process is in **D state** | Blocked in kernel; kernel will deliver on wake. Fix the IO (often NFS / dead disk / stuck driver). |
| Process is a **zombie (Z)** | It's already dead. Need its parent to `wait()`. Kill (or restart) the parent. |
| Process is a **kernel thread** | `[kworker/...]` etc. — `kill` is no-op. Reboot or fix the cause. |
| You don't have **permission** | Need to be root or the EUID owner. |
| Process is in a **frozen cgroup** | `cgroup.freeze` or systemd `Freezer=`. Thaw it first. |

## 5. Process listing — `ps` cheats

```bash
ps -ef                              # SysV style
ps aux                              # BSD style (no dash) — most common
ps auxf                             # ASCII tree
ps -eLf                             # one row per THREAD
ps -eo pid,ppid,user,%cpu,%mem,etime,stat,cmd --sort=-%cpu | head
ps -eo pid,nlwp,cmd                 # nlwp = number of threads
ps -p $PID -o etime,cputime         # wall + cpu time

pstree -p $PID                      # children tree with PIDs
pstree -aps $PID                    # full tree up to init, with args
```

## 6. Jobs, bg, fg, disown, nohup

```bash
long_cmd &                          # start in background (job 1)
jobs                                # list jobs in this shell
fg %1                               # foreground job 1
bg %1                               # resume in background
Ctrl+Z                              # suspend foreground
disown %1                           # detach from shell (won't get HUP on shell exit)
nohup long_cmd >out.log 2>&1 &      # run immune to HUP, output to file
setsid long_cmd </dev/null >out 2>&1 &   # cleaner: new session, no tty

# View jobs across the whole system, grouped by tty / session
ps -eo pid,sess,pgid,tty,cmd | head
```

## 7. Niceness & priorities

```bash
nice -n 10 long_cmd                 # start with niceness 10 (lower priority)
renice -n 5 -p $PID                 # change a running process
renice -n 5 -u alice                # all of alice's processes
ionice -c 3 -p $PID                 # IO class 3 = idle (only when no one needs disk)
chrt -f 50 cmd                      # SCHED_FIFO realtime (DANGEROUS without limits)
chrt -p $PID                        # show current scheduler / prio
```

| Niceness | Meaning |
|----------|---------|
| -20 | Highest priority (root only) |
| 0   | Default |
| +19 | Lowest |

## 8. Limits (per process)

```bash
ulimit -a                           # show all limits for current shell
ulimit -n                           # max open files
ulimit -n 65536                     # raise (subject to hard limit)
ulimit -u                           # max user processes (RLIMIT_NPROC)
ulimit -c unlimited                 # allow core dumps
prlimit --pid $PID                  # show / change limits of running process
prlimit --pid $PID --nofile=65536:65536
cat /proc/$PID/limits               # current effective limits
```

## 9. What is a process actually doing right now?

```bash
ls -l /proc/$PID/exe                # path to the binary
ls -l /proc/$PID/cwd                # working directory
ls -l /proc/$PID/fd                 # open file descriptors (incl. sockets, pipes)
cat /proc/$PID/status               # state, threads, uids, signals masked
cat /proc/$PID/stack                # current kernel stack (debug)
cat /proc/$PID/wchan                # wait channel — what kernel func is it sleeping in?
cat /proc/$PID/cmdline | tr '\0' ' '; echo
cat /proc/$PID/environ | tr '\0' '\n'

strace -p $PID -f                   # live syscall trace
strace -c -p $PID                   # summary table of syscalls
ltrace -p $PID                      # library calls
lsof -p $PID                        # all open files (richer than /proc)
gdb -p $PID                         # full debugger; bt to see backtrace
```

## 10. Find a zombie's parent (the only way to fix it)

```bash
ps -eo pid,ppid,stat,cmd | awk '$3 ~ /Z/'
# then restart the PPID — that's the irresponsible parent
```

## 11. cgroups & systemd-cgls

```bash
systemd-cgls                            # tree of all cgroups & their PIDs
systemd-cgtop                           # live, per-cgroup (= per-service) top
cat /proc/$PID/cgroup                   # which cgroup a process is in
```

---

## ★ If you remember nothing else ★

```
1.  D state ≠ stuck process. It's stuck IO. Fix the disk/network, not the proc.
2.  Z state ≠ alive. Fix the PARENT (kill or restart it).
3.  TERM first, KILL last.  Use kill -0 PID to check before re-sending.
4.  pkill -f 'pattern'    matches FULL cmdline — most precise everyday tool.
5.  /proc/PID/{status,fd,wchan,stack}   tells you what a process is really doing.
```
