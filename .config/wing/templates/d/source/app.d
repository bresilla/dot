import std.stdio;

import {{snake_name}}.core;

/// The version is read from dub.json at compile time rather than repeated here. dub.json is where
/// dub and `veri` both keep it, so a literal in D source would be a second copy that nothing bumps:
/// it would still say 0.1.0 long after the project had moved on.
enum versionString = readDubVersion();

private string readDubVersion()
{
    import std.algorithm : findSplitAfter;
    import std.string : indexOf, strip;

    auto rest = import("dub.json").findSplitAfter("\"version\"");
    assert(rest, "dub.json is missing its version field");
    auto opening = rest[1].indexOf('"');
    assert(opening >= 0, "dub.json's version field is malformed");
    auto value = rest[1][opening + 1 .. $];
    return value[0 .. value.indexOf('"')];
}

void main(string[] args)
{
    if (args.length > 1 && (args[1] == "-h" || args[1] == "--help"))
    {
        writeln("{{PROJECT_NAME}}");
        writeln("");
        writeln("Usage:");
        writeln("  {{kebab_name}} [--help] [--version]");
        return;
    }
    if (args.length > 1 && (args[1] == "-V" || args[1] == "--version"))
    {
        writeln(versionString);
        return;
    }
    writeln(greeting());
}
