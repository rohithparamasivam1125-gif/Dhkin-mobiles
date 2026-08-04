import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../utils/shop_helper.dart';

class PdfInventoryReportHelper {
  static Future<void> generateAndShareInventoryReport(String shopId, BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final db = DatabaseService();
      
      // Fetch categories
      final categories = await db.getCategories().first;
      
      // Fetch products
      final products = await db.getProducts(shopId).first;
      
      // Group products by category
      Map<String, List<dynamic>> productsByCategory = {};
      for (var product in products) {
        if (!productsByCategory.containsKey(product.category)) {
          productsByCategory[product.category] = [];
        }
        productsByCategory[product.category]!.add(product);
      }

      // Sort categories
      Set<String> allCategoryNames = Set.from(categories.map((c) => c.name));
      allCategoryNames.addAll(productsByCategory.keys);
      List<String> sortedCategories = allCategoryNames.toList()..sort();
      
      final shopName = ShopHelper.getDisplayName(shopId);

      // Create PDF
      final pdf = pw.Document();
      
      // Load fonts
      final fontR = await PdfGoogleFonts.notoSansRegular();
      final fontB = await PdfGoogleFonts.notoSansBold();
      final fontTamil = await PdfGoogleFonts.tiroTamilRegular();
      
      final primaryColor = PdfColor.fromHex('#153422');
      final darkColor = PdfColor.fromHex('#212121');
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(
            base: fontR,
            bold: fontB,
            fontFallback: [fontTamil],
          ),
          header: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '$shopName - Inventory Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generated on: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 16),
                pw.Divider(color: primaryColor, thickness: 2),
                pw.SizedBox(height: 16),
              ],
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            );
          },
          build: (pw.Context context) {
            List<pw.Widget> blocks = [];

            for (var category in sortedCategories) {
              final catProducts = productsByCategory[category] ?? [];
              // Sort products by name
              catProducts.sort((a, b) => a.name.compareTo(b.name));

              blocks.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8, top: 16),
                  child: pw.Text(
                    category,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                )
              );

              if (catProducts.isEmpty) {
                blocks.add(pw.Text('No products listed.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)));
              } else {
                final tableHeaders = ['Product Name', 'Units Available', 'Selling Price', 'Cost Price'];
                
                final tableData = catProducts.map((p) {
                  return [
                    p.name,
                    p.units.toString(),
                    'Rs. ${p.price.toStringAsFixed(2)}',
                    'Rs. ${p.costPrice.toStringAsFixed(2)}',
                  ];
                }).toList();

                blocks.add(
                  pw.TableHelper.fromTextArray(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    cellAlignment: pw.Alignment.centerLeft,
                    headerDecoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#E8F5E9'), // Light green header
                    ),
                    headerHeight: 25,
                    cellHeight: 25,
                    headerStyle: pw.TextStyle(
                      color: primaryColor,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    cellStyle: pw.TextStyle(
                      color: darkColor,
                      fontSize: 10,
                    ),
                    rowDecoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          color: PdfColors.grey200,
                          width: 0.5,
                        ),
                      ),
                    ),
                    headers: tableHeaders,
                    data: tableData,
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(1.5),
                    },
                  ),
                );
              }
            }
            return blocks;
          },
        ),
      );

      // Hide loading
      if (context.mounted) Navigator.pop(context);

      // Share/Save PDF
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final safeShopName = shopName.replaceAll(' ', '_');
      
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Inventory_Report_${safeShopName}_$dateStr.pdf',
      );

    } catch (e) {
      // Hide loading
      if (context.mounted) Navigator.pop(context);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
