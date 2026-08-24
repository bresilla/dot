// The project's own package. `main.carbon` and `lib_test.carbon` both import it, which is what
// keeps the code under test out of the binary's entry point.
package {{PascalName}} library "core";

fn Add(a: i32, b: i32) -> i32 {
  return a + b;
}
