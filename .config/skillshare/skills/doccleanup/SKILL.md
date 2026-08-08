---
name: doccleanup
description: Rewrites and trims code comments and API doc comments so they state only what the code does, never why it was added. Strips rationale, changelog notes, apologies, and self-justification, then caps comments inside each function body at one line per five code lines while leaving doc comments on the declaration intact. Use when the user asks to clean up comments, strip justification from documentation, make comments purely functional, reduce comment noise, or run doccleanup. Does not edit Markdown files, README content, or commit messages.
---

# Doccleanup

Make every surviving comment answer one question: *what does this code do?*
Delete every trace of *why we added it*, *what it used to be*, and *who asked
for it*. Rationale belongs in commit messages and issue trackers, which already
preserve it; a comment repeating it goes stale the moment the reason changes.

## Scope

Operate on **comments inside source files only**:

- inline comments (`//`, `#`, `/* */`, `--`, `;`)
- doc comments and docstrings (`///`, `/** */`, `"""..."""`, `//!`, `///!`)

Never edit Markdown files, README content, commit messages, PR descriptions,
changelogs, or string literals that merely look like prose.

**Never author new documentation.** This skill rewrites, trims, and removes what
exists. A block with no comment and no problem is already correct.

**Skip entirely** — do not read, count, or edit:

- generated files (`// Code generated ... DO NOT EDIT.`, `@generated`, `.pb.go`)
- vendored and third-party trees (`vendor/`, `node_modules/`, `third_party/`)
- lockfiles, minified bundles, and anything not tracked by version control

## Workflow

### 1. Set scope

With no path argument, process the **whole repository**: every tracked source
file, minus the skip list above. With a path or glob, process only that.

Detect the build system first. If the project has a Makefile, read its targets
now — step 6 needs them.

### 2. Classify every comment

Read [classification rules](references/classification.md) before the first edit.
It carries the decision table, per-language protected-directive inventory, and
before/after examples. Summary:

| Comment content | Action |
|---|---|
| Describes what the code does | Keep; tighten wording |
| Explains why it was added, who asked, what it replaced | Rewrite to state behavior; delete if nothing functional remains |
| Restates the adjacent line | Delete |
| `TODO` / `FIXME` / `HACK` | Keep marker and actionable item; strip the rationale |
| Tool directive or pragma | **Preserve verbatim** |
| License or copyright header | **Preserve verbatim** |
| Issue, RFC, or CVE link | **Preserve verbatim** |

Preserved directives are compiler and linter instructions, not documentation —
removing one changes program behavior. They are excluded from the density counts
in step 3. Preserved links and license headers *are* documentation: one sitting
in a block body counts toward that block's budget but is never deleted, so it
forces cuts elsewhere.

### 3. Apply the density gate

Enforce per **block** — one function, method, or top-level declaration.

The gate governs **body comments only**. A block's attached doc comment is
exempt: it is never counted and never cut by this step. Public contracts survive
regardless of how short the block is.

Count within the block body:

- `code_lines` — non-blank lines containing code (a line with a trailing comment
  counts here)
- `comment_lines` — full-line comments, plus 1 for each trailing comment

The budget is `floor(code_lines / 5)`. The gate passes when
`comment_lines <= floor(code_lines / 5)`.

A 4-line function gets zero body comments and keeps its doc comment. A 20-line
function gets four body comments plus its doc comment.

When over budget, delete in this order until it passes:

1. Decorative banners and section separators
2. Comments restating a single self-evident statement
3. Comments duplicating the block's doc comment
4. Lowest-information remaining comment

Exempt from the gate is not exempt from cleanup. Doc comments still go through
classification in step 2 and rewriting in step 4 — a doc comment that is pure
rationale is deleted there, and one that rambles is cut to the contract.

Keep to the last: comments recording non-obvious behavior — invariants, required
ordering, units, overflow and edge-case handling, concurrency constraints.

**Lint escape hatch.** The gate no longer removes doc comments, but step 2 still
deletes one whose content is entirely rationale. If step 6 fails because a
project-configured linter requires a doc comment that was removed, restore the
shortest comment that satisfies that linter and list every restoration in the
report. A red build is not a cleanup.

### 4. Rewrite in functional voice

Apply [comment style rules](references/comment-style.md) to every comment you
rewrite. In short: present tense, third person, subject is the code. State
behavior, inputs, outputs, and failure modes. No `we`, no `I`, no hedging, no
apology, no history.

Match each language's doc convention when rewriting a doc comment — a Go doc
comment on an exported identifier still opens with that identifier's name.

### 5. Humanizer review pass

Run once per invocation, after all edits are applied, over the collected set of
rewritten comment text.

If a `humanizer` skill is available in the current agent environment, invoke it
through whatever skill-invocation mechanism that environment provides, passing
the batch, and apply its corrections. If it is unavailable, the inline tells in
[comment style rules](references/comment-style.md) already ran in step 4 — note
in the report that the fallback was used.

### 6. Verify

Comments are not always inert: build tags, generate directives, and doc-lint
rules all read them.

Run the project's own gate. Prefer Makefile targets in this order, using the
first that exists: `verify`, `check`, `test`, `build`. Otherwise use the
language's native command (`go build ./...`, `cargo check`, `tsc --noEmit`).

On failure, diagnose whether an edit caused it. If so, fix or revert that edit
and re-run. Never report success on a failing gate.

### 7. Report

Deliver edits directly, then report:

- files changed, with comments rewritten / deleted / preserved per file
- blocks still over budget solely because of protected content
- every doc comment restored by the lint escape hatch
- the verification command run and its result
- whether the humanizer skill ran or the inline fallback was used

## Boundaries

Triggers: "clean up the comments", "strip justification from the docs", "make
these comments functional", "too many comments in this package", "/doccleanup".

Does not trigger: writing a README, authoring missing documentation, reviewing
code for bugs, editing commit messages, or general refactoring. If the user wants
comments *added*, this is the wrong skill — say so rather than expanding scope.
