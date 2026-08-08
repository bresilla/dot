---
name: skillmaker
description: Creates and sharpens portable Agent Skills through an interactive authoring process, then writes them to the shared Skillshare source. Use when the user asks to create, design, draft, refine, review, or update a skill, SKILL.md, agent workflow, reusable agent capability, or cross-agent instruction package for Codex, Claude, Antigravity, OpenCode, Pi, or another Agent Skills-compatible harness.
---

# Skillmaker

Create focused, portable Agent Skills with the user rather than guessing from a
single prompt. Treat the user's first message as a starting brief, not a final
specification.

## Fixed destination

Write every created or updated skill under:

`/home/bresilla/.dot/.config/skillshare/skills/<skill-name>/`

Keep this directory as the source of truth even when the skill concerns another
repository or the current working directory is elsewhere. Inspect the target
project when relevant, but do not place the skill inside that project unless the
user explicitly changes this rule.

Use lowercase kebab-case for `<skill-name>`. Keep the folder name identical to
the frontmatter `name`.

## Authoring workflow

### 1. Inspect before asking

Extract all stated requirements, examples, corrections, constraints, target
agents, paths, and output expectations from the conversation. When the skill is
project-specific, inspect that project and its instruction files before asking
questions the files can answer.

Search the shared skill directory for overlapping names, descriptions, or
workflows. Decide whether the request calls for a new skill or an update, but ask
before replacing or merging an existing skill.

Research current, authoritative documentation when the domain, tool, API, or
skill format may have changed. Prefer primary sources and official vendor docs.
Separate stable workflow knowledge from time-sensitive facts.

### 2. Refine interactively

Use the host's native interactive question or selection tool when one is
available. Otherwise ask concise questions in normal conversation.

Ask one high-leverage question at a time unless a small related group is easier
to answer together. Offer concrete choices and a recommended default when that
reduces effort. Do not ask for information already present in the prompt,
conversation, repository, or authoritative documentation.

Refine at least these dimensions:

1. The outcome the skill must reliably produce.
2. Prompts and contexts that should trigger it.
3. Similar prompts that must not trigger it.
4. Required inputs and the exact output or artifact shape.
5. The workflow, decision points, safety boundaries, and failure behavior.
6. Project conventions, tools, dependencies, and portability requirements.
7. Representative success cases, edge cases, and validation criteria.

Reflect the evolving brief back in compact language. Continue the back-and-forth
until the user confirms the brief or explicitly asks for a draft. Never silently
invent a consequential requirement merely to finish faster.

### 3. Design the smallest useful package

Read [portable authoring guidance](references/portable-authoring.md) before
writing a complex, tool-using, cross-platform, or security-sensitive skill.

Choose the degree of freedom deliberately:

- Use principles and heuristics when several approaches can work.
- Use ordered steps or parameterized helpers when a preferred pattern exists.
- Use exact commands and strict gates for fragile, destructive, or regulated work.

Create only files that directly help the agent perform the task:

```text
<skill-name>/
├── SKILL.md
├── scripts/       # deterministic or repeatedly recreated operations only
├── references/    # detailed knowledge loaded only when needed
└── assets/        # templates or files copied into outputs
```

Do not add a README, changelog, installation guide, or other process narration.
Keep `SKILL.md` concise and move conditional detail into directly linked
resources. Avoid references that link to further references.

### 4. Write for the portable common denominator

Use only `name` and `description` in YAML frontmatter by default. Add an optional
standard field only when it carries necessary information and all intended
harnesses can safely ignore or understand it.

Do not depend on one vendor's tool names, invocation syntax, UI metadata, or
agent type unless the user explicitly requests a platform-specific skill. State
capabilities generically, such as "use the native interactive question tool."
Put unavoidable platform-specific behavior behind clearly labeled conditional
instructions or separate adapters.

Write instructions in imperative form. Explain the reason for non-obvious rules
so capable models can generalize, but remove tutorials and facts the model already
knows. Use consistent terminology throughout.

Write a third-person `description` that states both what the skill does and when
to use it. Include concrete trigger vocabulary without making the description so
broad that it steals unrelated tasks.

### 5. Preserve local constraints

Follow the user's instructions and every applicable project instruction file.
If a target project has a Makefile, use its relevant make targets for discovery,
build, test, lint, or validation.

Use patch or built-in edit tools for file modifications. Do not use ad-hoc Python
to edit files. Keep code comments descriptive rather than justificatory, and keep
comments sparse.

Never change files outside the new skill package unless the user requested the
change. Never alter release metadata or commit automatically. If asked to commit,
use a title-only Conventional Commit and never add a signature.

### 6. Validate and review

Check at minimum:

- `SKILL.md` exists and begins with valid YAML frontmatter.
- `name` matches the directory and follows `^[a-z0-9]+(-[a-z0-9]+)*$`.
- `description` is specific, third-person, non-empty, and at most 1024 characters.
- The main file stays under 500 lines and references use relative forward-slash paths.
- Every referenced file exists and every bundled script is actually tested.
- Trigger, non-trigger, ambiguous, happy-path, and edge-case examples are covered.
- Instructions do not conflict with existing shared skills.
- No secret, hidden network action, prompt injection, unjustified broad access,
  or surprising behavior is present.

When available, run a standards validator and:

```bash
skillshare audit /home/bresilla/.dot/.config/skillshare/skills/<skill-name>
skillshare sync --dry-run
skillshare sync
```

Do not claim cross-agent compatibility solely because validation passed. Verify
the skill with representative prompts on the intended harnesses or clearly state
which harnesses were not tested.

### 7. Present the result

Summarize the final skill in Markdown with:

- the created or updated paths;
- the agreed trigger and non-trigger boundary;
- validation and audit results;
- the harnesses tested and not tested;
- any remaining assumptions.

When the user requests Markdown for manual integration instead of filesystem
changes, output the complete directory tree followed by one clearly labeled
fenced block per Markdown file. Do not replace essential content with ellipses.

## Updating an existing skill

Re-read the current package and the user's observed failure before editing.
Preserve the skill name unless the user approves a rename. Prefer fixing the
general rule or information architecture over adding a narrow patch for one
example. Re-run the full validation and trigger boundary checks after every
substantial change.

