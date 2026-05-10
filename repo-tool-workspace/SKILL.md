---
name: repo-tool-workspace
description: Work safely in Google `repo` tool manifest workspaces where the workspace root is not a normal Git repository. Use when Codex is in a checkout with `.repo/`, manifest-managed Git projects, manifest `linkfile` root files, repo commands such as `repo status`, `repo sync`, or `repo manifest`, or instructions warning not to run workspace-wide Git commands from the root.
---

# Repo Tool Workspace

Use this skill for workspaces managed by Google's `repo` tool: one workspace root, `.repo/` metadata, and many Git projects checked out underneath.

## Orient First

1. Treat the directory containing the project instructions as the workspace root.
2. Check for `.repo/` before assuming normal Git layout.
3. Inspect all projects with `repo status` from the workspace root.
4. Inspect the resolved manifest with `repo manifest` from the workspace root when project ownership, paths, remotes, revisions, or `linkfile` entries matter.
5. Use `repo sync` from the workspace root only when the user asks to update projects or the task requires freshly synced manifests/projects.

## Git Rules

- Do not assume the workspace root is a Git repository for the source projects.
- Run `git` commands inside the specific manifest project checkout being inspected or changed.
- Confirm project paths from the manifest, local tree, or workspace instructions before using examples from prior workspaces.
- Do not run destructive workspace-wide Git commands from the root, especially `git reset --hard`, `git checkout --`, or broad clean/reset operations.
- Do not delete, rewrite, or "fix" project `.git` entries just because they are symlinks, gitdir files, or indirections into `.repo/projects/...`.
- Treat dirty changes in any project as user-owned unless you made them.

## Linked Root Files

Manifest `linkfile` entries can make root files appear at the workspace root while their real content lives in a manifest project.

When editing root support files such as `CMakeLists.txt`, build scripts, or agent instructions:

1. Resolve whether the file is a symlink or manifest-linked support file.
2. Edit the owning project file when that is the actual source.
3. Run `git` status/commit operations inside the owning project, not from the workspace root.

## Build And Test

Prefer workspace-provided helpers when present, such as `./bld.sh`, `./build.sh`, or documented project scripts.

If no helper exists, inspect the manifest and local docs before inventing build commands. When a root aggregate build exists, run it from the workspace root; when a project has its own standalone build, run it from that project checkout.

## Before Committing

1. Run `repo status` at the root to understand all changed projects.
2. For each changed project, run `git status` inside that project.
3. Update repository documentation when local instructions require it.
4. Commit from the relevant project checkout only.
5. If changes span multiple projects, make separate commits in the appropriate projects unless the user gives different release instructions.
