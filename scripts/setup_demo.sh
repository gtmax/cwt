#!/usr/bin/env bash
# setup_demo.sh — Create a self-contained demo repo for wotr.
#
# Usage:
#   scripts/setup_demo.sh [dir]    # creates ./wotr-demo/ (or specified dir)
#   cd wotr-demo && wotr           # launch the TUI
#
# Cleanup:
#   rm -rf wotr-demo/ .worktrees/wotr-demo/
set -e

DEMO_DIR="${1:-my-app}"

# ── Cleanup ────────────────────────────────────────────────────────────────────

if [ -d "$DEMO_DIR" ]; then
  rm -rf "$(dirname "$DEMO_DIR")/.worktrees/$(basename "$DEMO_DIR")" 2>/dev/null || true
  rm -rf "$DEMO_DIR"
fi

# ── Create repo ───────────────────────────────────────────────────────────────

echo "🌊 Setting up wotr demo..."
echo

mkdir -p "$DEMO_DIR"
cd "$DEMO_DIR"

git init -q
git config user.email "demo@wotr.dev"
git config user.name "Demo User"

# ── Project files ─────────────────────────────────────────────────────────────

cat > README.md << 'EOF'
# My App

A demo project for wotr.
EOF

cat > server.py << 'PYEOF'
#!/usr/bin/env python3
"""Tiny HTTP server for demo purposes."""
import http.server, os
PORT = int(os.environ.get("PORT", "8080"))
class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/plain")
        self.end_headers()
        branch = os.popen("git rev-parse --abbrev-ref HEAD 2>/dev/null").read().strip()
        self.wfile.write(f"Hello from {branch}!\n".encode())
    def log_message(self, *args): pass
if __name__ == "__main__":
    print(f"Server running on port {PORT}")
    http.server.HTTPServer(("", PORT), Handler).serve_forever()
PYEOF
chmod +x server.py

cat > run_tests.sh << 'TESTEOF'
#!/usr/bin/env bash
echo "Running tests..."
sleep 0.5
echo "  ✓ test_login (0.2s)"
sleep 0.2
echo "  ✓ test_signup (0.4s)"
sleep 0.2
echo "  ✓ test_dashboard (0.3s)"
sleep 0.1
echo ""
echo "3 tests passed, 0 failed"
TESTEOF
chmod +x run_tests.sh

cp .env.example .env 2>/dev/null || echo "DATABASE_URL=postgres://localhost/myapp" > .env

git add -A
git commit -q -m "Initial commit: app skeleton"

# ── .wotr/config ──────────────────────────────────────────────────────────────

mkdir -p .wotr

cat > .wotr/config << 'WOTREOF'
hooks:
  new:
    - bg: |
        echo "Installing dependencies..."
        sleep 0.8
        echo "  ✓ 42 packages installed"
        sleep 0.3
        echo "Symlinking .env..."
        sleep 0.3
        echo "  ✓ .env ready"
        echo "Preparing Claude session..."
        bash "$WOTR_ROOT/.demo-seed-claude"

  switch:
    - fg: CLAUDE_CODE_USE_BEDROCK=1 claude --continue

actions:
  test:
    key: t
    steps:
      - bg: bash run_tests.sh

resources:
  web-server:
    icon: 💻
    exclusive: true
    description: Dev server (port 8080)
    acquire: |
      pid=$(lsof -ti :8080 -sTCP:LISTEN 2>/dev/null)
      [ -n "$pid" ] && kill "$pid" 2>/dev/null && sleep 0.3
      nohup python3 server.py > /dev/null 2>&1 &
      echo "Server started on port 8080"
    inquire: |
      pid=$(lsof -ti :8080 -sTCP:LISTEN 2>/dev/null | head -1)
      if [ -z "$pid" ]; then
        wotr-output status=unowned
        exit 0
      fi
      cwd=$(lsof -p "$pid" -a -d cwd -Fn 2>/dev/null | grep '^n' | sed 's/^n//')
      root="$cwd"
      while [ "$root" != "/" ] && [ ! -e "$root/.git" ]; do
        root=$(dirname "$root")
      done
      wotr-output status=owned owner="$root"

  db-schema:
    icon: 💾
    exclusive: false
    description: Database migrations
    acquire: |
      echo "Applying migrations..."
      sleep 0.3
      echo "  ✓ 001_create_users"
      sleep 0.2
      echo "  ✓ 002_add_email"
      echo "All migrations applied."
      touch .migrations_applied
    inquire: |
      if [ -f "$WOTR_WORKTREE/.migrations_applied" ]; then
        wotr-output status=compatible
      else
        wotr-output status=incompatible reason="pending migrations"
      fi
