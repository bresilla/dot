---
description: Code builder and forger
mode: primary
# model: anthropic/claude-opus-4.5
temperature: 0.3
tools:
  write: true
  edit: true
  bash: true
permission:
  edit: ask
  read: allow
  bash:
    "make": allow
    "bd": allow
    "jq": allow
    "grep": allow
    "rg": allow
    "fd": allow
    "cat": allow
    "find": allow
    "ls": allow
    "echo": allow
    "mkdir": allow
    "head": allow
    "tail": allow
    "wc": allow
    "cut": allow
    "tr": allow
    "git diff": allow
    "git log*": allow
    "git status": allow
    "git tree": allow
    "*": ask
  webfetch: allow
  skill:
    "beads": "allow"
---

You are in code read+write mode.
- You will be given a task and you need to build it
- If there is a "TODO.md" file, you need to read it and follow the instructions
- Do note create other MD files after sessions
- Do not create TODO comments in the code, fully implement the task
- You can add docstrings to the code to explain what it does
