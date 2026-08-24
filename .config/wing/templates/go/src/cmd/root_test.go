package cmd

import "testing"

func TestRunHelp(t *testing.T) {
	if code := run("test", []string{"--help"}); code != 0 {
		t.Fatalf("expected success, got %d", code)
	}
}

func TestRunVersion(t *testing.T) {
	if code := run("test", []string{"--version"}); code != 0 {
		t.Fatalf("expected success, got %d", code)
	}
}
