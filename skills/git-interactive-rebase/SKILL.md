---
name: git-interactive-rebase
description: Use this skill for git workflows that require careful, programmatic execution — interactive rebases, commit history cleanup, fixups, squashes, commit splitting, reordering, and conflict resolution. Activate whenever the user wants to clean up commit history, reorganize commits, or perform interactive rebase operations, even if they don't explicitly say "rebase".
---

# Git Workflows

## Programmatic Interactive Rebase

Git's interactive rebase (`git rebase -i`) normally opens an editor for the user to modify a "todo" file. Since Claude Code can't interact with terminal editors, use `GIT_SEQUENCE_EDITOR` to supply the todo list programmatically, and `GIT_EDITOR` when you need to control commit message editing (for `reword` and `squash` actions).

### Why a temp script instead of inline sed

- macOS BSD `sed` has different syntax than GNU `sed` for multi-line operations
- Complex todo modifications (reordering, inserting lines) are error-prone with sed
- A temp script approach works identically on macOS and Linux

### Shell compatibility

All examples in this skill use `>|` instead of `>` for file redirection. This is because zsh's `noclobber` option (common in user configs) makes `>` fail on existing files — and `mktemp` creates the file before you write to it. The `>|` operator forces the overwrite and works in both bash and zsh. See the **shell** skill for full details on zsh compatibility.

### Core pattern

```bash
# 1. Create a temp editor script that writes the desired todo
EDITOR_SCRIPT=$(mktemp)
cat >| "$EDITOR_SCRIPT" << 'SCRIPT'
#!/bin/bash
cat > "$1" << 'TODO'
pick abc1234 First commit message
fixup def5678 Commit to absorb into first
pick ghi9012 Third commit stays separate
TODO
SCRIPT
chmod +x "$EDITOR_SCRIPT"

# 2. Run the rebase with our custom editor
GIT_SEQUENCE_EDITOR="$EDITOR_SCRIPT" git rebase -i <base-commit>

# 3. Clean up
rm -f "$EDITOR_SCRIPT"
```

### Step-by-step process

#### 1. Identify the commits

```bash
git log --oneline -10
```

Note the commit hashes and messages.

#### 2. Determine the base commit

The base commit is the **parent** of the oldest commit you want to modify. Use the `^` suffix to reference the parent:

```bash
# If oldest commit to modify is abc1234:
git rebase -i 'abc1234^'  # Quote the caret for zsh compatibility
```

If the oldest commit is the very first commit in the repo, use `--root`:

```bash
git rebase -i --root
```

**Important with `--root`**: Every commit in the repository is in scope. Any commit not listed in the todo will be **dropped**. Always list all commits when using `--root`.

#### 3. Plan the todo list

The todo file format is one line per commit:

```text
<action> <hash> <message>
```

Available actions:

| Action   | Short | Description                                      |
| -------- | ----- | ------------------------------------------------ |
| `pick`   | `p`   | Use commit as-is                                 |
| `reword` | `r`   | Use commit but change the message                |
| `edit`   | `e`   | Pause rebase so commit can be amended or split   |
| `squash` | `s`   | Meld into previous commit, combine messages      |
| `fixup`  | `f`   | Meld into previous commit, discard this message  |
| `drop`   | `d`   | Remove commit entirely                           |
| `exec`   | `x`   | Run a shell command (not tied to a commit)        |

Omitting a line is equivalent to `drop` — the commit will be removed.

The `exec` action is special — it doesn't take a commit hash, just a shell command. It runs at that point in the rebase sequence. If the command fails (non-zero exit), the rebase pauses so you can investigate. See "Using exec in the todo list" below for details.

#### 4. Build and execute

```bash
EDITOR_SCRIPT=$(mktemp)
cat >| "$EDITOR_SCRIPT" << 'SCRIPT'
#!/bin/bash
cat > "$1" << 'TODO'
pick abc1234 First commit
fixup def5678 Second commit (will be absorbed)
pick ghi9012 Third commit
TODO
SCRIPT
chmod +x "$EDITOR_SCRIPT"

GIT_SEQUENCE_EDITOR="$EDITOR_SCRIPT" git rebase -i '<base>^'
rm -f "$EDITOR_SCRIPT"
```

