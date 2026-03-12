# wotr Config Reference

## File Location

`.wotr/config` — YAML file at repository root.

## Top-Level Structure

```yaml
hooks:
  new: |
    # Shell script — runs in the NEW worktree directory after creation
  switch: |
    # Shell script — runs when switching to an EXISTING worktree

resources:
  resource-name:
    icon: <emoji>
    exclusive: true|false
    description: "Human-readable description"
    acquire: |
      # Shell script — sets up or claims the resource
    inquire: |
      # Shell script — checks resource status (must output JSON via wotr-output)
```

Both `hooks` and `resources` are optional.

## Hooks

### `new`

Runs inside the newly created worktree directory. Typical uses:
- Install dependencies (`npm ci`, `pnpm install`, `bundle install`)
- Symlink shared config files (`.env`, credentials)
- Copy files that can't be symlinked (Docker requires real files, not symlinks)
- Run `wotr-default-setup` first to symlink `.claude/` contents

### `switch`

Runs when the user switches focus to an existing worktree. Typical uses:
- Restart dev servers pointed at this worktree
- Reload environment

### Hook Execution Order (for `new`)

1. `~/.wotr/setup` (user-level global hook, if executable)
2. `.wotr/config` `new:` hook (if defined)
3. Default symlinks (`.env`, `node_modules`) — ONLY if neither 1 nor 2 ran

## Resources

### Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `icon` | string | `•` | Single emoji for TUI display |
| `exclusive` | boolean | `false` | Whether only one worktree can own it |
| `description` | string | — | Shown in resource legend |
| `acquire` | string | — | Shell script to claim/setup the resource |
| `inquire` | string | — | Shell script to check status (outputs JSON) |

### Exclusive vs Compatible

**Exclusive** (`exclusive: true`):
- Only one worktree at a time. Think: port bindings, singleton services.
- `inquire` must report who owns it.
- `acquire` typically stops the resource elsewhere, then starts it here.

**Compatible** (`exclusive: false`):
- Each worktree independently compatible or not. Think: DB migrations, file state.
- `inquire` reports whether this worktree is compatible.
- `acquire` makes this worktree compatible (e.g., runs migrations).

### inquire Script Output

Scripts must use `wotr-output` to emit JSON:

```bash
# Exclusive resource — currently owned by a worktree
wotr-output status=owned owner="/path/to/worktree"

# Exclusive resource — not running / not owned
wotr-output status=unowned

# Compatible resource — this worktree is in sync
wotr-output status=compatible

# Compatible resource — this worktree is out of sync
wotr-output status=incompatible reason="3 pending migrations"
```

Exit code must be 0. Non-zero = error state.

### Environment Variables Available to Scripts

| Variable | Description |
|----------|-------------|
| `WOTR_ROOT` | Absolute path to the main repo checkout |
| `WOTR_WORKTREE` | Absolute path to the worktree being checked |

### wotr-default-setup

Built-in helper for `new` hooks. Symlinks `.claude/` directory contents from root to worktree, except `settings.local.json` which is copied (for per-worktree isolation).

```yaml
hooks:
  new: |
    wotr-default-setup
    npm ci
```

## Resource Polling

- Resources are polled every 60 seconds
- Exclusive: stops checking other worktrees once owner is found
- Compatible: checks each worktree independently
- Icons appear in the TUI's "resources" column per worktree

## Keyboard Shortcuts

Each resource gets an auto-assigned single-letter shortcut from its name. Pressing the shortcut on a selected worktree runs `acquire` for that resource.

Reserved letters: `n`, `/`, `Enter`, `s`, `d`, `Esc`, `q`, `j`, `k`, `D`, `R`
