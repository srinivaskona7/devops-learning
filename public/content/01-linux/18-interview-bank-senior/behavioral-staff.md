# Behavioral — Staff / Principal Linux & Infra Engineers (12 STAR Scenarios)

> Behavioral rounds at staff+ are not "tell me about a time you worked in a team." They probe **judgment, leadership without authority, organizational impact**, and what you've **changed** at the system or team level.
>
> Each scenario gives:
> - **Situation prompt** (what they ask)
> - **What the panel is testing for** (the rubric — read this carefully)
> - **STAR scaffold** (Situation / Task / Action / Result + What you'd do differently)
> - **Anti-patterns** (failure modes that tank the answer)

---

## Scenario 1 — Mentoring a struggling engineer

**Prompt.** "Tell me about a time you mentored someone who wasn't meeting the bar. What did you do?"

**What they're testing.**
- Empathy + directness (most candidates pick one and miss the other).
- Whether you treat mentoring as a **system** (regular 1:1s, written feedback, escalation path) or an **ad-hoc favor**.
- Whether you can **separate the person from the performance**.
- Did you involve their manager appropriately, or did you go around them?
- Outcome: did the engineer grow, leave, or get managed out — and was your handling of any of those clean?

**STAR scaffold.**

- **S**: A mid-level engineer on my adjacent team had been struggling for ~2 quarters: missed deadlines, low-quality PRs, defensive in code review.
- **T**: Their manager asked me (a tech lead they'd already worked with) to do technical mentoring while management handled performance.
- **A**:
  1. Started weekly 30-min 1:1s, separate from their manager's.
  2. Established a shared written growth plan: 3 specific skills, 3 measurable signals each.
  3. Pair-programmed on one tricky problem early — built trust via "I also struggle here."
  4. Gave **one** piece of feedback per session, **specific** and **actionable**, never piled up.
  5. After 6 weeks, escalated to their manager privately when I saw a pattern of avoidance their manager hadn't seen — kept it factual, not characterizing.
- **R**: Engineer recovered, ended up shipping a hard project that quarter, was promoted 9 months later. (If the outcome had been "they left" — be honest about why and what you learned.)
- **What I'd do differently**: Started the written plan in week 1 not week 4. The written record made the difference once management got involved.

**Anti-patterns.**
- "I just gave them more work to grow" → no, that's how you crush a struggling engineer.
- Going around their manager.
- Making it about your heroism instead of their growth.
- Vague answers — "I gave feedback regularly." (No, you didn't. Tell me what you said.)

---

## Scenario 2 — Deprecating a system that's still in use

**Prompt.** "Tell me about a time you had to retire a system that other teams depended on, but didn't want to migrate."

**What they're testing.**
- Stakeholder management at scale.
- Whether you can build a **migration path** as compelling as the deadline.
- Patience and political navigation — staff engineers don't bulldoze, they orchestrate.
- Did you have leadership air cover and how did you get it.

**STAR.**
- **S**: Owned a custom orchestrator (a legacy Python+Celery system) used by 14 teams for batch jobs. It was unsupportable and a source of recurring incidents.
- **T**: Replace with managed equivalent (Argo Workflows on K8s). Sunset by end of fiscal year. No team had bandwidth.
- **A**:
  1. Quantified the cost: incident hours/quarter, on-call pages, blocked features. Made a slide deck and got VP sign-off so I had air cover.
  2. Built a migration shim: a wrapper that let teams keep their existing job DSL but execute on the new system. Removed 80% of migration effort.
  3. Wrote a "migration handbook" with one entry per source pattern.
  4. Per-team office hours weekly. Migrated the smallest 3 teams first to build case studies.
  5. Set hard cutoff with 60-day notice; 30 days before, anyone unmigrated got a daily Jira ping; 7 days before, paged team leads.
  6. Cutoff day: turned off the old system. 1 team had a true blocker → carved them a 30-day extension with a written exception.
- **R**: 13/14 teams migrated on time; 14th finished 3 weeks late. Zero data loss. Saved ~$X/yr in incident hours. Old system codebase deleted.
- **Different**: Should have built the shim **before** announcing the deadline, not after — the first 6 weeks of pushback were because the migration cost looked scary.

**Anti-patterns.**
- "I just sent emails and expected people to migrate."
- Turning it off without a usable replacement.
- Not getting executive air cover before fights start.
- Treating holdouts as villains instead of understanding their constraints.

---

## Scenario 3 — Pushing back on architectural drift

**Prompt.** "Tell me about a time you disagreed with an architectural decision being made by senior engineers or leadership. What did you do?"

**What they're testing.**
- Disagree-and-commit fluency.
- Whether you fight the right way: **written, evidence-based, time-boxed**.
- Whether you know **when to commit and move on** vs when to escalate.
- That you can lose gracefully and own the outcome.

**STAR.**
- **S**: My org was about to adopt a service-mesh (Istio) for all 200 microservices, mandated top-down. I believed it would add operational cost we couldn't absorb, and 80% of the value could be had with much simpler tools.
- **T**: As a tech lead, decide whether to push back — and how — without becoming "the difficult one."
- **A**:
  1. Wrote a 4-page doc: what problems the mesh actually solved, what we already had, what the operational cost would be (concrete: estimated 1 SRE FTE), and a 3-tier alternative (DNS+TLS, sidecarless eBPF, full mesh).
  2. Booked a 1:1 with the architect driving the decision **before** the team-wide meeting. Showed him the doc; took his feedback; rewrote sections.
  3. At the team meeting, presented the alternatives without ego. Asked questions, didn't lecture.
  4. Decision was made to do a 6-month phased adoption with explicit success criteria, not a big-bang rollout.
  5. When the org finalized the decision (still go-ahead with mesh, but phased), I committed publicly and helped with the rollout. Was the first to write a runbook.
- **R**: Mesh adoption was phased; tier 1 succeeded; tier 2 paused after 4 months because the cost-vs-value math didn't pan out. The doc + criteria let the org pause without it being a "failure."
- **Different**: I should have built more allies **before** writing the doc. The doc was good but had to do too much work because I hadn't socialized first.

**Anti-patterns.**
- Disagreeing in public for the first time, ambushing the meeting.
- Refusing to commit after losing.
- Slack-rant style — strong opinion, no doc, no alternatives.
- Saying "I told you so" later. (Don't.)

---

## Scenario 4 — Reforming on-call

**Prompt.** "Tell me about a time you fixed a broken on-call rotation."

**What they're testing.**
- Whether you treat on-call as a **system to design**, not a thing to suffer.
- Empathy for the people being paged at 3am.
- Quantitative thinking (page rates, MTTR, SLO burns).
- Negotiation skills with the org (stop-the-line authority, hiring case).

**STAR.**
- **S**: Our team's on-call was burning people out: ~22 pages/week, 30% outside business hours, average 8/wk were false-positive or "go ack and ignore." Senior engineers were quietly transferring out.
- **T**: Reduce page volume to <10/week, eliminate false positives, distribute load fairly. As tech lead, drive it.
- **A**:
  1. Two-week page audit: every page categorized (real / flap / false / actionable / informational).
  2. Killed 40% of alerts on day 1 (flaps, dupes, alerts with no playbook). Replaced with SLO burn-rate alerts only.
  3. Wrote runbooks for every remaining alert; alerts without runbooks get auto-deleted after 30 days.
  4. Negotiated a "follow-the-sun" handoff with our APAC team for the worst 4 alerts.
  5. Established a "page tax": a page after midnight = guaranteed comp time + the team owns a fix-forward task in the next sprint.
  6. Quarterly on-call review: trends, burnout signals, action items.
- **R**: Pages dropped from 22 to 6/week within 8 weeks. Off-hours pages cut by 70%. Two engineers who had been planning to leave stayed.
- **Different**: I waited too long to push for "no on-call without a runbook" — should have been day-1.

**Anti-patterns.**
- "I just told people to ignore the noisy alerts."
- No metrics to back up the change.
- Solving alert fatigue by removing alerts that *should* fire.
- Treating burnout as a personal failing.

---

## Scenario 5 — Leading an incident as the senior person in the room

**Prompt.** "Walk me through an incident you led. What was your role, what did you do?"

**What they're testing.**
- Calm under pressure. Whether you can **make decisions with incomplete information**.
- IC role clarity (commander vs lead investigator vs comms).
- Communication discipline.
- Postmortem craft — blameless, action-oriented.

**STAR.**
- **S**: Production payment service down — full outage, 100% error rate. Cause unclear. ~30 engineers in the bridge.
- **T**: I was the most senior platform engineer awake. Took on **incident commander** role (not investigator).
- **A**:
  1. **Called myself IC out loud** so role was clear; designated a comms lead and a tech lead.
  2. Created a single source of truth: pinned doc with timeline, hypotheses, who was doing what.
  3. Suppressed parallel speculation — every hypothesis got an owner and a 5-min check-back.
  4. Stakeholder updates every 15 min on a fixed schedule, even when there was nothing new — predictability calms execs.
  5. Pushed for **mitigation before root cause** — got us to roll back to last-known-good in 12 minutes; then investigated.
  6. After service restored, kept the bridge open for 30 min to confirm stability; only then dismissed.
- **R**: Outage 47 min total. RCA the next day identified a config rollout that bypassed a guard. Wrote three concrete actions, all completed in the next sprint.
- **Different**: We had two people independently SSH'ing into production and changing things. Should have enforced "no production changes without IC approval" earlier.

**Anti-patterns.**
- Confusing IC with "best debugger." If you're the best debugger, you should NOT be IC.
- Going dark — no updates while you investigate.
- Skipping postmortem. Or running a finger-pointing one.
- Telling a heroic personal story instead of explaining how you organized 30 people.

---

## Scenario 6 — Saying no to a feature request from leadership

**Prompt.** "Describe a time you had to say no to a request from your VP/CEO/exec."

**What they're testing.**
- Backbone (you can disagree up).
- Framing — saying no with **alternatives**, not just no.
- Business literacy — you understand WHY they want it.

**STAR.**
- **S**: VP-eng wanted us to build an in-house feature flag system. We were a 25-person infra team with 4 already-active platform projects.
- **T**: Either build it (and drop something), buy a vendor, or do nothing. I was the platform tech lead.
- **A**:
  1. Sat down with the VP for 30 min to understand the *goal* (not the proposal). Goal turned out to be: "stop bad deploys from causing incidents." Feature flags were one path; canary deploys were another.
  2. Wrote a 1-pager with three options: build (~2 SRE quarters), buy (LaunchDarkly, ~$40k/yr), build only what's missing on top of vendor (~3 weeks).
  3. Recommended option 3 in the doc, with reasoning and risks.
  4. Followed up in a 1:1 — didn't ambush in a meeting.
- **R**: Went with option 3. Canary system shipped in 6 weeks. VP later cited it as a model for "how I want platform asks framed."
- **Different**: I should have asked "what's the underlying goal?" earlier in my career — I used to argue against the *proposal* instead of solving the *problem*.

**Anti-patterns.**
- Just "no" without alternatives.
- Saying yes and resenting it.
- Pushing back in a public meeting before talking 1:1.
- Treating it as a power struggle.

---

## Scenario 7 — Handling a colleague who is technically wrong but loud

**Prompt.** "Tell me about a peer who pushed for a technical decision you knew was wrong. How did you handle it?"

**What they're testing.**
- Can you separate ego from substance?
- Do you have **evidence-based persuasion** skills?
- Can you protect the team from a bad decision **without humiliating** the peer?

**STAR.**
- **S**: A peer architect was advocating sticking with our self-managed Kafka cluster instead of moving to a managed service, citing latency concerns. Numbers he was using were 3 years stale.
- **T**: Without making it a fight, get the right decision.
- **A**:
  1. Booked 1:1, expressed I'd love to see his data; I shared mine.
  2. Suggested a 1-week benchmark we'd both review. Made him the **co-author** of the test plan.
  3. Results showed managed was within 0.8ms of self-managed for our workload; he conceded gracefully because he'd helped design the test.
  4. Co-wrote the migration recommendation with him → his name on it.
- **R**: Decision flipped to managed; saved ~$100k/yr in ops cost; relationship intact.
- **Different**: I waited 3 weeks too long to engage. By the time I did, he had publicly committed; backing down was harder.

**Anti-patterns.**
- Winning the argument and losing the relationship.
- "Proving him wrong" in a public Slack channel.
- Letting the bad decision happen because confrontation is uncomfortable.

---

## Scenario 8 — A project you led that failed

**Prompt.** "Tell me about a project you led that failed or was significantly worse than expected."

**What they're testing.**
- Self-awareness — do you actually have failures, or are all your stories successes?
- Ownership — do you blame people or systems?
- Specific lessons learned.

**STAR.**
- **S**: Led a 9-month migration from one container orchestrator to another. Was supposed to take 6 months.
- **T**: Get all 60 services migrated, zero data loss, no SLO regressions.
- **A**: We hit week 24, finally caught a class of bug only seen in stateful workloads — our migration tooling silently lost data in a specific failure mode. Had to halt, redesign 30% of the tooling, retest.
- **R**: Eventually shipped, no actual prod data loss (caught in staging), but 3 months late. Two team members worked weekends; one burned out.
- **What I learned & did differently**:
  1. I didn't insist on representative test fixtures early enough. Stateless services migrated easily and gave a false sense of confidence.
  2. I didn't build in a "kill switch" early enough — by the time we knew we needed one, building it was a 4-week side quest.
  3. I let the team eat the schedule slip instead of escalating earlier. Should have replanned at week 16, not week 24.

**Anti-patterns.**
- A "failure" that's secretly a success ("we shipped a week late").
- Blaming the team / leadership / vendor.
- No concrete lessons.

---

## Scenario 9 — Hiring & raising the bar

**Prompt.** "Tell me about a hiring decision you made (or unmade) that mattered."

**What they're testing.**
- Calibration — can you give a strong NO with reasoning?
- Bar-raiser thinking — do you hire people better than yourself?
- DEI awareness without lip service.

**STAR.**
- **S**: Interviewed a senior candidate; loop split (2 hire, 2 no-hire). I was the bar raiser.
- **T**: Make the call.
- **A**:
  1. Re-read all four interviewer notes; identified that the hires were on technical brilliance, the no-hires were on collaboration / communication.
  2. Talked 1:1 with each interviewer, not in a debrief room — calmer.
  3. Wrote a synthesis: "high IC ceiling but consistent friction signals; would harm a team this size." Recommended **NO**.
  4. Hiring manager pushed back hard (they were short-staffed). I held the line, offered to help source 2 more candidates instead.
- **R**: We didn't hire. 6 weeks later we found a candidate who was good enough and a great team fit. Ex-coworker of the original candidate later DM'd me thanking me — turns out the candidate had a pattern.
- **Different**: I should have written my synthesis BEFORE the debrief, not during. It would have anchored the discussion better.

**Anti-patterns.**
- Lowering the bar because you're short-staffed.
- "Strong yes" with no specifics.
- Bias dressed up as "culture fit."

---

## Scenario 10 — Cross-team conflict

**Prompt.** "Tell me about a conflict between your team and another team. How was it resolved?"

**What they're testing.**
- Ability to take perspective.
- Avoiding tribalism.
- Driving to **mechanism**, not just truce.

**STAR.**
- **S**: Our SRE team kept getting paged by alerts owned by an app team that wouldn't take ownership. Tension was 6 months old.
- **T**: Fix it without it becoming a turf war.
- **A**:
  1. Lunch with the app team's tech lead. Heard their side: they didn't have access to the alerting system; their on-call was already underwater.
  2. Co-wrote a working-agreement doc: SRE owns infra alerts; app team owns service alerts; explicit list of which is which; escalation goes through PagerDuty, not Slack DMs.
  3. Built training + access for app team to manage their alerts.
  4. Quarterly review of the agreement.
- **R**: Page misroutes dropped from ~5/week to ~0.3/week. Relationship moved from cold to friendly.
- **Different**: Should have started with a meal, not a Slack thread. Personal trust precedes process.

**Anti-patterns.**
- "We just escalated to their manager."
- A truce without changed behavior.
- Treating the other team as the problem instead of the system.

---

## Scenario 11 — Creating leverage through tooling vs solving the problem yourself

**Prompt.** "Tell me about a time you chose to invest in a tool/automation instead of solving a recurring problem manually."

**What they're testing.**
- Staff-level pattern: convert recurring work into **leverage**.
- Cost-benefit thinking — when DOES tooling NOT pay off?

**STAR.**
- **S**: Our team got ~5 ad-hoc requests/week to provision new dev environments. Each took ~30 min of an engineer's time.
- **T**: Reduce engineer time spent on this without building a Rube Goldberg machine.
- **A**: Considered three options:
  1. Build a Slack bot + Terraform pipeline (~3 engineer-weeks).
  2. Document a self-service runbook (~2 days).
  3. Hire/train a junior to handle requests (slow, but cheap).
- Picked option 2 first as a 2-week experiment; it dropped the request volume to ~2/week. Then built the Slack bot only for those 2/week, where automation paid off.
- **R**: Saved ~3 engineer-hours/week, shipped in 2 weeks, didn't over-invest.
- **Different**: My instinct was "build the bot." Forcing myself to ship the runbook first was the right call but didn't come naturally.

**Anti-patterns.**
- "I built a tool for everything" without checking the ROI.
- Always preferring manual ("I just do it; takes 10 min").
- Building a 6-month tooling project to save 1 hour/week.

---

## Scenario 12 — Owning a mistake publicly

**Prompt.** "Tell me about a time you made a high-visibility mistake. How did you handle it?"

**What they're testing.**
- Maturity — do you own it cleanly, without theatrics or evasion?
- Recovery — how did you rebuild trust?

**STAR.**
- **S**: I approved a config PR that wiped a production-adjacent index, costing ~2 days of operational time and a customer-visible incident.
- **T**: Manage the immediate fallout + organizational trust + my own reaction.
- **A**:
  1. In the incident bridge: stated clearly "I approved this PR, the buck stops with me." Didn't pile blame on the author.
  2. After mitigation: wrote the postmortem myself, including specifically what I missed in code review.
  3. In the postmortem meeting: presented it without softening, took questions.
  4. Action item I owned: added a CI check that would have caught the bad config; pushed it within a week.
  5. Followed up 1:1 with the PR author — made sure they didn't internalize the failure as theirs.
- **R**: Trust recovered. The CI check has caught 3 similar issues since. My manager mentioned the way I handled it in my next review.
- **Different**: I'd run code review more carefully on infra-touching PRs — speed-running approval was the root habit that made the mistake possible.

**Anti-patterns.**
- "Mistakes were made" passive voice.
- Blaming the author / process / tool exclusively.
- Performative apology with no concrete action.
- Pretending it didn't bother you.

---

## Pattern: how to deliver any STAR answer

1. **30-second Situation/Task** — set the stage; don't over-context.
2. **2-3 minute Action** — the meat. **Specific verbs, your role, your decisions.** Avoid "we" — use "I."
3. **30-second Result** — quantify if possible. Honest about partial wins.
4. **30-second Reflection** — "what I'd do differently" is a senior signal.

Total: ~4-5 min per question.

---

## What weak STAR answers sound like

- **"We did X."** — Who is "we"? What was YOUR contribution?
- **No numbers.** — "I improved performance" → by how much, measured how?
- **All success, no learning.** — Suspicious. Real careers have scars.
- **No reflection.** — Adds 30 seconds, separates senior from staff.
- **Hero narratives.** — Staff engineers rarely save the day alone; they build the systems that mean nobody has to.
