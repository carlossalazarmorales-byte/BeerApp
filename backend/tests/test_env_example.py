"""`.env.example` must not drift from the real settings: every variable it
documents (set or commented-out) is either a `Settings` field or one of the few
variables read outside `Settings` on purpose.
"""

import re
from pathlib import Path

from app.config import Settings

_ENV_EXAMPLE = Path(__file__).resolve().parent.parent.parent / ".env.example"

# Read directly by scripts/tests, deliberately not part of the running app's Settings.
_READ_OUTSIDE_SETTINGS = {
    "SEED_DATABASE_URL",  # backend/scripts/seed_catalog.py only
    "INTEGRATION_DATABASE_URL",  # tests/integration only
    "INTEGRATION_DATABASE_ALLOW_REMOTE",  # tests/integration only
}

_VARIABLE = re.compile(r"^#?\s*([A-Z][A-Z0-9_]+)=")


def _documented_variables() -> set[str]:
    names = set()
    for line in _ENV_EXAMPLE.read_text(encoding="utf-8").splitlines():
        match = _VARIABLE.match(line)
        if match:
            names.add(match.group(1))
    return names


def test_every_documented_variable_is_a_real_setting_or_a_known_exception():
    known = {name.upper() for name in Settings.model_fields} | _READ_OUTSIDE_SETTINGS

    unknown = _documented_variables() - known

    assert not unknown, f".env.example documents variables nothing reads: {sorted(unknown)}"


def test_every_operational_setting_is_documented_in_env_example():
    documented = _documented_variables()
    # Settings that have no meaningful operator-facing knob.
    internal = {"api_base_url"}
    expected = {name.upper() for name in Settings.model_fields if name not in internal}

    missing = expected - documented

    assert not missing, f"settings missing from .env.example: {sorted(missing)}"


def test_env_example_holds_no_real_looking_values():
    # Placeholders only: every assigned (uncommented) value is empty or a plain default.
    for line in _ENV_EXAMPLE.read_text(encoding="utf-8").splitlines():
        if re.match(r"^[A-Z][A-Z0-9_]+=", line):
            value = line.split("=", 1)[1].strip()
            assert "://" not in value or value.startswith("http://localhost"), line
            assert "sb_" not in value and "eyJ" not in value, line
