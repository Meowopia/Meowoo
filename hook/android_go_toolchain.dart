import 'dart:io';

const androidBuildNdkVersion = '28.2.13676358';

/// No machine-specific SDK fallback: both supported SDK variables are accepted.
String androidSdkRoot(Map<String, String> environment) {
  for (final key in ['ANDROID_HOME', 'ANDROID_SDK_ROOT']) {
    final value = environment[key]?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  throw StateError('Set ANDROID_HOME or ANDROID_SDK_ROOT to the Android SDK.');
}

/// Match Gradle's pinned NDK; an explicit override is validated, never ignored.
String androidNdkRoot(String sdk, Map<String, String> environment) {
  final override = environment['ANDROID_NDK_HOME']?.trim();
  final root = override != null && override.isNotEmpty
      ? override
      : '$sdk/ndk/$androidBuildNdkVersion';
  if (!File('$root/source.properties').existsSync()) {
    throw StateError(
      'Android NDK not found at $root. Install ndk;$androidBuildNdkVersion '
      'or set ANDROID_NDK_HOME to a complete NDK.',
    );
  }
  return root;
}

final class AndroidGoToolchain {
  const AndroidGoToolchain({
    required this.abi,
    required this.goArch,
    required this.target,
    required this.hostTag,
    required this.environment,
  });

  final String abi;
  final String goArch;
  final String target;
  final String hostTag;
  final Map<String, String> environment;
}

/// Use the NDK host binaries, not Linux scripts on Windows. Calling clang
/// directly also avoids .cmd argument forwarding and supports SDK paths with
/// spaces. Go's CC/CXX parser accepts a quoted executable followed by options.
AndroidGoToolchain androidGoToolchain({
  required String sdk,
  required String ndk,
  required String hostOS,
  required String architecture,
  required String inheritedPath,
  int apiLevel = 21,
}) {
  final hostTag = switch (hostOS) {
    'windows' => 'windows-x86_64',
    'linux' => 'linux-x86_64',
    'macos' => 'darwin-x86_64',
    _ => throw UnsupportedError('Unsupported NDK host: $hostOS'),
  };
  if (apiLevel < 21) throw ArgumentError.value(apiLevel, 'apiLevel', '>= 21');
  final (triple, goArch, abi) = switch (architecture) {
    'arm64' => ('aarch64-linux-android', 'arm64', 'arm64-v8a'),
    'arm' => ('armv7a-linux-androideabi', 'arm', 'armeabi-v7a'),
    'x64' => ('x86_64-linux-android', 'amd64', 'x86_64'),
    'ia32' => ('i686-linux-android', '386', 'x86'),
    _ => throw UnsupportedError(
      'Unsupported Android architecture: $architecture',
    ),
  };
  final bin = '$ndk/toolchains/llvm/prebuilt/$hostTag/bin';
  final suffix = hostOS == 'windows' ? '.exe' : '';
  String compiler(String name) {
    final executable = '$bin/$name$suffix';
    if (executable.contains('"') ||
        executable.contains('\n') ||
        executable.contains('\r')) {
      throw ArgumentError('Unsupported characters in NDK compiler path.');
    }
    if (!File(executable).existsSync()) {
      throw StateError('NDK compiler missing: $executable');
    }
    return '"$executable" --target=$triple$apiLevel';
  }

  final delimiter = hostOS == 'windows' ? ';' : ':';
  return AndroidGoToolchain(
    abi: abi,
    goArch: goArch,
    target: '$triple$apiLevel',
    hostTag: hostTag,
    environment: {
      'ANDROID_HOME': sdk,
      'ANDROID_SDK_ROOT': sdk,
      'ANDROID_NDK_HOME': ndk,
      'PATH': inheritedPath.isEmpty ? bin : '$bin$delimiter$inheritedPath',
      'CC': compiler('clang'),
      'CXX': compiler('clang++'),
      'CGO_ENABLED': '1',
      'GOOS': 'android',
      'GOARCH': goArch,
      if (goArch == 'arm') 'GOARM': '7',
    },
  );
}
