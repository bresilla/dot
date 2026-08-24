from {{snake_name}} import name
from {{snake_name}}.__main__ import main


def test_name() -> None:
    assert name() == "{{PROJECT_NAME}}"


def test_cli(capsys) -> None:
    assert main([]) == 0
    assert capsys.readouterr().out.strip() == "{{PROJECT_NAME}}"
