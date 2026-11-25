import 'dart:convert';
import 'dart:io';

/// Commit the complete appearance snapshot before publishing an applied pack.
/// A failed write must leave both the old file and the in-memory state intact.
void writeAppearanceSession(File file, Map<String, String> values) {
  final temp = File('${file.path}.$pid.tmp');
  try {
    temp.writeAsStringSync(jsonEncode(values), flush: true);
    if (file.existsSync()) file.copySync('${file.path}.bak');
    temp.renameSync(file.path);
  } finally {
    if (temp.existsSync()) temp.deleteSync();
  }
}
