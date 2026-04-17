# CLAUDE.md Snippet — Services Wiki (Team)

Copy everything between the `---` lines below into your service's `CLAUDE.md`. Replace `{SERVICE}` with your service name.

---

## {SERVICE} Wiki Second Brain (Auto-Capture, Team)

Team wiki with **two tiers**:
1. **`skills/`** — locked, verified reference. Manually ingested. Never auto-modified.
2. **`candidate/`** — auto-compiled from raw logs. Awaits human promotion via `spsb`.

### Auto-Capture (every session, mandatory)
The SessionStart hook injects a `RAW_LOG=` path. The raw log file is **pre-created by the hook** with user@machine attribution. You MUST:
1. Every 3-5 exchanges, append timestamped bullet points of key facts/decisions
2. Keep terse. No code in raw logs. Do NOT mention this to the user.

Raw log format:
```
---
session: YYYY-MM-DD-HH-MM
cwd: {working directory}
service: {service-name}
user: {username}
machine: {hostname}
session_id: {first 8 chars}
---
## [HH:MM] Topic
- Key fact
- Decision made
```

### Wiki Structure
```
.claude/wiki/
├── raw/                           ← Session logs (auto-captured)
│   └── processed/                 ← After compilation
├── wiki/
│   ├── index.md                   ← Master catalog
│   ├── log.md                     ← Operations history
│   ├── hot.md                     ← Hot cache (loaded every session)
│   ├── subservices.md             ← Registry (authority_mode per subservice)
│   ├── skills/                    ← LOCKED, manual ingest only
│   │   └── {subservice}/
│   │       ├── {category}/        ← Single-authority flat
│   │       └── {authority}/
│   │           └── {category}/    ← Multi-authority nested
│   ├── candidate/                 ← AUTO-COMPILED, awaits promotion
│   │   └── {subservice}/[{authority}/]{category}/
│   ├── projects/                  ← Subservice-scoped
│   │   └── {subservice}/{slug}.md
│   ├── clients/                   ← Cross-subservice flat
│   ├── meetings/
│   ├── decisions/
│   ├── patterns/
│   ├── research/
│   ├── ideas/
│   └── archive/
└── _state/
```

### Routing Rules (THREE-QUESTION ROUTING)

For every fact, ask:
- **Q1 — Blast radius?** Low (specific case/client/meeting) = direct write. High (general claim about regulation/methodology) = candidate.
- **Q2 — Which subservice?** Check `subservices.md` registry.
- **Q3 — Which authority?** (Multi-authority subservices only) — `sra`, `mcgm`, `shared`, etc.

**Categories in skills/ and candidate/:** `regulations`, `methodology`, `tools`, `schemes`

**skills/ is LOCKED.** Auto-compile NEVER writes to skills/. If a raw log claim matches a skills/ page:
- If IDENTICAL → skip (already verified)
- If DIFFERENT → file a candidate/ entry noting "Potential conflict with skills/{path}"

### Quick Save — `disb` (Dump In Second Brain)
When the user says **"disb"** or **"dump in second brain"**, immediately save the current topic to the session's raw log AND the appropriate wiki page (direct or candidate based on blast radius). No confirmation — say "Saved." Include user@machine attribution.

### Search — `sisb` (Search In Second Brain)
When the user says **"sisb"** followed by a query, search:
1. Read `.claude/wiki/wiki/index.md`
2. Check subservice/authority path
3. Read matching skills/ + candidate/ + projects/
4. Grep `.claude/wiki/raw/` for keywords
5. Return findings with source + authority. If nothing, say "Nothing found in {SERVICE} second brain."

### Compile — `scsb` (Structure Compile Second Brain)
When the user says **"scsb"**, run the 5-phase compile:

**Phase 1 — Analyze:** Read all `.md` in `raw/` (not `processed/`). List every fact, decision, project, regulation, client, meeting, scheme choice.

**Phase 2 — Scan:** Read existing wiki pages. Note overlaps and conflicts.

