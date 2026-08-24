import Core library "io";
import {{PascalName}} library "core";

fn Greet(name: str) {
  Core.PrintStr("hello from ");
  Core.PrintStr(name);
  Core.PrintStr("\n");
}

fn Run() {
  Greet("{{kebab_name}}");
  Core.PrintStr("2 + 3 = ");
  Core.Print({{PascalName}}.Add(2, 3));
  Core.PrintStr("\n");
}
