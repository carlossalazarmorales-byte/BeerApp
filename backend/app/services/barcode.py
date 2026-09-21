def _has_valid_check_digit(canonical: str) -> bool:
    """Standard GS1 mod-10 check digit algorithm: from the digit adjacent to
    the check digit, alternate multipliers 3 and 1 leftward across the
    payload. Length-agnostic -- applies identically to EAN-8, EAN-13, and
    UPC-A represented as a 13-digit GTIN, so the same physical product code
    validates the same way regardless of which of those it started as.
    """
    payload, check_digit = canonical[:-1], int(canonical[-1])
    total = 0
    for index, char in enumerate(reversed(payload)):
        weight = 3 if index % 2 == 0 else 1
        total += int(char) * weight
    return (10 - (total % 10)) % 10 == check_digit


def canonicalize_barcode(raw: str) -> str:
    """Returns the canonical GTIN representation of a supported barcode: 8
    digits for EAN-8, or 13 digits for EAN-13/UPC-A (a 12-digit UPC-A is
    zero-prefixed to its canonical GTIN-13 form, so the same physical UPC-A
    code resolves identically whether a scanner reports it as 12-digit
    UPC-A or 13-digit EAN-13-with-leading-zero).

    Raises ValueError if `raw` is not digits-only, is not one of the
    supported lengths (8, 12, 13), or fails the GS1 check digit. UPC-E is
    deliberately unsupported -- there is no unambiguous canonical mapping
    for it defined yet.
    """
    trimmed = raw.strip()
    # `str.isdigit()` alone is not enough: it is True for Arabic-Indic,
    # fullwidth and other non-ASCII digits, which int() parses, so such a code
    # would canonicalize to a non-ASCII string that the database's ASCII-only
    # barcode CHECK then rejects (a 500). A barcode is ASCII 0-9 only.
    if not (trimmed.isascii() and trimmed.isdigit()):
        raise ValueError("barcode must contain digits only")

    if len(trimmed) == 12:
        canonical = "0" + trimmed
    elif len(trimmed) in (8, 13):
        canonical = trimmed
    else:
        raise ValueError("unsupported barcode length")

    if not _has_valid_check_digit(canonical):
        raise ValueError("invalid barcode check digit")

    return canonical
