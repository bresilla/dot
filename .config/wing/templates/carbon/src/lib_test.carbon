// Carbon has no test runner yet, so the suite is a second entry point: `Run` returns the number of
// failures and `make test` gates on the exit status.
import Core library "io";
import {{PascalName}} library "core";

fn Check(name: str, got: i32, want: i32) -> i32 {
  if (got == want) {
    Core.PrintStr("ok   ");
    Core.PrintStr(name);
    Core.PrintStr("\n");
    return 0;
  }
  Core.PrintStr("FAIL ");
  Core.PrintStr(name);
  Core.PrintStr("\n");
  return 1;
}

fn Run() -> i32 {
  var failed: i32 = 0;
  failed += Check("Add adds", {{PascalName}}.Add(2, 3), 5);
  failed += Check("Add leaves zero alone", {{PascalName}}.Add(0, 0), 0);
  return failed;
}
