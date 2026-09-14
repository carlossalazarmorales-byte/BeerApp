# BeerApp — Development Roadmap

This roadmap defines the recommended order of implementation.

The objective is to build BeerApp incrementally, keeping every phase functional before moving to the next.

Do not attempt to build the entire application at once.

---

# Phase 0 — Project Foundation

Goal: create a professional project structure before feature development.

Tasks:

- [ ] Initialize Git repository
- [ ] Create GitHub repository
- [ ] Create Flutter application under `/mobile`
- [ ] Create FastAPI application under `/backend`
- [ ] Create `/docs`
- [ ] Preserve `/stitch` unchanged
- [ ] Add `.gitignore`
- [ ] Add `.env.example`
- [ ] Create root `README.md`
- [ ] Create initial architecture documentation
- [ ] Create initial database documentation
- [ ] Create design system documentation
- [ ] Configure linting
- [ ] Configure formatting
- [ ] Configure basic tests
- [ ] Verify Flutter project runs
- [ ] Verify backend health endpoint runs
- [ ] Make first clean Git commit

Exit criteria:

- Mobile app launches
- Backend launches
- Repository structure is clean
- No feature logic yet

---

# Phase 1 — Design System and App Shell

Goal: create the visual and navigation foundation.

Tasks:

- [ ] Analyze Stitch visual references
- [ ] Define colors
- [ ] Define typography
- [ ] Define spacing scale
- [ ] Define border radii
- [ ] Define shadows
- [ ] Define button styles
- [ ] Define card styles
- [ ] Define form styles
- [ ] Create reusable loading states
- [ ] Create reusable error states
- [ ] Create bottom navigation
- [ ] Create base app routing
- [ ] Create placeholder screens
- [ ] Add localization structure
- [ ] Add responsive layout rules

Initial navigation:

- Map
- Discover
- Scan
- Collection
- Profile

Exit criteria:

- Navigation works
- Visual identity resembles Stitch
- Reusable design components exist
- No duplicated styling

---

# Phase 2 — Supabase and Authentication

Goal: establish secure user accounts.

Tasks:

- [ ] Create Supabase project
- [ ] Configure local environment variables
- [ ] Integrate Supabase client
- [ ] Create profile table
- [ ] Configure Row Level Security
- [ ] Email registration
- [ ] Email login
- [ ] Email verification
- [ ] Password recovery
- [ ] Persistent login
- [ ] Logout
- [ ] Google login
- [ ] Apple login
- [ ] Authentication error states
- [ ] Authentication loading states
- [ ] Protected app routes

Exit criteria:

- User can register
- User can sign in
- Session persists
- User cannot access private app without authentication

---

# Phase 3 — Core Database

Goal: create the core beer catalog data model.

Tables/entities:

- [ ] users / profiles
- [ ] countries
- [ ] beer_styles
- [ ] breweries
- [ ] beers
- [ ] user_beer_logs
- [ ] favorites
- [ ] wishlist

Tasks:

- [ ] Define database schema
- [ ] Add constraints
- [ ] Add indexes
- [ ] Add foreign keys
- [ ] Add migrations
- [ ] Add seed data
- [ ] Document entity relationships
- [ ] Create backend repository layer
- [ ] Create backend service layer
- [ ] Create initial API schemas

Exit criteria:

- Database can represent the core product correctly
- No duplicate business logic exists in controllers/routes

---

# Phase 4 — Beer Catalog and Beer Detail

Goal: allow users to browse real catalog data.

Tasks:

- [ ] Beer list API
- [ ] Pagination
- [ ] Beer detail API
- [ ] Brewery relation
- [ ] Style relation
- [ ] Country relation
- [ ] Beer cards
- [ ] Beer detail screen
- [ ] Loading states
- [ ] Empty states
- [ ] Error states
- [ ] Beer imagery fallback
- [ ] Favorite action
- [ ] Wishlist action

Exit criteria:

- User can browse beers
- User can open a beer
- Beer details are loaded from backend/database

---

# Phase 5 — Search and Discover

Goal: make catalog exploration easy.

Tasks:

- [ ] Search endpoint
- [ ] Search by beer name
- [ ] Search by brewery
- [ ] Search by country
- [ ] Search by style
- [ ] Search screen
- [ ] Search history
- [ ] Filters
- [ ] Discover sections
- [ ] Country browsing
- [ ] Style browsing
- [ ] Brewery browsing

Exit criteria:

- User can reliably find a known beer
- Discover presents useful catalog entry points

---

# Phase 6 — Logging a Beer

Goal: complete the main user action.

Tasks:

- [ ] Create beer log endpoint
- [ ] Edit beer log
- [ ] Delete beer log
- [ ] Rating input
- [ ] Optional review
- [ ] Consumption date
- [ ] Optional serving note
- [ ] Price
- [ ] Currency
- [ ] Venue
- [ ] Optional location
- [ ] Optional photo
- [ ] Quick-log flow
- [ ] Detailed-log flow
- [ ] Update collection state after logging

Exit criteria:

- User can log a beer in a few taps
- A beer may have multiple user logs
- Personal data persists correctly

---

# Phase 7 — Personal Collection

Goal: turn logging into a visible collection.

Tasks:

- [ ] Collection screen
- [ ] Unique beers tried
- [ ] Recent beers
- [ ] Favorites
- [ ] Wishlist
- [ ] Filter by country
- [ ] Filter by style
- [ ] Filter by brewery
- [ ] Sort by rating
- [ ] Sort by date
- [ ] Sort by name
- [ ] Collection empty states

Exit criteria:

