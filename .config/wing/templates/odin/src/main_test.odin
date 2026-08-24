package main

import "core:testing"

@(test)
test_greeting :: proc(t: ^testing.T) {
	testing.expect_value(t, greeting(), "hello from {{kebab_name}}")
}
