import pytest

from app.services.barcode import canonicalize_barcode
from scripts.seed_catalog import _BEERS


class TestCanonicalizeBarcode:
    def test_ean13_already_canonical_is_returned_unchanged(self) -> None:
        assert canonicalize_barcode("5000213007075") == "5000213007075"

    def test_ean8_is_returned_unchanged(self) -> None:
        assert canonicalize_barcode("11111115") == "11111115"

    def test_upca_is_zero_prefixed_to_canonical_gtin13(self) -> None:
        # A checksum-valid 12-digit UPC-A code.
        assert canonicalize_barcode("111111111117") == "0111111111117"

    def test_upca_and_its_zero_prefixed_ean13_form_canonicalize_identically(
        self,
    ) -> None:
        # The same physical product must resolve the same way regardless of
        # which representation a given platform/scanner reports.
        assert canonicalize_barcode("111111111117") == canonicalize_barcode("0111111111117")

    def test_surrounding_whitespace_is_trimmed(self) -> None:
        assert canonicalize_barcode("  5000213007075  ") == "5000213007075"

    def test_leading_zeroes_are_preserved(self) -> None:
        assert canonicalize_barcode("00000123") == "00000123"

    def test_non_digit_input_is_rejected(self) -> None:
        with pytest.raises(ValueError, match="digits only"):
            canonicalize_barcode("5000213A07075")

    @pytest.mark.parametrize("length", [1, 5, 7, 9, 10, 11, 14, 20])
    def test_unsupported_length_is_rejected(self, length: int) -> None:
        with pytest.raises(ValueError, match="unsupported barcode length"):
            canonicalize_barcode("1" * length)

    def test_invalid_check_digit_is_rejected(self) -> None:
        # Same payload as the valid EAN-13 fixture above, wrong check digit.
        with pytest.raises(ValueError, match="check digit"):
            canonicalize_barcode("5000213007072")

    def test_upce_is_not_supported(self) -> None:
        # UPC-E (6 digits) has no unambiguous canonical mapping defined yet
        # and is deliberately deferred, not silently accepted as EAN-8/other.
        with pytest.raises(ValueError, match="unsupported barcode length"):
            canonicalize_barcode("123456")


class TestSeedCatalogBarcodesAreValid:
    def test_every_non_null_seeded_barcode_has_a_valid_checksum(self) -> None:
        # Catches exactly the class of bug found during Phase 11 planning:
        # a "13-digit-shaped" seed value that looked plausible but failed
        # GS1 check-digit validation.
        barcodes = [beer[-1] for beer in _BEERS if beer[-1] is not None]
        assert barcodes, "expected at least one seeded barcode fixture"
        for barcode in barcodes:
            canonicalize_barcode(barcode)  # raises ValueError if invalid

    def test_most_seeded_beers_remain_barcode_less(self) -> None:
        # A beer with no barcode is normal product behavior, not an error --
        # the seed catalog must keep exercising that case, not just the
        # scanner-happy path.
        with_barcode = sum(1 for beer in _BEERS if beer[-1] is not None)
        assert with_barcode < len(_BEERS)
