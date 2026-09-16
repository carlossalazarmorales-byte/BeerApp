from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.schemas.collection import CollectionStateUpdate

_BEER_ID = uuid4()


def test_update_empty_patch_is_rejected():
    with pytest.raises(ValidationError):
        CollectionStateUpdate()


def test_update_single_field_is_accepted():
    payload = CollectionStateUpdate(is_favorite=True)
    assert payload.model_fields_set == {"is_favorite"}


def test_update_both_fields_is_accepted():
    payload = CollectionStateUpdate(is_favorite=True, is_wishlist=False)
    assert payload.model_fields_set == {"is_favorite", "is_wishlist"}


def test_update_explicit_false_is_distinguishable_from_omitted():
    payload = CollectionStateUpdate(is_favorite=False)
    assert "is_favorite" in payload.model_fields_set
    assert "is_wishlist" not in payload.model_fields_set
    assert payload.model_dump(exclude_unset=True) == {"is_favorite": False}


def test_update_rejects_unknown_field_eg_user_id():
    with pytest.raises(ValidationError):
        CollectionStateUpdate.model_validate({"is_favorite": True, "user_id": str(uuid4())})


def test_update_rejects_unknown_field_eg_beer_id():
    with pytest.raises(ValidationError):
        CollectionStateUpdate.model_validate({"is_favorite": True, "beer_id": str(_BEER_ID)})
