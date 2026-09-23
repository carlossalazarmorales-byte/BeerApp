# BeerApp — Product Specification

## 1. Product Vision

BeerApp is an adult-oriented mobile beer discovery, collection and catalog application built around a world map.

The core experience is simple:

- Discover beers from around the world.
- Explore beers geographically through an interactive world map.
- Register beers the user has tried.
- Build a personal beer collection.
- Rate and review beers.
- Track personal discovery and collection statistics.
- Unlock exploration achievements.
- Discover breweries, beer styles, countries and regions.

The product should feel like a digital beer passport: visual, intuitive, rewarding and easy to use.

The app is intended to be published on both Android and iOS and positioned for adults of legal drinking age in each supported market.

---

## 2. Product Principles

BeerApp should always prioritize:

1. Simplicity
2. Visual clarity
3. Fast navigation
4. Discoverability
5. Strong identity
6. Extensibility
7. Reliable personal data
8. A premium but friendly user experience

The interface should feel modern and polished without becoming overloaded.

---

## 3. Adult Audience and Responsible Product Design

BeerApp is designed for adults of legal drinking age.

Product rules:

- Do not encourage rapid, excessive or competitive alcohol consumption.
- Do not create leaderboards based on alcohol volume.
- Do not create streaks that reward drinking on consecutive days.
- Do not create achievements based on liters consumed.
- Exploration achievements may reward discovering countries, breweries, styles, regions, catalog entries, reviews and collection milestones, provided progress never depends on how much or how often the user drinks (see §16).
- Achievements must not reward or encourage drinking quantity, frequency, streaks or consumption volume.
- Consumption-related history, if implemented for adult users, must remain descriptive rather than competitive.
- Age-gating and store-policy requirements must be reviewed before release in each market.

---

## 4. Visual Identity

The current Stitch designs located in `/stitch` are the primary visual reference.

They are not production code.

The application should reproduce the overall identity rather than blindly copy the HTML.

Key visual ideas:

- Warm cream / off-white backgrounds
- Beer-gold and amber accents
- Large rounded cards
- Minimal borders
- Strong photography
- Spacious layouts
- Premium but approachable aesthetic
- Soft shadows
- Clear typography
- Subtle animation
- Haptic feedback where appropriate

Suggested visual references from Stitch:

- Gold / amber as the primary accent
- Plus Jakarta Sans / Inter-style typography
- Rounded UI
- Map as a central visual experience
- Bottom navigation with a prominent central Scan action

The visual system may evolve over time, but the beer-gold identity should remain recognizable.

---

## 5. Primary Navigation

Initial main navigation:

- Map
- Discover
- Scan
- Collection
- Profile

The exact labels may evolve during UX refinement.

The Scan action may be visually emphasized.

---

## 6. Authentication

Authentication is mandatory.

There should be no permanent guest mode.

Initial authentication methods:

- Email + password
- Google
- Apple

Possible future providers:

- Facebook
- Other social providers

Required authentication functionality:

- Sign up
- Sign in
- Sign out
- Email verification
- Forgot password
- Reset password
- Persistent session
- Secure token handling

Authentication should use a trusted provider rather than a custom password system.

Preferred solution: Supabase Auth.

---

## 7. Core Domain Model

### User

A user should have:

- id
- username
- display name
- avatar
- email
- preferred currency
- preferred units
- country
- language
- created_at
- updated_at

Future additions may include:

- bio
- social connections
- privacy settings

---

### Beer

A beer is a global catalog entity.

A beer should exist once in the global catalog regardless of how many users drink it.

Example fields:

- id
- official_name
- brewery_id
- style_id
- country_id
- region
- city
- latitude
- longitude
- abv
- ibu
- description
- official_image
- barcode
- verified
- source
- created_at
- updated_at

Not every field is required for every beer.

---

### Brewery

Example fields:

- id
- official_name
- country_id
- region
- city
- latitude
- longitude
- description
- website
- logo
- verified

---

### Beer Style

Example fields:

- id
- name
- category
- description
- origin_country
- typical_abv_min
- typical_abv_max

---

### User Beer Log

A user beer log represents an adult user's personal record of having tried or reviewed a beer.

Example fields:

- id
- user_id
- beer_id
- rating
- review
- consumed_at
- optional serving_note
- optional price
- currency
- optional serving_volume_ml (added Phase 6; canonical unit milliliters, never inferred — see `docs/DECISIONS.md`)
- latitude (deferred — not built in Phase 6)
- longitude (deferred — not built in Phase 6)
- venue_name
- photo (deferred — not built in Phase 6)
- created_at
- updated_at

A user may log the same beer multiple times.

The system must distinguish between:

- A beer being discovered/collected
- Individual drinking logs

---

## 8. Map Experience

The world map is one of BeerApp's central features, and is primarily a
**beer-origin** map (QA Round 1 Block 2). It should not be treated as a
secondary page.

Users should be able to:

- Explore beer by country
- Explore beer by region
- See beers geographically, plotted at their origin
- See a country-level view of their own catalog coverage
- Filter the map
- Open beer details from the map

