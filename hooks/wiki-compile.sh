#!/bin/bash
# Wiki compile/lint/restructure (SERVICES) — routes to direct vs candidate/
# Usage: bash .claude/hooks/wiki-compile.sh [compile|lint|restructure]

ACTION="${1:-compile}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOCAL_CLAUDE="$PROJECT_DIR/.claude"
WIKI_HOME="$LOCAL_CLAUDE/wiki"
WIKI_RAW="$WIKI_HOME/raw"
WIKI_PAGES="$WIKI_HOME/wiki"
WIKI_STATE="$WIKI_HOME/_state"
SERVICE_NAME=$(basename "$PROJECT_DIR")

[ ! -d "$WIKI_HOME" ] && echo "Wiki not found at $WIKI_HOME" && exit 1

RAW_COUNT=$(ls "$WIKI_RAW"/*.md 2>/dev/null | wc -l | tr -d '[:space:]')
echo "[$SERVICE_NAME Wiki] Action: $ACTION | Raw logs: $RAW_COUNT"

if [ "$ACTION" = "compile" ] && [ "$RAW_COUNT" -eq 0 ]; then
  echo "[Wiki] Nothing to compile."
  exit 0
fi

ACTIVE_LOG=""
[ -f "$WIKI_STATE/current_rawlog.txt" ] && ACTIVE_LOG=$(cat "$WIKI_STATE/current_rawlog.txt" 2>/dev/null | tr -d '\n\r')
ACTIVE_BASENAME=""
[ -n "$ACTIVE_LOG" ] && ACTIVE_BASENAME=$(basename "$ACTIVE_LOG")

RAW_CONTENT=""
LOGS_TO_PROCESS=""
if [ "$ACTION" = "compile" ]; then
  for f in "$WIKI_RAW"/*.md; do
    [ -f "$f" ] || continue
    [ "$(basename "$f")" = "$ACTIVE_BASENAME" ] && continue
    RAW_CONTENT+="--- FILE: $(basename "$f") ---
"
    RAW_CONTENT+="$(head -80 "$f")

"
    LOGS_TO_PROCESS+="$(basename "$f") "
  done
fi

INDEX_CONTENT=""
[ -f "$WIKI_PAGES/index.md" ] && INDEX_CONTENT=$(cat "$WIKI_PAGES/index.md")

SUBSERVICES_CONTENT=""
[ -f "$WIKI_PAGES/subservices.md" ] && SUBSERVICES_CONTENT=$(cat "$WIKI_PAGES/subservices.md")

# Primer action — early exit, own loop (no standard prompt/claude flow)
if [ "$ACTION" = "primer" ]; then
  echo "[$SERVICE_NAME Wiki] Generating session primers..."
  SKILLS_BASE="$WIKI_PAGES/skills"
  [ ! -d "$SKILLS_BASE" ] && echo "[Wiki] No skills dir." && exit 0

  for subdir in "$SKILLS_BASE"/*/; do
    [ -d "$subdir" ] || continue
    SUBSERVICE=$(basename "$subdir")

    SKILLS_CONTENT=""
    while IFS= read -r sf; do
      [ -f "$sf" ] || continue
      rel="${sf#$subdir}"
      SKILLS_CONTENT+="--- $rel ---
$(cat "$sf")

"
    done < <(find "$subdir" -name "*.md" ! -name "_*" 2>/dev/null | sort)

    [ -z "$SKILLS_CONTENT" ] && continue

    PRIMER_FILE="$subdir/_session-primer.md"
    SUBSERVICE_TITLE=$(echo "$SUBSERVICE" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1))substr($i,2)};print}')

    PTMP=$(mktemp)
    cat > "$PTMP" << PRIMEREOF
Write a session primer for the '$SUBSERVICE' real estate subservice.

SKILL PAGES:
$SKILLS_CONTENT

Write ONLY the content for this file: $PRIMER_FILE
(The file will be saved at that path — write it now using the Write tool)

Sections (~400 words total, strict order):

# Session Primer — $SUBSERVICE_TITLE
> Auto-generated | Updated: $(date +%Y-%m-%d) | Source: skills/$SUBSERVICE/

## Workflow
(numbered 5-step sequence for this subservice)

## Key Rules
(3-4 regulation/calculation facts used in 80% of sessions — include numbers)

## Schemes
(active schemes with FSI/eligibility snapshot — one line each)

## Tools
(which MCP or script for which task — practical mapping)

## Common Mistakes
(top 3 gotchas from methodology pages)

Be dense and practical. No fluff.
PRIMEREOF

    cd "$WIKI_HOME" && claude -p "$(cat "$PTMP")" --dangerously-skip-permissions 2>/dev/null > "$PRIMER_FILE"
    rm -f "$PTMP"
    echo "[$SERVICE_NAME Wiki] Primer: $SUBSERVICE done."
  done
  echo "[$SERVICE_NAME Wiki] All primers complete."
  exit 0
fi

case "$ACTION" in
  compile)
    PROMPT="You are the $SERVICE_NAME wiki compiler at $WIKI_HOME. This is a TEAM wiki with skills/candidate tiers.

RAW SESSION LOGS:
$RAW_CONTENT

CURRENT INDEX:
$INDEX_CONTENT

SUBSERVICES REGISTRY:
$SUBSERVICES_CONTENT

COMPILE IN 5 PHASES:

Phase 1 ANALYZE: Read raw logs. List every discrete fact, decision, project, regulation, calculation, meeting, scheme choice, or pattern.

Phase 2 SCAN: Read existing wiki pages in $WIKI_PAGES/. Note overlaps and conflicts.

Phase 3 UPDATE — THREE-QUESTION ROUTING:

