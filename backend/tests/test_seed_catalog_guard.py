import subprocess
import sys
from pathlib import Path

import pytest

from scripts import seed_catalog

# Fabricated DSNs on the reserved `.invalid` TLD -- never a real credential.
_SEED_URL = "postgresql://beerapp_seed.testref:seed-pass@seed.example.invalid:5432/postgres"
_RUNTIME_URL = "postgresql://beerapp_backend.testref:runtime-pass@db.example.invalid:5432/postgres"

_BACKEND_DIR = Path(__file__).resolve().parent.parent


@pytest.mark.parametrize("environment", ["local", "dev"])
def test_check_seed_target_allows_local_and_dev_and_returns_only_the_host(environment):
    host = seed_catalog.check_seed_target(
        seed_url=_SEED_URL, runtime_url=_RUNTIME_URL, environment=environment
    )

    assert host == "seed.example.invalid"
    assert "seed-pass" not in host


@pytest.mark.parametrize("environment", ["production", "prod", "staging", ""])
def test_check_seed_target_refuses_any_other_environment(environment):
    with pytest.raises(seed_catalog.SeedRefusedError):
        seed_catalog.check_seed_target(
            seed_url=_SEED_URL, runtime_url=_RUNTIME_URL, environment=environment
        )


def test_check_seed_target_refuses_a_missing_seed_url():
    with pytest.raises(seed_catalog.SeedRefusedError, match="SEED_DATABASE_URL is not set"):
        seed_catalog.check_seed_target(seed_url=None, runtime_url=_RUNTIME_URL, environment="local")


def test_check_seed_target_refuses_the_runtime_url_as_seed_url():
    with pytest.raises(seed_catalog.SeedRefusedError, match="identical to DATABASE_URL"):
        seed_catalog.check_seed_target(
            seed_url=_RUNTIME_URL, runtime_url=_RUNTIME_URL, environment="local"
        )


def test_refusal_messages_never_contain_credentials():
    with pytest.raises(seed_catalog.SeedRefusedError) as excinfo:
        seed_catalog.check_seed_target(
            seed_url=_RUNTIME_URL, runtime_url=_RUNTIME_URL, environment="local"
        )

    assert "runtime-pass" not in str(excinfo.value)


@pytest.fixture
def isolated_main(monkeypatch):
    """Run seed_catalog.main() with no real .env and no real database."""
    monkeypatch.setattr(seed_catalog, "load_dotenv", lambda *_a, **_k: None)
    calls: list[str] = []

    async def fake_seed(seed_url: str) -> None:
        calls.append(seed_url)

    monkeypatch.setattr(seed_catalog, "seed", fake_seed)
    monkeypatch.setenv("SEED_DATABASE_URL", _SEED_URL)
    monkeypatch.setenv("DATABASE_URL", _RUNTIME_URL)
    monkeypatch.setenv("ENVIRONMENT", "local")
    return calls


def test_main_without_yes_prints_target_and_writes_nothing(isolated_main, capsys):
    with pytest.raises(SystemExit) as excinfo:
        seed_catalog.main([])

    assert excinfo.value.code == 2
    assert isolated_main == []
    err = capsys.readouterr().err
    assert "seed.example.invalid" in err
    assert "seed-pass" not in err


def test_main_with_yes_seeds_the_seed_url(isolated_main):
    seed_catalog.main(["--yes"])

    assert isolated_main == [_SEED_URL]


def test_main_with_yes_still_refuses_in_production(isolated_main, monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")

    with pytest.raises(SystemExit) as excinfo:
        seed_catalog.main(["--yes"])

    assert excinfo.value.code == 1
    assert isolated_main == []


def test_importing_the_seed_module_does_not_load_dotenv_into_the_environment():
    # tests import `_BEERS` from this module; that must never inject the
    # developer's real .env credentials into a test process.
    probe = (
        "import os; before = dict(os.environ); "
        "import scripts.seed_catalog; "
        "assert dict(os.environ) == before, 'importing seed_catalog changed os.environ'"
    )

    result = subprocess.run(
        [sys.executable, "-c", probe],
        cwd=_BACKEND_DIR,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, result.stderr
