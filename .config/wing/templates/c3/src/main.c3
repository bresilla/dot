module {{snake_name}};
import std::io;

const VERSION = "0.1.0";

fn String greeting()
{
	return "hello from {{kebab_name}}";
}

fn void usage()
{
	io::printn("{{PROJECT_NAME}}");
	io::printn("");
	io::printn("Usage:");
	io::printn("  {{kebab_name}} [--help] [--version]");
}

fn int main(String[] args)
{
	if (args.len > 1)
	{
		if (args[1] == "-h" || args[1] == "--help")
		{
			usage();
			return 0;
		}
		if (args[1] == "-V" || args[1] == "--version")
		{
			io::printn(VERSION);
			return 0;
		}
	}
	io::printn(greeting());
	return 0;
}
