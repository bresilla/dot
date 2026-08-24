# The one thing this library does, so the starter has something to test.
module {{PascalName}}
  # Mirrors the version in shard.yml, which is the one place that holds it.
  VERSION = "0.1.0"

  def self.greeting : String
    "hello from {{kebab_name}}"
  end
end