There is no brewery-browsing mode on the main map: a brewery is not
necessarily where a given beer is sold, brewed for that market, or
available, so treating brewery location as "where to get this beer" would
be misleading. Brewery data (location, detail) remains available to other
features; it is just not a main-map mode.

Possible map states:

- All beers
- Beers tried
- Beers not tried
- Favorites
- Wishlist

Beer-origin points: a beer's own origin coordinates when the catalog has
them, approximated by its brewery's location otherwise (never a fabricated
or invented coordinate, and never the point of sale/consumption). Point
color distinguishes only two states -- not yet in the current user's
history, or in it.

Country fill: three flat, informational states per country -- no catalog
beers, catalog beers but none in the current user's history yet, or at
least one in their history. This is informational map coverage, not a
completion/progress mechanic: there is no percentage shown, no "complete
this country" state, and no stronger/celebratory visual at 100% -- see
Section 3's Responsible Product Design constraints, which this map must
never violate no matter how the coverage math is later extended.

The map supports clustering and smooth zoom transitions.

Preferred map technology: MapLibre.

---

## 9. Discover

Discover should help users find interesting beer without requiring them to know exactly what they are looking for.

Possible sections:

- Trending beers
- Popular nearby beers
- New additions
- Recommended beers
- By country
- By beer style
- By brewery
- Highly rated
- Hidden gems
- Recently discovered by the user

The recommendation system can begin rule-based and become more advanced later.

---

## 10. Search

Global search should eventually support:

- Beer name
- Brewery
- Country
- Region
- City
- Beer style
- Barcode

Filters may include:

- Country
- Style
- ABV
- Rating
- Tried / not tried
- Favorite
- Wishlist

Search should remain fast even with a large catalog.

---

## 11. Beer Detail Screen

Each beer should have its own profile.

Possible content:

- Beer name
- Image
- Brewery
- Country
- Region
- City
- Style
- ABV
- IBU
- Description
- Average rating
- Number of ratings
- Map origin
- User status
- Favorite button
- Wishlist button
- User's own rating
- User's own review
- User's logs
- Related beers
- Brewery link

Primary action:

- Log / Register Beer

---

## 12. Registering a Beer

Logging a beer should be fast and pleasant.

Possible fields:

- Beer
- Rating
- Review
- Date and time
- Optional serving note
- Price
- Currency
- Venue
- Location
- Photo

Not all fields should be mandatory.

The user should be able to submit a quick log and optionally add details.

---

## 13. Scanner

The scanner should eventually support:

### Barcode scanning

Use a product barcode to identify beers when possible.

### Label recognition

Potential future functionality:

- User takes a photo of the label
- Image recognition suggests matching beers
- User confirms the correct beer

Label recognition should not be part of the first production milestone.

---

## 14. Collection

The personal collection should display the user's beer journey.

Possible views:

- All discovered beers
- Recently tried
- Favorites
- Wishlist
- By country
- By style
- By brewery
- Highest rated
- Most frequently logged

Collection progress should connect naturally with the map.

---

## 15. Statistics

BeerApp should provide meaningful personal statistics.

Potential statistics:

- Total beers tried
- Unique beers tried
- Total logs
- Countries discovered
- Regions discovered
- Breweries discovered
- Styles discovered
- Average rating
- Most-rated style
- Favorite country
- Favorite brewery
- Monthly activity
- Yearly activity
- Amount spent on recorded purchases
- Recorded volume (sum of each log's optional `serving_volume_ml`, added in
  Phase 6 — see `docs/DECISIONS.md`)

Statistics should be based on explicit user data.

Calculated statistics should be reproducible from stored logs whenever possible.

"Recorded volume" must be labeled and documented as a sum over *logs that
included a volume*, never as a claim about total real-world consumption —
logs with no recorded volume are expected and common. This is descriptive
data, not a target, streak, or leaderboard input; see §3's Responsible
Product Design rules, which apply to this statistic exactly as to any other.

---

## 16. Achievements

BeerApp includes an achievement system. Achievements recognize **exploration and collection**, never drinking.

**Product rule.** An achievement must not reward or encourage drinking quantity, drinking frequency, streaks or consumption volume (see §3 and `CLAUDE.md`, "Responsible Product Design"). No achievement may be based on:

- the number of logs, or the number of beers or unique beers consumed or tried;
- how often, or on how many consecutive days, a user logs;
- any volume, amount or quantity consumed.

Logged consumption activity is therefore not a valid source of achievement progress. This is deliberate: counting logged beers toward a threshold gives users a reason to log more drinking to reach a number (see `docs/DECISIONS.md`, Phase 10).

Permitted directions (each must be designed so that unlocking does not depend on how much or how often the user drinks):

- Collection and curation milestones (favorites, wishlist, curated collections)
- Catalog discovery and map exploration
- Countries, regions, styles and breweries explored, **only** from a data source that does not incentivize consumption (for example catalog or map exploration), not from counts of logged beers
- Special discoveries and compound achievements built from other unlocked achievements

