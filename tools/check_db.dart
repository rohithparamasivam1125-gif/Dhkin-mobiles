import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(Uri.parse(
    'https://firestore.googleapis.com/v1/projects/dhkin-mobiles/databases/(default)/documents/system_config/app_status'
  ));
  print(res.body);
}
