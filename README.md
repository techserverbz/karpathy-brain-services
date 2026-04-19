# Karpathy Brain — Services

Team wiki for service-based work (feasibility, liaisoning, development, etc.). Project-scoped and Google-Drive-synced so teammates share one brain.

**Two-tier architecture:**
- **`skills/`** — locked, verified reference material. Manually ingested. Never auto-modified.
- **`candidate/`** — auto-compiled from raw logs. Awaits human promotion to `skills/`.

This split matters because multiple teammates write raw logs, and not every claim should become canon. Auto-compile proposes; humans promote.

## ⚠️ Security — No Credentials In Sessions

Raw logs capture every conversation line verbatim and sync to Google Drive where the whole team reads them.

- **No passwords, API tokens, private keys, or session cookies in prompts — ever.**
- **No CRM / external API integration inside sessions.** The Personal setup (separate folder) includes CRM/localhost API sync because it's solo and machine-local. The Services setup deliberately omits it. If a teammate needs CRM access, they do it in their Personal wiki.
- **Only tracks:** orders, tasks, clients, meetings, decisions, regulations, methodologies. Never secrets.
- If a credential leaks into a raw log: rotate immediately, purge the file from `raw/`, `processed/`, and Drive version history.

See `CLAUDEMD-SNIPPET.md` for the full security section that goes into your CLAUDE.md.

---

## Where to Clone This Repo (Each Teammate)

**The clone is local to each teammate's machine. The TARGET service folder is on Google Drive.**

Two separate locations:

| What | Where | Why |
|---|---|---|
| **Repo clone** (source) | `~/Code/karpathy-brain-services` (local only) | Each teammate has their own clone for `git pull`. Never on Drive — Drive syncing `.git/` causes conflicts. |
| **Service folder** (target) | `G:/My Drive/Services/{ServiceName}/` (Drive-synced) | This is the actual team wiki. Drive syncs it to everyone. |

### One-time setup (each teammate)

```bash
# 1. Clone the repo locally (NOT on Drive)
mkdir -p ~/Code
cd ~/Code
git clone https://github.com/techserverbz/karpathy-brain-services.git
cd karpathy-brain-services

# 2. Run install.sh pointing at the Drive service folder
bash install.sh "/g/My Drive/Services/Real Estate"
```

### To update later (each teammate runs this periodically)

```bash
cd ~/Code/karpathy-brain-services
git pull
bash install.sh "/g/My Drive/Services/Real Estate"
```

Every run updates the hooks on Drive and writes a new entry to `{service}/.claude/wiki/_state/karpathy_sync.json` + `karpathy_sync_history.log`. The whole team can then see who last synced + from which commit.

### Windows paths

- Git Bash Drive letter format: `/g/My Drive/Services/...` (not `G:/`)
- On Mac, replace `/g/` with `/Users/{you}/Google Drive/`

---

## What's in this folder

```
Karpathy Brain - Services/
├── README.md                      ← this file
├── CLAUDEMD-SNIPPET.md            ← copy-paste into service's CLAUDE.md
├── subservices.md.template        ← registry template
└── hooks/
    ├── session-start.sh           ← pre-creates raw log + loads local skills
    ├── session-stop.sh            ← extracts conversation + finalizes log
    ├── wiki-compile.sh            ← routes facts to direct/ or candidate/
    ├── wiki-ingest.sh             ← manual ingest of curated docs to skills/
    ├── wiki-logger.sh             ← (PostToolUse) injects session_id + nudges
    └── register-subservice.sh     ← create new subservice/authority folders
```

---

## Mental model

```
Team member works in Claude Code
   ↓ session auto-captures
raw/YYYY-MM-DD-HH-MM.md (user@machine attributed)
   ↓ every 10 sessions
wiki-compile.sh routes facts:
   ├── LOW blast radius (specific) → projects/ clients/ meetings/ decisions/ ...
   └── HIGH blast radius (general claim) → candidate/{subservice}/{category}/
                                             ↓ human reviews + promotes
                                           skills/{subservice}/{category}/ (LOCKED)
```

**Curated docs** (existing SOPs, regulations, manuals) bypass this flow — use `wiki-ingest.sh` to drop them directly into `skills/` with `locked: true`.

