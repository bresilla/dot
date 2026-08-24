module main

import os

// The version lives in v.mod, embedded and parsed at compile time. A literal here is exactly what
// release tooling rewrites -- wing's own `git-rel` did, leaving this template reporting wing's
// version instead of the project's.
const version = read_version()

fn read_version() string {
	manifest := $embed_file('../v.mod').to_string()
	for line in manifest.split_into_lines() {
		trimmed := line.trim_space()
		if trimmed.starts_with('version:') {
			return trimmed.all_after('version:').trim_space().trim('\'"')
		}
	}
	return '0.0.0'
}

fn greeting() string {
	return 'hello from {{kebab_name}}'
}

fn main() {
	args := os.args[1..]
	if args.len > 0 && args[0] in ['-h', '--help'] {
		println('{{PROJECT_NAME}}')
		println('')
		println('Usage:')
		println('  {{kebab_name}} [--help] [--version]')
		return
	}
	if args.len > 0 && args[0] in ['-V', '--version'] {
		println(version)
		return
	}
	println(greeting())
}
