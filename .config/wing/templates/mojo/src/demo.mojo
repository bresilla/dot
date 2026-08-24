# The project's own module. `main.mojo` and `main_test.mojo` both import it, which is what keeps
# the code under test out of the binary's entry point. `-I src` is what puts it on the path.


def add(a: Int, b: Int) -> Int:
    return a + b


def greeting(name: String) -> String:
    return "hello from " + name
