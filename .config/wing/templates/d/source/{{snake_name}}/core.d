module {{snake_name}}.core;

/// The one thing this library does, so the starter has something to test.
string greeting()
{
    return "hello from {{kebab_name}}";
}

unittest
{
    assert(greeting() == "hello from {{kebab_name}}");
}
