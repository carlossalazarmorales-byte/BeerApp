from decimal import Decimal
from uuid import UUID

import pytest
from pydantic import ValidationError

from app.schemas.contributions import (
    BeerContributionCreate,
    BeerDuplicateCandidatesOut,
    BeerDuplicateCheckQuery,
    BreweryContributionCreate,
    BreweryDuplicateCheckQuery,
)

_BREWERY_ID = "44444444-4444-4444-4444-444444444444"
_STYLE_ID = "55555555-5555-5555-5555-555555555555"
_COUNTRY_ID = "66666666-6666-6666-6666-666666666666"


def _beer(**overrides) -> BeerContributionCreate:
    fields = {"official_name": "Hazy IPA", "brewery_id": _BREWERY_ID}
    fields.update(overrides)
    return BeerContributionCreate(**fields)


# -- beer: server-controlled fields can never be supplied ---------------------


@pytest.mark.parametrize(
    "field",
    ["user_id", "status", "reviewed_at", "review_note", "resolved_beer_id", "id", "created_at"],
)
def test_beer_contribution_rejects_server_controlled_fields(field):
    with pytest.raises(ValidationError):
        _beer(**{field: "anything"})


@pytest.mark.parametrize("field", ["user_id", "status", "reviewed_at", "resolved_brewery_id"])
def test_brewery_contribution_rejects_server_controlled_fields(field):
    with pytest.raises(ValidationError):
        BreweryContributionCreate(name="X", country_id=_COUNTRY_ID, **{field: "anything"})


# -- beer: text normalization -------------------------------------------------


def test_beer_name_is_trimmed_and_internal_whitespace_collapsed():
    assert _beer(official_name="  Hazy \t  IPA\n").official_name == "Hazy IPA"


@pytest.mark.parametrize("name", ["", "   ", "\t\n"])
def test_beer_name_must_not_be_blank(name):
    with pytest.raises(ValidationError):
        _beer(official_name=name)


def test_beer_name_length_is_measured_after_normalization():
    assert len(_beer(official_name="  " + "x" * 200 + "  ").official_name) == 200
    with pytest.raises(ValidationError):
        _beer(official_name="x" * 201)


# -- beer: brewery is canonical XOR proposed ---------------------------------


def test_beer_accepts_a_canonical_brewery():
    contribution = _beer()
    assert contribution.brewery_id == UUID(_BREWERY_ID)
    assert contribution.proposed_brewery_name is None


def test_beer_accepts_a_proposed_brewery_without_any_brewery_contribution():
    contribution = BeerContributionCreate(
        official_name="Hazy IPA", proposed_brewery_name="  Brand   New Brewery "
    )
    assert contribution.brewery_id is None
    assert contribution.proposed_brewery_name == "Brand New Brewery"


def test_beer_rejects_both_brewery_forms():
    with pytest.raises(ValidationError):
        _beer(proposed_brewery_name="Also Named")


def test_beer_rejects_no_brewery_at_all():
    with pytest.raises(ValidationError):
        BeerContributionCreate(official_name="Hazy IPA")


def test_beer_rejects_a_blank_proposed_brewery():
    with pytest.raises(ValidationError):
        BeerContributionCreate(official_name="Hazy IPA", proposed_brewery_name="   ")


def test_beer_has_no_reference_to_a_brewery_contribution():
    # The decision: a beer never depends on a separate brewery suggestion.
    assert not any("contribution" in name for name in BeerContributionCreate.model_fields)


# -- beer: style --------------------------------------------------------------


def test_beer_style_is_optional_and_can_be_canonical_or_proposed():
    assert _beer().style_id is None
    assert _beer(style_id=_STYLE_ID).style_id == UUID(_STYLE_ID)
    assert _beer(proposed_style_name="Weird Style").proposed_style_name == "Weird Style"


def test_beer_rejects_both_style_forms():
    with pytest.raises(ValidationError):
        _beer(style_id=_STYLE_ID, proposed_style_name="Weird Style")


def test_beer_proposed_style_is_limited_to_100_characters():
    with pytest.raises(ValidationError):
        _beer(proposed_style_name="s" * 101)


# -- beer: abv ---------------------------------------------------------------


@pytest.mark.parametrize("abv", ["0", "5.5", "99.99"])
def test_beer_abv_accepts_the_numeric_4_2_range(abv):
    assert _beer(abv=abv).abv == Decimal(abv)


