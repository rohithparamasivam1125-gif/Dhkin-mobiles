import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/expense_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/shop_helper.dart';

// ─────────────────────────── Constants ────────────────────────────────────────
const _kForestPdf = PdfColor(0.08, 0.20, 0.13);         // #153422
const _kRedPdf = PdfColor(0.83, 0.18, 0.18);            // #D32F2F
const _kBgPdf = PdfColor(0.94, 0.93, 0.88);             // #F0EDCF
const _kGreyPdf = PdfColor(0.60, 0.60, 0.60);
const _kWhitePdf = PdfColors.white;

// ─────────────────────────── Screen ───────────────────────────────────────────

class ExpenseReportScreen extends StatelessWidget {
  final String shopId;
  final List<ExpenseModel> expenses;
  final String periodLabel;

  const ExpenseReportScreen({
    super.key,
    required this.shopId,
    required this.expenses,
    required this.periodLabel,
  });

  // ── Computed ────────────────────────────────────────────────────────────────

  double get _total => expenses.fold(0, (s, e) => s + e.amount);

  double get _avg => expenses.isEmpty ? 0 : _total / expenses.length;

  double get _highest => expenses.isEmpty
      ? 0
      : expenses.map((e) => e.amount).reduce((a, b) => a > b ? a : b);

