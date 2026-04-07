# Claude Plugins

Claude Code skills for general-purpose git workflows and other development tasks.

## Skills

| Skill | Description |
|-------|-------------|
| **git-interactive-rebase** | Programmatic interactive git rebase — fixups, squashes, rewords, reordering, commit splitting, conflict resolution, and shell compatibility workarounds (zsh noclobber, etc.) |

## Installation

### Quick start (local testing)

Load the skills for a single session without installing:

```bash
claude --plugin-dir /path/to/claude-plugins
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
/plugin marketplace add /path/to/claude-plugins
```

#### 2. Install the plugin

From within Claude Code, run `/plugin` and select `claude-plugins` to install. Or install directly:

```
/plugin install claude-plugins@claude-plugins
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
/plugin install claude-plugins@claude-plugins --scope user
/plugin install claude-plugins@claude-plugins --scope project
/plugin install claude-plugins@claude-plugins --scope local
```

## Reinstalling

To pick up changes after updating the repo (e.g., `git pull`):

```
/plugin uninstall claude-plugins
/plugin install claude-plugins@claude-plugins
/reload-plugins
```

Or for a quick session reload without reinstalling:

```
/reload-plugins
```

## Uninstalling

To remove the plugin and marketplace:

```
/plugin uninstall claude-plugins
/plugin marketplace remove claude-plugins
/reload-plugins
```

## Usage

Once installed, skills activate automatically based on context. Mention interactive rebase, commit cleanup, fixups, squashing, or reordering and the git-interactive-rebase skill kicks in.

You can also invoke a skill explicitly:

```
/claude-plugins:git-interactive-rebase
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
  "./skills/git-interactive-rebase",
  "./skills/new-skill"
]
```

The `SKILL.md` requires YAML frontmatter with `name` and `description` fields, followed by markdown instructions. See the existing skills for examples.
