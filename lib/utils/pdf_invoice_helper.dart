import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../models/sale_model.dart';
import '../models/gst_settings_model.dart';
import '../models/service_model.dart';

class PdfInvoiceHelper {
  static const _shareChannel = MethodChannel('com.dhkin_mobiles.share/whatsapp');
  static Future<pw.Document> buildInvoiceDocument(SaleModel sale, GstSettingsModel gstSettings) async {
    final pdf = pw.Document();
    
    // Load fonts
    final fontR = await PdfGoogleFonts.notoSansRegular();
    final fontB = await PdfGoogleFonts.notoSansBold();

    // Decode logo
    pw.Widget? logoWidget;
    if (gstSettings.logoBase64 != null && gstSettings.logoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(gstSettings.logoBase64!);
        final image = pw.MemoryImage(bytes);
        logoWidget = pw.Container(
          height: 55,
          alignment: pw.Alignment.centerLeft,
          child: pw.Image(image, fit: pw.BoxFit.contain),
        );
      } catch (e) {
        logoWidget = null;
      }
    }

    final primaryColor = PdfColor.fromHex('#153422'); // Premium Forest Green
    final secondaryColor = PdfColor.fromHex('#2E7D32'); // Accent Green
    final darkColor = PdfColor.fromHex('#212121'); // Text Charcoal
    final lightColor = PdfColor.fromHex('#F8F9FA'); // Background Off-white

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: fontR,
          bold: fontB,
        ),
        build: (pw.Context context) {
          final dateStr = DateFormat('dd-MM-yyyy hh:mm a').format(sale.timestamp);
          
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Colored top brand bar
              pw.Container(
                height: 5,
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
                ),
              ),
              pw.SizedBox(height: 20),

              // Header Row (Logo / Brand Name on Left, Invoice Details on Right)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoWidget != null) ...[
                          logoWidget,
                          pw.SizedBox(height: 8),
                        ] else ...[
                          pw.Text(
                            gstSettings.shopName.toUpperCase(),
                            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryColor),
                          ),
                          pw.SizedBox(height: 4),
                        ],
                        pw.Text(gstSettings.address, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 2),
                        pw.Text('Phone: ${gstSettings.contactNumber}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        if (gstSettings.email.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text('Email: ${gstSettings.email}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: lightColor,
                            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text('GSTIN: ${gstSettings.gstNumber}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkColor)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 12),

              // Billing and Customer Details Card
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILLED TO:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text(sale.customerName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkColor)),
                        pw.SizedBox(height: 2),
                        pw.Text('Phone: +91 ${sale.customerPhone}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Invoice No: #${sale.id.substring(0, 8).toUpperCase()}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkColor)),
                        pw.SizedBox(height: 2),
                        pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 2),
                        pw.Text('Billed By: ${sale.employeeId}', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Items Table
              pw.TableHelper.fromTextArray(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.75),
                ),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.center,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.center,
                  6: pw.Alignment.centerRight,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FixedColumnWidth(40),
                  4: const pw.FixedColumnWidth(70),
                  5: const pw.FixedColumnWidth(60),
                  6: const pw.FixedColumnWidth(70),
                },
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                headerDecoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: ['S.No', 'Product Description', 'Rate', 'Qty', 'Taxable Val', 'GST%', 'Total'],
                data: List<List<String>>.generate(sale.items.length, (index) {
                  final item = sale.items[index];
                  final double total = item.price * item.quantity;
                  
                  final double taxPercent = gstSettings.cgstRate + gstSettings.sgstRate;
                  final double netRate = sale.isGstBill ? (item.price / (1 + taxPercent / 100)) : item.price;
                  final double netTotal = netRate * item.quantity;
                  
                  return [
                    '${index + 1}',
                    item.productName,
                    'Rs.${netRate.toStringAsFixed(2)}',
                    '${item.quantity}',
                    'Rs.${netTotal.toStringAsFixed(2)}',
                    sale.isGstBill ? '${taxPercent.toStringAsFixed(0)}%' : '0%',
                    'Rs.${total.toStringAsFixed(2)}',
                  ];
                }),
              ),
              pw.SizedBox(height: 20),

              // Summary Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Terms and Payment Info
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text('1. Goods once sold cannot be taken back or exchanged.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                        pw.Text('2. Warranty claims are subject to brand terms & services.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                        pw.SizedBox(height: 12),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: const pw.BoxDecoration(
                            color: PdfColor(0.88, 0.96, 0.9), // Subtle Light Green
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text('PAYMENT RECEIVED (PAID)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text('Payment Mode: ${sale.paymentMode}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkColor)),
                        if (sale.exchangeAmount > 0) ...[
                          pw.SizedBox(height: 2),
                          pw.Text('Exchange Credit: Rs.${sale.exchangeAmount.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        ],
                        if (sale.paymentMode == 'Split') ...[
                          pw.SizedBox(height: 2),
                          pw.Text('Cash Paid: Rs.${sale.cashAmount.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text('Online Paid: Rs.${sale.onlineAmount.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  // Totals Box
                  pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: lightColor,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    ),
                    child: pw.Column(
                      children: [
                        _buildSummaryRow('Subtotal (Taxable Value):', 'Rs.${sale.taxableAmount.toStringAsFixed(2)}', fontR, darkColor),
                        if (sale.isGstBill) ...[
                          pw.SizedBox(height: 4),
                          _buildSummaryRow('CGST (${gstSettings.cgstRate}%):', 'Rs.${sale.cgstAmount.toStringAsFixed(2)}', fontR, darkColor),
                          pw.SizedBox(height: 4),
                          _buildSummaryRow('SGST (${gstSettings.sgstRate}%):', 'Rs.${sale.sgstAmount.toStringAsFixed(2)}', fontR, darkColor),
                        ],
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6),
                          child: pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                        ),
                        _buildSummaryRow('GRAND TOTAL:', 'Rs.${sale.totalPrice.toStringAsFixed(2)}', fontB, primaryColor, isTotal: true),
                        if (sale.exchangeAmount > 0) ...[
                          pw.SizedBox(height: 4),
                          _buildSummaryRow('Exchange Credit:', '-Rs.${sale.exchangeAmount.toStringAsFixed(2)}', fontR, secondaryColor),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4),
                            child: pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                          ),
                          _buildSummaryRow(
                            sale.totalPrice >= sale.exchangeAmount ? 'NET PAYABLE:' : 'REFUND DUE:',
                            'Rs.${(sale.totalPrice - sale.exchangeAmount).abs().toStringAsFixed(2)}',
                            fontB,
                            primaryColor,
                            isTotal: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              
              // Bottom Footer
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Thank you for shopping with us! 🙏', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.SizedBox(height: 3),
                    pw.Text('This is a computer-generated invoice and requires no signature.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static Future<void> generateAndPrintInvoice(SaleModel sale, GstSettingsModel gstSettings) async {
    final pdf = await buildInvoiceDocument(sale, gstSettings);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_${sale.id.substring(0, 8).toUpperCase()}.pdf',
    );
  }

  static Future<void> shareInvoicePdf(SaleModel sale, GstSettingsModel gstSettings) async {
    final pdf = await buildInvoiceDocument(sale, gstSettings);
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Invoice_${sale.id.substring(0, 8).toUpperCase()}.pdf');
    await file.writeAsBytes(bytes);
    
    bool sharedDirectly = false;
    try {
      if (Platform.isAndroid) {
        sharedDirectly = await _shareChannel.invokeMethod('sharePdfDirect', {
          'phone': sale.customerPhone,
          'filePath': file.path,
        });
      }
    } catch (_) {
      sharedDirectly = false;
    }

    if (!sharedDirectly) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Invoice - ${gstSettings.shopName}',
        ),
      );
    }
  }

  static pw.Row _buildSummaryRow(String label, String value, pw.Font font, PdfColor color, {bool isTotal = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: isTotal ? 10 : 8, fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: isTotal ? 11 : 8, fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
      ],
    );
  }

  static Future<pw.Document> buildServiceInvoiceDocument(ServiceModel service, GstSettingsModel gstSettings) async {
    final pdf = pw.Document();
    
    final fontR = await PdfGoogleFonts.notoSansRegular();
    final fontB = await PdfGoogleFonts.notoSansBold();

    pw.Widget? logoWidget;
    if (gstSettings.logoBase64 != null && gstSettings.logoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(gstSettings.logoBase64!);
        final image = pw.MemoryImage(bytes);
        logoWidget = pw.Container(
          height: 55,
          alignment: pw.Alignment.centerLeft,
          child: pw.Image(image, fit: pw.BoxFit.contain),
        );
      } catch (e) {
        logoWidget = null;
      }
    }

    final primaryColor = PdfColor.fromHex('#153422');
    final secondaryColor = PdfColor.fromHex('#2E7D32');
    final darkColor = PdfColor.fromHex('#212121');
    final lightColor = PdfColor.fromHex('#F8F9FA');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: fontR,
          bold: fontB,
        ),
        build: (pw.Context context) {
          final dateStr = DateFormat('dd-MM-yyyy hh:mm a').format(service.timestamp);
          
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                height: 5,
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
                ),
              ),
              pw.SizedBox(height: 20),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoWidget != null) ...[
                          logoWidget,
                          pw.SizedBox(height: 8),
                        ] else ...[
                          pw.Text(
                            gstSettings.shopName.toUpperCase(),
                            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryColor),
                          ),
                          pw.SizedBox(height: 4),
                        ],
                        pw.Text(gstSettings.address, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 2),
                        pw.Text('Phone: ${gstSettings.contactNumber}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        if (gstSettings.email.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text('Email: ${gstSettings.email}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('SERVICE INVOICE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.SizedBox(height: 8),
                        if (service.isGstBill)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: lightColor,
                              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Text('GSTIN: ${gstSettings.gstNumber}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkColor)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 12),

              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILLED TO:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text(service.customerName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkColor)),
                        pw.SizedBox(height: 2),
                        pw.Text('Phone: +91 ${service.customerPhone}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Job ID: #${service.id.substring(0, 8).toUpperCase()}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkColor)),
                        pw.SizedBox(height: 2),
                        pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 2),
                        pw.Text('Employee: ${service.employeeName}', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              pw.TableHelper.fromTextArray(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.75),
                ),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.center,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.center,
                  6: pw.Alignment.centerRight,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FixedColumnWidth(40),
                  4: const pw.FixedColumnWidth(70),
                  5: const pw.FixedColumnWidth(60),
                  6: const pw.FixedColumnWidth(70),
                },
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                headerDecoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: ['S.No', 'Service Description', 'Rate', 'Qty', 'Taxable Val', 'GST%', 'Total'],
                data: [
                  [
                    '1',
                    'Mobile Repair Service - ${service.mobileModel}\nDetails: ${service.mobileDetails}',
                    'Rs.${(service.isGstBill ? service.taxableAmount : service.totalAmount).toStringAsFixed(2)}',
                    '1',
                    'Rs.${(service.isGstBill ? service.taxableAmount : service.totalAmount).toStringAsFixed(2)}',
                    service.isGstBill ? '${(gstSettings.cgstRate + gstSettings.sgstRate).toStringAsFixed(0)}%' : '0%',
                    'Rs.${service.totalAmount.toStringAsFixed(2)}',
                  ]
                ],
              ),
              pw.SizedBox(height: 20),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Service Information:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text('1. Delivery of serviced devices is subject to payment completion.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                        pw.Text('2. Warranty is applicable only on repaired components/spares as specified.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                        pw.SizedBox(height: 12),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: service.status == 'Completed' || service.status == 'Delivered'
                              ? const PdfColor(0.88, 0.96, 0.9)
                              : const PdfColor(0.98, 0.93, 0.88),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            'STATUS: ${service.status.toUpperCase()}',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: service.status == 'Completed' || service.status == 'Delivered'
                                ? secondaryColor
                                : PdfColors.orange800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: lightColor,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    ),
                    child: pw.Column(
                      children: [
                        _buildSummaryRow('Subtotal (Taxable Value):', 'Rs.${service.taxableAmount.toStringAsFixed(2)}', fontR, darkColor),
                        if (service.isGstBill) ...[
                          pw.SizedBox(height: 4),
                          _buildSummaryRow('CGST (${gstSettings.cgstRate}%):', 'Rs.${service.cgstAmount.toStringAsFixed(2)}', fontR, darkColor),
                          pw.SizedBox(height: 4),
                          _buildSummaryRow('SGST (${gstSettings.sgstRate}%):', 'Rs.${service.sgstAmount.toStringAsFixed(2)}', fontR, darkColor),
                        ],
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6),
                          child: pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                        ),
                        _buildSummaryRow('GRAND TOTAL:', 'Rs.${service.totalAmount.toStringAsFixed(2)}', fontB, primaryColor, isTotal: true),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                        ),
                        _buildSummaryRow('Advance Paid:', 'Rs.${service.advanceAmount.toStringAsFixed(2)}', fontR, secondaryColor),
                        pw.SizedBox(height: 4),
                        _buildSummaryRow('Balance Due:', 'Rs.${service.remainingAmount.toStringAsFixed(2)}', fontB, PdfColors.red800),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Thank you for choosing ${gstSettings.shopName}! 🙏', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.SizedBox(height: 3),
                    pw.Text('This is a computer-generated invoice and requires no signature.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static Future<void> generateAndPrintServiceInvoice(ServiceModel service, GstSettingsModel gstSettings) async {
    final pdf = await buildServiceInvoiceDocument(service, gstSettings);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Service_Invoice_${service.id.substring(0, 8).toUpperCase()}.pdf',
    );
  }

  static Future<void> shareServiceInvoicePdf(ServiceModel service, GstSettingsModel gstSettings) async {
    final pdf = await buildServiceInvoiceDocument(service, gstSettings);
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Service_Invoice_${service.id.substring(0, 8).toUpperCase()}.pdf');
    await file.writeAsBytes(bytes);
    
    bool sharedDirectly = false;
    try {
      if (Platform.isAndroid) {
        sharedDirectly = await _shareChannel.invokeMethod('sharePdfDirect', {
          'phone': service.customerPhone,
          'filePath': file.path,
        });
      }
    } catch (_) {
      sharedDirectly = false;
    }

    if (!sharedDirectly) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Service Invoice - ${gstSettings.shopName}',
        ),
      );
    }
  }
}
