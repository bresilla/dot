# Mojo 1.0 ships no test runner, so the suite is a second entry point: an assertion that fails
# raises, and `make test` gates on the exit status.
from std.testing import assert_equal
from demo import add, greeting


def main() raises:
    assert_equal(add(2, 3), 5)
    assert_equal(add(0, 0), 0)
    assert_equal(greeting("wing"), "hello from wing")
    print("ok")
