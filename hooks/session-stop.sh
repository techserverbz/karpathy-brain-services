#!/bin/bash
# Stop hook (SERVICES) — extract conversation + finalize raw log

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CLAUDE_HOME="$USERPROFILE/.claude"
LOCAL_CLAUDE="$PROJECT_DIR/.claude"
WIKI_HOME="$LOCAL_CLAUDE/wiki"
WIKI_STATE="$WIKI_HOME/_state"
WIKI_RAW="$WIKI_HOME/raw"
SERVICE_NAME=$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
TODAY=$(date +%Y-%m-%d)
TIME=$(date +%H:%M)
SESSION_TS=$(date +%Y-%m-%d-%H-%M)

SESSION_JSON=$(cat)
SESSION_ID=$(echo "$SESSION_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id',''))" 2>/dev/null)
CWD=$(echo "$SESSION_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd','unknown'))" 2>/dev/null)

[ -z "$SESSION_ID" ] && exit 0
[ ! -d "$WIKI_HOME" ] && exit 0

LAST_SID=""
[ -f "$WIKI_STATE/last_session_id.txt" ] && LAST_SID=$(cat "$WIKI_STATE/last_session_id.txt" 2>/dev/null | tr -d '[:space:]')
if [ "${SESSION_ID:0:8}" = "$LAST_SID" ]; then
  exit 0
fi
echo "${SESSION_ID:0:8}" > "$WIKI_STATE/last_session_id.txt"

RAW_LOG=""
[ -f "$WIKI_STATE/current_rawlog.txt" ] && RAW_LOG=$(cat "$WIKI_STATE/current_rawlog.txt" 2>/dev/null | tr -d '[:space:]')
if [ -z "$RAW_LOG" ] || [ ! -f "$RAW_LOG" ]; then
  RAW_LOG=$(ls -t "$WIKI_RAW"/${TODAY}*.md 2>/dev/null | head -1)
fi

JSONL_FILE=""
for projdir in "$CLAUDE_HOME/projects"/*/; do
  if [ -f "${projdir}${SESSION_ID}.jsonl" ]; then
    JSONL_FILE="${projdir}${SESSION_ID}.jsonl"
    break
  fi
done

CONVERSATION=""
if [ -n "$JSONL_FILE" ] && [ -f "$JSONL_FILE" ]; then
  CONVERSATION=$(python3 -c "
import json, sys
try:
    with open(r'$JSONL_FILE', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()
except Exception:
    sys.exit(0)
out = []
for line in lines:
    try:
        e = json.loads(line)
        if e.get('type') in ('user', 'human'):
            content = e.get('message',{}).get('content','')
            if isinstance(content, list):
                text = ' '.join(b.get('text','') for b in content if b.get('type')=='text')
            else:
                text = str(content)
            text = text.strip()
            if text and len(text) > 2 and not text.startswith('{'):
                out.append('> ' + text[:200])
        elif e.get('type') == 'assistant':
            blocks = e.get('message',{}).get('content',[])
            if isinstance(blocks, list):
                texts = [b.get('text','') for b in blocks if isinstance(b,dict) and b.get('type')=='text' and b.get('text')]
                if texts:
                    combined = ' '.join(texts)[:300]
                    out.append('- ' + combined)
    except Exception:
        pass
print('\n'.join(out[-20:])[:2000])
" 2>/dev/null)
fi

USER_NAME="${USERNAME:-$USER}"
[ -z "$USER_NAME" ] && USER_NAME=$(whoami 2>/dev/null | tr -d '[:space:]')
[ -z "$USER_NAME" ] && USER_NAME="unknown"
MACHINE_NAME="${COMPUTERNAME:-$(hostname 2>/dev/null | tr -d '[:space:]')}"
[ -z "$MACHINE_NAME" ] && MACHINE_NAME="unknown"

if [ -n "$RAW_LOG" ] && [ -f "$RAW_LOG" ]; then
  if [ -n "$CONVERSATION" ]; then
    printf '\n## [%s] Conversation (auto-extracted)\n%s\n' "$TIME" "$CONVERSATION" >> "$RAW_LOG"
  fi
  printf '\n---\nsession_end: %s\nsession_id: %s\n' "$TIME" "${SESSION_ID:0:8}" >> "$RAW_LOG"
else
  RAW_LOG="$WIKI_RAW/$SESSION_TS.md"
  printf -- '---\nsession: %s\ncwd: %s\nservice: %s\nuser: %s\nmachine: %s\nsession_id: %s\n---\n' "$SESSION_TS" "$CWD" "$SERVICE_NAME" "$USER_NAME" "$MACHINE_NAME" "${SESSION_ID:0:8}" > "$RAW_LOG"
  if [ -n "$CONVERSATION" ]; then
    printf '\n## [%s] Conversation (auto-extracted)\n%s\n' "$TIME" "$CONVERSATION" >> "$RAW_LOG"
  fi
fi

TOTAL=0
[ -f "$WIKI_STATE/total_counter.txt" ] && TOTAL=$(cat "$WIKI_STATE/total_counter.txt" 2>/dev/null | tr -d '[:space:]')
[[ "$TOTAL" =~ ^[0-9]+$ ]] || TOTAL=0
echo $((TOTAL + 1)) > "$WIKI_STATE/total_counter.txt"

exit 0