### Common operations

#### Fixup: absorb fix commits into a feature commit

Scenario: A feature commit followed by fix commits that should be part of it.

```text
# Before:
abc1234 feat: add user authentication
def5678 fix: correct token validation     <- absorb
ghi9012 fix: handle edge case             <- absorb
jkl3456 chore: update deps                <- keep separate

# Todo:
pick abc1234 feat: add user authentication
fixup def5678 fix: correct token validation
fixup ghi9012 fix: handle edge case
pick jkl3456 chore: update deps
```

#### Autosquash: let git arrange fixup!/squash! commits

If commits were created with `git commit --fixup=<target>` or have messages starting with `fixup!` or `squash!`, git can automatically arrange the todo list:

```bash
# Use "true" as GIT_SEQUENCE_EDITOR to accept the auto-arranged todo without editing
GIT_SEQUENCE_EDITOR="true" git rebase -i --autosquash '<base>^'
```

This moves each `fixup!`/`squash!` commit to right after its target and sets the appropriate action. Be aware that this can still cause conflicts if the fixup commit's changes don't apply cleanly at the target's position in history.

#### Squash: combine commits and merge their messages

Use `squash` instead of `fixup` to keep all commit messages combined.

**To accept the default combined message** (both commit messages concatenated):

```bash
GIT_EDITOR="true" GIT_SEQUENCE_EDITOR="$EDITOR_SCRIPT" git rebase -i '<base>^'
```

The `true` command exits successfully without modifying the file, so git uses the default combined message as-is. Do NOT use `GIT_EDITOR="cat"` — it reads the file to stdout and leaves the comment-stripped version, which loses the secondary commit messages.

**To supply a custom combined message**, write a `GIT_EDITOR` script:

```bash
MSG_EDITOR=$(mktemp)
cat >| "$MSG_EDITOR" << 'MSGEDIT'
#!/bin/bash
cat > "$1" << 'MSG'
feat: add complete user module

Combines user model, controller, and routes into a single commit.
MSG
MSGEDIT
chmod +x "$MSG_EDITOR"

GIT_EDITOR="$MSG_EDITOR" GIT_SEQUENCE_EDITOR="$EDITOR_SCRIPT" git rebase -i '<base>^'
rm -f "$MSG_EDITOR"
```

#### Reword: change a commit message

Use the `reword` action and supply a `GIT_EDITOR` script with the new message:

```bash
EDITOR_SCRIPT=$(mktemp)
cat >| "$EDITOR_SCRIPT" << 'SCRIPT'
#!/bin/bash
cat > "$1" << 'TODO'
reword abc1234 old message here
pick def5678 keep this one
TODO
SCRIPT
chmod +x "$EDITOR_SCRIPT"

MSG_EDITOR=$(mktemp)
cat >| "$MSG_EDITOR" << 'MSGEDIT'
#!/bin/bash
cat > "$1" << 'MSG'
feat: better commit message

More detailed description here.
MSG
MSGEDIT
chmod +x "$MSG_EDITOR"

GIT_EDITOR="$MSG_EDITOR" GIT_SEQUENCE_EDITOR="$EDITOR_SCRIPT" git rebase -i '<base>^'
rm -f "$EDITOR_SCRIPT" "$MSG_EDITOR"
```

**Important**: The `GIT_EDITOR` script is called once per `reword` (and once per `squash`). A static script applies the same message to all of them. For different messages, see "Rewording multiple commits" below.

`GIT_EDITOR` is NOT called during conflict resolution — only during `reword` and `squash` actions.

#### Reorder commits

List commits in the desired new order:

```text
pick ghi9012 Third commit (now first)
pick abc1234 First commit (now second)
pick def5678 Second commit (now third)
```

