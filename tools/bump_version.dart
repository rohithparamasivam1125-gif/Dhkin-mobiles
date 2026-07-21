import 'dart:io';

void main() {
  // 1. Read pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('Error: pubspec.yaml not found.');
    exit(1);
  }
  
  final pubspecContent = pubspecFile.readAsStringSync();
  final versionRegExp = RegExp(r'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)');
  final match = versionRegExp.firstMatch(pubspecContent);
  
  if (match == null) {
    print('Error: Could not parse version in pubspec.yaml');
    exit(1);
  }
  
  final major = int.parse(match.group(1)!);
  final minor = int.parse(match.group(2)!);
  final patch = int.parse(match.group(3)!);
  final build = int.parse(match.group(4)!);
  
  // Increment patch and build code
  final newPatch = patch + 1;
  final newBuild = build + 1;
  final newVersionName = '$major.$minor.$newPatch';
  final newVersion = '$newVersionName+$newBuild';
  
  print('Bumping version: $major.$minor.$patch+$build -> $newVersion');
  
  // Write back to pubspec.yaml
  final newPubspecContent = pubspecContent.replaceFirst(
    versionRegExp,
    'version: $newVersion',
  );
  pubspecFile.writeAsStringSync(newPubspecContent);
  
  // 2. Read lib/main.dart
  final mainFile = File('lib/main.dart');
  if (mainFile.existsSync()) {
    var mainContent = mainFile.readAsStringSync();
    
    final codeRegExp = RegExp(r'const int kCurrentVersionCode = \d+;');
    final nameRegExp = RegExp(r"const String kCurrentVersionName = '[^']+'");
    
    mainContent = mainContent.replaceFirst(codeRegExp, 'const int kCurrentVersionCode = $newBuild;');
    mainContent = mainContent.replaceFirst(nameRegExp, "const String kCurrentVersionName = '$newVersionName'");
    
    mainFile.writeAsStringSync(mainContent);
    print('Updated lib/main.dart constants.');
  } else {
    print('Warning: lib/main.dart not found.');
  }
  
  print('Version bump completed successfully.');
}