  Map<String, double> get _byCategory {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  Map<String, List<ExpenseModel>> get _byDate {
    final map = <String, List<ExpenseModel>>{};
    final sorted = List<ExpenseModel>.from(expenses)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    for (final e in sorted) {
      final key = DateFormat('dd MMM yyyy').format(e.timestamp);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  // ── Rupee helper — avoids unsupported glyph in PDF ─────────────────────────
  /// Use "Rs." in PDF (Noto Sans covers ₹ but only when font is explicitly set
  /// on every text node; this helper keeps it consistent).
  static String _rs(double v) => 'Rs.${v.toStringAsFixed(2)}';
  static String _rsInt(double v) => 'Rs.${v.toStringAsFixed(0)}';

  // ── PDF ──────────────────────────────────────────────────────────────────────

  Future<pw.Document> _buildPdf() async {
    // Load Noto Sans — supports ₹ and all Indian characters
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontItalic = await PdfGoogleFonts.notoSansItalic();

    final pdf = pw.Document();
    final catMap = _byCategory;
    final dateMap = _byDate;

    // Colour palette (PdfLinearGradient not available — use solid fills)
    const forestColor = _kForestPdf;
    const redColor = _kRedPdf;
    const bgColor = _kBgPdf;

    // ────────────────────────── Page ──────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 30, 32, 30),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
          italic: fontItalic,
        ),

        // ── Header ────────────────────────────────────────────────────────────
        header: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Column(children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: pw.BoxDecoration(
                color: forestColor,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('EXPENSE REPORT',
                          style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 16,
                              color: _kWhitePdf,
                              letterSpacing: 1.2)),
                      pw.SizedBox(height: 2),
                      pw.Text(ShopHelper.getDisplayName(shopId),
                          style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 10,
                              color: PdfColor(1, 1, 1, 0.7))),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor(1, 1, 1, 0.15),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text('CONFIDENTIAL',
                            style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 7,
                                color: _kWhitePdf,
                                letterSpacing: 1)),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Period: $periodLabel',
                          style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 8,
                              color: PdfColor(1, 1, 1, 0.75))),
                      pw.Text(
                          'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                          style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 8,
                              color: PdfColor(1, 1, 1, 0.6))),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ]),
        ),

        // ── Footer ────────────────────────────────────────────────────────────
        footer: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
              border: pw.Border(
                  top: pw.BorderSide(
                      color: PdfColors.grey300, width: 0.5))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('${ShopHelper.getDisplayName(shopId)}  |  Expense Report',
                  style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8,
                      color: _kGreyPdf)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8,
                      color: _kGreyPdf)),
            ],
          ),
        ),

        // ── Body ──────────────────────────────────────────────────────────────
        build: (ctx) => [

          // ── Summary boxes ──────────────────────────────────────────────────
          pw.Row(children: [
            _pdfStat('Total Spent', _rs(_total), forestColor, fontRegular, fontBold),
            pw.SizedBox(width: 8),
            _pdfStat('Total Entries', '${expenses.length}', redColor, fontRegular, fontBold),
            pw.SizedBox(width: 8),
            _pdfStat('Avg / Entry', _rs(_avg), const PdfColor(0.55, 0.27, 0.07), fontRegular, fontBold),
            pw.SizedBox(width: 8),
            _pdfStat('Highest', _rsInt(_highest), const PdfColor(0.42, 0.11, 0.60), fontRegular, fontBold),
          ]),
          pw.SizedBox(height: 18),

          // ── Category Breakdown ─────────────────────────────────────────────
          if (catMap.isNotEmpty) ...[
            _pdfSectionHeader('CATEGORY BREAKDOWN', fontBold),
            pw.SizedBox(height: 8),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: catMap.entries.toList().asMap().entries.map((me) {
                  final i = me.key;
                  final entry = me.value;
                  final pct = _total > 0 ? entry.value / _total : 0.0;
                  final barFill = (pct * 100).round().clamp(1, 99);
                  final isLast = i == catMap.length - 1;
                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: i.isEven
                          ? bgColor
                          : _kWhitePdf,
                      borderRadius: isLast
                          ? const pw.BorderRadius.only(
                              bottomLeft: pw.Radius.circular(8),
                              bottomRight: pw.Radius.circular(8))
                          : pw.BorderRadius.zero,
                    ),
                    child: pw.Column(
                        crossAxisAlignment:
                            pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(children: [
                            pw.Expanded(
                              child: pw.Text(entry.key,
                                  style: pw.TextStyle(
                                      font: fontBold,
                                      fontSize: 10,
                                      color: PdfColors.grey800)),
                            ),
                            pw.Text(
                                '${(pct * 100).toStringAsFixed(1)}%',
                                style: pw.TextStyle(
                                    font: fontRegular,
                                    fontSize: 8,
                                    color: _kGreyPdf)),
                            pw.SizedBox(width: 8),
                            pw.Text(_rsInt(entry.value),
                                style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 10,
                                    color: forestColor)),
                          ]),
                          pw.SizedBox(height: 4),
                          pw.Row(children: [
                            pw.Expanded(
                              flex: barFill,
                              child: pw.Container(
                                height: 5,
                                decoration: pw.BoxDecoration(
                                  color: forestColor,
                                  borderRadius:
                                      pw.BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 100 - barFill,
                              child: pw.Container(
                                height: 5,
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.grey200,
                                  borderRadius:
                                      pw.BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ]),
                        ]),
                  );
                }).toList(),
              ),
            ),
            pw.SizedBox(height: 18),
          ],

          // ── Date-wise Breakdown ────────────────────────────────────────────
          if (dateMap.isNotEmpty) ...[
            _pdfSectionHeader('DATE-WISE BREAKDOWN', fontBold),
            pw.SizedBox(height: 8),
            ...dateMap.entries.expand((entry) {
              final dayTotal =
                  entry.value.fold<double>(0, (s, e) => s + e.amount);
              return [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: pw.BoxDecoration(
                    color: forestColor,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(children: [
                    pw.Expanded(
                      child: pw.Text(entry.key,
                          style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 10,
                              color: _kWhitePdf)),
                    ),
                    pw.Text(_rsInt(dayTotal),
                        style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            color: _kWhitePdf)),
                  ]),
                ),
                pw.SizedBox(height: 4),
                ...entry.value.asMap().entries.map((ie) {
                  final ei = ie.key;
                  final e = ie.value;
                  return pw.Container(
                    color: ei.isOdd ? bgColor : _kWhitePdf,
                    padding: const pw.EdgeInsets.fromLTRB(16, 6, 12, 6),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 5,
                          height: 5,
                          margin: const pw.EdgeInsets.only(top: 3),
                          decoration: const pw.BoxDecoration(
                              color: _kRedPdf,
                              shape: pw.BoxShape.circle),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(e.category,
                              style: pw.TextStyle(
                                  font: fontBold, fontSize: 9)),
                        ),
                        if (e.description.isNotEmpty)
                          pw.Expanded(
                            flex: 4,
                            child: pw.Text(
                                () {
                                  final parts = e.description.split('|');
                                  if (parts.length >= 3 && parts[1].contains('[Item:')) {
                                    final itemName = parts[1].replaceAll(RegExp(r'\[Item: |\]'), '').trim();
                                    final qty = parts[2].replaceAll(RegExp(r'\[Qty: |\]'), '').trim();
                                    return '$itemName (Qty: $qty)';
                                  }
                                  if (parts.length >= 2) {
                                    String detail = parts[1].replaceAll(RegExp(r'\[.*?\]'), '').trim();
                                    if (detail.isEmpty) detail = parts[1].replaceAll(RegExp(r'[\[\]]'), '').trim();
                                    return detail;
                                  }
                                  return e.description;
                                }(),
                                style: pw.TextStyle(
                                    font: fontItalic,
                                    fontSize: 8,
                                    color: _kGreyPdf)),
                          ),
                        pw.SizedBox(width: 8),
                        pw.Text(_rsInt(e.amount),
                            style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 9,
                                color: _kRedPdf)),
                      ],
                    ),
                  );
                }),
                pw.SizedBox(height: 10),
              ];
            }),
          ],
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _pdfStat(String label, String value, PdfColor color,
      pw.Font regular, pw.Font bold) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    font: regular,
                    fontSize: 8,
                    color: PdfColor(1, 1, 1, 0.7))),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(
                    font: bold,
                    fontSize: 13,
                    color: _kWhitePdf)),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfSectionHeader(String title, pw.Font bold) {
    return pw.Row(children: [
      pw.Container(width: 4, height: 14,
          decoration: pw.BoxDecoration(
              color: _kForestPdf,
              borderRadius: pw.BorderRadius.circular(2))),
      pw.SizedBox(width: 8),
      pw.Text(title,
          style: pw.TextStyle(
              font: bold, fontSize: 11,
              color: _kForestPdf, letterSpacing: 0.8)),
    ]);
  }

  // ── Share ────────────────────────────────────────────────────────────────────

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final pdf = await _buildPdf();
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/expense_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Expense Report — ${ShopHelper.getDisplayName(shopId)} ($periodLabel)',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Share failed: $e')));
      }
    }
  }

  // ── Print ────────────────────────────────────────────────────────────────────

  Future<void> _printPdf(BuildContext context) async {
    try {
      final pdf = await _buildPdf();
      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'Expense Report — ${ShopHelper.getDisplayName(shopId)}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Print failed: $e')));
      }
    }
  }

  // ── UI Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final catMap = _byCategory;
    final dateMap = _byDate;
    final palette = [
      const Color(0xFF153422),
      const Color(0xFFD32F2F),
      const Color(0xFFE65100),
      const Color(0xFF1565C0),
      const Color(0xFF6A1B9A),
      const Color(0xFF00695C),
      const Color(0xFFF57F17),
      const Color(0xFF37474F),
    ];

    return Scaffold(
      backgroundColor: AppTheme.primaryIvory,
      appBar: AppBar(
        title: const Text('Expense Report'),
        actions: [
          IconButton(
            tooltip: 'Share PDF',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _sharePdf(context),
          ),
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => _printPdf(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Gradient Header Card ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.accentForest, Color(0xFF1E4D35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.accentForest.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart_rounded,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Text('EXPENSE REPORT',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('CONFIDENTIAL',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(ShopHelper.getDisplayName(shopId),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: Colors.white60, size: 13),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(periodLabel,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.access_time,
                        color: Colors.white60, size: 13),
                    const SizedBox(width: 6),
                    Text(
                        'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 4-stat grid ──────────────────────────────────────────────────
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.75,
              children: [
                _StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Total Spent',
                  value: '₹${_total.toStringAsFixed(2)}',
                  color: const Color(0xFFD32F2F),
                ),
                _StatCard(
                  icon: Icons.receipt_outlined,
                  label: 'Total Entries',
                  value: '${expenses.length}',
                  color: AppTheme.accentForest,
                ),
                _StatCard(
                  icon: Icons.trending_up_rounded,
                  label: 'Avg per Entry',
                  value: '₹${_avg.toStringAsFixed(2)}',
                  color: const Color(0xFFE65100),
                ),
                _StatCard(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Highest Entry',
                  value: '₹${_highest.toStringAsFixed(0)}',
                  color: const Color(0xFF6A1B9A),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Category Breakdown ───────────────────────────────────────────
            if (catMap.isNotEmpty) ...[
              _SectionHeader(
                  icon: Icons.donut_small_outlined,
                  title: 'Category Breakdown'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.secondaryIvory,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: catMap.entries.toList().asMap().entries.map((me) {
                    final i = me.key;
                    final entry = me.value;
                    final pct = _total > 0 ? entry.value / _total : 0.0;
                    final color = palette[i % palette.length];
                    final isLast = i == catMap.length - 1;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: !isLast
                            ? Border(
                                bottom: BorderSide(
                                    color: AppTheme.accentForest
                                        .withValues(alpha: 0.07)))
                            : null,
                      ),
                      child: Column(children: [
                        Row(children: [
                          Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(entry.key,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppTheme.charcoalBlack)),
                          ),
                          Text('${(pct * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.graphiteGray
                                      .withValues(alpha: 0.7))),
                          const SizedBox(width: 12),
                          Text('₹${entry.value.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: color)),
                        ]),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 7,
                            backgroundColor:
                                color.withValues(alpha: 0.12),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Date-wise Breakdown ──────────────────────────────────────────
            if (dateMap.isNotEmpty) ...[
              _SectionHeader(
                  icon: Icons.calendar_view_day_outlined,
                  title: 'Date-wise Breakdown'),
              const SizedBox(height: 12),
              ...dateMap.entries.map(
                  (e) => _DateGroup(date: e.key, items: e.value)),
            ],

            // ── Empty ────────────────────────────────────────────────────────
            if (expenses.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 56,
                        color: AppTheme.accentForest.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text('No expenses found for this period',
                        style: TextStyle(
                            color: AppTheme.graphiteGray
                                .withValues(alpha: 0.6),
                            fontSize: 15)),
                  ]),
                ),
              ),
          ],
        ),
      ),

      // ── Bottom bar ────────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding:
            const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: AppTheme.secondaryIvory,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -3)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _sharePdf(context),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentForest,
                  side: const BorderSide(
                      color: AppTheme.accentForest, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _printPdf(context),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Print Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentForest,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────── Sub-widgets ─────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.secondaryIvory,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.graphiteGray.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          color: AppTheme.accentForest,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Icon(icon, size: 17, color: AppTheme.accentForest),
      const SizedBox(width: 7),
      Text(title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.charcoalBlack)),
      const SizedBox(width: 10),
      Expanded(
        child: Divider(
            color: AppTheme.accentForest.withValues(alpha: 0.2),
            thickness: 1),
      ),
    ]);
  }
}

class _DateGroup extends StatelessWidget {
  final String date;
  final List<ExpenseModel> items;

  const _DateGroup({required this.date, required this.items});

  @override
  Widget build(BuildContext context) {
    final dayTotal = items.fold<double>(0, (s, e) => s + e.amount);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.secondaryIvory,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        // Date header
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.accentForest.withValues(alpha: 0.09),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14)),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined,
                size: 13, color: AppTheme.accentForest),
            const SizedBox(width: 8),
            Text(date,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.accentForest)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accentForest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('₹${dayTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ]),
        ),

        // Rows
        ...items.asMap().entries.map((me) {
          final i = me.key;
          final e = me.value;
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: i.isOdd
                  ? AppTheme.primaryIvory.withValues(alpha: 0.5)
                  : Colors.transparent,
              border: i < items.length - 1
                  ? Border(
                      bottom: BorderSide(
                          color: AppTheme.accentForest
                              .withValues(alpha: 0.06)))
                  : null,
              borderRadius: i == items.length - 1
                  ? const BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14))
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                      color: Color(0xFFD32F2F),
                      shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.category,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.charcoalBlack)),
                      if (e.description.isNotEmpty)
                        Text(e.description,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.graphiteGray
                                    .withValues(alpha: 0.8),
                                height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Text('₹${e.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFFD32F2F))),
              ],
            ),
          );
        }),
      ]),
    );
  }
}