@pytest.mark.parametrize("abv", ["-0.1", "100", "150", "5.555"])
def test_beer_abv_rejects_out_of_range_or_too_precise_values(abv):
    with pytest.raises(ValidationError):
        _beer(abv=abv)


# -- beer: barcode reuses the Phase 11 canonicalizer --------------------------


def test_beer_barcode_is_canonicalized_and_optional():
    assert _beer().barcode is None
    assert _beer(barcode="4006381333931").barcode == "4006381333931"
    assert _beer(barcode="96385074").barcode == "96385074"
    # A 12-digit UPC-A is stored as its canonical zero-prefixed GTIN-13.
    assert _beer(barcode=" 036000291452 ").barcode == "0036000291452"


@pytest.mark.parametrize(
    "barcode",
    [
        "4006381333932",  # wrong check digit
        "12345",  # unsupported length
        "ABCDEFGHIJKLM",  # not digits
        "",  # blank is not "omitted" -- omit the field instead
        "01234567",  # 8 digits, wrong EAN-8 check digit (UPC-E is not supported)
    ],
)
def test_beer_rejects_invalid_barcodes(barcode):
    with pytest.raises(ValidationError):
        _beer(barcode=barcode)


# -- brewery ------------------------------------------------------------------


def test_brewery_accepts_a_canonical_country_and_optional_location():
    contribution = BreweryContributionCreate(
        name="  Hop   House ", country_id=_COUNTRY_ID, region=" Bavaria ", city="Munich"
    )
    assert contribution.name == "Hop House"
    assert contribution.region == "Bavaria"
    assert contribution.city == "Munich"


def test_brewery_accepts_a_proposed_country_when_the_country_is_not_listed():
    contribution = BreweryContributionCreate(name="Hop House", proposed_country_name="Atlantis")
    assert contribution.country_id is None
    assert contribution.proposed_country_name == "Atlantis"


def test_brewery_rejects_both_or_neither_country_form():
    with pytest.raises(ValidationError):
        BreweryContributionCreate(
            name="Hop House", country_id=_COUNTRY_ID, proposed_country_name="Atlantis"
        )
    with pytest.raises(ValidationError):
        BreweryContributionCreate(name="Hop House")


@pytest.mark.parametrize("field", ["region", "city"])
def test_brewery_optional_text_must_not_be_blank_or_too_long(field):
    with pytest.raises(ValidationError):
        BreweryContributionCreate(name="X", country_id=_COUNTRY_ID, **{field: "  "})
    with pytest.raises(ValidationError):
        BreweryContributionCreate(name="X", country_id=_COUNTRY_ID, **{field: "x" * 101})


def test_brewery_has_no_coordinates_website_or_description():
    # Deliberately omitted: a moderator geocodes/verifies; no user-supplied URLs.
    assert set(BreweryContributionCreate.model_fields) == {
        "name",
        "country_id",
        "proposed_country_name",
        "region",
        "city",
    }


# -- duplicate-check query models ---------------------------------------------


def test_beer_duplicate_query_normalizes_and_canonicalizes_like_a_submission():
    query = BeerDuplicateCheckQuery(
        official_name="  Hazy  IPA ", brewery_id=_BREWERY_ID, barcode="036000291452"
    )
    assert query.official_name == "Hazy IPA"
    assert query.barcode == "0036000291452"


def test_beer_duplicate_query_requires_exactly_one_brewery_form():
    with pytest.raises(ValidationError):
        BeerDuplicateCheckQuery(official_name="X")
    with pytest.raises(ValidationError):
        BeerDuplicateCheckQuery(
            official_name="X", brewery_id=_BREWERY_ID, proposed_brewery_name="Y"
        )


def test_brewery_duplicate_query_requires_exactly_one_country_form():
    with pytest.raises(ValidationError):
        BreweryDuplicateCheckQuery(name="X")
    with pytest.raises(ValidationError):
        BreweryDuplicateCheckQuery(name="X", country_id=_COUNTRY_ID, proposed_country_name="Y")


def test_duplicate_candidates_result_exposes_no_other_users_data():
    """The only cross-user signal is one boolean: the result model has no
    field that could carry another contribution's row, id or owner.
    """
    fields = set(BeerDuplicateCandidatesOut.model_fields)
    assert fields == {
        "barcode_match",
        "name_matches",
        "brewery_matches",
        "already_submitted",
        "pending_barcode_duplicate_exists",
    }
    assert (
        BeerDuplicateCandidatesOut.model_fields["pending_barcode_duplicate_exists"].annotation
        is bool
    )
