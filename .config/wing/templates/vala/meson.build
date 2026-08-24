project('{{kebab_name}}', ['vala', 'c'],
  version: '0.1.0',
  license: 'MIT',
  default_options: ['warning_level=2'])

glib = dependency('glib-2.0')
gobject = dependency('gobject-2.0')

{{snake_name}}_lib = static_library('{{snake_name}}',
  'src/{{snake_name}}.vala',
  dependencies: [glib, gobject])

executable('{{kebab_name}}',
  'src/main.vala',
  link_with: {{snake_name}}_lib,
  dependencies: [glib, gobject],
  install: true)

test_exe = executable('{{kebab_name}}-test',
  'test/{{snake_name}}_test.vala',
  link_with: {{snake_name}}_lib,
  dependencies: [glib, gobject])
test('{{kebab_name}}', test_exe)
