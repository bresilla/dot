# Comment Classification

Read before the first edit of a doccleanup run.

## Contents

- Decision procedure
- Rewrite: rationale to behavior
- Delete: no functional content
- TODO markers
- Protected directives by language
- Ambiguous cases

## Decision procedure

For each comment, in order:

1. Is it a tool directive, license header, or bare issue link? → **preserve
   verbatim**, and skip the rest.
2. Strip every clause about *why*, *when*, *who*, or *what it replaced*. Is any
   description of behavior left? → **rewrite** to that description alone.
3. Nothing left, or what remains only restates the adjacent line? → **delete**.

## Rewrite: rationale to behavior

Salvage the factual core and drop the story around it.

```go
// BEFORE
// We had to add this check because users kept passing empty slices
// and it blew up in production back in March. Ticket #4412.
if len(items) == 0 {
    return nil
}

// AFTER
// Returns nil for an empty input.
if len(items) == 0 {
    return nil
}
```

```python
# BEFORE
def parse(raw):
    """
    Parses the payload. I originally wrote this with regex but that was
    too slow, so now it uses the streaming decoder instead. Much better.
    """

# AFTER
def parse(raw):
    """Decodes the payload with the streaming decoder."""
```

```rust
// BEFORE
/// Retry wrapper. Added after the incident review — the team decided
/// three attempts was a reasonable compromise between latency and
/// reliability, though we may revisit this later.
pub fn fetch_with_retry(url: &str) -> Result<Response> {

// AFTER
/// Fetches `url`, retrying up to three times before returning the last error.
pub fn fetch_with_retry(url: &str) -> Result<Response> {
```

A rationale that is genuinely load-bearing has a functional restatement. "We
must lock in this order because the scheduler deadlocks otherwise" becomes
"Acquires `a` before `b`; the reverse order deadlocks." The constraint survives,
the meeting does not.

## Delete: no functional content

```ts
// BEFORE
// increment the counter
count += 1;

// TODO(me): not sure this is the best approach but it works for now
// ---------------- HELPERS ----------------
// Copied from the old service, cleaned up a bit.

// AFTER
count += 1;
```

Delete outright: changelog notes, attribution, apologies, uncertainty
("hopefully", "not sure why this works"), decorative banners, commented-out
code, and anything that restates the line beneath it.

## TODO markers

Keep the marker and the actionable item. Strip the justification.

```go
// BEFORE
// TODO: we should probably refactor this at some point because the API
// is honestly pretty ugly and hard to read

// AFTER
// TODO: replace with the batch API.
```

A `TODO` with no actionable item after stripping is a complaint, not a task —
delete it.

## Protected directives by language

Preserve verbatim. Excluded from density counts.

| Language | Directives |
|---|---|
| Go | `//go:build`, `// +build`, `//go:generate`, `//go:embed`, `//go:noinline`, `//nolint:`, `// Code generated ... DO NOT EDIT.` |
| Rust | `#[allow]`, `#[cfg]`, `#[doc(hidden)]` and every other attribute, `// rustfmt::skip` |
| Python | `# type:`, `# noqa`, `# pragma: no cover`, `# fmt: off/on`, `# isort:`, encoding declarations |
| JS/TS | `// eslint-disable*`, `// @ts-ignore`, `// @ts-expect-error`, `// prettier-ignore`, `/* webpackChunkName */`, `// @flow` |
| C/C++ | `// NOLINT`, `// clang-format off/on`, `#pragma` |
| Shell | shebangs, `# shellcheck disable=` |
| Any | SPDX identifiers, copyright and license headers |

When unsure whether a comment is a directive, check whether removing it could
change what a compiler, linter, formatter, or build tool does. If it could,
preserve it.

## Ambiguous cases

**Bare link comments** (`// See RFC 7231 §6.5.1`, `// https://github.com/x/y/issues/12`)
are preserved. One inside a block body counts toward that block's budget; one in
a doc comment does not. A link wrapped in rationale gets the rationale stripped,
keeping the link.

**Example blocks in doc comments** (Go `Example` prose, Rust doc tests, Python
doctests) are functional documentation — they describe usage. Keep them. They sit
in the doc comment, so the density gate does not count or cut them.

**Parameter and return documentation** (`@param`, `:returns:`, `# Arguments`) is
functional. Keep the structure the language's doc tooling expects.

**Commented-out code** is never documentation. Delete it; version control has it.
