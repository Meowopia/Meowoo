import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:miru_alpha/ui/features/jellyfin/jellyfin_client.dart';
import 'package:miru_alpha/ui/features/jellyfin/jellyfin_page.dart';

const _library = JellyfinItem(
  id: 'library',
  name: 'My films',
  kind: JellyfinKind.library,
);
const _show = JellyfinItem(
  id: 'show',
  name: 'My series',
  kind: JellyfinKind.series,
);
const _episode = JellyfinItem(
  id: 'episode',
  name: 'Episode one',
  kind: JellyfinKind.episode,
);

class _Session implements JellyfinConnection {
  bool closed = false;
  @override
  String get historyScope => 'fixture';
  @override
  Future<List<JellyfinItem>> libraries() async => [_library];
  @override
  Future<JellyfinPage> browse(JellyfinItem parent, {int offset = 0}) async =>
      JellyfinPage(
        parent.kind == JellyfinKind.library ? [_show] : [_episode],
        null,
      );
  @override
  Future<JellyfinItem> item(String id) => throw UnimplementedError();
  @override
  Future<Uint8List> poster(JellyfinItem item) => throw UnimplementedError();
  @override
  Future<JellyfinPlayback> play(JellyfinItem item) =>
      throw UnimplementedError();
  @override
  void close() => closed = true;
}

Widget _app(JellyfinConnector connect) => MaterialApp(
  // video_player's legacy Material dependencies use this app-wide bridge.
  // ignore: deprecated_member_use
  builder: (_, child) => MaterialUiCompatibilityBridge(child: child!),
  home: JellyfinLibraryPage(connect: connect),
);

Future<void> _fill(WidgetTester tester) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'https://media.example.com');
  await tester.enterText(fields.at(1), 'test-user');
  await tester.enterText(fields.at(2), 'fixture-secret');
}

void main() {
  testWidgets('Jellyfin browses libraries and releases the session on exit', (
    tester,
  ) async {
    final session = _Session();
    await tester.pumpWidget(
      _app((uri, username, password) async {
        expect(uri.toString(), 'https://media.example.com');
        expect(username, 'test-user');
        expect(password, 'fixture-secret');
        return session;
      }),
    );
    await _fill(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('fixture-secret'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('show')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('episode')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(session.closed, isTrue);
  });

  testWidgets('login completed after leaving closes the unclaimed session', (
    tester,
  ) async {
    final pending = Completer<JellyfinConnection>();
    final session = _Session();
    await tester.pumpWidget(_app((_, _, _) => pending.future));
    await _fill(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete(session);
    await tester.pumpAndSettle();
    expect(session.closed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
