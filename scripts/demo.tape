# wotr demo — generates an animated GIF for the README
#
# Prerequisites:
#   Build vhs with subtitle support: cd /Users/max/dev/vhs && go build -o vhs-dev .
#   Set up demo repo: bash /Users/max/dev/wotr/scripts/setup_demo.sh /tmp/my-app
#
# Generate:
#   cd /tmp/my-app && export WOTR_START_POINT=main && vhs-dev /path/to/demo.tape

Output demo.gif

Require wotr

Set Shell zsh
Set FontSize 14
Set Width 1200
Set Height 650
Set Padding 8
Set Theme "Dracula"
Set TypingSpeed 50ms
Set WindowBar Colorful
Set WindowBarSize 40

Set SubtitleFontSize 20
Set SubtitleColor "#ffffff"
Set SubtitleBackground "rgba(0,0,0,0.8)"
Set SubtitlePadding 8
Set SubtitleBorderRadius 6
Set SubtitlePosition "bottom"

Env WOTR_START_POINT main

# ── Scene 1: Launch ──────────────────────────────────────────────────────────

Subtitle "🌊 wotr 🌊 the worktree manager"
Type "wotr"
Sleep 500ms
Enter
Sleep 3s

# ── Scene 2: Create first worktree ───────────────────────────────────────────

Subtitle "One keypress to create a new worktree"
Sleep 1500ms
Type "n"
Sleep 800ms

Type "feat/user-auth"
Sleep 500ms
Enter

Subtitle "Custom project hooks run for new worktree setup"
Sleep 5s

# Claude launches with pre-seeded conversation
Subtitle "Each worktree gets its own agentic session"
Sleep 5s

# Exit Claude
Type "exit"
Enter
Sleep 2s

# ── Scene 3: Create second worktree ──────────────────────────────────────────

Subtitle "Work on multiple things in parallel in the same repo"
Sleep 2s

Type "n"
Sleep 600ms
Type "fix/api-timeout"
Sleep 500ms
Enter

Subtitle "Each session is fully independent"
Sleep 5s

# Claude launches with different pre-seeded conversation
Sleep 5s

# Exit Claude
Type "exit"
Enter
Sleep 2s

# ── Scene 4: Session persistence ─────────────────────────────────────────────

Subtitle "Come back anytime — your conversation is right where you left it"
Sleep 2s

# Navigate to first worktree
Type "j"
Sleep 300ms
Enter

# Claude shows the previous conversation
Sleep 6s

# Exit Claude
Type "exit"
Enter
Sleep 2s

# ── Scene 5: Resource management ─────────────────────────────────────────────

Subtitle "Custom-defined resources (servers, db-schemas,...) move between worktrees with a keypress"
Sleep 4s

Type "w"
Sleep 3s

Type "b"
Sleep 3s

Subtitle "💻 web-server and 💾 db-schema now belong to feat/user-auth"
Sleep 4s

# ── Scene 6: Run tests action ────────────────────────────────────────────────

Subtitle "Custom actions run commands (tests, editor, ...) against any worktree"
Sleep 1s
Type "t"
Sleep 5s

# ── Scene 7: End ─────────────────────────────────────────────────────────────

Subtitle "🌊 be wotr, my friend 🌊"
Sleep 3s
