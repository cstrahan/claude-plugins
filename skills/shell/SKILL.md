---
name: shell
description: Use this skill when running shell commands, writing shell scripts, or working with file redirection. Covers zsh compatibility (noclobber, extended globbing, special characters), shell detection, and safe patterns that work across bash and zsh. Activate whenever commands fail with "file exists", "no matches found", "event not found", or other shell-specific errors, and whenever writing commands that use redirection, globbing, or special characters.
---

# Shell Compatibility

When Claude Code runs commands via the Bash tool, it's actually running whatever the user's `$SHELL` is — often zsh with the user's full configuration loaded. This means shell options like `noclobber`, `extended_glob`, and others are active and can cause commands that work fine in vanilla bash to fail in surprising ways.

## Detecting the shell

```bash
echo "$SHELL"          # User's login shell (e.g., /bin/zsh)
echo "$ZSH_VERSION"    # Set only in zsh
echo "$BASH_VERSION"   # Set only in bash
```

In practice, assume zsh on macOS — it's been the default since Catalina (10.15). Write commands that work under both bash and zsh.

## File redirection and noclobber

Many zsh configurations set `noclobber` (`set -o noclobber` or `setopt noclobber`), which changes how `>` and `>>` behave.

### The problem

With `noclobber` enabled:

| What you write | What happens | Error |
|:---|:---|:---|
| `echo "data" > existing_file.txt` | Fails | `file exists` |
| `echo "data" >> missing_file.txt` | Fails (zsh only) | `no such file or directory` |

The `>` operator refuses to overwrite existing files, and in zsh (not bash), the `>>` operator refuses to create new files.

### The solution: always use `>|` for overwrite

The `>|` operator forces the redirect regardless of `noclobber`. It works identically in both bash and zsh:

```bash
echo "data" >| file.txt      # Create or overwrite — always works
```

**Use `>|` whenever the intent is "this file should contain exactly this content."** There is no downside — it behaves identically to `>` when `noclobber` is off, and does the right thing when it's on.

### Append safely in zsh with `>>|`

For appending, zsh's `>>` fails if the target file doesn't exist (with `noclobber`). The force variant `>>|` handles both cases:

```bash
echo "data" >>| file.txt     # Append, creating file if needed (zsh)
```

However, `>>|` is **zsh-only syntax** — it causes a syntax error in bash. If you need a portable append-or-create:

```bash
# Portable: works in both bash and zsh
touch file.txt && echo "data" >> file.txt
```

Or if you know you're in zsh:

```bash
echo "data" >>| file.txt
```

### Do NOT use `>!` — it's not portable

Zsh also supports `>!` as a force-overwrite operator, but in bash, `>!` is parsed as `>` followed by `!` (history expansion). This creates a file literally named `!` and silently does the wrong thing. **Always use `>|` instead.**

### Summary of safe redirection

| Intent | Safe syntax | Notes |
|:---|:---|:---|
| Overwrite/create | `>|` | Works in both bash and zsh |
| Append to existing file | `>>` | Works everywhere when file exists |
| Append, create if missing | `>>|` | Zsh only; use `touch f && echo >> f` for portable |

### Common pattern: writing temp scripts

When creating temp files (e.g., for `GIT_SEQUENCE_EDITOR`), `mktemp` creates the file before you write to it — so `>` will fail with noclobber:

```bash
# WRONG — fails with noclobber because mktemp already created the file
TMPFILE=$(mktemp)
cat > "$TMPFILE" << 'EOF'
content
EOF

# RIGHT — use >| to force overwrite
TMPFILE=$(mktemp)
cat >| "$TMPFILE" << 'EOF'
content
EOF

# ALSO RIGHT — remove first, then write
TMPFILE=$(mktemp)
rm -f "$TMPFILE"
cat > "$TMPFILE" << 'EOF'
content
EOF
```

## Zsh special characters

Zsh treats several characters as functional operators that bash treats as literal. These cause "no matches found" errors or silent misbehavior when they appear unquoted in arguments.

### Characters that are dangerous in zsh

| Character | Zsh behavior | Example that breaks |
|:---|:---|:---|
| `=` (word-initial) | Filename expansion — `=cmd` becomes `/path/to/cmd` | `echo =true` outputs `/bin/true` |
| `^` | Extended glob negation, or history substitution at line start | `git rebase -i abc1234^` → "no matches found" |
| `~` | Extended glob exclusion (also home dir expansion) | `*.c~main.c` means "all .c except main.c" |
| `#` | Extended glob repetition (with `extended_glob`) | Part of a regex-like pattern matching |
| `()` | Glob qualifiers | `data(1).txt` → zsh interprets `(1)` as a qualifier |
| `<>` | Numeric range glob | `file<1-10>` matches `file1` through `file10` |
| `!` | History expansion (inside double quotes too) | `echo "Hello!"` → "event not found" |

