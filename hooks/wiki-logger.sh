#!/bin/bash
# PostToolUse hook (SERVICES) — injects session_id + nudges capture every 5 tools

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CLAUDE_HOME="$USERPROFILE/.claude"
LOCAL_CLAUDE="$PROJECT_DIR/.claude"
WIKI_HOME="$LOCAL_CLAUDE/wiki"
WIKI_STATE="$WIKI_HOME/_state"
TIME=$(date +%H:%M)

[ ! -d "$WIKI_HOME" ] && exit 0

MSG_COUNTER_FILE="$WIKI_STATE/msg_counter.txt"
MSG_COUNT=0
[ -f "$MSG_COUNTER_FILE" ] && MSG_COUNT=$(cat "$MSG_COUNTER_FILE" 2>/dev/null | tr -d '[:space:]')
[[ "$MSG_COUNT" =~ ^[0-9]+$ ]] || MSG_COUNT=0
MSG_COUNT=$((MSG_COUNT + 1))
echo "$MSG_COUNT" > "$MSG_COUNTER_FILE"

HOOK_JSON=$(cat)
TOOL_NAME=$(echo "$HOOK_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
SESSION_ID=$(echo "$HOOK_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id',''))" 2>/dev/null)

RAW_LOG=""
[ -f "$WIKI_STATE/current_rawlog.txt" ] && RAW_LOG=$(cat "$WIKI_STATE/current_rawlog.txt" 2>/dev/null | tr -d '\n\r')
[ -z "$RAW_LOG" ] || [ ! -f "$RAW_LOG" ] && exit 0

# Inject session_id on first tool call
if [ -n "$SESSION_ID" ] && ! grep -q "session_id:" "$RAW_LOG" 2>/dev/null; then
  python3 -c "
import sys
lines = open(r'$RAW_LOG', encoding='utf-8').readlines()
found_first = False
out = []
for line in lines:
    if line.strip() == '---' and found_first:
        out.append('session_id: $SESSION_ID\n')
        out.append(line)
        found_first = None
    elif line.strip() == '---' and not found_first:
        out.append(line)
        found_first = True
    else:
        out.append(line)
open(r'$RAW_LOG', 'w', encoding='utf-8').writelines(out)
" 2>/dev/null
fi

[ -n "$TOOL_NAME" ] && echo "- [$TIME] Tool: $TOOL_NAME" >> "$RAW_LOG"

# Every 5 tool calls — nudge capture
if [ "$((MSG_COUNT % 5))" -eq 0 ]; then
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"WIKI_LOG_NOW: $MSG_COUNT tool calls. Append 2-3 bullet points of recent decisions/facts to the raw log. Do this silently.\"}}"
fi
