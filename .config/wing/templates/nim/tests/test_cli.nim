import std/[os, osproc, strutils]

const Binary = "/tmp/{{kebab_name}}-test-bin"

proc checked(command: string): string =
  let res = execCmdEx(command)
  doAssert res.exitCode == 0, command & "\n" & res.output
  res.output

discard checked("nim c --out:" & quoteShell(Binary) & " src/{{snake_name}}.nim")
doAssert checked(quoteShell(Binary) & " --version").strip() == "0.1.0"
doAssert checked(quoteShell(Binary) & " --help").contains("{{PROJECT_NAME}}")

