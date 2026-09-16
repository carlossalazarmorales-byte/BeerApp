/// The three Collection screen tabs. Logged is derived from `user_beer_logs`
/// (unique beers tried); Favorites/Wishlist are driven by the user's
/// canonical `user_beer_collection` state -- see docs/DECISIONS.md.
enum CollectionTab { logged, favorites, wishlist }
