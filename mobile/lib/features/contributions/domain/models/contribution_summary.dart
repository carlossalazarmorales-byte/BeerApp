enum ContributionKind { beer, brewery }

/// The moderation lifecycle the backend models. Only [pending] is reachable
/// today -- no moderator workflow exists yet -- but the others are parsed so
/// a future backend needs no client model change. [unknown] is what an
/// unrecognized value becomes; it is never shown as if it were approved.
enum ContributionStatus {
  pending,
  approved,
  rejected,
  unknown;

  static ContributionStatus parse(String? value) {
    switch (value) {
      case 'pending':
        return ContributionStatus.pending;
      case 'approved':
        return ContributionStatus.approved;
      case 'rejected':
        return ContributionStatus.rejected;
      default:
        return ContributionStatus.unknown;
    }
  }
}

/// One row of the user's own submission history (`GET /contributions`), and
/// also what a successful submit returns. A contribution is a private
/// proposal, never a catalog row -- this deliberately shares nothing with
/// `Beer`/`Brewery`.
class ContributionSummary {
  const ContributionSummary({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final ContributionKind kind;
  final String title;
  final ContributionStatus status;
  final DateTime createdAt;

  factory ContributionSummary.fromJson(Map<String, dynamic> json) {
    return ContributionSummary(
      id: json['id'] as String,
      kind: _parseKind(json['kind'] as String?),
      title: json['title'] as String,
      status: ContributionStatus.parse(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// From the `POST /beer-contributions` response body, which is the full
  /// contribution rather than a history row.
  factory ContributionSummary.fromBeerSubmission(Map<String, dynamic> json) {
    return ContributionSummary(
      id: json['id'] as String,
      kind: ContributionKind.beer,
      title: json['official_name'] as String,
      status: ContributionStatus.parse(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// From the `POST /brewery-contributions` response body.
  factory ContributionSummary.fromBrewerySubmission(Map<String, dynamic> json) {
    return ContributionSummary(
      id: json['id'] as String,
      kind: ContributionKind.brewery,
      title: json['name'] as String,
      status: ContributionStatus.parse(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static ContributionKind _parseKind(String? value) {
    switch (value) {
      case 'beer':
        return ContributionKind.beer;
      case 'brewery':
        return ContributionKind.brewery;
      default:
        throw FormatException('Unknown contribution kind: $value');
    }
  }
}