WOTREOF

# Demo seed script — pre-seeds Claude conversation transcripts
cat > .demo-seed-claude << 'SEEDEOF'
#!/bin/bash
# Seeds a Claude Code conversation transcript for the current worktree.
# Called from the switch hook before wotr-launch-claude.

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
CWD=$(pwd -P)
ENCODED=$(echo "$CWD" | tr -c 'a-zA-Z0-9-\n' '-')
PROJECT_DIR="$HOME/.claude/projects/$ENCODED"
SESSION_ID=$(python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || echo "00000000-0000-0000-0000-$(date +%s)")
JSONL="$PROJECT_DIR/$SESSION_ID.jsonl"

# Already seeded — skip
[ -f "$JSONL" ] && exit 0

# Pre-trust this directory in Claude's ~/.claude.json
python3 -c "
import json
path = '$CWD'
f = '$HOME/.claude.json'
try:
    data = json.load(open(f))
except:
    data = {}
data.setdefault('projects', {}).setdefault(path, {})['hasTrustDialogAccepted'] = True
json.dump(data, open(f, 'w'))
" 2>/dev/null || true

mkdir -p "$PROJECT_DIR"

TS=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

# Pick conversation based on branch name
case "$BRANCH" in
  feat/user-auth)
    USER_MSG="Add JWT authentication to the login endpoint"
    ASST_MSG="I'll set up JWT auth for the login endpoint. Let me start by reading the current route handlers to understand the structure.\n\nLooking at \`src/routes/login.ts\`..."
    ;;
  fix/api-timeout)
    USER_MSG="The /api/users endpoint is timing out at 30s, find and fix the bottleneck"
    ASST_MSG="I'll investigate the timeout issue. Let me check the database queries in the users endpoint for missing indexes or N+1 problems.\n\nLooking at \`src/api/users.ts\`..."
    ;;
  *)
    USER_MSG="Help me with this branch: $BRANCH"
    ASST_MSG="I'll take a look at what needs to be done on this branch."
    ;;
esac

# Write user message
cat >> "$JSONL" << MSGEOF
{"parentUuid":null,"isSidechain":false,"userType":"external","cwd":"$CWD","sessionId":"$SESSION_ID","version":"2.1.76","gitBranch":"$BRANCH","type":"user","message":{"role":"user","content":"$USER_MSG"},"uuid":"msg-user-001","timestamp":"$TS"}
MSGEOF

# Write assistant response
cat >> "$JSONL" << MSGEOF
{"parentUuid":"msg-user-001","isSidechain":false,"userType":"external","cwd":"$CWD","sessionId":"$SESSION_ID","version":"2.1.76","gitBranch":"$BRANCH","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"$ASST_MSG"}],"model":"claude-sonnet-4-20250514","stop_reason":"end_turn"},"uuid":"msg-asst-001","timestamp":"$TS"}
MSGEOF

SEEDEOF
chmod +x .demo-seed-claude

git add -A
git commit -q -m "Add wotr config and demo scripts"

# Set WOTR_START_POINT so worktree creation doesn't try to fetch from origin
# (demo repo has no remote)
echo 'export WOTR_START_POINT=main' >> .envrc 2>/dev/null || true

echo "✨ Demo ready!"
echo "  cd $(pwd)"
echo "  export WOTR_START_POINT=main"
echo "  wotr"
