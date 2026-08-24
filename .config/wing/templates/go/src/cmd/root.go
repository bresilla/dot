package cmd

import (
	"flag"
	"fmt"
	"io"
)

type command struct {
	version string
	stdout  io.Writer
	stderr  io.Writer
}

func Execute(version string, exit func(int), args []string) {
	code := run(version, args)
	if code != 0 {
		exit(code)
	}
}

func run(version string, args []string) int {
	cmd := command{version: version, stdout: flag.CommandLine.Output(), stderr: flag.CommandLine.Output()}
	fs := flag.NewFlagSet("{{kebab_name}}", flag.ContinueOnError)
	fs.SetOutput(cmd.stderr)
	showVersion := fs.Bool("version", false, "print version")
	showHelp := fs.Bool("help", false, "print help")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if *showVersion {
		fmt.Fprintln(cmd.stdout, cmd.version)
		return 0
	}
	if *showHelp || fs.NArg() == 0 {
		cmd.printHelp()
		return 0
	}
	fmt.Fprintf(cmd.stderr, "unknown command: %s\n", fs.Arg(0))
	return 2
}

func (c command) printHelp() {
	fmt.Fprintln(c.stdout, "{{PROJECT_NAME}}")
	fmt.Fprintln(c.stdout)
	fmt.Fprintln(c.stdout, "Usage:")
	fmt.Fprintln(c.stdout, "  {{kebab_name}} [--version] [--help]")
}