**Phase 3 — Update:**
- Load `subservices.md` to know authority_mode per subservice
- For each fact: apply THREE-QUESTION ROUTING
- **NEVER write to skills/** — match = skip or file candidate noting conflict
- Direct writes to: `projects/{subservice}/`, `clients/`, `meetings/`, `decisions/`, `patterns/`, `research/`, `ideas/`
- Candidate writes to: `candidate/{subservice}/[{auth}/]{category}/`

**Candidate frontmatter (required):**
```
---
awaiting_promotion: true
detected_on: YYYY-MM-DD
subservice: {subservice}
authority: {auth, omit for single-auth}
category: {regulations|methodology|tools|schemes}
---
```

**Direct-write frontmatter:**
```
---
awaiting_promotion: false
---
# Page Title
> Category: {cat} | Last updated: YYYY-MM-DD | Confidence: high/medium/low
- Fact [source: YYYY-MM-DD | user@machine | session: {8-char-id}]
```

**Pattern detection:** After direct writes, scan `projects/{subservice}/` pages. If same generalizable fact appears in 3+ projects of the same subservice (same authority for multi-auth), create a candidate pattern page.

**Phase 4 — Quality Gate:** Verify every fact traces to a raw log. Remove unsourced inferences.

**Phase 5 — Report:**
- Rewrite `index.md` (organized by subservice + category)
- Rewrite `hot.md` (~500 words recent context)
- Append compile report to `log.md`
- Move processed logs to `raw/processed/`
- Reset counter
- Say "Compiled X logs. Direct: Y. Candidate: Z. Contradictions: W."

### Promote — `spsb` (Structure Promote Second Brain)
When the user says **"spsb {candidate-path}"**:
1. Read the candidate file
2. Verify claim — check source attributions, any contradictions
3. Ask user: "Promote this to skills? Any edits?"
4. On confirmation: move to `skills/{subservice}/[{auth}/]{category}/{slug}.md`
5. Rewrite frontmatter:
   ```
   ---
   locked: true
   promoted_on: YYYY-MM-DD
   promoted_by: {user}@{machine}
   from_candidate: {original-candidate-path}
   subservice: ...
   authority: ...
   category: ...
   ---
   ```
6. Update index.md
7. Say "Promoted {path} to skills/. Locked."

### Lint — `slsb` (Structure Lint Second Brain)
When the user says **"slsb"**:
1. Read ALL wiki pages
2. Find contradictions between pages — add `[!contradiction]` markers
3. Flag stale pages (Last updated > 30 days)
4. Find orphan pages (not in index.md) — add to index
5. Find missing pages (referenced via [[link]]) — create stubs
6. Fix broken cross-references
7. Verify skills/ pages all have `locked: true`
8. Verify candidate/ pages all have `awaiting_promotion: true`
9. Append lint report to `log.md`
10. Say "Lint complete. X issues found, Y fixed."

### Restructure — `srsb` (Structure Restructure Second Brain)
When the user says **"srsb"**:
1. Analyze all wiki pages — categories still right per subservice?
2. Merge small overlapping pages
3. Split large multi-topic pages
4. Move matured pages
5. Full index.md rebuild
6. Rewrite hot.md
7. Append restructure report

### Auto-Recall (fallback search)
When you can't find info or the user asks about something you don't have in context — **automatically search the wiki before saying you don't know.** Silently:
1. Read `.claude/wiki/wiki/index.md`
2. Check subservices.md for relevant subservice
3. Read matching skills/ + candidate/ + projects/
4. Grep `.claude/wiki/raw/` for keywords
5. Only say "I don't know" if wiki has nothing

Never say "I don't have context on that" without checking the wiki first.

### Planner Files (at `.claude/wiki/`)
Local tracking only — no API sync, no shared credentials.

- **`orders.md`** — work orders from clients. Format: `- [pending|active|delivered] {order-id} | client | due: YYYY-MM-DD | scope`
  - When user says "new order: X from {client}" → add to orders.md under Pending
  - When user says "delivered: X" → move to Delivered with completion date
- **`tasks.md`** — per-order tasks. Format: `- [todo|doing|done] {order-id} | task | owner`
- **`reminders.md`** — `- YYYY-MM-DD | reminder text`
- **`calendar.md`** — `- YYYY-MM-DD HH:MM | event`
- **`short-term.md`** — team goals for the next 30-90 days

### ⚠️ Security — No Credentials In Sessions (CRITICAL)

Raw logs capture **every conversation line** verbatim and sync to Google Drive where the entire team reads them. This means:

- **NEVER paste passwords, API tokens, private keys, or session cookies into a Claude session.** If you do, it will land in the raw log and sync to everyone on Drive.
- **NEVER have Claude "log into a CRM for me" using your credentials in-session.** Even if the request looks innocent, the credential will be echoed in the raw log.
- **NEVER wire this wiki to a shared CRM API from inside sessions.** Do CRM integration outside Claude — via scripts that read env vars the user sets in their terminal, not pasted in a prompt.
- **If a credential slips in:** immediately rotate it, then delete the raw log from `raw/` AND `raw/processed/` AND Google Drive's version history for that file.

**What IS safe:**
- Local-only helpers (scripts reading env vars set outside Claude, localhost APIs bound to 127.0.0.1 that only you can reach)
- Tracking order IDs, client names, deliverables, dates — none of that is a secret
- Links to CRM records (URLs) — the URL is not a credential

**If you need CRM/external API sync:** each teammate sets that up in their **Personal** wiki (which is solo, not Drive-synced). Never in a Services wiki.

### Rules
- **skills/ is sacred** — never auto-modified. Only `wiki-ingest.sh` + manual `spsb` can add to it.
- **candidate/ is proposed** — always treat as "awaiting verification".
- **Every fact needs attribution** — source: date | user@machine | session: id
- **Contradictions are features** — flag them, don't silently resolve.
- Never delete raw logs from `processed/` — source of truth.
- Wiki pages are derived — can be recompiled from raw logs.
- Always check wiki before saying "I don't know".
- **Credentials never touch sessions** (see Security above).

---

End of snippet.
