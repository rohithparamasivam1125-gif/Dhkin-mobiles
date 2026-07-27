import 'package:printing/printing.dart';

void main() async {
  try {
    final font = await PdfGoogleFonts.notoSans();
    print('SUCCESS: Loaded font ${font.name}');
  } catch (e) {
    print('Error: $e');
  }
}
