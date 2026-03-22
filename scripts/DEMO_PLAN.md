# wotr Demo GIF Plan

## Prerequisites
- VHS with subtitle support (fork at /Users/max/dev/vhs)
- Demo repo created via `scripts/setup_demo.sh`

## Demo Script (single GIF, ~45 seconds)

### Scene 1: Starting point (3s)
- **Subtitle:** "Working on multiple features in parallel on the same repo"
- wotr launches showing just `main` branch
- Clean, empty state — no worktrees yet

### Scene 2: Create first worktree (8s)
- **Subtitle:** "Create an isolated worktree with one keypress"
- Press `n`, type `feat/user-auth`, Enter
- **Subtitle:** "Custom project hooks configure the worktree automatically"
- Watch the `new` hook run in the log pane (installing deps, symlinking env)
- Chains to `switch` hook → fake Claude prompt appears

### Scene 3: Work in Claude (4s)
- **Subtitle:** "Each worktree gets its own AI agent session"
- Type something recognizable into the fake Claude prompt, e.g. "Add login form with email/password validation"
- Press Enter (or Ctrl+D) to exit back to wotr

### Scene 4: Create second worktree (6s)
- **Subtitle:** "Switch between sessions without waiting"
- Press `n`, type `fix/api-timeout`, Enter
- Watch hooks run, Claude launches
- Type something different: "Fix the 30s timeout on /api/users endpoint"
- Exit back to wotr

### Scene 5: Resource management (6s)
- Navigate to first worktree (feat/user-auth)
- **Subtitle:** "Shared resources move between worktrees with a keypress"
- Press `w` to acquire web-server — watch acquire script run, icon appears
- Press `b` to acquire db-schema — icon appears
- **Subtitle:** "💻 web-server and 💾 database now belong to this worktree"

### Scene 6: Session persistence (5s)
- **Subtitle:** "Come back anytime — your conversation is right where you left it"
- Press Enter to resume feat/user-auth
- See the fake Claude prompt with the previous message still visible
- Pause to let viewer read
- Exit back to wotr

### Scene 7: Run tests action (4s)
- **Subtitle:** "Custom actions run commands against any worktree"
- Press `t` to run tests
- Watch test output stream in the log pane

### Scene 8: Filter and navigate (3s)
- **Subtitle:** "Filter worktrees by name"
- Press `/`, type `feat`, see filtered list
- Escape to clear

### Scene 9: End (3s)
- **Subtitle:** "wotr — be wotr, my friend 🌊"
- Press `q` to quit

## Demo .wotr/config Notes

The switch hook should use a fake Claude prompt (not real Claude Code):
```yaml
switch:
  - bg: wotr-rename-tab
    stop_on_failure: false
  - fg: |
      echo ""
      echo "╭─────────────────────────────────────────╮"
      echo "│  Claude Code  ⑂ $(git rev-parse --abbrev-ref HEAD)"
      echo "╰─────────────────────────────────────────╯"
      echo ""
      read -p "> "
```

The `setup_demo.sh` script needs to be updated:
- Start with NO pre-created worktrees (just main)
- Keep resources and actions config
- Fake Claude prompt instead of wotr-launch-claude

## Technical Notes

- VHS with subtitle support: fork at /Users/max/dev/vhs, Approach A (Chrome DOM injection)
- Subtitle settings: font size, color, background, position, border radius, animations
- GIF target size: < 2MB for GitHub README
- Terminal theme: something dark with good contrast (not purple — avoid Catppuccin)
- VHS `Set Theme` — try "Dracula", "Tokyo Night", or a custom JSON theme
