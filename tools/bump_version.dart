import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('Fetching target version from Firebase Database...');
  
  int? dbMinBuildCode;
  String? dbMinVersionName;

  try {
    final response = await http.get(Uri.parse(
      'https://firestore.googleapis.com/v1/projects/dhkin-mobiles/databases/(default)/documents/system_config/app_status'
    )).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final fields = json['fields'] as Map<String, dynamic>?;
      if (fields != null) {
        if (fields.containsKey('minVersionCode')) {
          final codeStr = fields['minVersionCode']['integerValue'] ?? fields['minVersionCode']['stringValue'];
          dbMinBuildCode = int.tryParse(codeStr?.toString() ?? '');
        }
        if (fields.containsKey('minVersionName')) {
          dbMinVersionName = fields['minVersionName']['stringValue'];
        }
      }
    }
  } catch (e) {
    print('Warning: Could not fetch from Firestore DB ($e). Falling back to pubspec.yaml.');
  }

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
  final currentBuild = int.parse(match.group(4)!);
  final targetBuild = (dbMinBuildCode != null && dbMinBuildCode > currentBuild) ? dbMinBuildCode! : currentBuild;
  final targetVersionName = '$major.$minor.$patch';
  final newVersion = '$targetVersionName+$targetBuild';
  
  print('Syncing app version to Database Target: $newVersion (Build $targetBuild)');
  
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
    
    mainContent = mainContent.replaceFirst(codeRegExp, 'const int kCurrentVersionCode = $targetBuild;');
    mainContent = mainContent.replaceFirst(nameRegExp, "const String kCurrentVersionName = '$targetVersionName'");
    
    mainFile.writeAsStringSync(mainContent);
    print('Updated lib/main.dart constants to Build $targetBuild.');
  } else {
    print('Warning: lib/main.dart not found.');
  }

  // Update latestVersionCode, latestVersionName, & updateUrl in Firestore so Owner gets the sweet alert popup!
  try {
    await http.patch(
      Uri.parse('https://firestore.googleapis.com/v1/projects/dhkin-mobiles/databases/(default)/documents/system_config/app_status?updateMask.fieldPaths=latestVersionCode&updateMask.fieldPaths=latestVersionName&updateMask.fieldPaths=updateUrl'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fields': {
          'latestVersionCode': {'integerValue': targetBuild.toString()},
          'latestVersionName': {'stringValue': targetVersionName},
          'updateUrl': {'stringValue': 'https://github.com/rohithparamasivam1125-gif/Dhkin-mobiles/raw/main/apks/app-release.apk'},
        }
      }),
    );
    print('Updated latestVersionCode in Firestore DB to Build $targetBuild.');
  } catch (e) {
    print('Notice: Could not patch latestVersionCode in Firestore ($e).');
  }

  print('Version sync completed successfully.');
}
