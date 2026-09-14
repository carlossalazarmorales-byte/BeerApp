# API

No application endpoints exist yet beyond `GET /health`. This document will be
filled in as real endpoints are added (starting Phase 3+), covering naming,
pagination, filtering, error shape, and status code conventions per
`CLAUDE.md`.

## Auth scope (Phase 2 decision)

FastAPI has **no role in Phase 2 authentication**. The mobile app talks to
Supabase Auth directly via `supabase_flutter` for sign-up, sign-in, sign-out,
password reset, and (later) Google/Apple sign-in — matching
`docs/ARCHITECTURE.md`'s data-flow note that Supabase Auth issues the session
token the mobile app holds. FastAPI has no `config.py`, no Supabase client,
and no JWT-verification dependency yet: nothing in Phase 2 needs a protected
backend endpoint. That lands in Phase 3 alongside the first real API
endpoint, at which point this document gets its first real conventions.
