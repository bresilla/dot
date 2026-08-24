package main

import (
	"fmt"
	"os"

	"github.com/bresilla/{{kebab_name}}/src/cmd"
)

// go.mod carries no version, so this literal is where the project's version lives -- it is the
// file `veri` rewrites on release. commit, date and builtBy are for a release pipeline to stamp in.
var (
	version = "0.1.0"
	commit  = ""
	date    = ""
	builtBy = ""
)

func main() {
	cmd.Execute(buildVersion(version, commit, date, builtBy), os.Exit, os.Args[1:])
}

func buildVersion(version, commit, date, builtBy string) string {
	result := version
	if commit != "" {
		result = fmt.Sprintf("%s\ncommit: %s", result, commit)
	}
	if date != "" {
		result = fmt.Sprintf("%s\nbuilt at: %s", result, date)
	}
	if builtBy != "" {
		result = fmt.Sprintf("%s\nbuilt by: %s", result, builtBy)
	}
	return result
}
