# Processes & Signals — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Throwaway shell with ps, killall, htop
docker run -it --rm ubuntu:22.04 bash
apt-get update && apt-get install -y procps psmisc htop >/dev/null
```

## Core commands

```bash
# BSD-style: every process with user + full cmd
ps aux
```

```bash
# SysV-style: every process, full format
ps -ef
```

```bash
# Custom columns sorted by CPU descending
ps -eo pid,ppid,user,stat,pcpu,pmem,cmd --sort=-pcpu | head
```

```bash
# Process tree with PIDs
pstree -p
```

```bash
# Live view — q to quit, P sort by CPU, M by MEM
top
```

```bash
# Nicer interactive viewer; F9 to send a signal
htop
```

```bash
# Polite stop (default SIGTERM = 15)
kill 1234
```

```bash
# Forceful kill — uncatchable, no cleanup
kill -9 1234
```

```bash
# Reload config (typical SIGHUP convention)
kill -HUP 1234
```

```bash
# List every signal name + number
kill -l
```

```bash
# Kill all processes by exact name
killall nginx
```

```bash
# Match against full command line
pkill -f 'python myapp.py'
```

```bash
# Start a command at lower priority (nice 10)
nice -n 10 ./batch.sh
```

```bash
# Re-prioritise a running process (negative needs root)
renice -n 5 -p 1234
```

```bash
# Run in background, returns shell prompt
long_running &
```

```bash
# Show shell jobs
jobs
```

```bash
# Bring job 1 to foreground / resume in background
fg %1
bg %1
```

```bash
# Detach from shell — won't get SIGHUP on logout
disown %1
```

```bash
# Survive logout: immune to hangups, output redirected
nohup ./script.sh >out.log 2>&1 &
```

## Inspection / verification

```bash
# Detailed state: threads, capabilities, memory
cat /proc/1234/status
```

```bash
# Open file descriptors of a PID
ls /proc/1234/fd
```

```bash
# Decode null-separated cmdline into spaces
cat /proc/1234/cmdline | tr '\0' ' '
```

```bash
# Current working dir + executable path of a PID
ls -l /proc/1234/cwd /proc/1234/exe
```

```bash
# Find zombies (state Z) — parent failed to wait()
ps -eo pid,ppid,stat,cmd | awk '$3 ~ /Z/'
```

```bash
# Capture exit status after kill -9 (128 + signal = 137)
wait $PID 2>/dev/null; echo "exit: $?"
```

## Cleanup

```bash
# TERM all jobs in this shell
kill $(jobs -p) 2>/dev/null
```

```bash
# Force-kill a stuck PID as last resort
kill -KILL <PID>
```

## One-liners worth memorising

```bash
# Top 10 CPU hogs right now
ps -eo pid,user,pcpu,pmem,cmd --sort=-pcpu | head -11
```

```bash
# Tree view of all processes with PIDs
pstree -p | less
```

```bash
# Kill the most recent background job by PID
kill $!
```

```bash
# Detached background using setsid (cleaner than nohup+disown)
setsid ./script.sh >out.log 2>&1 < /dev/null &
```

```bash
# Show top threads instead of processes
top -H
```