### The golden rule: single-quote strings with special characters

If a string contains any non-alphanumeric character beyond `/`, `_`, `-`, or `.`, wrap it in single quotes:

```bash
# WRONG
git rebase -i abc1234^
echo Hello!

# RIGHT
git rebase -i 'abc1234^'
echo 'Hello!'
```

Single quotes prevent ALL interpretation — no variable expansion, no globbing, no history expansion. They are the only truly safe quoting mechanism for literal strings in zsh.

### When you need variable expansion AND special characters

Use double quotes for the variable parts and single quotes for the literal parts, concatenated:

```bash
# Variable $BASE with a literal ^
git rebase -i "${BASE}"'^'

# Or escape the specific character
git rebase -i "${BASE}\^"
```

### Common gotchas in practice

**Git caret notation:**
```bash
# These all work in zsh:
git rebase -i 'abc1234^'       # Single quotes
git rebase -i "abc1234^"       # Double quotes (^ is safe in double quotes)
git rebase -i abc1234\^        # Escaped
git rebase -i 'abc1234^{commit}'  # Extended ref syntax
```

**Filenames with parentheses:**
```bash
# WRONG — zsh treats (1) as a glob qualifier
cp "download (1).pdf" ~/Documents/

# RIGHT — single quotes prevent glob qualification
cp 'download (1).pdf' ~/Documents/
```

**Exclamation points in commit messages:**
```bash
# WRONG — history expansion inside double quotes
git commit -m "fix: handle edge case!"

# RIGHT — single quotes, or escape
git commit -m 'fix: handle edge case!'
git commit -m "fix: handle edge case\!"
```

## Behavioral differences between bash and zsh

Beyond special characters and options, bash and zsh have fundamental behavioral differences that can cause scripts to silently produce wrong results.

### Word splitting

This is the most significant difference between the two shells.

- **Bash**: Unquoted variables are automatically split on whitespace into separate arguments.
- **Zsh**: Unquoted variables are NOT split — the value stays as a single argument.

```bash
VAR="hello world"

# Bash: $VAR becomes two arguments → looks for files "hello" and "world"
ls $VAR    # bash: ls hello world

# Zsh: $VAR stays one argument → looks for file "hello world"
ls $VAR    # zsh: ls "hello world"
```

This means scripts that rely on unquoted variables to pass multiple arguments (a common bash pattern) will break in zsh. If you need word splitting in zsh, use `$=VAR`. But the better approach is to always use arrays for multi-value data, which works in both shells.

### Array indexing

- **Bash**: Arrays are **0-indexed**. `${arr[0]}` is the first element.
- **Zsh**: Arrays are **1-indexed**. `${arr[1]}` is the first element. `${arr[0]}` returns empty.

```bash
arr=(a b c)

# Bash:
echo "${arr[0]}"   # "a"

# Zsh:
echo "${arr[1]}"   # "a"
echo "${arr[0]}"   # "" (empty!)
```

Any logic that calculates array offsets will be off-by-one between the two shells.

### Non-existent glob patterns

- **Bash**: If a glob matches nothing, the literal pattern string is passed as an argument (e.g., `*.xyz` stays as `*.xyz`).
- **Zsh**: If a glob matches nothing, zsh throws a **fatal error**: `no matches found`.

```bash
# Bash: passes literal "*.nonexistent" to echo
echo *.nonexistent    # bash: *.nonexistent

# Zsh: aborts the command entirely
echo *.nonexistent    # zsh: error: no matches found: *.nonexistent
```

This is particularly dangerous for commands that use glob-like syntax for non-file purposes (e.g., `pip install package[extra]`). In zsh, quote these to prevent glob interpretation: `pip install 'package[extra]'`.

### The shebang line: the universal escape hatch

When writing scripts (as opposed to inline commands), always include a shebang to ensure the correct interpreter:

```bash
#!/usr/bin/env bash
```

When zsh encounters a script starting with `#!/bin/bash` or `#!/usr/bin/env bash`, it spawns a bash subprocess, bypassing all zsh-specific behavior. This is the simplest way to guarantee bash semantics for a script file.

This is why the `GIT_SEQUENCE_EDITOR` temp scripts in the git-interactive-rebase skill use `#!/bin/bash` — the outer shell may be zsh, but the inner script runs in bash where `cat > "$1"` works without noclobber issues.

### Summary of behavioral differences

| Behavior | Bash | Zsh |
|:---|:---|:---|
| Word splitting on unquoted vars | Automatic | None (use `$=VAR` to force) |
| Array start index | `0` | `1` |
| Unmatched glob | Passes literal string | Fatal error: "no matches found" |
| Empty unquoted variable | Removed from arg list | Removed from arg list |
| `read -n 1` (single char) | Works | Use `read -k 1` instead |
