"""The dependency files are split so a deployment installs only what the running
API needs: `requirements.txt` is runtime, `requirements-dev.txt` adds test/lint tools.

Both files must stay plain UTF-8: a PowerShell `pip freeze >` redirect once turned
`requirements.txt` into UTF-16 (see docs/DECISIONS.md).
"""

import re
from pathlib import Path

_BACKEND = Path(__file__).resolve().parent.parent
_RUNTIME = _BACKEND / "requirements.txt"
_DEV = _BACKEND / "requirements-dev.txt"

_DEV_ONLY = {"pytest", "iniconfig", "pluggy", "ruff"}
# Import roots the app/scripts use, mapped to the distribution that provides them.
_RUNTIME_REQUIRED = {
    "fastapi",
    "starlette",
    "uvicorn",
    "asyncpg",
    "httpx",
    "pydantic",
    "pydantic-settings",
    "pyjwt",
    "cryptography",
    "python-dotenv",
}


def _norm(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def _pins(path: Path) -> dict[str, str]:
    pins = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith(("#", "-r ")):
            continue
        name, sep, version = line.partition("==")
        assert sep and version, f"{path.name}: {line!r} must be an exact ==pin"
        pins[_norm(name)] = version
    return pins


def test_dependency_files_are_plain_utf8_without_bom():
    for path in (_RUNTIME, _DEV):
        raw = path.read_bytes()
        assert not raw.startswith((b"\xef\xbb\xbf", b"\xff\xfe", b"\xfe\xff")), path.name
        assert b"\x00" not in raw, f"{path.name} looks UTF-16"
        raw.decode("utf-8")


def test_runtime_requirements_exclude_dev_tools():
    assert _DEV_ONLY.isdisjoint(_pins(_RUNTIME))


def test_runtime_requirements_include_what_the_app_imports():
    assert _RUNTIME_REQUIRED <= set(_pins(_RUNTIME))


def test_dev_requirements_extend_runtime_and_add_the_tools():
    lines = [ln.strip() for ln in _DEV.read_text(encoding="utf-8").splitlines()]
    assert "-r requirements.txt" in lines
    assert _DEV_ONLY == set(_pins(_DEV))


def test_dev_only_pins_do_not_also_appear_in_runtime():
    # One source of truth per package, so versions cannot drift between the files.
    assert set(_pins(_RUNTIME)).isdisjoint(_pins(_DEV))
