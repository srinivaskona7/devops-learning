# Senior / Staff Linux Interview Bank

> Junior interviews test commands. Senior interviews test **judgment**.

This bank is built for engineers with **15-20 years of Linux/SRE experience** preparing for staff-level (or principal/IC4-IC6 equivalent) loops at companies that take infra seriously: Big Tech, hyperscalers, banks/exchanges, hot startups, and SRE/Platform teams.

---

## How senior interviews differ from junior ones

| Junior loop | Senior loop |
|---|---|
| "What does `chmod 644` mean?" | "Walk me through the kernel path of `open(2)` until the inode is in cache." |
| "How do you check disk usage?" | "Disk is full but `du` says it isn't. What's happening?" |
| "How does `ssh` work?" | "Design a multi-tenant SSH access plane for 100k engineers. What goes wrong at scale?" |
| One right answer | Multiple defensible answers — they want to hear the **tradeoffs** you considered |
| "Did you fix it?" | "Why did this happen? What's the systemic fix? What did you change in the org?" |

### What the panel actually tests for

1. **Depth** — can you explain things three layers below the abstraction you normally work at?
2. **Tradeoff fluency** — every solution has a cost. Naming the cost out loud is the differentiator.
3. **War stories** — "when have you actually done this in production?" Stories trump theory.
4. **System thinking** — does the candidate think about cardinality, blast radius, failure modes, day-2 ops?
5. **Influence & calm** — how do you behave when something is on fire and 8 people are in a Zoom?

---

## Files in this bank

| File | Question type | Count |
|------|---------------|-------|
| [system-design-linux.md](system-design-linux.md) | Open-ended system design at OS / infra level | 10 |
| [deep-troubleshooting.md](deep-troubleshooting.md) | "We see X but Y" diagnosis scenarios | 30 |
| [internals-deep.md](internals-deep.md) | Kernel & userspace internals "why" questions | 40 |
| [behavioral-staff.md](behavioral-staff.md) | STAR-format scenarios for staff/principal | 12 |

**Total: 92 questions.**

---

## How to prepare

### 4-week plan

**Week 1 — Internals refresh**
- Work through every Q in `internals-deep.md`. Write your answer in plain English **before** reading the model.
- For each question you can't answer cleanly, find the kernel doc / LWN article / book chapter, read it, then re-write your answer.

**Week 2 — Troubleshooting reps**
- Pick 2 scenarios per day from `deep-troubleshooting.md`. Time-box to 15 min per scenario.
- For each, write your **diagnosis tree** (what would I run, in order, and what would each result mean?).
- Bonus: try to recreate the symptom in a VM. Building muscle memory beats reading.

**Week 3 — System design**
- Work the 10 designs from `system-design-linux.md`. Each one should take ~45 min on a whiteboard or text doc.
- Use the 6-section structure (see `system-design-linux.md` README at top): scope → constraints → high-level → deep-dive → failure modes → day-2 ops.
- Practice **out loud** — talking through a design is a skill.

**Week 4 — Behavioral**
- Pick 6 of the 12 STAR scenarios from `behavioral-staff.md` that map to your real career.
- Write each up in 250-400 words: **Situation, Task, Action, Result + What you'd do differently**.
- Rehearse 3 of them out loud, ideally with someone else as audience.

### Useful background reading

| Book / source | Why |
|---------------|-----|
| **Brendan Gregg — Systems Performance, 2e** | The single best book for senior infra interviews |
| **Linux Programming Interface (Kerrisk)** | Authority on syscalls, signals, IPC, namespaces |
| **Designing Data-Intensive Applications (Kleppmann)** | Distributed systems vocabulary you'll need |
| **Google SRE / SRE Workbook** | Errror budgets, SLOs, incident reviews — required vocabulary |
| **LWN.net** | The deep "why" behind kernel changes |
| **`man 7 capabilities`, `man 7 cgroups`, `man 7 namespaces`** | Free, surprisingly good |

### Interview-day rules

1. **Restate the problem.** "So you want X with constraint Y, optimizing for Z. Is that right?"
2. **Ask scope questions out loud.** Cardinality (how many?), latency targets, consistency, blast-radius budget.
3. **Whiteboard a high-level picture before going deep.** Boxes and arrows first.
4. **Name the tradeoff every time.** "We could do X. The cost is Y. I'd pick X if Z."
5. **Explicitly address failure & day-2.** What breaks, who pages, how do you upgrade, how do you roll back.
6. **It's OK to say "I don't know."** Then say what you'd do to find out.
7. **End every section with a summary.** Senior signal: you can compress your own ideas.

### Red flags interviewers watch for

- Going straight to a tool ("I'd use Prometheus") before defining the problem.
- Memorized answers without nuance.
- Inability to make a recommendation when asked ("it depends" without follow-up).
- Treating every problem as a greenfield design — seniors should reach for **adopted** technology and explain why, not invent.
- Not asking about cost, on-call, or who maintains it after launch.

---

## Final thought

> The senior+ bar isn't "do you know more commands than a junior."
> It's "can you make the right call when no one else in the room can."
>
> Practice **judgment**, not trivia.
