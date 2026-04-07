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

Omitting a line is equivalent to `drop` — the commit will be removed.

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
cat >| "$MSG_EDITOR" << MSGEDIT
#!/bin/bash
COUNT=\$(cat "$COUNTER_FILE")
COUNT=\$((COUNT + 1))
echo "\$COUNT" >| "$COUNTER_FILE"

if [ "\$COUNT" -eq 1 ]; then
  cat > "\$1" << 'MSG1'
feat: first reworded message
MSG1
elif [ "\$COUNT" -eq 2 ]; then
  cat > "\$1" << 'MSG2'
fix: second reworded message
MSG2
fi
MSGEDIT
chmod +x "$MSG_EDITOR"

GIT_EDITOR="$MSG_EDITOR" GIT_SEQUENCE_EDITOR="$EDITOR_SCRIPT" git rebase -i '<base>^'
rm -f "$MSG_EDITOR" "$COUNTER_FILE"
```

Note: The counter file path must be an absolute path embedded in the script (the `$COUNTER_FILE` variable is expanded when the heredoc is written since it uses `MSGEDIT` without quotes, not `'MSGEDIT'`). This is important because the script runs in a separate bash process.

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
