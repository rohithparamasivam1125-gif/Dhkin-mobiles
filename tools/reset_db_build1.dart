import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse(
    'https://firestore.googleapis.com/v1/projects/dhkin-mobiles/databases/(default)/documents/system_config/app_status?updateMask.fieldPaths=latestVersionCode&updateMask.fieldPaths=minVersionCode&updateMask.fieldPaths=latestVersionName&updateMask.fieldPaths=minVersionName'
  );

  final res = await http.patch(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'fields': {
        'latestVersionCode': {'integerValue': '1'},
        'minVersionCode': {'integerValue': '1'},
        'latestVersionName': {'stringValue': '1.0.1'},
        'minVersionName': {'stringValue': '1.0.1'},
      }
    }),
  );

  if (res.statusCode == 200) {
    print('SUCCESS: Firestore DB reset to Build 1 (latestVersionCode=1, minVersionCode=1).');
  } else {
    print('Error: ${res.statusCode} ${res.body}');
  }
}
