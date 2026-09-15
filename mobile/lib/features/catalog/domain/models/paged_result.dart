/// Mirrors the backend's generic `Page[T]` envelope, used by `/breweries`
/// and `/beers` (unlike `/countries`/`/beer-styles`, which return plain
/// arrays).
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    return PagedResult(
      items: (json['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(itemParser)
          .toList(),
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      total: json['total'] as int,
    );
  }
}