**Beware of cascading conflicts**: Reordering can cause conflicts, and resolving one conflict may create another as the rebase continues to the next commit. This happens because each commit is replayed sequentially — if commit B depended on commit A and you move B before A, then both B (now applied out of order) and A (now applied on top of B's resolution) may conflict. Be prepared to resolve multiple conflicts in succession.

#### Drop a commit

Use `drop` or simply omit the line:

```text
pick abc1234 Keep this
drop def5678 Remove this
pick ghi9012 Keep this too
```

Be aware that later commits depending on the dropped commit's changes will conflict.

#### Using `exec` in the todo list

The `exec` (or `x`) action runs a shell command at a specific point in the rebase sequence. Unlike `--exec` (the command-line flag, which inserts a command after *every* pick), `exec` lines in the todo give you precise control over where commands run.

The syntax differs from other actions — no commit hash, just the command:

```text
pick abc1234 feat: add user model
pick def5678 feat: add user controller
exec python -m pytest tests/user/
pick ghi9012 feat: add user routes
exec python -m pytest tests/
```

If the command fails (non-zero exit), the rebase pauses so you can investigate. Fix the issue, then `git rebase --continue`.

**When `exec` is useful:**

- **Running tests at specific points** to verify each commit in isolation:
  ```text
  pick abc1234 feat: add parser
  exec make test
  pick def5678 refactor: optimize parser
  exec make test
  ```

- **Running a check only after certain commits** (not all of them):
  ```text
  pick abc1234 chore: update deps
  exec npm audit
  pick def5678 feat: add feature
  pick ghi9012 docs: update readme
  ```

- **Inserting a new commit mid-history** by running commands that create one:
  ```text
  pick abc1234 feat: add feature
  exec echo "v1.2.0" > VERSION && git add VERSION && git commit -m "chore: bump version to 1.2.0"
  pick def5678 next commit
  ```

**`exec` vs `--exec` flag:** Use the `--exec` flag when you want the same command after every commit (e.g., retroactive formatting). Use `exec` lines in the todo when you want commands at specific points, or different commands at different points.

#### Split a commit into multiple commits

Use the `edit` action to pause the rebase at a commit, then reset and recommit in pieces. This is a multi-step process — the rebase pauses and you must run additional commands before continuing.

**Step 1: Set up the rebase to pause at the commit:**

```bash
EDITOR_SCRIPT=$(mktemp)
cat >| "$EDITOR_SCRIPT" << 'SCRIPT'
#!/bin/bash
cat > "$1" << 'TODO'
edit abc1234 commit to split
pick def5678 next commit
TODO
SCRIPT
chmod +x "$EDITOR_SCRIPT"

GIT_SEQUENCE_EDITOR="$EDITOR_SCRIPT" git rebase -i '<base>^'
rm -f "$EDITOR_SCRIPT"
# The rebase is now paused at abc1234
```

**Step 2: Reset to unstage the commit's changes:**

```bash
# Use mixed reset (the default) — NOT --soft
# Mixed reset unstages everything, making it easy to selectively re-add
# --soft keeps files staged, requiring you to unstage before selective commits
git reset HEAD~1
```

**Retrieving file contents from any commit:**

During a rebase (or any time), you can read or restore files from any commit without copying files to `/tmp`. Since everything is committed, git itself is the backup.

```bash
# READ a file from a commit (prints to stdout, doesn't modify working tree)
git show <sha>:path/to/file.py

# RESTORE a file from a commit into the working tree
git restore --source=<sha> -- path/to/file.py

# RESTORE multiple files or a whole directory
git restore --source=<sha> -- path/to/dir/

# FIND which files changed between two refs
git diff --name-only <base>..<head>
git diff --name-status <base>..<head>   # includes A/M/D status
```

**Important**: `git restore --source=<sha> -- path` will **delete** the file from the working tree if it doesn't exist in that commit. This is silent — no error, no warning.

**Tag before rebasing**: If you need to reference the final state of your branch during a rebase (e.g., to restore files from it), tag it first. Commit hashes change during rebase, but tags are stable:

```bash
git tag pre-rebase-state
# ... do the rebase ...
git restore --source=pre-rebase-state -- path/to/file.py
# ... when done ...
git tag -d pre-rebase-state
```

**Step 3: Stage and commit in pieces** — choose the approach that fits:

##### Approach A: Changes are in separate files

The simplest case. Just `git add` each file and commit separately:

```bash
git add src/models/user.rb
git commit -m "feat: add user model"

git add src/controllers/users_controller.rb
git commit -m "feat: add users controller"
```

##### Approach B: Changes are in the same file, in separable hunks

When the same file has multiple non-overlapping changes (e.g., a new function added at the bottom AND a modification to an existing function at the top), use `git apply --cached` with a partial patch to stage specific hunks:

```bash
# Save the full working state
cp path/to/file.py /tmp/file_full.py

# Create a patch for just the hunk you want in the first commit
cat >| /tmp/first_change.patch << 'PATCH'
diff --git a/path/to/file.py b/path/to/file.py
--- a/path/to/file.py
+++ b/path/to/file.py
@@ -1,4 +1,4 @@
-def greet(name):
-    return f"Hello, {name}"
+def greet(name, greeting="Hello"):
+    return f"{greeting}, {name}"
 
 
PATCH

# Stage just that hunk (--cached applies to index only, leaving working tree intact)
git apply --cached /tmp/first_change.patch
git commit -m "feat: add optional greeting parameter"

# Stage and commit the remaining changes
git add path/to/file.py
git commit -m "feat: add multiply function"
```

The patch must be a valid unified diff with correct context lines. If crafting patches feels error-prone, use Approach C instead.

##### Approach C: Write the intermediate file state directly (most reliable)

When changes are interleaved in the same lines — or when the intermediate state needs to be different from either the before or after state to remain valid — write the intermediate file content directly. This is the most reliable approach because you have full control over each state.

This is necessary when:
- Splitting a rename + addition (the intermediate state has the rename done but not the addition — a state that never existed in the original history)
- Splitting a new function + calls to it (the intermediate state adds the function but doesn't wire it up yet)
- Any case where partial application would leave the code syntactically or semantically broken

```bash
# Save the full desired end state
cp path/to/file.py /tmp/file_full.py

# Write the intermediate state — this may be a version of the file
# that never existed in the original commit history
cat >| path/to/file.py << 'EOF'
class Config:
    def __init__(self):
        self.debug = False
        self.fmt = "text"          # renamed from output_format

    def summary(self):
        return f"debug={self.debug}, fmt={self.fmt}"  # updated reference
EOF

git add path/to/file.py
git commit -m "refactor: rename output_format to fmt"

# Restore the full end state for the second commit
cp /tmp/file_full.py path/to/file.py
git add path/to/file.py
git commit -m "feat: add max_retries to Config"
```

The intermediate state must be valid on its own — it should compile/parse and ideally pass tests. Think of it as: "if someone checked out this commit, would the code work?"

**Step 4: Continue the rebase:**

```bash
git rebase --continue
```

### Rewording multiple commits

When you need different messages for multiple reworded commits in a single rebase, use a counter file to track which invocation of `GIT_EDITOR` you're on:

```bash
COUNTER_FILE=$(mktemp)
echo "0" >| "$COUNTER_FILE"

MSG_EDITOR=$(mktemp)

# Unquoted heredoc: $COUNTER_FILE is expanded to the actual temp path.
# Lines that reference the counter file must be in this section.
cat >| "$MSG_EDITOR" << MSGEDIT
#!/bin/bash
COUNT=\$(cat "$COUNTER_FILE")
COUNT=\$((COUNT + 1))
echo "\$COUNT" >| "$COUNTER_FILE"
MSGEDIT

# Quoted heredoc: no expansion, no escaping needed.
# The message logic goes here for readability.
cat >> "$MSG_EDITOR" << 'MSGEDIT'

if [ "$COUNT" -eq 1 ]; then
  cat > "$1" << 'MSG1'
feat: first reworded message
MSG1
elif [ "$COUNT" -eq 2 ]; then
  cat > "$1" << 'MSG2'
fix: second reworded message
MSG2
fi
MSGEDIT
chmod +x "$MSG_EDITOR"

GIT_EDITOR="$MSG_EDITOR" GIT_SEQUENCE_EDITOR="$EDITOR_SCRIPT" git rebase -i '<base>^'
rm -f "$MSG_EDITOR" "$COUNTER_FILE"
```

The split-heredoc pattern keeps the counter mechanics (which need `$COUNTER_FILE` expanded) in an unquoted heredoc, and the message logic (which uses `$1`, `$COUNT`, etc. literally) in a quoted heredoc. This avoids the error-prone escaping of every `$` in a single unquoted heredoc. Note the use of `>|` (first write) then `>>` (append) to build the script in two parts.

### Retroactively applying a formatter across commits

A common scenario: you've made several commits but forgot to run the project's formatter. You want each commit in the history to have properly formatted code, not just a single formatting commit tacked on at the end.

The challenge is that formatting an early commit changes its content, causing conflicts with every subsequent commit that touches the same files. This is unavoidable — the subsequent commits were authored against the unformatted code.

#### The approach: edit-amend with conflict resolution

Use `edit` on each commit, run the formatter, amend, and continue. When conflicts occur (and they will), resolve them by taking the incoming commit's content (`--theirs`) and re-running the formatter. This works because:

- `--theirs` gives you the original commit's intended content (the new code it added/changed)
- Re-running the formatter ensures that content is properly formatted
- The resolution is always correct because formatting is purely cosmetic — the logic in `--theirs` is right, you're just fixing the style

**Step 1: Set up edit stops on all commits to format:**

```bash
EDITOR_SCRIPT=$(mktemp)
cat >| "$EDITOR_SCRIPT" << 'SCRIPT'
#!/bin/bash
cat > "$1" << 'TODO'
edit abc1234 first commit to format
edit def5678 second commit to format
edit ghi9012 third commit to format
TODO
SCRIPT
chmod +x "$EDITOR_SCRIPT"

GIT_SEQUENCE_EDITOR="$EDITOR_SCRIPT" git rebase -i '<base>^'
rm -f "$EDITOR_SCRIPT"
```

**Step 2: At each edit stop, format and amend:**

```bash
# Run the project's formatter (replace with your actual formatter command)
npx prettier --write 'src/**/*.{ts,tsx}'   # or: black ., gofmt -w ., etc.

# Stage and amend if the formatter changed anything
git add -A
git commit --amend --no-edit
git rebase --continue
```

**Step 3: When a conflict occurs, resolve by accepting theirs + reformatting:**

```bash
# For each conflicted file: take the original commit's version, then reformat
git checkout --theirs <conflicted-file>
npx prettier --write <conflicted-file>     # re-run formatter on resolved file
git add <conflicted-file>
git rebase --continue
```

Repeat step 3 for each subsequent conflict. With formatting changes, conflicts are predictable — they'll occur on files that the current commit modifies if you formatted those same files in a previous commit.

#### Why `--theirs` is safe here

During a rebase, `--theirs` refers to the commit being replayed (the original commit's changes). `--ours` refers to the rebased history so far (which now has formatted code). Since the only difference between ours and theirs is formatting (not logic), taking theirs gives you the correct logic, and re-running the formatter gives you the correct style. This wouldn't be safe for non-cosmetic conflicts.

#### Alternative: `--exec` for automation (recommended)

Instead of manual `edit` stops, use the `--exec` flag to run the formatter after each commit automatically. The `--exec` flag inserts the command after every `pick` in the todo — no `GIT_SEQUENCE_EDITOR` script needed:

```bash
git rebase '<base>^' --exec 'npx prettier --write "src/**/*.{ts,tsx}" && git add -A && git commit --amend --no-edit'
```

When a conflict occurs, resolve it by just taking `--theirs` — you don't even need to re-run the formatter manually, because the exec command fires after `git rebase --continue` and will format+amend the commit for you:

```bash
git checkout --theirs <conflicted-file>
git add <conflicted-file>
git rebase --continue
# exec fires automatically: formats, stages, and amends the commit
```

Repeat for each conflict. The pattern is always the same: `--theirs`, `add`, `continue`.

**Note**: The formatter command must be available at an absolute path or installed globally — it may not exist in the working tree at earlier commits. Formatting is idempotent, so the amend is safe even if the formatter makes no changes.

### Collapsing and rearranging commits with `git restore`

A common workflow: you have a series of commits and want to collapse them into a different structure — for example, turning 8 implementation commits into a "before tests" commit and an "after implementation + tests" commit.

Instead of copying files to `/tmp` and restoring them manually, use `git restore --source=<ref>` to pull file contents directly from any commit. Tag the final state first so you have a stable reference:

```bash
# 1. Tag the final state (commit hashes change during rebase, tags don't)
git tag pre-rebase-state

# 2. Find which files changed across the whole branch
git diff --name-only <base>..HEAD

# 3. Start the rebase — edit the first commit, drop the rest
#    (you'll manually create the commits you want)
```

During the rebase, use `git restore` to assemble each commit's content:

```bash
# Pull a specific file from an earlier commit
git restore --source=<earlier-sha> -- path/to/tests.ts

# Pull all files from the tagged final state
git restore --source=pre-rebase-state -- src/ tests/

# Stage and commit
git add -A
git commit -m "commit message"
```

After the rebase, clean up the tag:

```bash
git tag -d pre-rebase-state
```

This avoids the overhead and fragility of copying files to `/tmp`, works with any number of files, and handles binary files correctly since git manages the content.

### Handling conflicts

When a rebase encounters conflicts:

1. **The rebase pauses** with a message indicating which files conflict
2. **Check conflict status**: `git status` shows conflicted files (marked `UU`)
3. **Resolve conflicts** in the affected files — look for `<<<<<<<`, `=======`, `>>>>>>>` markers (with diff3 enabled, there's also a `|||||||` section showing the common ancestor)
4. **Stage resolved files**: `git add <files>`
5. **Continue**: `git rebase --continue`
6. **Or abort to start over**: `git rebase --abort`

Conflicts are most likely when:
- **Reordering**: A later commit modifies lines introduced by an earlier commit and you swap their order. This often causes **cascading conflicts** — resolving the first conflict changes the base for subsequent commits, triggering additional conflicts.
- **Fixup/squash**: The commit being absorbed touches code that changed between it and its target. Particularly common with `--autosquash` when the `fixup!` commit was created much later in history.
- **Dropping**: Later commits depend on changes from the dropped commit.

### Troubleshooting

**"fatal: could not read file..."**
The todo file path wasn't passed correctly. Ensure the inner script uses `"$1"`.

**Rebase doesn't seem to do anything / todo silently ignored**
The editor script may have failed to write the todo file. Common cause: zsh `noclobber` preventing `cat >` from overwriting the mktemp file — use `>|` instead. See the **shell** skill for details. Also check that commit hashes match actual commits in the range — use short hashes (7+ chars) from `git log --oneline`.

**"zsh: no matches found: abc^"**
Quote the caret: `'abc1234^'` or escape it: `abc1234\^`

**"error: could not apply..."**
A conflict occurred. Use `git status` to see conflicted files, resolve them, `git add`, then `git rebase --continue`.

**Rebase seems stuck after `edit`**
You're in the paused state. Make your changes (e.g., `git reset HEAD~1` for splitting), then run `git rebase --continue`.

**Squash produces unexpected message with `GIT_EDITOR="cat"`**
Don't use `cat` as the editor for squash. It dumps the message template to stdout and git uses the comment-stripped version, losing secondary commit messages. Use `GIT_EDITOR="true"` to accept the default combined message, or write a script that produces the exact message you want.
