require "./{{snake_name}}"

args = ARGV

if args.size > 0 && (args[0] == "-h" || args[0] == "--help")
  puts "{{PROJECT_NAME}}"
  puts ""
  puts "Usage:"
  puts "  {{kebab_name}} [--help] [--version]"
elsif args.size > 0 && (args[0] == "-V" || args[0] == "--version")
  puts {{PascalName}}::VERSION
else
  puts {{PascalName}}.greeting
end
