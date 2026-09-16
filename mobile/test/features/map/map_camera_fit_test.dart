import 'package:beerapp/features/map/presentation/map_camera_fit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cameraFitSignatureToRecord', () {
    test('the loading-start notification of a new search is never eligible, '
        'and never consumes the signature -- this is the exact race that '
        'produced the stale whole-world camera fit on a Belgium search', () {
      // A broad ("All beers") result is on screen; a Belgium search has
      // just started (appliedCountryId/query already updated), but its
      // repository call has not resolved yet -- isLoading is still true,
      // and the old broad marker list is still what MapScreen would plot
      // if it fit right now.
      final result = cameraFitSignatureToRecord(
        isLoading: true,
        error: null,
        searchActive: true,
        signature: 'all|belgium-id|Belgium',
        lastFitSignature: null,
      );

      expect(
        result,
        isNull,
        reason: 'must not fit while the request for this signature is still in flight',
      );
    });

    test('the completed successful result for that same search IS eligible, '
        'proving the loading-start call above did not burn the signature', () {
      // Same signature as the in-flight case, but now isLoading is
      // false: the repository call for the Belgium search has resolved
      // and the controller's marker list now reflects it.
      final result = cameraFitSignatureToRecord(
        isLoading: false,
        error: null,
        searchActive: true,
        signature: 'all|belgium-id|Belgium',
        lastFitSignature:
            null, // still null: the loading-start call above never set it
      );

      expect(result, 'all|belgium-id|Belgium');
    });

    test('a failed load is never eligible, loading or not', () {
      expect(
        cameraFitSignatureToRecord(
          isLoading: false,
          error: Exception('network blip'),
          searchActive: true,
          signature: 'all|belgium-id|Belgium',
          lastFitSignature: null,
        ),
        isNull,
      );
    });

    test('no search active is never eligible, even with a completed load', () {
      expect(
        cameraFitSignatureToRecord(
          isLoading: false,
          error: null,
          searchActive: false,
          signature: 'all||',
          lastFitSignature: null,
        ),
        isNull,
      );
    });

    test(
      'a repeat notification for an already-fitted signature is not eligible '
      '-- e.g. a CollectionRefreshSignal-triggered reload of the same search '
      'must not re-fit and fight the user\'s manual camera',
      () {
        expect(
          cameraFitSignatureToRecord(
            isLoading: false,
            error: null,
            searchActive: true,
            signature: 'all|belgium-id|Belgium',
            lastFitSignature: 'all|belgium-id|Belgium',
          ),
          isNull,
        );
      },
    );

    test('a genuinely new signature is eligible even when a different '
        'signature was already fitted before', () {
      expect(
        cameraFitSignatureToRecord(
          isLoading: false,
          error: null,
          searchActive: true,
          signature: 'all|france-id|France',
          lastFitSignature: 'all|belgium-id|Belgium',
        ),
        'all|france-id|France',
      );
    });

    test('a completed search with (implicitly) zero points is still eligible '
        '-- the caller records the signature regardless of point count, so a '
        'later refresh of the same empty search does not re-fit', () {
      // This function only decides eligibility/signature; it doesn't see
      // the point list at all, so "zero points" isn't a special input
      // here -- the point is that eligibility doesn't depend on it.
      expect(
        cameraFitSignatureToRecord(
          isLoading: false,
          error: null,
          searchActive: true,
          signature: 'all|nowhere-id|Nowhereland',
          lastFitSignature: null,
        ),
        'all|nowhere-id|Nowhereland',
      );
    });
  });
}