Reviews and ratings are permitted by `CLAUDE.md` as subject matter, but a count of reviews written or ratings given is a count of logged activity and is subject to the rule above; none exists.

**Current starter achievements** (collection and curation only, derived from favorites and wishlist status, never from logs):

- First favorite
- First wishlist item
- Collection curator (a compound achievement that requires the two above)

The exact further list will be designed later within this rule.

The achievement system must be data-driven so that achievements can be added or modified without rewriting large parts of the app.

---

## 17. Wishlist and Favorites

Users should be able to:

- Add beers to favorites
- Remove beers from favorites
- Add beers to a wishlist
- Mark wishlist beers as tried

Favorite and wishlist status must be stored per user.

---

## 18. User Profile

Profile should eventually include:

- Avatar
- Username
- Total beers discovered
- Countries discovered
- Achievements
- Statistics preview
- Collection preview
- Recent activity

Future possibilities:

- Public profiles
- Friends
- Followers
- Activity feed

Social functionality is not part of the MVP.

---

## 19. Community Features — Future

Potential future features:

- Public reviews
- Likes
- Following users
- Friends
- Activity feed
- Shared tasting lists
- Beer recommendations between users
- Community beer submissions
- Community edits

These should not be implemented before the core personal experience is stable.

---

## 20. Global Beer Database

BeerApp needs a scalable global beer catalog.

The database should support:

- Imported beer data
- Manually verified data
- Community submissions
- Community corrections
- Moderation
- Duplicate detection
- Verification state
- Source attribution

The application must not assume that a complete global beer database exists.

The system should support gradual catalog growth.

---

## 21. User Contributions

Future functionality may allow users to submit missing beers.

Potential workflow:

1. User searches for beer
2. Beer is not found
3. User selects "Add missing beer"
4. User enters available information
5. Beer is submitted as unverified
6. Moderation checks submission
7. Beer becomes verified

Duplicate prevention is important.

Clarification (Phase 13): "submitted as unverified" (step 5) means the
*submission* is pending review — it is kept separate from the catalog and is
not visible in it as an unverified beer. A beer or brewery enters the catalog
only when a moderator approves it (steps 6–7); no moderation workflow exists
yet, so submissions currently stay pending. See `docs/DECISIONS.md`.

---

## 22. Administration — Future

A future admin dashboard may provide:

- Beer moderation
- Brewery moderation
- Duplicate merging
- User reports
- Achievement configuration
- Catalog import tools
- Analytics
- Content management

The mobile app should not contain administrative functionality.

---

## 23. Localization

The architecture should support localization from the beginning.

Initial target languages may include:

- Spanish
- English

Do not hardcode visible UI strings throughout the application.

---

## 24. Currency and Units

Users may log prices using different currencies.

Architecture should support:

- User preferred currency
- Original log currency
- Possible future currency conversion

Quantity should be stored internally using a consistent unit such as milliliters.

UI may display:

- ml
- cl
- L
- oz

depending on preferences.

---

## 25. Notifications — Future

Potential notifications:

- Achievement unlocked
- Wishlist beer discovered nearby
- Community interactions
- Product announcements

Push notifications are not required for the MVP.

---

## 26. Offline Behavior

The app should eventually tolerate unstable mobile connections.

Possible offline behavior:

- Cache recently viewed beers
- Cache map state
- Queue beer logs
- Sync when connectivity returns

Full offline support is not required in the earliest phase.

---

## 27. Security

Security requirements:

- Never store plaintext passwords
- Never commit secrets
- Use environment variables
- Enforce authorization server-side
- Validate all backend input
- Restrict storage access
- Use database row-level security where appropriate
- Never trust mobile client authorization alone

---

## 28. Analytics and Crash Reporting

Before production release, consider:

- Crash reporting
- Performance monitoring
- Product analytics

Analytics must be privacy-conscious.

---

## 29. Accessibility

The app should support:

- Sufficient contrast
- Large text scaling
- Screen reader labels
- Reasonable touch target sizes
- Clear focus states
- Non-color-only status indicators

---

## 30. Technology Direction

Current preferred stack:

### Mobile
- Flutter
- Dart

### Backend
- Python
- FastAPI

### Database
- PostgreSQL

### Platform services
- Supabase
- Supabase Auth
- Supabase Storage

### Maps
- MapLibre

### Version control
- Git
- GitHub

These choices may change only for a documented technical reason.

---

## 31. MVP Definition

The first real MVP should allow a user to:

1. Create an account
2. Sign in
3. Browse a beer catalog
4. Search for a beer
5. Open a beer profile
6. Register having tried a beer
7. Rate the beer
8. View their collection
9. Explore beers on a map
10. View basic personal statistics
11. Sign out

Features outside these requirements are secondary until the MVP is stable.

---

## 32. Definition of Success

BeerApp succeeds if a new user can understand its main purpose within seconds:

> Explore the beer world, discover beers and build your personal beer map.

The core loop should feel obvious:

Discover → Explore → Collect → Review → Unlock → Explore more.
