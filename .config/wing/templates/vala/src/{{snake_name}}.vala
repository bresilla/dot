namespace {{PascalName}} {
    // Mirrors the version in meson.build, which is the one place that holds it.
    public const string VERSION = "0.1.0";

    // The one thing this library does, so the starter has something to test.
    public string greeting () {
        return "hello from {{kebab_name}}";
    }
}
