# Functional Comment Style

Apply to every comment doccleanup rewrites. These rules also serve as the
fallback when no `humanizer` skill is available in the agent environment.

## Voice

- **Present tense, third person.** The subject is the code, not the reader and
  not the author. "Returns the parsed config." Not "We return" or "This will
  return".
- **State behavior, not intent.** "Caps the batch at 500 items." Not "Tries to
  keep batches reasonable."
- **Lead with the verb** for a block description; lead with the identifier when
  the language's doc convention requires it (Go, Rust).
- **One sentence** unless the behavior genuinely needs two. Stop at the period.

Banned openings: "This function", "This method", "Here we", "Basically",
"Simply", "Note that", "It's worth noting".

## Content

Include only what the reader cannot get from the signature:

- non-obvious return or error conditions
- units, ranges, and encodings (`milliseconds`, `0–1 inclusive`, `UTF-8`)
- required ordering, locking, and concurrency constraints
- side effects on arguments, globals, or the filesystem
- edge-case handling that the code expresses tersely

Exclude: history, alternatives considered, performance anecdotes, personal
opinion, gratitude, uncertainty, and anything with a date in it.

## AI tells to strip

Rewritten comments must not read as generated. Remove these on sight:

- **Rule of three.** "Fast, reliable, and maintainable." Pick the one that is
  true and measurable, or cut the sentence.
- **Inflated significance.** "Crucially", "importantly", "it is essential to
  note", "plays a vital role in", "serves as a cornerstone".
- **Promotional adjectives.** "robust", "seamless", "elegant", "powerful",
  "comprehensive", "efficient" used without a number behind it.
- **Superficial `-ing` clauses.** "...parsing the input, ensuring correctness
  and improving reliability." The trailing clause adds nothing; cut at the
  comma.
- **Hedging.** "may potentially", "generally speaking", "in most cases",
  "should typically". Either it does or it does not — read the code and say
  which.
- **Vague attribution.** "It is widely considered", "best practice suggests",
  "the standard approach is".
- **Filler transitions.** "Additionally", "Furthermore", "Moreover", "In order
  to" (use "to").
- **Em dash asides.** In a one-line comment, an em dash aside is padding. Cut it
  or split into two sentences.
- **Negative parallelism.** "Not just X, but Y." Say Y.

## Length

A body comment longer than three lines is describing too much. Either the block
does too many things, or the comment is restating the implementation. Cut to the
contract.

A doc comment is exempt from the density gate but not from this rule. Let it run
longer when it carries a real contract — parameters, errors, units, usage
examples — and cut it hard when the extra lines are padding.

## Before and after

```go
// BEFORE
// This function is a robust and efficient helper that handles the crucial
// task of validating user input — ensuring data integrity and improving
// overall system reliability. Note that it may potentially return an error.
func Validate(u User) error {

// AFTER
// Validate reports whether u has a non-empty ID and a parseable email address.
func Validate(u User) error {
```

```python
# BEFORE
# Here we simply iterate over the items, processing each one in turn and
# building up the result set, which is generally the cleanest approach.
for item in items:

# AFTER
# Skips items already present in seen.
for item in items:
```
