import 'package:printing/printing.dart';

void main() async {
  try {
    final font = await PdfGoogleFonts.getFont('Noto Sans Tamil');
    print('SUCCESS: Loaded font ${font.name}');
  } catch (e) {
    print('Error: $e');
  }
}
