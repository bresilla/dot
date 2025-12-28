---
name: make
description: Use Makefile to config and build the project
license: MIT
compatibility: opencode
metadata:
  audience: coders
---

## What I do

When a project uses a **Makefile** for building, I follow **safe and preferred build behavior** instead of blindly invoking destructive targets.

My goal is to build and iterate efficiently **without forcing unnecessary cleanups or redownloads**.

- Prefer using:
  - `make config`
  - `make build`

- Avoid using:
  - `make clean`
  - `make reconfig`

These targets are **more destructive** and may:
- remove build caches
- force redownloads
- significantly slow down iteration

If `make config` or `make build` fails:

1. Analyze the failure
2. Retry using the least destructive target possible
3. Use `make clean` or `make reconfig` **only if necessary** and only after simpler options fail

I do not default to clean or reconfigure unless explicitly instructed.

- I DO NOT RUN BARE "cmake", "gcc", "g++", "xmake", etc...
- I assume the user wants **fast, incremental builds**
- I explain which Makefile target I am choosing and why
- I warn before running destructive targets
- I ask before forcing a full clean or reconfigure

## When to use me

Use this skill when:

- the Makefile defines both incremental and destructive targets
- clean or reconfig triggers heavy rebuilds or downloads
- you want cautious, developer-friendly build behavior
