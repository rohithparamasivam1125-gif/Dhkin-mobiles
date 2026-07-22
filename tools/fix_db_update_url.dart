import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse(
    'https://firestore.googleapis.com/v1/projects/dhkin-mobiles/databases/(default)/documents/system_config/app_status?updateMask.fieldPaths=latestVersionCode&updateMask.fieldPaths=latestVersionName&updateMask.fieldPaths=updateUrl'
  );

  final res = await http.patch(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'fields': {
        'latestVersionCode': {'integerValue': '3'},
        'latestVersionName': {'stringValue': '1.0.3'},
        'updateUrl': {'stringValue': 'https://github.com/rohithparamasivam1125-gif/Dhkin-mobiles/raw/main/apks/app-release.apk'},
      }
    }),
  );

  if (res.statusCode == 200) {
    print('SUCCESS: Updated Firestore updateUrl and set latestVersionCode to 3.');
  } else {
    print('Error: ${res.statusCode} ${res.body}');
  }
}
