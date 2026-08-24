import std/[os, strutils]

# The version is read from the nimble file at compile time rather than repeated here. A literal
# `Version = "0.1.0"` is exactly what release tooling rewrites, and a copy in Nim source drifts
# from the one place that is supposed to hold it.
const
  Version = block:
    var found = ""
    for line in staticRead("../{{snake_name}}.nimble").splitLines():
      let parts = line.split('=', 1)
      if parts.len == 2 and parts[0].strip() == "version":
        found = parts[1].strip().strip(chars = {'"'})
        break
    doAssert found.len > 0, "{{snake_name}}.nimble is missing its version line"
    found

  About = "{{PROJECT_NAME}}"

proc showHelp() =
  echo About
  echo ""
  echo "Usage:"
  echo "  {{kebab_name}} [--help] [--version]"

proc main*() =
  let args = commandLineParams()
  if args.len == 0 or args[0] in ["-h", "--help"]:
    showHelp()
  elif args[0] in ["-V", "--version"]:
    echo Version
  else:
    stderr.writeLine("unknown command: " & args[0])
    quit(2)

when isMainModule:
  main()
