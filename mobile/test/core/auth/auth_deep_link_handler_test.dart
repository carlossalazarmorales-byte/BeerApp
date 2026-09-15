import 'dart:async';

import 'package:beerapp/core/auth/auth_deep_link_handler.dart';
import 'package:beerapp/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeDeepLinkSource implements DeepLinkSource {
  Uri? initialLink;
  final _controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async => initialLink;

  @override
  Stream<Uri> get uriLinkStream => _controller.stream;

  void emit(Uri uri) => _controller.add(uri);
  void emitError(Object error) => _controller.addError(error);
}

final Uri _recoveryUri = Uri.parse('${Env.authRedirectUrl}?code=abc123');

void main() {
  test('exchanges the cold-start initial link exactly once', () async {
    final source = _FakeDeepLinkSource()..initialLink = _recoveryUri;
    final exchanged = <Uri>[];

    AuthDeepLinkHandler(
      source: source,
      exchangeSessionFromUrl: (uri) async => exchanged.add(uri),
    );
    await pumpEventQueue();

    expect(exchanged, [_recoveryUri]);
  });

  test('exchanges a warm-start link received on the stream', () async {
    final source = _FakeDeepLinkSource();
    final exchanged = <Uri>[];

    AuthDeepLinkHandler(
      source: source,
      exchangeSessionFromUrl: (uri) async => exchanged.add(uri),
    );
    await pumpEventQueue();
    expect(exchanged, isEmpty);

    source.emit(_recoveryUri);
    await pumpEventQueue();

    expect(exchanged, [_recoveryUri]);
  });

  test('never exchanges the same URI twice, even if it arrives via both the '
      'initial link and the stream', () async {
    final source = _FakeDeepLinkSource()..initialLink = _recoveryUri;
    final exchanged = <Uri>[];

    AuthDeepLinkHandler(
      source: source,
      exchangeSessionFromUrl: (uri) async => exchanged.add(uri),
    );
    await pumpEventQueue();
    expect(exchanged, [_recoveryUri]);

    source.emit(_recoveryUri);
    await pumpEventQueue();

    expect(exchanged, [_recoveryUri]);
  });

  test('ignores a link with a different scheme', () async {
    final source = _FakeDeepLinkSource();
    final exchanged = <Uri>[];

    AuthDeepLinkHandler(
      source: source,
      exchangeSessionFromUrl: (uri) async => exchanged.add(uri),
    );
    await pumpEventQueue();

    source.emit(Uri.parse('https://example.com/unrelated'));
    await pumpEventQueue();

    expect(exchanged, isEmpty);
  });

  test('ignores a link that shares our scheme but has a different host -- a '
      'scheme match alone must not be treated as proof of origin', () async {
    final source = _FakeDeepLinkSource();
    final exchanged = <Uri>[];

    AuthDeepLinkHandler(
      source: source,
      exchangeSessionFromUrl: (uri) async => exchanged.add(uri),
    );
    await pumpEventQueue();

    source.emit(
      Uri.parse('com.carlossalazarmorales.beerapp://not-our-callback'),
    );
    await pumpEventQueue();

    expect(exchanged, isEmpty);
  });

  test('an AuthException (invalid/expired link) is caught -- fails safely, no '
      'crash, no unhandled exception', () async {
    final source = _FakeDeepLinkSource();

    AuthDeepLinkHandler(
      source: source,
      exchangeSessionFromUrl: (uri) async {
        throw const AuthException('Email link is invalid or has expired');
      },
    );
    await pumpEventQueue();

    source.emit(_recoveryUri);
    await pumpEventQueue();

    // Reaching here without the test framework reporting an unhandled
    // exception is the assertion.
  });

  test(
    'a stream error on uriLinkStream does not crash or stop processing',
    () async {
      final source = _FakeDeepLinkSource();
      final exchanged = <Uri>[];

      AuthDeepLinkHandler(
        source: source,
        exchangeSessionFromUrl: (uri) async => exchanged.add(uri),
      );
      await pumpEventQueue();

      source.emitError(Exception('platform channel hiccup'));
      await pumpEventQueue();

      source.emit(_recoveryUri);
      await pumpEventQueue();

      expect(exchanged, [_recoveryUri]);
    },
  );
}
