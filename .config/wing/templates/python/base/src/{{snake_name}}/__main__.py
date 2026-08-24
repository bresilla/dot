"""Command-line entry point for {{PROJECT_NAME}}."""

from __future__ import annotations

import argparse
from collections.abc import Sequence

from . import __version__, name


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=name())
    parser.add_argument("--version", action="version", version=__version__)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    build_parser().parse_args(argv)
    print(name())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