- Collection accurately reflects user logs
- Wishlist and favorites work independently

---

# Phase 8 — World Map

Goal: implement BeerApp's flagship experience.

Tasks:

- [ ] Add MapLibre
- [ ] Base map style
- [ ] Beer origin markers
- [ ] Brewery markers
- [ ] Marker clustering
- [ ] Country-level exploration
- [ ] Region-level exploration
- [ ] Tried / not-tried filters
- [ ] Favorite filter
- [ ] Wishlist filter
- [ ] Beer preview card
- [ ] Brewery preview card
- [ ] Smooth camera transitions
- [ ] Loading states
- [ ] Location permission handling if needed

Exit criteria:

- User can explore beer geographically
- Map performance remains acceptable with many points

---

# Phase 9 — Statistics

Goal: summarize personal beer activity.

Tasks:

- [ ] Total unique beers
- [ ] Total logs
- [ ] Countries discovered
- [ ] Styles discovered
- [ ] Breweries discovered
- [ ] Average rating
- [ ] Amount spent
- [ ] Monthly activity
- [ ] Yearly activity
- [ ] Favorite style
- [ ] Favorite country
- [ ] Favorite brewery
- [ ] Statistics UI
- [ ] Basic charts

Exit criteria:

- Statistics match underlying log data
- Calculations are tested

---

# Phase 10 — Achievements

Goal: add progression and motivation.

Tasks:

- [ ] Achievement data model
- [ ] Achievement definitions
- [ ] Progress values
- [ ] Locked state
- [ ] Unlocked state
- [ ] Unlock timestamp
- [ ] Achievement evaluation service
- [ ] Achievement screen
- [ ] Achievement notifications
- [ ] Categories
- [ ] Progress bars

Potential categories:

- Beers tried
- Countries
- Regions
- Styles
- Breweries
- Reviews
- Ratings
- Collection
- Special milestones

Exit criteria:

- Achievements are data-driven
- Adding a new achievement does not require major application changes

---

# Phase 11 — Scanner

Goal: reduce friction when identifying a beer.

First milestone:

- [ ] Camera permission
- [ ] Barcode scanner
- [ ] Barcode lookup
- [ ] Matching result
- [ ] No-result fallback
- [ ] Manual search fallback

Later:

- [ ] Label image recognition
- [ ] Suggested matches
- [ ] Confidence score
- [ ] User confirmation

Exit criteria:

- Common supported barcodes can open a matching beer

---

# Phase 12 — Profile and Settings

Goal: complete the user's personal area.

Tasks:

- [ ] Avatar
- [ ] Display name
- [ ] Username
- [ ] Preferred currency
- [ ] Preferred units
- [ ] Language
- [ ] Account settings
- [ ] Privacy settings placeholder
- [ ] Logout
- [ ] Delete account flow
- [ ] Legal links

Exit criteria:

- User can manage account essentials

---

# Phase 13 — Beer Contributions

Goal: allow catalog growth.

Tasks:

- [ ] Missing beer submission
- [ ] Brewery submission
- [ ] Duplicate candidate detection
- [ ] Unverified state
- [ ] Submission history
- [ ] Moderation-ready data model

Exit criteria:

- User contributions cannot overwrite verified catalog data directly

---

# Phase 14 — Quality and Production Hardening

Goal: prepare for real users.

Tasks:

- [ ] Improve test coverage
- [ ] Integration tests
- [ ] End-to-end critical flows
- [ ] Performance profiling
- [ ] Image optimization
- [ ] Map performance
- [ ] API rate limiting
- [ ] Error logging
- [ ] Crash reporting
- [ ] Analytics
- [ ] Accessibility audit
- [ ] Security review
- [ ] Database backup strategy
- [ ] Privacy policy
- [ ] Adult audience / age-gating review
- [ ] Responsible product design review
- [ ] Terms
- [ ] Account deletion compliance

Exit criteria:

- Core flows are stable
- App is production-ready

---

# Phase 15 — Store Release

Goal: publish BeerApp.

Android:

- [ ] Production package identifier
- [ ] Signing configuration
- [ ] Play Store listing
- [ ] Screenshots
- [ ] App icon
- [ ] Privacy disclosures
- [ ] Internal testing
- [ ] Closed testing
- [ ] Production release

iOS:

- [ ] Apple Developer setup
- [ ] Bundle identifier
- [ ] Signing
- [ ] App Store Connect
- [ ] Screenshots
- [ ] Privacy disclosures
- [ ] TestFlight
- [ ] App Review
- [ ] Production release

---

# Post-MVP Possibilities

Do not implement these until the core application is stable.

Possible future work:

- Social profiles
- Friends
- Followers
- Activity feed
- Public reviews
- Review likes
- Recommendations
- Nearby beer discovery
- Venue database
- Beer lists
- Shared lists
- Events
- Brewery check-ins
- Advanced achievements
- Seasonal campaigns
- AI recommendations
- Label recognition
- Admin dashboard
- Catalog moderation tools
- Import pipelines
- Web version

---

# Roadmap Rules

1. Finish the current phase before starting large work from a later phase.
2. Small foundational work for future phases is allowed when architecturally necessary.
3. Every completed phase must leave the application runnable.
4. Never sacrifice architecture merely to finish a phase faster.
5. Avoid speculative abstractions with no current use.
6. Add tests to important business rules.
7. Update this roadmap when scope meaningfully changes.
8. Mark tasks complete only when they actually work.
9. Do not silently remove roadmap requirements.
10. Major roadmap changes must be documented in `docs/DECISIONS.md`.
