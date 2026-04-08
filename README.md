# Claude Plugins

Claude Code skills for general-purpose git workflows and other development tasks.

## Skills

| Skill | Description |
|-------|-------------|
| **git-rebase-interactive** | Programmatic interactive git rebase — fixups, squashes, rewords, reordering, commit splitting, conflict resolution, and shell compatibility workarounds (zsh noclobber, etc.) |
| **shell** | Shell compatibility — zsh detection, noclobber-safe redirection, extended globbing pitfalls, special character quoting, and portable patterns that work across bash and zsh |

## Installation

### Quick start (local testing)

Load the skills for a single session without installing:

```bash
claude --plugin-dir /path/to/cstrahan-claude-plugins
```

After making changes to a skill, reload without restarting:

```
/reload-plugins
```

### Permanent installation

#### 1. Add the repo as a marketplace source

From within Claude Code:

```
/plugin marketplace add git@github.com:cstrahan/claude-plugins.git
```

Or from a local clone:

```
/plugin marketplace add /path/to/cstrahan-claude-plugins
```

#### 2. Install the plugin

From within Claude Code, run `/plugin` and select `cstrahan-claude-plugins` to install. Or install directly:

```
/plugin install cstrahan-claude-plugins@cstrahan-claude-plugins
```

#### 3. Reload

```
/reload-plugins
```

### Installation scopes

Skills can be installed at different scopes:

- **User** (default): Available to you across all projects
- **Project**: Available to all collaborators in a specific repo (stored in `.claude/settings.json`)
- **Local**: Available to you in a specific repo only

```
/plugin install cstrahan-claude-plugins@cstrahan-claude-plugins --scope user
/plugin install cstrahan-claude-plugins@cstrahan-claude-plugins --scope project
/plugin install cstrahan-claude-plugins@cstrahan-claude-plugins --scope local
```

## Reinstalling

To pick up changes after updating the repo (e.g., `git pull`):

```
/plugin uninstall cstrahan-claude-plugins
/plugin install cstrahan-claude-plugins@cstrahan-claude-plugins
/reload-plugins
```

Or for a quick session reload without reinstalling:

```
/reload-plugins
```

## Uninstalling

To remove the plugin and marketplace:

```
/plugin uninstall cstrahan-claude-plugins
/plugin marketplace remove cstrahan-claude-plugins
/reload-plugins
```

## Usage

Once installed, skills activate automatically based on context. Mention interactive rebase, commit cleanup, fixups, squashing, or reordering and the git-rebase-interactive skill kicks in.

You can also invoke a skill explicitly:

```
/cstrahan-claude-plugins:git-rebase-interactive
```

## Adding new skills

Create a new directory under `skills/` with a `SKILL.md` file:

```
skills/new-skill/
└── SKILL.md
```

Then add it to `.claude-plugin/marketplace.json` in the `skills` array:

```json
"skills": [
  "./skills/git-rebase-interactive",
  "./skills/new-skill"
]
```

The `SKILL.md` requires YAML frontmatter with `name` and `description` fields, followed by markdown instructions. See the existing skills for examples.
