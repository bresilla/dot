int main (string[] args) {
    if (args.length > 1) {
        if (args[1] == "-h" || args[1] == "--help") {
            stdout.printf ("{{PROJECT_NAME}}\n\n");
            stdout.printf ("Usage:\n");
            stdout.printf ("  {{kebab_name}} [--help] [--version]\n");
            return 0;
        }
        if (args[1] == "-V" || args[1] == "--version") {
            stdout.printf ("%s\n", {{PascalName}}.VERSION);
            return 0;
        }
    }
    stdout.printf ("%s\n", {{PascalName}}.greeting ());
    return 0;
}
