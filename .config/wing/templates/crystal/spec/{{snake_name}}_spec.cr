require "spec"
require "../src/{{snake_name}}"

describe {{PascalName}} do
  it "greets" do
    {{PascalName}}.greeting.should eq("hello from {{kebab_name}}")
  end
end
