import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miru_alpha/provider/app_update_provider.dart';
import 'package:miru_alpha/utils/update/update_service.dart';

void main() {
  test('initial release has no update feed and never falls back to Miru', () async {
    final service = UpdateService();
    expect(service.enabled, isFalse);
    expect(UpdateService.releasesApi, isEmpty);
    expect(AppUpdate.autoCheckEnabled, isFalse);
    await expectLater(service.fetchReleases(), throwsUnsupportedError);
  });
  test(
    'manual check describes an unconfigured channel, not up-to-date',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(appUpdateProvider.notifier).checkNow();
      final state = container.read(appUpdateProvider);
      expect(state.status, UpdateStatus.failed);
      expect(state.error, 'settings.update.channel_pending');
      expect(state.release, isNull);
      expect(state.manual, isTrue);
    },
  );
}