---

## Setup (10 minutes)

### Step 1 — Decide where the wiki lives

Best practice: project folder on Google Drive, accessed via local symlink.

```
G:/My Drive/Services/{ServiceName}/
└── .claude/
    ├── hooks/       ← from this folder
    ├── wiki/        ← the brain (Drive-synced)
    ├── skills/      ← project's own skill files (independent)
    └── assets/      ← source docs (PDFs, regulations, etc.)
```

Every teammate gets the SAME folder via Drive. Their hooks run against it.

### Step 2 — Create the folder structure

```bash
SERVICE="/g/My Drive/Services/YourService"
mkdir -p "$SERVICE/.claude/"{hooks,wiki/{raw/processed,_state,wiki/{skills,candidate,projects,clients,meetings,decisions,patterns,research,ideas,archive}},skills,assets}
```

### Step 3 — Copy the hooks

```bash
cp hooks/*.sh "$SERVICE/.claude/hooks/"
chmod +x "$SERVICE/.claude/hooks/"*.sh
```

### Step 4 — Seed initial files

```bash
echo "# {SERVICE} Wiki Index" > "$SERVICE/.claude/wiki/wiki/index.md"
echo "# Recent Context" > "$SERVICE/.claude/wiki/wiki/hot.md"
echo "# Wiki Operations Log" > "$SERVICE/.claude/wiki/wiki/log.md"
echo "0" > "$SERVICE/.claude/wiki/_state/counter.txt"
echo "0" > "$SERVICE/.claude/wiki/_state/total_counter.txt"

# Copy subservices.md template and customize
cp subservices.md.template "$SERVICE/.claude/wiki/wiki/subservices.md"
```

Edit `subservices.md` to list your actual subservices (see template).

### Step 5 — Register each subservice

For each subservice the team will work on:

**Single-authority** (one regulator covers it all):
```bash
cd "$SERVICE"
bash .claude/hooks/register-subservice.sh subservice feasibility single
```

**Multi-authority** (multiple authorities — e.g. SRA, MCGM, MHADA):
```bash
bash .claude/hooks/register-subservice.sh subservice liaisoning multi
bash .claude/hooks/register-subservice.sh authority liaisoning sra SRA
bash .claude/hooks/register-subservice.sh authority liaisoning mcgm MCGM
```

Each `register` call creates matching folders in `skills/`, `candidate/`, `projects/`, and `assets/`.

### Step 6 — Register hooks in `~/.claude/settings.json`

Each teammate adds this to their local settings:

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "bash .claude/hooks/session-start.sh" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "bash .claude/hooks/session-stop.sh" }] }
    ],
    "PostToolUse": [
      { "matcher": "*", "hooks": [{ "type": "command", "command": "bash .claude/hooks/wiki-logger.sh" }] }
    ]
  }
}
```

The paths are relative to `CLAUDE_PROJECT_DIR`, so they follow whichever service you `cd` into.

### Step 7 — Add CLAUDE.md to the service folder

Create `$SERVICE/CLAUDE.md` (or `$SERVICE/.claude/CLAUDE.md`) and paste everything from `CLAUDEMD-SNIPPET.md`.

### Step 8 — Restart Claude Code

`cd` into the service folder and start a session. You should see `RAW_LOG=...` and the wiki status in the context.

---

## Daily use

### Team member writes a raw log (auto)
Just work in Claude Code. Every 3-5 exchanges, Claude silently appends to `raw/{date}.md`. Your user@machine is stamped in the frontmatter.

### Auto-compile (every 10 sessions)
- Counter hits 10 → `wiki-compile.sh` runs in background
- New facts route to direct files (projects/, clients/, etc.) OR candidate/
- Contradictions get `[!contradiction]` markers for review

### Promote candidate to skills (manual, `spsb`)
When a team lead reviews `candidate/{subservice}/{category}/{slug}.md` and decides it's canonical:
1. Move the file to `skills/{subservice}/{category}/{slug}.md`
2. Change frontmatter: `awaiting_promotion: true` → `locked: true`
3. Add `promoted_by: {user}@{machine}`, `promoted_on: YYYY-MM-DD`

Or say `spsb {path}` in a session (if command is added to CLAUDE.md).

### Ingest existing SOPs (`wiki-ingest.sh`)

For pre-curated reference docs:

```bash
# Single-authority
bash .claude/hooks/wiki-ingest.sh feasibility "assets/Feasibility/workflow.md"

