#!/bin/bash
# install.sh — install or update Karpathy Brain (Services)
# Usage: bash install.sh /path/to/service/project

SERVICE_DIR="$1"
if [ -z "$SERVICE_DIR" ]; then
  echo "Usage: bash install.sh /path/to/service/project"
  echo "       bash install.sh /path/to/service/project/.claude"
  echo ""
  echo "Example:"
  echo "  bash install.sh \"/g/My Drive/Real Estate\""
  echo "  bash install.sh \"/g/My Drive/Real Estate/.claude\""
  exit 1
fi

# Normalize backslashes to forward slashes (Windows paths from Explorer come with \)
SERVICE_DIR="${SERVICE_DIR//\\//}"

# Strip trailing slash (any) so /.claude pattern matching is consistent
SERVICE_DIR="${SERVICE_DIR%/}"

# If user passed the .claude path directly, strip it to get the project root
case "$SERVICE_DIR" in
  */.claude) SERVICE_DIR="${SERVICE_DIR%/.claude}" ;;
esac

if [ ! -d "$SERVICE_DIR" ]; then
  echo "Directory not found: $SERVICE_DIR"
  exit 1
fi

LOCAL_CLAUDE="$SERVICE_DIR/.claude"
WIKI_HOME="$LOCAL_CLAUDE/wiki"
HOOKS_DIR="$LOCAL_CLAUDE/hooks"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Karpathy Brain — Services Install ==="
echo "Service: $SERVICE_DIR"

# --- Capture git metadata from the clone (for sync log) ---
GIT_COMMIT="unknown"
GIT_COMMIT_DATE="unknown"
GIT_COMMIT_MSG="unknown"
GIT_REMOTE="unknown"
if [ -d "$SCRIPT_DIR/.git" ]; then
  GIT_COMMIT=$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null | head -c 40)
  GIT_COMMIT_DATE=$(git -C "$SCRIPT_DIR" log -1 --format=%cI 2>/dev/null)
  GIT_COMMIT_MSG=$(git -C "$SCRIPT_DIR" log -1 --format=%s 2>/dev/null)
  GIT_REMOTE=$(git -C "$SCRIPT_DIR" config --get remote.origin.url 2>/dev/null)
fi

INSTALLED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
USER_NAME="${USERNAME:-$USER}"
[ -z "$USER_NAME" ] && USER_NAME=$(whoami 2>/dev/null | tr -d '[:space:]')
MACHINE_NAME="${COMPUTERNAME:-$(hostname 2>/dev/null | tr -d '[:space:]')}"
SERVICE_NAME=$(basename "$SERVICE_DIR")

# Create structure
mkdir -p "$WIKI_HOME"/{raw/processed,wiki/{skills,candidate,projects,clients,meetings,decisions,patterns,research,ideas,archive},_state}
mkdir -p "$HOOKS_DIR"
mkdir -p "$LOCAL_CLAUDE"/{skills,assets}

# Copy hooks (overwrites — this IS the update mechanism)
cp "$SCRIPT_DIR/hooks/"*.sh "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/"*.sh 2>/dev/null

# Seed wiki files only if they don't exist
[ ! -f "$WIKI_HOME/wiki/index.md" ] && echo "# Wiki Index" > "$WIKI_HOME/wiki/index.md"
[ ! -f "$WIKI_HOME/wiki/hot.md" ] && echo "# Recent Context" > "$WIKI_HOME/wiki/hot.md"
[ ! -f "$WIKI_HOME/wiki/log.md" ] && echo "# Wiki Operations Log" > "$WIKI_HOME/wiki/log.md"
[ ! -f "$WIKI_HOME/_state/counter.txt" ] && echo "0" > "$WIKI_HOME/_state/counter.txt"
[ ! -f "$WIKI_HOME/_state/total_counter.txt" ] && echo "0" > "$WIKI_HOME/_state/total_counter.txt"

# Copy subservices template only if doesn't exist
if [ ! -f "$WIKI_HOME/wiki/subservices.md" ]; then
  cp "$SCRIPT_DIR/subservices.md.template" "$WIKI_HOME/wiki/subservices.md"
  echo "Created subservices.md — edit it to register your subservices"
fi

# --- Write sync log (overwrites current state) ---
# Services wiki goes on Google Drive, so every teammate sees who last updated + from which commit
SYNC_LOG="$WIKI_HOME/_state/karpathy_sync.json"
cat > "$SYNC_LOG" <<EOF
{
  "flavour": "services",
  "service_name": "$SERVICE_NAME",
  "service_dir": "$SERVICE_DIR",
  "installed_at": "$INSTALLED_AT",
  "installed_by": "$USER_NAME@$MACHINE_NAME",
  "git_commit": "$GIT_COMMIT",
  "git_commit_short": "${GIT_COMMIT:0:7}",
  "git_commit_date": "$GIT_COMMIT_DATE",
  "git_commit_message": "$GIT_COMMIT_MSG",
  "git_remote": "$GIT_REMOTE",
  "script_dir": "$SCRIPT_DIR"
}
EOF

# --- Append install entry to history log (visible to whole team on Drive) ---
HISTORY_LOG="$WIKI_HOME/_state/karpathy_sync_history.log"
printf '%s | commit=%s | %s | by=%s@%s\n' \
  "$INSTALLED_AT" "${GIT_COMMIT:0:7}" "$GIT_COMMIT_MSG" "$USER_NAME" "$MACHINE_NAME" >> "$HISTORY_LOG"

echo ""
echo "Hooks installed to: $HOOKS_DIR/"
ls "$HOOKS_DIR/"*.sh 2>/dev/null | while read f; do echo "  $(basename "$f")"; done
echo ""
echo "Wiki at: $WIKI_HOME/"
echo ""
echo "Sync log:"
echo "  Commit: ${GIT_COMMIT:0:7} ($GIT_COMMIT_DATE)"
echo "  Message: $GIT_COMMIT_MSG"
echo "  State:   $SYNC_LOG"
echo "  History: $HISTORY_LOG"
echo ""
echo "Next steps:"
echo "  1. Edit $WIKI_HOME/wiki/subservices.md with your subservices"
echo "  2. Register subservices:"
echo "     cd \"$SERVICE_DIR\""
echo "     bash .claude/hooks/register-subservice.sh subservice {name} {single|multi}"
echo "  3. Add hooks to ~/.claude/settings.json (see README.md)"
echo "  4. Paste CLAUDEMD-SNIPPET.md into $SERVICE_DIR/CLAUDE.md"
echo "  5. Restart Claude Code"
echo ""
echo "To check when you (or teammate) last updated: cat '$SYNC_LOG'"
echo "To see full sync history:                     cat '$HISTORY_LOG'"
echo "To update later: git pull && bash install.sh \"$SERVICE_DIR\""
