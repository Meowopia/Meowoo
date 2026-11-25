import 'package:flutter_test/flutter_test.dart';
import 'package:miru_alpha/miru_core/default_extension_repo.dart';
import 'package:miru_alpha/model/model.dart';

const retired = DefaultExtensionRepoRepair.retiredUrl;
const replacement = DefaultExtensionRepoRepair.replacementUrl;
const custom = 'https://example.org/index.json';

class FakeRepoStore {
  FakeRepoStore({String? oldName = DefaultExtensionRepoRepair.retiredName}) {
    if (oldName != null) rows[retired] = oldName;
  }

  final rows = <String, String>{custom: 'Custom'};
  final writes = <String>[];
  final errors = <Object>[];
  bool failAdd = false;
  bool failDelete = false;

  late final repair = DefaultExtensionRepoRepair(
    read: () async => [
      for (final (i, row) in rows.entries.indexed)
        RepoConfig(id: i + 1, name: row.value, link: row.key),
    ],
    add: (url, name) async {
      writes.add('add $url');
      if (failAdd) throw Exception('registration failed');
      rows[url] = name;
    },
    remove: (url) async {
      writes.add('remove $url');
      if (failDelete) throw Exception('cleanup failed');
      rows.remove(url);
    },
    onError: (error, _) => errors.add(error),
  );
}

void main() {
  test('replaces only the stock row; a second read makes no writes', () async {
    final store = FakeRepoStore();
    final result = await store.repair.load();

    expect(result.map((r) => r.link), [custom, replacement]);
    expect(result.last.name, DefaultExtensionRepoRepair.replacementName);
    await store.repair.load();
    expect(store.writes, ['add $replacement', 'remove $retired']);
  });

  test('custom-only configs and user-renamed rows remain untouched', () async {
    for (final oldName in [null, 'Manually configured']) {
      final store = FakeRepoStore(oldName: oldName);
      await store.repair.load();
      expect(store.rows, {custom: 'Custom', retired: ?oldName});
      expect(store.writes, isEmpty);
    }
  });

  test('keeps the name and config of an existing replacement', () async {
    final store = FakeRepoStore()..rows[replacement] = 'My Miru repo';
    await store.repair.load();
    expect(store.rows[replacement], 'My Miru repo');
    expect(store.writes, ['remove $retired']);
  });

  test('does not delete the old row if adding failed, and retries', () async {
    final store = FakeRepoStore()..failAdd = true;
    expect((await store.repair.load()).map((r) => r.link), [custom, retired]);
    expect(store.errors, hasLength(1));
    expect(store.writes, ['add $replacement']);

    store.failAdd = false;
    expect((await store.repair.load()).map((r) => r.link), [
      custom,
      replacement,
    ]);
    expect(store.writes, [
      'add $replacement',
      'add $replacement',
      'remove $retired',
    ]);
  });

  test('replacement remains usable if cleanup fails', () async {
    final store = FakeRepoStore()..failDelete = true;
    expect((await store.repair.load()).map((r) => r.link), [
      custom,
      retired,
      replacement,
    ]);
    expect(store.errors, hasLength(1));

    store.failDelete = false;
    expect((await store.repair.load()).map((r) => r.link), [
      custom,
      replacement,
    ]);
    expect(store.writes, [
      'add $replacement',
      'remove $retired',
      'remove $retired',
    ]);
  });

  test('simultaneous readers perform one repair', () async {
    final store = FakeRepoStore();
    final first = store.repair.load();
    final second = store.repair.load();
    expect(second, same(first));
    await Future.wait([first, second]);
    expect(store.writes, ['add $replacement', 'remove $retired']);
  });
}