# Multi-authority
bash .claude/hooks/wiki-ingest.sh liaisoning sra "assets/SRA/33-10-Reference.md"
```

Each document is split into focused skill pages with `locked: true`.

---

## Commands (after CLAUDEMD-SNIPPET is in place)

| Command | Action |
|---------|--------|
| **disb** | Dump In Second Brain — save current topic immediately |
| **sisb {query}** | Search In Second Brain |
| **scsb** | Structure Compile |
| **slsb** | Structure Lint (finds contradictions, orphans, broken refs) |
| **srsb** | Structure Restructure |
| **spsb {path}** | Structure Promote — move candidate/ to skills/ (manual review) |

---

## Why skills vs candidate matters

**Without the split** (everyone writes to one tier):
- Team member A writes "FSI is 3.0 for Scheme X" based on one case
- Team member B writes "FSI is 2.5 for Scheme X" based on another case
- Auto-compile silently overwrites one with the other
- Wiki becomes unreliable

**With the split:**
- Both claims land in `candidate/` with `[!contradiction]` marker
- Team lead reviews → investigates → picks correct value → promotes ONE
- `skills/` stays clean. Only verified claims live there.

Candidate is proposed knowledge. Skills is verified knowledge. Only humans promote.

---

## Google Drive notes

**File lock conflicts:** Drive doesn't lock files. Two teammates editing the same raw log at the same time = conflict. Solutions:
- Each teammate's session creates a DIFFERENT raw log (timestamped to the minute) — no conflict there.
- Compile runs local per-machine; processed logs move to `processed/` which Drive happily syncs.
- Only dangerous case: two teammates running `scsb` at the exact same time. Rare. Coordinate.

**Sync lag:** Drive syncs are eventual. A raw log written on machine A may take 10-60 seconds to appear on machine B. Team compiles should run after sync settles.

**Version history:** Drive keeps file history. If someone overwrites badly, restore from Drive's version UI.

---

## Troubleshooting

**Hook says "Unknown subservice":** You tried to ingest to a subservice not in `subservices.md`. Run `register-subservice.sh subservice {slug} {single|multi}` first.

**Compile routes everything to candidate/:** That's correct for high-blast-radius facts. If genuinely specific (one client, one meeting), it should go direct. Check raw log wording — vague claims end up in candidate/.

**Skills page got overwritten:** It shouldn't have. Check frontmatter — if `locked: true` is missing, add it. Compile honors `locked: true` strictly.

**Team member's raw logs not appearing:** Check Drive sync status. Check their `.claude/settings.json` has the hooks registered with correct paths.

---

## Sync Log — Team Sees Who Last Updated (Google Drive)

Every time someone runs `bash install.sh ...`, it writes two files inside `{service}/.claude/wiki/_state/`:

- `karpathy_sync.json` — current state: commit hash, date, who installed, from which machine
- `karpathy_sync_history.log` — append-only history (visible to the whole team since it's on Drive)

This means any teammate can check who last synced the hooks and which commit they were on — useful when debugging "why does X behave differently for Akhil than me?"

**Check current state:**
```bash
cat "/g/My Drive/Services/Real Estate/.claude/wiki/_state/karpathy_sync.json"
```

Example:
```json
{
  "flavour": "services",
  "service_name": "Real Estate",
  "installed_at": "2026-04-19T21:55:00Z",
  "installed_by": "Shubham(Code)@DESKTOP",
  "git_commit": "2a524f4a...",
  "git_commit_short": "2a524f4",
  "git_commit_date": "2026-04-17T14:10:13Z",
  "git_commit_message": "Karpathy Brain — Services: ...",
  "git_remote": "https://github.com/techserverbz/karpathy-brain-services.git"
}
```

**See full team history:**
```bash
cat "{service}/.claude/wiki/_state/karpathy_sync_history.log"
```

**Update:** `cd` into your clone, then `git pull && bash install.sh "{service-path}"`. Every teammate should do this periodically to stay in sync.
