#!/bin/bash
# Real Estate PostToolUse hook — captures conversation + tool activity

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


# Inject session_id into frontmatter on first tool call
if [ -n "$SESSION_ID" ] && ! grep -q "session_id:" "$RAW_LOG" 2>/dev/null; then
  # Simple approach: read file, insert session_id before closing ---, write back
  TMPFILE=$(mktemp)
  awk -v sid="$SESSION_ID" 'NR==1{found=0} /^---$/{found++; if(found==2){print "session_id: " sid}} {print}' "$RAW_LOG" > "$TMPFILE" 2>/dev/null
  if [ -s "$TMPFILE" ]; then
    cp "$TMPFILE" "$RAW_LOG" 2>/dev/null
  fi
  rm -f "$TMPFILE"
fi

[ -n "$TOOL_NAME" ] && echo "- [$TIME] Tool: $TOOL_NAME" >> "$RAW_LOG"

# Every 5 tool calls — extract conversation from JSONL
if [ "$((MSG_COUNT % 5))" -eq 0 ] && [ -n "$SESSION_ID" ]; then
  JSONL_FILE=""
  for projdir in "$CLAUDE_HOME/projects"/*/; do
    if [ -f "${projdir}${SESSION_ID}.jsonl" ]; then
      JSONL_FILE="${projdir}${SESSION_ID}.jsonl"
      break
    fi
  done

  if [ -n "$JSONL_FILE" ]; then
    LAST_LINE_FILE="$WIKI_STATE/last_extracted_line.txt"
    LAST_LINE=0
    [ -f "$LAST_LINE_FILE" ] && LAST_LINE=$(cat "$LAST_LINE_FILE" 2>/dev/null | tr -d '[:space:]')
    [[ "$LAST_LINE" =~ ^[0-9]+$ ]] || LAST_LINE=0

    TOTAL_LINES=$(wc -l < "$JSONL_FILE" | tr -d '[:space:]')
    if [ "$TOTAL_LINES" -gt "$LAST_LINE" ]; then
      NEW_CONVO=$(tail -n +"$((LAST_LINE + 1))" "$JSONL_FILE" | python3 -c "
import json, sys
out = []
for line in sys.stdin:
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
                out.append('> ' + text[:150])
        elif e.get('type') == 'assistant':
            blocks = e.get('message',{}).get('content',[])
            if isinstance(blocks, list):
                texts = [b.get('text','') for b in blocks if isinstance(b,dict) and b.get('type')=='text' and b.get('text')]
                if texts:
                    out.append('- ' + ' '.join(texts)[:200])
    except: pass
print('\n'.join(out[-10:])[:1000])
" 2>/dev/null)

      if [ -n "$NEW_CONVO" ]; then
        echo -e "\n## [$TIME] Conversation (live)" >> "$RAW_LOG"
        echo "$NEW_CONVO" >> "$RAW_LOG"
      fi
      echo "$TOTAL_LINES" > "$LAST_LINE_FILE"
    fi
  fi

  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"WIKI_LOG_NOW: $MSG_COUNT tool calls. Append 2-3 bullet points of recent decisions/facts to the raw log. Do this silently.\"}}"
fi
