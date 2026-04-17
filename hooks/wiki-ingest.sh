#!/bin/bash
# wiki-ingest.sh (SERVICES) — convert curated doc into locked skill pages
#
# Usage:
#   Single-authority subservice:
#     bash .claude/hooks/wiki-ingest.sh {subservice} {source-file}
#
#   Multi-authority subservice (authority required):
#     bash .claude/hooks/wiki-ingest.sh {subservice} {authority} {source-file}
#
# Writes to skills/ with locked: true + source attribution.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOCAL_CLAUDE="$PROJECT_DIR/.claude"
WIKI_HOME="$LOCAL_CLAUDE/wiki"
WIKI_PAGES="$WIKI_HOME/wiki"
ASSETS="$LOCAL_CLAUDE/assets"

SUBSERVICE="$1"
if [ -z "$SUBSERVICE" ]; then
  echo "Usage:"
  echo "  wiki-ingest.sh {subservice} {source-file}              # single-authority"
  echo "  wiki-ingest.sh {subservice} {authority} {source-file}  # multi-authority"
  exit 1
fi

# Detect authority_mode from subservices.md
AUTHORITY_MODE=$(grep -A5 "^### $SUBSERVICE\$" "$WIKI_PAGES/subservices.md" 2>/dev/null | grep 'authority_mode' | head -1 | sed 's/.*`\([^`]*\)`.*/\1/' | tr -d '[:space:]')
if [ -z "$AUTHORITY_MODE" ]; then
  echo "[ingest] Unknown subservice '$SUBSERVICE' — add it to $WIKI_PAGES/subservices.md first"
  echo "[ingest] Run: bash .claude/hooks/register-subservice.sh subservice $SUBSERVICE {single|multi}"
  exit 1
fi

if [ "$AUTHORITY_MODE" = "multi" ]; then
  AUTHORITY="$2"
  SOURCE_FILE="$3"
  if [ -z "$AUTHORITY" ] || [ -z "$SOURCE_FILE" ]; then
    echo "[ingest] '$SUBSERVICE' is multi-authority — need authority slug (e.g. sra, mcgm, shared)"
    echo "Usage: wiki-ingest.sh $SUBSERVICE {authority} {source-file}"
    exit 1
  fi
  WIKI_TARGET="$WIKI_PAGES/skills/$SUBSERVICE/$AUTHORITY"
  if [ ! -d "$WIKI_TARGET" ]; then
    echo "[ingest] Authority '$AUTHORITY' not registered under '$SUBSERVICE'"
    echo "[ingest] Run: bash .claude/hooks/register-subservice.sh authority $SUBSERVICE $AUTHORITY {AuthorityName}"
    exit 1
  fi
else
  AUTHORITY=""
  SOURCE_FILE="$2"
  if [ -z "$SOURCE_FILE" ]; then
    echo "[ingest] Usage: wiki-ingest.sh $SUBSERVICE {source-file}"
    exit 1
  fi
  WIKI_TARGET="$WIKI_PAGES/skills/$SUBSERVICE"
fi

if [ ! -f "$SOURCE_FILE" ]; then
  echo "[ingest] Source file not found: $SOURCE_FILE"
  exit 1
fi

SOURCE_BASENAME=$(basename "$SOURCE_FILE")
ASSETS_REL=""
if [[ "$SOURCE_FILE" == "$ASSETS/"* ]]; then
  ASSETS_REL="${SOURCE_FILE#$ASSETS/}"
fi

USER_NAME="${USERNAME:-$USER}"
[ -z "$USER_NAME" ] && USER_NAME=$(whoami 2>/dev/null | tr -d '[:space:]')
MACHINE_NAME="${COMPUTERNAME:-$(hostname 2>/dev/null | tr -d '[:space:]')}"
TODAY=$(date +%Y-%m-%d)

echo "[ingest] Subservice: $SUBSERVICE (authority_mode: $AUTHORITY_MODE)"
[ -n "$AUTHORITY" ] && echo "[ingest] Authority: $AUTHORITY"
echo "[ingest] Source: $SOURCE_BASENAME"
echo "[ingest] Target: $WIKI_TARGET"

PROMPT_FILE=$(mktemp)
cat > "$PROMPT_FILE" <<PROMPT
You are ingesting a curated reference document into the skills layer.

SOURCE FILE: $SOURCE_FILE
SUBSERVICE: $SUBSERVICE
AUTHORITY_MODE: $AUTHORITY_MODE
AUTHORITY: $AUTHORITY
TODAY: $TODAY
USER: $USER_NAME
MACHINE: $MACHINE_NAME
ASSETS_REF: $ASSETS_REL
WIKI_TARGET_BASE: $WIKI_TARGET

TASK: Read source completely, split into focused skill pages under \$WIKI_TARGET_BASE/{category}/{slug}.md. Source is CURATED — pages go directly to skills/ with locked: true, bypassing candidate gate.

STEP 1 — READ source: $SOURCE_FILE
STEP 2 — IDENTIFY natural sections. Categories: regulations/, methodology/, tools/, schemes/
STEP 3 — WRITE each focused page
STEP 4 — WRITE master index: \$WIKI_TARGET_BASE/schemes/{scheme-slug}.md (links to sub-pages)

PAGE FORMAT (required):
---
locked: true
ingested_on: $TODAY
ingested_by: $USER_NAME@$MACHINE_NAME
source_file: $SOURCE_BASENAME
source_path: $SOURCE_FILE
assets_ref: $ASSETS_REL
subservice: $SUBSERVICE
$([ -n "$AUTHORITY" ] && echo "authority: $AUTHORITY")
category: {regulations|methodology|tools|schemes}
---

# Page Title
> Subservice: $SUBSERVICE$([ -n "$AUTHORITY" ] && echo " | Authority: $AUTHORITY") | Category: {cat} | Confidence: verified

Content derived from source. Preserve tables, formulas, exact numbers.

## Source
See \\\`$ASSETS_REL\\\` for the authoritative document.

## Related
- [[other-page]]

RULES:
1. Every page has locked: true — bypasses candidate review.
2. One topic per page. Keep focused.
3. Preserve tables, formulas, exact numbers — do NOT paraphrase.
4. Cross-link via relative [[...]] refs.
5. Master page lists ALL sub-pages with one-line descriptions.
6. Append to $WIKI_PAGES/log.md: date, source, pages created.
7. Update $WIKI_PAGES/index.md under the correct subservice section.

Execute now.
PROMPT

cd "$WIKI_HOME" && claude -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions

rm -f "$PROMPT_FILE"
echo "[ingest] Done. Review: ls '$WIKI_TARGET'"
