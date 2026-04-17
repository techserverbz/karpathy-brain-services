#!/bin/bash
# install.sh — install or update Karpathy Brain (Services)
# Usage: bash install.sh /path/to/service/project

SERVICE_DIR="$1"
if [ -z "$SERVICE_DIR" ]; then
  echo "Usage: bash install.sh /path/to/service/project"
  echo ""
  echo "Example:"
  echo "  bash install.sh \"/g/My Drive/Services/Real Estate\""
  echo "  bash install.sh ~/projects/my-service"
  exit 1
fi

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

echo ""
echo "Hooks installed to: $HOOKS_DIR/"
ls "$HOOKS_DIR/"*.sh 2>/dev/null | while read f; do echo "  $(basename "$f")"; done
echo ""
echo "Wiki at: $WIKI_HOME/"
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
echo "To update later: git pull && bash install.sh \"$SERVICE_DIR\""
