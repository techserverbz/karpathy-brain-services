#!/bin/bash
# register-subservice.sh — create matching folders in wiki + assets
#
# Usage:
#   Subservice:
#     bash .claude/hooks/register-subservice.sh subservice {slug} {single|multi}
#
#   Authority (under multi-auth subservice):
#     bash .claude/hooks/register-subservice.sh authority {subservice} {auth-slug} {AuthorityName}
#
#   Scheme folder in assets:
#     bash .claude/hooks/register-subservice.sh scheme {subservice} {AuthorityName} {SchemeName}

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOCAL_CLAUDE="$PROJECT_DIR/.claude"
WIKI_PAGES="$LOCAL_CLAUDE/wiki/wiki"
ASSETS="$LOCAL_CLAUDE/assets"

ACTION="$1"
shift

CATS="regulations methodology tools schemes"

case "$ACTION" in
  subservice)
    SLUG="$1"
    MODE="${2:-single}"
    if [ -z "$SLUG" ]; then
      echo "Usage: register-subservice.sh subservice {slug} {single|multi}"
      exit 1
    fi
    echo "[register] Creating subservice: $SLUG (authority_mode: $MODE)"

    if [ "$MODE" = "multi" ]; then
      mkdir -p "$WIKI_PAGES/skills/$SLUG/shared" \
               "$WIKI_PAGES/candidate/$SLUG/shared" \
               "$WIKI_PAGES/projects/$SLUG"
      for cat in $CATS; do
        mkdir -p "$WIKI_PAGES/skills/$SLUG/shared/$cat" \
                 "$WIKI_PAGES/candidate/$SLUG/shared/$cat"
      done
      echo "[register] Multi-authority subservice created."
      echo "[register] Next: add authorities via 'register-subservice.sh authority $SLUG {auth-slug} {AuthorityName}'"
    else
      for cat in $CATS; do
        mkdir -p "$WIKI_PAGES/skills/$SLUG/$cat" \
                 "$WIKI_PAGES/candidate/$SLUG/$cat"
      done
      mkdir -p "$WIKI_PAGES/projects/$SLUG"
      echo "[register] Single-authority subservice created."
    fi

    echo "[register] Remember to add the subservice entry to $WIKI_PAGES/subservices.md"
    ;;

  authority)
    SUBSERVICE="$1"
    AUTH_SLUG="$2"
    AUTH_NAME="$3"
    if [ -z "$SUBSERVICE" ] || [ -z "$AUTH_SLUG" ] || [ -z "$AUTH_NAME" ]; then
      echo "Usage: register-subservice.sh authority {subservice} {auth-slug} {AuthorityName}"
      exit 1
    fi

    for cat in $CATS; do
      mkdir -p "$WIKI_PAGES/skills/$SUBSERVICE/$AUTH_SLUG/$cat" \
               "$WIKI_PAGES/candidate/$SUBSERVICE/$AUTH_SLUG/$cat"
    done

    SUBSERVICE_CAP="$(echo ${SUBSERVICE:0:1} | tr '[:lower:]' '[:upper:]')${SUBSERVICE:1}"
    ASSETS_TARGET="$ASSETS/$SUBSERVICE_CAP/$AUTH_NAME"
    mkdir -p "$ASSETS_TARGET"

    echo "[register] Authority '$AUTH_NAME' added under '$SUBSERVICE'"
    echo "[register]   Wiki: skills/$SUBSERVICE/$AUTH_SLUG/{regulations,methodology,tools,schemes}/"
    echo "[register]   Assets: $SUBSERVICE_CAP/$AUTH_NAME/"
    echo "[register] Update $WIKI_PAGES/subservices.md with the new authority."
    ;;

  scheme)
    SUBSERVICE="$1"
    AUTH_NAME="$2"
    SCHEME="$3"
    if [ -z "$SUBSERVICE" ] || [ -z "$AUTH_NAME" ] || [ -z "$SCHEME" ]; then
      echo "Usage: register-subservice.sh scheme {subservice} {AuthorityName} {SchemeName}"
      exit 1
    fi
    SUBSERVICE_CAP="$(echo ${SUBSERVICE:0:1} | tr '[:lower:]' '[:upper:]')${SUBSERVICE:1}"
    TARGET="$ASSETS/$SUBSERVICE_CAP/$AUTH_NAME/$SCHEME"
    mkdir -p "$TARGET"
    echo "[register] Scheme folder created: $TARGET"
    ;;

  *)
    echo "Usage:"
    echo "  register-subservice.sh subservice {slug} {single|multi}"
    echo "  register-subservice.sh authority {subservice} {auth-slug} {AuthorityName}"
    echo "  register-subservice.sh scheme {subservice} {AuthorityName} {SchemeName}"
    exit 1
    ;;
esac
