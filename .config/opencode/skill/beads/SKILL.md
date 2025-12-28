---
name: beads
description: Use Beads to structure and execute work via epics, tasks, and dependencies
license: MIT
compatibility: opencode
metadata:
  audience: coders
---

## What I do

When a project uses **Beads (`bd`)**, I follow a **graph-driven workflow** based on
explicit epics, tasks, and dependencies.

My goal is to execute work in the **correct order**, without guessing, skipping,
or inventing priorities that are not encoded in the graph.

I treat Beads as the single source of truth for:
- what exists
- what blocks what
- what is allowed to be worked on next

### Epics

An **epic** represents a high-level goal or outcome.

- defines *what should exist*
- is not worked on directly
- is completed by closing its tasks

I create one epic per major objective.

```bash
bd create "Build demo CLI" -t epic -p 0
````

### Tasks

A **task** is a concrete, executable unit of work.

Good tasks:

* fit in one work session
* produce a clear result
* unblock other tasks

Tasks are the only issues I actively work on.

```bash
bd create "Scaffold project structure" -p 1
bd create "Implement CLI command" -p 1
bd create "Add basic test" -p 2
```

### Dependencies

A **dependency** defines ordering between issues.

```bash
bd dep add <child> <parent>
```

Meaning:

* `<child>` is blocked until `<parent>` is closed

Dependencies form a **directed execution graph**.

```bash
bd dep add implement-command scaffold-project
bd dep add add-test implement-command
```

```
scaffold-project
        ↓
implement-command
        ↓
add-test
```

### Graph-Based Structure

* nodes = epics and tasks
* edges = blocking relationships
* order comes only from dependencies
* priority affects choice, not order

If order matters, it is encoded as a dependency.

---

## How I work

I never start work by guessing.

I always ask Beads what is valid to do next.

### Finding Work

```bash
bd ready
```

This returns issues that:

* are open
* have no unmet dependencies

Only these issues are allowed to be worked on.

### Execution Loop

1. Check ready work

```bash
bd ready
```

2. Inspect a task

```bash
bd show <issue-id>
```

3. Mark it in progress

```bash
bd update <issue-id> --status in_progress
```

4. Implement and commit code

5. Close the task

```bash
bd close <issue-id> --reason "Completed"
```

Closing a task may unblock others.

## Rules I Follow

* I only work on tasks, never epics
* I always respect dependencies
* I never infer order from names or priority
* I always close tasks explicitly
* If something must happen first, I add a dependency

Beads is used to **execute work deterministically**, not to improvise.
