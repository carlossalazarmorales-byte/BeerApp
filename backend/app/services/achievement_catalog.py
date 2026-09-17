from dataclasses import dataclass, field
from enum import StrEnum


class AchievementCategory(StrEnum):
    """All product-approved achievement categories (PRODUCT.md sec. 16 /
    CLAUDE.md), kept in full even though only a subset has catalog entries
    today -- the architecture is not shrunk to match the current starter
    catalog. See docs/DECISIONS.md for why BEERS_TRIED/COUNTRIES/STYLES/
    BREWERIES/REVIEWS/RATINGS have no entries yet: counting logged/reviewed/
    rated beers toward an unlock threshold would incentivize logging more
    consumption activity to reach a number, which is outside the approved
    product boundary -- the categories themselves remain valid for a future,
    non-incentivizing data source (e.g. Discover-driven "viewed" activity).
    """

    BEERS_TRIED = "beers_tried"
    COUNTRIES = "countries"
    STYLES = "styles"
    BREWERIES = "breweries"
    REVIEWS = "reviews"
    RATINGS = "ratings"
    COLLECTION = "collection"
    SPECIAL = "special"


@dataclass(frozen=True)
class AchievementDefinition:
    """One catalog entry. Exactly one of `requirements`/`prerequisite_keys`
    is expected to be non-empty for any given entry (see docs/DECISIONS.md):

    - `requirements`: one or more (metric_name, threshold) pairs, checked
      against *live* metrics (e.g. current favorites_count). A single
      requirement is a progressive achievement with a numeric progress bar.

    - `prerequisite_keys`: other catalog keys that must already be
      permanently unlocked. This is how a compound "special" achievement is
      built, and it is deliberately NOT the same as re-checking the
      underlying live metrics simultaneously -- checking against
      already-unlocked keys is permanence-safe even when the underlying
      metrics are live and reversible (e.g. favorites/wishlist counts).
    """

    key: str
    category: AchievementCategory
    requirements: tuple[tuple[str, int], ...] = field(default_factory=tuple)
    prerequisite_keys: tuple[str, ...] = field(default_factory=tuple)


def _metric(
    key: str, category: AchievementCategory, metric: str, threshold: int
) -> AchievementDefinition:
    return AchievementDefinition(key=key, category=category, requirements=((metric, threshold),))


# Phase 10 starter catalog -- deliberately small and consumption-free. Every
# entry derives only from user_beer_collection (is_favorite/is_wishlist),
# never from user_beer_logs (no counts of logged/reviewed/rated beers) --
# see docs/DECISIONS.md for why. `profile_complete` and a "Regions explored"
# category were both considered and deferred (see docs/DECISIONS.md); this
# is not the full product achievement list, just Phase 10's starting point.
ACHIEVEMENT_CATALOG: dict[str, AchievementDefinition] = {
    "collection_first_favorite": _metric(
        "collection_first_favorite", AchievementCategory.COLLECTION, "favorites_count", 1
    ),
    "collection_first_wishlist": _metric(
        "collection_first_wishlist", AchievementCategory.COLLECTION, "wishlist_count", 1
    ),
    "collection_curator": AchievementDefinition(
        key="collection_curator",
        category=AchievementCategory.SPECIAL,
        prerequisite_keys=("collection_first_favorite", "collection_first_wishlist"),
    ),
}
