import 'dart:io';

import '../../hook/android_go_toolchain.dart';

int checks = 0;
void check(bool value, String label) {
  checks++;
  if (!value) throw StateError(label);
}

void rejects(void Function() action, String label) {
  try {
    action();
  } on Object {
    checks++;
    return;
  }
  throw StateError('Expected rejection: $label');
}

Future<void> main(List<String> args) async {
  final fixture = Directory.systemTemp.createTempSync('meowoo-ndk-check-');
  try {
    // Spaces, dotted directory names and host separators must not change ABI.
    final sdk = '${fixture.path}/Android SDK';
    final ndk = '$sdk/ndk/$androidBuildNdkVersion';
    File('$ndk/source.properties').createSync(recursive: true);
    for (final (host, tag, suffix) in [
      ('windows', 'windows-x86_64', '.exe'),
      ('linux', 'linux-x86_64', ''),
      ('macos', 'darwin-x86_64', ''),
    ]) {
      final bin = '$ndk/toolchains/llvm/prebuilt/$tag/bin';
      File('$bin/clang$suffix').createSync(recursive: true);
      File('$bin/clang++$suffix').createSync();
      for (final (arch, go, abi, target) in [
        ('arm64', 'arm64', 'arm64-v8a', 'aarch64-linux-android21'),
        ('arm', 'arm', 'armeabi-v7a', 'armv7a-linux-androideabi21'),
        ('x64', 'amd64', 'x86_64', 'x86_64-linux-android21'),
        ('ia32', '386', 'x86', 'i686-linux-android21'),
      ]) {
        final plan = androidGoToolchain(
          sdk: sdk,
          ndk: ndk,
          hostOS: host,
          architecture: arch,
          inheritedPath: 'previous-path',
        );
        check(plan.goArch == go && plan.abi == abi, '$host/$arch ABI');
        check(plan.target == target, '$host/$arch target API');
        check(plan.hostTag == tag, '$host/$arch host');
        check(
          plan.environment['CC'] == '"$bin/clang$suffix" --target=$target',
          '$host/$arch quoted direct compiler',
        );
        check(
          plan.environment['CXX'] == '"$bin/clang++$suffix" --target=$target',
          '$host/$arch C++ compiler',
        );
        check(
          plan.environment['PATH'] ==
              '$bin${host == 'windows' ? ';' : ':'}previous-path',
          '$host/$arch PATH separator',
        );
        check(
          plan.environment['GOOS'] == 'android' &&
              plan.environment['CGO_ENABLED'] == '1',
          '$host/$arch CGO target',
        );
        check(
          plan.environment['GOARM'] == (arch == 'arm' ? '7' : null),
          '$host/$arch GOARM',
        );
      }
    }
    check(
      androidSdkRoot({'ANDROID_SDK_ROOT': sdk}) == sdk,
      'SDK_ROOT fallback',
    );
    check(
      androidSdkRoot({'ANDROID_HOME': ' ', 'ANDROID_SDK_ROOT': sdk}) == sdk,
      'empty HOME fallback',
    );
    check(
      androidSdkRoot({'ANDROID_HOME': sdk, 'ANDROID_SDK_ROOT': 'other'}) == sdk,
      'HOME priority',
    );
    check(androidNdkRoot(sdk, {}) == ndk, 'Gradle pinned version');
    check(
      androidNdkRoot('unused', {'ANDROID_NDK_HOME': ndk}) == ndk,
      'NDK override',
    );
    rejects(() => androidSdkRoot({}), 'missing SDK');
    rejects(() => androidNdkRoot('missing', {}), 'missing pinned NDK');
    rejects(
      () => androidNdkRoot(sdk, {'ANDROID_NDK_HOME': '$sdk/missing'}),
      'invalid explicit NDK',
    );
    for (final (host, arch, api) in [
      ('unknown', 'arm64', 21),
      ('linux', 'riscv64', 21),
      ('linux', 'arm64', 20),
    ]) {
      rejects(
        () => androidGoToolchain(
          sdk: sdk,
          ndk: ndk,
          hostOS: host,
          architecture: arch,
          inheritedPath: '',
          apiLevel: api,
        ),
        'unsupported $host/$arch/$api',
      );
    }
    rejects(
      () => androidGoToolchain(
        sdk: sdk,
        ndk: '$sdk/absent',
        hostOS: 'windows',
        architecture: 'arm64',
        inheritedPath: '',
      ),
      'missing compiler',
    );
    stdout.writeln('PASS: $checks Android Go toolchain checks');
  } finally {
    fixture.deleteSync(recursive: true);
  }
  if (args.contains('--smoke')) await smoke(args);
}

Future<void> smoke(List<String> args) async {
  String? option(String name) => args
      .where((a) => a.startsWith('$name='))
      .firstOrNull
      ?.substring(name.length + 1);
  final environment = {...Platform.environment};
  if (option('--sdk') case final sdk?) environment['ANDROID_HOME'] = sdk;
  final sdk = androidSdkRoot(environment);
  final plan = androidGoToolchain(
    sdk: sdk,
    ndk: androidNdkRoot(sdk, environment),
    hostOS: Platform.operatingSystem,
    architecture: 'arm64',
    inheritedPath: environment['PATH'] ?? '',
  );
  final work = Directory.systemTemp.createTempSync('meowoo-cgo-smoke-');
  try {
    final source = File('${work.path}/main.go')
      ..writeAsStringSync('''package main
/*
#include <stdint.h>
*/
import "C"
//export meowoo_toolchain_smoke
func meowoo_toolchain_smoke() C.int { return 42 }
func main() {}
''');
    final artifact = '${work.path}/libsmoke.so';
    final result = await Process.run(
      option('--go') ?? 'go',
      [
        'build',
        '-buildmode=c-shared',
        '-ldflags=-linkmode=external -extldflags "-Wl,-z,max-page-size=16384"',
        '-o',
        artifact,
        source.path,
      ],
      environment: {
        ...plan.environment,
        'GOTOOLCHAIN': 'local',
        'GOWORK': 'off',
      },
      workingDirectory: work.path,
    );
    if (result.exitCode != 0) {
      throw StateError(
        'CGO smoke build failed:\n${result.stdout}\n${result.stderr}',
      );
    }
    final bytes = File(artifact).readAsBytesSync();
    check(
      bytes.length > 20 &&
          bytes[0] == 0x7f &&
          bytes[1] == 0x45 &&
          bytes[2] == 0x4c &&
          bytes[3] == 0x46 &&
          bytes[4] == 2 &&
          bytes[18] == 0xb7 &&
          bytes[19] == 0,
      'AArch64 ELF output',
    );
    final readelf =
        '${androidNdkRoot(sdk, environment)}/toolchains/llvm/prebuilt/${plan.hostTag}/bin/llvm-readelf${Platform.isWindows ? '.exe' : ''}';
    final headers = await Process.run(readelf, ['--program-headers', artifact]);
    if (headers.exitCode != 0) throw StateError('${headers.stderr}');
    final loads = '${headers.stdout}'
        .split('\n')
        .where((l) => l.trimLeft().startsWith('LOAD'))
        .toList();
    check(
      loads.isNotEmpty && loads.every((l) => l.trimRight().endsWith('0x4000')),
      '16 KiB ELF LOAD alignment',
    );
    stdout.writeln(
      'PASS: real Windows/host NDK + Go -> AArch64 shared ELF, 16 KiB LOAD alignment. Not an APK or playback test.',
    );
  } finally {
    work.deleteSync(recursive: true);
  }
}
