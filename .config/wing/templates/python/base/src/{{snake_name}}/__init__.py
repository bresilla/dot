"""{{PROJECT_NAME}} package."""

from importlib.metadata import PackageNotFoundError
from importlib.metadata import version as _installed_version
from pathlib import Path
from re import search

__all__ = ["__version__", "name"]


def _read_version() -> str:
    """The version: from package metadata when installed, from pyproject.toml in a checkout."""
    try:
        return _installed_version("{{kebab_name}}")
    except PackageNotFoundError:
        pass
    for parent in Path(__file__).resolve().parents:
        pyproject = parent / "pyproject.toml"
        if pyproject.is_file():
            found = search(r'(?m)^version\s*=\s*"([^"]+)"', pyproject.read_text())
            if found:
                return found.group(1)
    return "0.0.0+unknown"


__version__ = _read_version()


def name() -> str:
    """Return the project display name."""
    return "{{PROJECT_NAME}}"
