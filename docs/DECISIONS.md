# Decisions

## 2026-09-14 — Backend linting/formatting: ruff

Chose `ruff` over `black` + `flake8` for the backend. It covers both linting
and formatting in one dependency, avoiding two tools that solve overlapping
problems. Config lives in `backend/pyproject.toml`.

## 2026-09-14 — Fixed `requirements.txt` encoding

`backend/requirements.txt` was UTF-16 (from a PowerShell `pip freeze >`
redirect, which defaults to UTF-16). Regenerated in UTF-8 to avoid tooling
that assumes UTF-8. `pytest` and `ruff` added as dependencies for testing/linting.

## 2026-09-14 — CI deferred

No GitHub Actions workflow added in Phase 0. `ROADMAP.md`'s Phase 0 checklist
doesn't call for it, and there isn't enough real code yet to make CI worth the
setup cost. Revisit once there's meaningful test coverage to gate on.
