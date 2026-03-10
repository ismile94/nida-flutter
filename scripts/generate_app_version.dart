// ignore_for_file: avoid_print
/// Reads versionName from android/app/build.gradle.kts and writes lib/app_version.g.dart.
/// Run from project root: dart run scripts/generate_app_version.dart
/// Or: dart scripts/generate_app_version.dart (if run from project root).
import 'dart:io';

void main() {
  // Run from project root: dart run scripts/generate_app_version.dart
  final projectRoot = Directory.current;
  final gradleFile = File(
      '${projectRoot.path}${Platform.pathSeparator}android${Platform.pathSeparator}app${Platform.pathSeparator}build.gradle.kts');
  final outFile = File(
      '${projectRoot.path}${Platform.pathSeparator}lib${Platform.pathSeparator}app_version.g.dart');

  if (!gradleFile.existsSync()) {
    print('Error: ${gradleFile.path} not found.');
    exit(1);
  }

  final content = gradleFile.readAsStringSync();
  // versionName = "2026.03.10" or versionName = '2026.03.10'
  final match = RegExp(r'versionName\s*=\s*"([^"]*)"').firstMatch(content);
  if (match == null) {
    print('Error: versionName not found in build.gradle.kts');
    exit(1);
  }

  final versionName = match.group(1)!;
  final dartContent =
      '''// Generated from android/app/build.gradle.kts - do not edit by hand.
// Run: dart run scripts/generate_app_version.dart (after changing versionName)

const String appVersionName = r'$versionName';
''';

  outFile.writeAsStringSync(dartContent);
  print('Wrote ${outFile.path} with appVersionName = "$versionName"');
}