FIRST — load $WIKI_PAGES/subservices.md. Each subservice declares authority_mode: 'single' or 'multi'.

FOR EACH FACT ASK:
  Q1: Blast radius? (low → direct write. high → candidate/)
  Q2: Which subservice? (check registry)
  Q3: If multi-authority — which authority? ('shared' for cross-authority facts)

ROUTE A — DIRECT WRITE (low blast radius, specific facts):

  Projects (subservice-scoped):
    $WIKI_PAGES/projects/{subservice}/{slug}.md
    For multi-authority: include authority: {auth} in frontmatter
    Example: 'Sai Alba plot is 752.9 sqm' → projects/{subservice}/sai-alba.md

  Cross-subservice flat:
    $WIKI_PAGES/clients/{slug}.md
    $WIKI_PAGES/meetings/{slug}.md
    $WIKI_PAGES/decisions/{slug}.md
    $WIKI_PAGES/patterns/{slug}.md
    $WIKI_PAGES/research/{slug}.md
    $WIKI_PAGES/ideas/{slug}.md

ROUTE B — CANDIDATE (high blast radius, generalizable claims awaiting human review):

  Single-authority subservice:
    $WIKI_PAGES/candidate/{subservice}/{category}/{slug}.md

  Multi-authority subservice:
    $WIKI_PAGES/candidate/{subservice}/{authority}/{category}/{slug}.md

  Categories: regulations | methodology | tools | schemes
  These NEVER go to skills/ directly — user promotes manually via 'spsb'.

CANDIDATE FRONTMATTER (required):
---
awaiting_promotion: true
detected_on: $(date +%Y-%m-%d)
subservice: {subservice}
authority: {auth, omit for single-auth}
category: {cat}
---

SKILLS LOCK:
- NEVER write to $WIKI_PAGES/skills/ — these have 'locked: true'
- If fact matches existing skills/ page: don't modify. Create candidate noting 'update candidate for skills/{path}'.

PATTERN DETECTION:
After direct writes, scan projects/{subservice}/ pages. If same generalizable fact appears in 3+ projects of same subservice (+same authority if multi-auth), create:
  Single: candidate/{subservice}/methodology/pattern-{slug}.md
  Multi:  candidate/{subservice}/{auth}/methodology/pattern-{slug}.md

ATTRIBUTION (required in every fact):
- Raw log frontmatter has: user:, machine:, session_id:, session: (date)
- Every fact: - Fact text [source: YYYY-MM-DD | user@machine | session: {8-char-id}]

PAGE TEMPLATE (direct-write):
---
awaiting_promotion: false
---
# Page Title
> Category: {cat} | Last updated: $(date +%Y-%m-%d) | Confidence: high/medium/low
- Fact [source: YYYY-MM-DD | user@machine | session: id]
## Related
- [[other-page]]

CONFLICT RULES:
- Non-locked page conflict: add [!contradiction], keep both, note newer.
- Skills/ locked match: if IDENTICAL, skip. If DIFFERENT, create candidate 'Potential conflict with skills/{path}'.
- Multiple users confirming: keep all sources (higher confidence).

Phase 4 QUALITY GATE: Verify every fact traces to a raw log. Remove unsourced inferences.

Phase 5 REPORT:
- Rewrite $WIKI_PAGES/index.md (organized by subservice + category)
- Rewrite $WIKI_PAGES/hot.md (~500 words recent context)
- Append compile report to $WIKI_PAGES/log.md
- Move processed logs to $WIKI_RAW/processed/: $LOGS_TO_PROCESS (NOT active session)
- Reset counter: echo 0 > $WIKI_STATE/counter.txt
- Update: date > $WIKI_STATE/last_compile.txt

Execute all 5 phases now."
    ;;

  lint)
    PROMPT="You are the $SERVICE_NAME wiki linter at $WIKI_HOME.

CURRENT INDEX:
$INDEX_CONTENT

LINT:
1. Read ALL wiki pages
2. Find contradictions — add [!contradiction] markers
3. Flag stale pages (>30 days)
4. Find orphan pages (not in index) — add to index
5. Find missing pages (referenced via [[link]]) — create stubs
6. Fix broken cross-references
7. Verify every page follows template format
8. Verify skills/ pages all have 'locked: true'
9. Verify candidate/ pages all have 'awaiting_promotion: true'
10. Append lint report to $WIKI_PAGES/log.md
11. Update: date > $WIKI_STATE/last_lint.txt

Execute now."
    ;;

  restructure)
    PROMPT="You are the $SERVICE_NAME wiki restructurer at $WIKI_HOME.

CURRENT INDEX:
$INDEX_CONTENT

RESTRUCTURE:
1. Read ALL wiki pages
2. Analyze category fit across subservices
3. Merge small overlapping pages
4. Split large multi-topic pages
5. Move matured pages (e.g. candidate/ promoted items, ideas/ → methodology/)
6. Full index.md rebuild
7. Rewrite hot.md
8. Append restructure report to log.md

Execute now."
    ;;

  *)
    echo "Usage: wiki-compile.sh [compile|lint|restructure]"
    exit 1
    ;;
esac

echo "[$SERVICE_NAME Wiki] Running $ACTION via claude -p..."

PROMPT_FILE=$(mktemp)
echo "$PROMPT" > "$PROMPT_FILE"

# Do NOT cd into wiki — it creates a session with .claude/wiki as cwd, polluting project dirs
claude -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions 2>/dev/null

rm -f "$PROMPT_FILE"
echo "[$SERVICE_NAME Wiki] $ACTION complete."

# After compile, regenerate session primers in background
[ "$ACTION" = "compile" ] && bash "$0" primer > "$WIKI_STATE/last_primer_log.txt" 2>&1 &
