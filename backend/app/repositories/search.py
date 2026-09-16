_LIKE_ESCAPE_CHAR = "\\"


def escape_like_term(value: str) -> str:
    """Escapes LIKE/ILIKE metacharacters so `value` is matched literally.

    Parameterized queries prevent SQL injection but do not make '%'/'_'
    literal inside an ILIKE *pattern* -- those remain wildcards even when the
    pattern itself is passed as a bound parameter. A search for a literal
    '%' must not match every row.

    Shared by BeerRepository and MapRepository -- extracted once a second
    consumer needed the identical escaping (see docs/DECISIONS.md).
    """
    escaped = value.replace(_LIKE_ESCAPE_CHAR, _LIKE_ESCAPE_CHAR * 2)
    escaped = escaped.replace("%", "\\%").replace("_", "\\_")
    return escaped
