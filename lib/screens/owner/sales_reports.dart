// Git sync test comment
import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/sale_model.dart';
import '../../models/service_model.dart';
import '../../utils/app_theme.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/expense_model.dart';
import '../../models/gst_settings_model.dart';
import '../../utils/shop_helper.dart';
import '../../utils/sound_helper.dart';

// ─── PDF colour constants ──────────────────────────────────────────────────────
const _kForest  = PdfColor(0.08, 0.20, 0.13);
const _kRed     = PdfColor(0.83, 0.18, 0.18);
const _kAmber   = PdfColor(0.55, 0.27, 0.07);
const _kBlue    = PdfColor(0.08, 0.27, 0.60);
const _kBg      = PdfColor(0.94, 0.93, 0.88);
const _kGrey    = PdfColor(0.55, 0.55, 0.55);
const _kWhite   = PdfColors.white;

enum FilterType { daily, weekly, monthly }

// ─────────────────────────────────────────────────────────────────────────────
class SalesReportsScreen extends StatefulWidget {
  const SalesReportsScreen({super.key});
  @override
  State<SalesReportsScreen> createState() => _SalesReportsScreenState();
}

class _SalesReportsScreenState extends State<SalesReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  FilterType _currentFilter = FilterType.monthly;
  DateTime _selectedDate  = DateTime.now();
  int    _weekOffset      = 0;   // 0 = this week, 1 = last week, 2 = 2 weeks ago
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Period label ────────────────────────────────────────────────────────────
  String get _periodLabel {
    switch (_currentFilter) {
      case FilterType.daily:
        return DateFormat('EEEE, dd MMM yyyy').format(_selectedDate);
      case FilterType.weekly:
        final now = DateTime.now();
        final start = now.subtract(Duration(days: now.weekday - 1 + (_weekOffset * 7)));
        final end   = start.add(const Duration(days: 6));
        return '${DateFormat('dd MMM').format(start)} – ${DateFormat('dd MMM yyyy').format(end)}';
      case FilterType.monthly:
        return DateFormat('MMMM yyyy').format(_selectedMonth);
    }
  }

  // ── Date filter predicate ───────────────────────────────────────────────────
  bool _inRange(DateTime ts) {
    switch (_currentFilter) {
      case FilterType.daily:
        return ts.year == _selectedDate.year &&
               ts.month == _selectedDate.month &&
               ts.day   == _selectedDate.day;
      case FilterType.weekly:
        final now   = DateTime.now();
        final start = now.subtract(Duration(days: now.weekday - 1 + (_weekOffset * 7)));
        final end   = start.add(const Duration(days: 7));
        return ts.isAfter(start.subtract(const Duration(seconds: 1))) &&
               ts.isBefore(end);
      case FilterType.monthly:
        return ts.year  == _selectedMonth.year &&
               ts.month == _selectedMonth.month;
    }
  }

  bool _isBefore(DateTime ts) {
    switch (_currentFilter) {
      case FilterType.daily:
        final startOfSelectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        return ts.isBefore(startOfSelectedDate);
      case FilterType.weekly:
        final now   = DateTime.now();
        final start = now.subtract(Duration(days: now.weekday - 1 + (_weekOffset * 7)));
        return ts.isBefore(start);
      case FilterType.monthly:
        final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
        return ts.isBefore(startOfMonth);
    }
  }

  // ── Filter picker ───────────────────────────────────────────────────────────
  Future<void> _openFilterPicker() async {
    switch (_currentFilter) {
      case FilterType.daily:
        final p = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppTheme.accentForest,
                onPrimary: Colors.white,
                surface: AppTheme.secondaryIvory,
              ),
            ),
            child: child!,
          ),
        );
        if (p != null) setState(() => _selectedDate = p);

      case FilterType.weekly:
        await showDialog(
          context: context,
          builder: (_) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: AppTheme.primaryIvory,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Week',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  ...[0, 1, 2].map((offset) {
                    final now   = DateTime.now();
                    final start = now.subtract(Duration(days: now.weekday - 1 + offset * 7));
                    final end   = start.add(const Duration(days: 6));
                    final lbl   = '${DateFormat('dd MMM').format(start)} – ${DateFormat('dd MMM').format(end)}';
                    return ListTile(
                      leading: Icon(
                        Icons.check_circle_rounded,
                        color: _weekOffset == offset
                            ? AppTheme.accentForest
                            : Colors.transparent,
                        size: 20,
                      ),
                      title: Text(lbl, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(offset == 0 ? 'This Week' : offset == 1 ? 'Last Week' : '2 Weeks Ago',
                          style: const TextStyle(fontSize: 11)),
                      onTap: () {
                        setState(() => _weekOffset = offset);
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );

      case FilterType.monthly:
        await showDialog(
          context: context,
          builder: (_) => _MonthPickerDialog(
            initial: _selectedMonth,
            onSelected: (d) => setState(() => _selectedMonth = d),
          ),
        );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryIvory,
      appBar: AppBar(
        title: const Text('Reports & Analysis'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // ── Period selector bar ──────────────────────────────────────
              Container(
                color: AppTheme.secondaryIvory,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      // Filter type toggle
                      ...FilterType.values.map((f) {
                        final selected = _currentFilter == f;
                        return GestureDetector(
                          onTap: () => setState(() => _currentFilter = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.accentForest
                                  : AppTheme.accentForest.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              f.name[0].toUpperCase() + f.name.substring(1),
                              style: TextStyle(
                                color: selected ? Colors.white : AppTheme.accentForest,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 16), // Replaced Spacer with fixed gap for scrollable row
                      // Period display chip
                      GestureDetector(
                        onTap: _openFilterPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.accentForest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  color: Colors.white, size: 13),
                              const SizedBox(width: 5),
                              Text(
                                _currentFilter == FilterType.daily
                                    ? DateFormat('dd MMM yyyy').format(_selectedDate)
                                    : _currentFilter == FilterType.monthly
                                        ? DateFormat('MMM yyyy').format(_selectedMonth)
                                        : _weekOffset == 0 ? 'This Week' : _weekOffset == 1 ? 'Last Week' : '2 Wks Ago',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12),
                              ),
                              const Icon(Icons.expand_more, color: Colors.white70, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Shop tabs ──────────────────────────────────────────────
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryIvory,
                unselectedLabelColor: AppTheme.primaryIvory.withValues(alpha: 0.5),
                indicatorColor: AppTheme.primaryIvory,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: [
                  Tab(text: ShopHelper.getDisplayName('Shop 1')),
                  Tab(text: ShopHelper.getDisplayName('Shop 2')),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: ['Shop 1', 'Shop 2']
            .map((shopId) => _ShopReportView(
                  shopId: shopId,
                  inRange: _inRange,
                  isBefore: _isBefore,
                  periodLabel: _periodLabel,
                  filterName: _currentFilter.name.toUpperCase(),
                ))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────── Per-shop report view ─────────────────────────────

class _ShopReportView extends StatelessWidget {
  final String shopId;
  final bool Function(DateTime) inRange;
  final bool Function(DateTime) isBefore;
  final String periodLabel;
  final String filterName;

  const _ShopReportView({
    required this.shopId,
    required this.inRange,
    required this.isBefore,
    required this.periodLabel,
    required this.filterName,
  });

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _exportPdf(
      BuildContext context,
      List<SaleModel> sales,
      List<ServiceModel> services,
      List<ExpenseModel> expenses,
      double netProfit,
      double cogs,
      [double openingDrawerAmount = 0.0]) async {
    try {
      final pdf  = await _buildPdf(sales, services, expenses, netProfit, cogs, openingDrawerAmount, filterName);
      final bytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${filterName[0].toUpperCase()}${filterName.substring(1).toLowerCase()} Sales Report - ${ShopHelper.getDisplayName(shopId)}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Print failed: $e')));
      }
    }
  }

  Future<void> _sharePdf(
      BuildContext context,
      List<SaleModel> sales,
      List<ServiceModel> services,
      List<ExpenseModel> expenses,
      double netProfit,
      double cogs,
      [double openingDrawerAmount = 0.0]) async {
    try {
      final pdf   = await _buildPdf(sales, services, expenses, netProfit, cogs, openingDrawerAmount, filterName);
      final bytes  = await pdf.save();
      final dir    = await getTemporaryDirectory();
      final file   = File('${dir.path}/sales_report_${shopId}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: '${filterName[0].toUpperCase()}${filterName.substring(1).toLowerCase()} Sales Report - ${ShopHelper.getDisplayName(shopId)} ($periodLabel)',
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    }
  }

  // ── PDF builder ────────────────────────────────────────────────────────────

  Future<pw.Document> _buildPdf(
      List<SaleModel> sales,
      List<ServiceModel> services,
      List<ExpenseModel> expenses,
      double netProfit,
      double cogs,
      [double openingDrawerAmount = 0.0,
      String filterName = 'SALES']) async {
    final fontR = await PdfGoogleFonts.notoSansRegular();
    final fontB = await PdfGoogleFonts.notoSansBold();
    final fontI = await PdfGoogleFonts.notoSansItalic();

    final pdf = pw.Document();
    final salesTotal   = sales.fold<double>(0, (s, e) => s + (e.isGstBill ? e.taxableAmount : e.totalPrice));
    final serviceTotal = services.fold<double>(0, (s, e) {
      final double effectiveAdvance = e.advanceAmount.clamp(0.0, e.totalAmount);
      return s + (e.isGstBill && e.totalAmount > 0 ? (effectiveAdvance * (e.taxableAmount / e.totalAmount)) : effectiveAdvance);
    });
    final expTotal     = expenses.where((e) => e.category != 'Specialist Fee' && e.category != 'Parts Cost').fold<double>(0, (s, e) => s + e.amount);
    final serviceExpenses = services.fold<double>(0, (sum, s) => sum + s.partsCost + s.technicianFee);
    final gstCollected = sales.fold<double>(0, (sum, s) => sum + (s.isGstBill ? (s.cgstAmount + s.sgstAmount) : 0.0)) +
                         services.fold<double>(0, (sum, s) {
                           final double effectiveAdvance = s.advanceAmount.clamp(0.0, s.totalAmount);
                           return sum + (s.isGstBill && s.totalAmount > 0 ? (effectiveAdvance * ((s.cgstAmount + s.sgstAmount) / s.totalAmount)) : 0.0);
                         });
    final cashTotal = sales.fold<double>(0, (sum, s) => sum + s.cashAmount) +
                      services.fold<double>(0, (sum, s) => sum + s.cashAmount);
    final onlineTotal = sales.fold<double>(0, (sum, s) => sum + s.onlineAmount) +
                        services.fold<double>(0, (sum, s) => sum + s.onlineAmount);
    
    final cashSpentOnExpenses = expenses.where((e) => e.paymentMode == 'Cash').fold<double>(0, (sum, e) => sum + e.amount);
    final onlineSpentOnExpenses = expenses.where((e) => e.paymentMode == 'Online').fold<double>(0, (sum, e) => sum + e.amount);

    // Split expenses into Wastage and General
    final wastageList = expenses.where((e) => e.category.contains('Loss')).toList();
    final generalExpenseList = expenses.where((e) => !e.category.contains('Loss') && e.category != 'Specialist Fee' && e.category != 'Parts Cost').toList();
    final allExpensesList = expenses.where((e) => !e.category.contains('Loss')).toList();
    
    final wastageTotal = wastageList.fold<double>(0, (s, e) => s + e.amount);
    final genericExpTotal = generalExpenseList.fold<double>(0, (s, e) => s + e.amount);
    final partsCostTotal = expenses.where((e) => e.category == 'Parts Cost').fold<double>(0, (s, e) => s + e.amount);
    final specialistFeeTotal = expenses.where((e) => e.category == 'Specialist Fee').fold<double>(0, (s, e) => s + e.amount);
    final giftExpensesTotal = generalExpenseList.where((e) => e.category == 'Complementary Gift').fold<double>(0, (s, e) => s + e.amount);

    final grossProfit  = salesTotal - cogs;
    final serviceProfit = serviceTotal - serviceExpenses;

    // Helper
    pw.TextStyle ts({double size = 10, bool bold = false, PdfColor? color}) =>
        pw.TextStyle(
          font: bold ? fontB : fontR,
          fontSize: size,
          color: color ?? PdfColors.black,
        );

    // ── Section header ───────────────────────────────────────────────────────
    pw.Widget secHeader(String title, PdfColor color) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(children: [
            pw.Container(
              width: 4, height: 16,
              decoration: pw.BoxDecoration(
                  color: color, borderRadius: pw.BorderRadius.circular(2)),
            ),
            pw.SizedBox(width: 8),
            pw.Text(title, style: ts(size: 12, bold: true, color: color)),
          ]),
        );

    // ── Stat box ────────────────────────────────────────────────────────────
    pw.Widget statBox(String label, String value, PdfColor bg, {String? sub}) =>
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            margin: const pw.EdgeInsets.only(right: 6),
            decoration: pw.BoxDecoration(
                color: bg, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(label,
                      style: ts(size: 7, color: PdfColor(1, 1, 1, 0.7))),
                  pw.SizedBox(height: 5),
                  pw.Text(value,
                      style: ts(size: 13, bold: true, color: _kWhite)),
                  if (sub != null) ...[pw.SizedBox(height: 2), pw.Text(sub, style: ts(size: 7, color: PdfColor(1,1,1,0.6)))],
                ]),
          ),
        );

    // ── Table header style ──────────────────────────────────────────────────
    pw.TextStyle hStyle = pw.TextStyle(
        font: fontB, fontSize: 9, color: _kWhite);
    pw.BoxDecoration hDec(PdfColor c) =>
        pw.BoxDecoration(color: c);
    pw.TextStyle cStyle = pw.TextStyle(font: fontR, fontSize: 9);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        theme: pw.ThemeData.withFont(base: fontR, bold: fontB, italic: fontI),

        // ── PDF Header ───────────────────────────────────────────────────────
        header: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 14),
          child: pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: _kForest,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('${filterName.toUpperCase()} SALES REPORT',
                          style: ts(size: 18, bold: true, color: _kWhite)),
                      pw.SizedBox(height: 2),
                      pw.Text(ShopHelper.getDisplayName(shopId),
                          style: ts(size: 10, color: PdfColor(1, 1, 1, 0.7))),
                    ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: _kWhite, width: 0.8),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text('CONFIDENTIAL',
                            style: ts(size: 7, bold: true, color: _kWhite)),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Period: $periodLabel',
                          style: ts(size: 8, color: PdfColor(1, 1, 1, 0.75))),
                      pw.Text(
                          'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                          style: ts(size: 8, color: PdfColor(1, 1, 1, 0.6))),
                    ]),
              ],
            ),
          ),
        ),

        // ── PDF Footer ───────────────────────────────────────────────────────
        footer: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 6),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
              border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey300))),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('${ShopHelper.getDisplayName(shopId)}  |  ${filterName.toUpperCase()} Sales Report',
                    style: ts(size: 8, color: _kGrey)),
                pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: ts(size: 8, color: _kGrey)),
              ]),
        ),

        // ── PDF Body ─────────────────────────────────────────────────────────
        build: (ctx) => [

          // Summary stats row
          pw.Row(children: [
            statBox('TOTAL REVENUE', 'Rs.${(salesTotal + serviceTotal).toStringAsFixed(0)}', _kForest,
                sub: '${sales.length} sales + ${services.length} services'),
            statBox('NET PROFIT',
                '${netProfit >= 0 ? '+' : ''}Rs.${netProfit.toStringAsFixed(0)}',
                netProfit >= 0 ? const PdfColor(0.04, 0.45, 0.24) : _kRed,
                sub: netProfit >= 0 ? 'Profitable period' : 'Loss period'),
            statBox('TOTAL EXPENSES', 'Rs.${expenses.length > 0 ? expenses.fold<double>(0, (s, e) => s + e.amount).toStringAsFixed(0) : '0'}', _kRed,
                sub: '${allExpensesList.length} expenses + ${wastageList.length} wastage'),
            statBox('SALES COUNT', '${sales.length}', _kBlue,
                sub: 'Services: ${services.length}'),
          ]),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            if (openingDrawerAmount > 0)
              statBox('OPENING DRAWER', 'Rs.${openingDrawerAmount.toStringAsFixed(0)}', const PdfColor(0.4, 0.3, 0.0),
                  sub: 'Pre-sales drawer cash'),
            statBox('CASH COLLECTED', 'Rs.${cashTotal.toStringAsFixed(0)}', _kForest,
                sub: 'Sales + Services cash'),
            statBox('TOTAL DRAWER CASH', 'Rs.${(openingDrawerAmount + cashTotal - cashSpentOnExpenses).toStringAsFixed(0)}', const PdfColor(0.04, 0.35, 0.15),
                sub: 'Opening + Cash - Expenses'),
            statBox('NET ONLINE AMOUNT', 'Rs.${(onlineTotal - onlineSpentOnExpenses).toStringAsFixed(0)}', _kBlue,
                sub: 'Coll: Rs.${onlineTotal.toStringAsFixed(0)} | Exp: Rs.${onlineSpentOnExpenses.toStringAsFixed(0)}'),
          ]),
          pw.SizedBox(height: 20),

          // ── Sales Records ────────────────────────────────────────────────
          if (sales.isNotEmpty) ...[
            secHeader('SALES RECORDS', _kForest),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Customer', 'Product', 'Qty', 'Amount'],
              headerStyle: hStyle,
              headerDecoration: hDec(_kForest),
              cellStyle: cStyle,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
              columnWidths: {
                0: const pw.FixedColumnWidth(40),
                1: const pw.FlexColumnWidth(2.2),
                2: const pw.FlexColumnWidth(2.5),
                3: const pw.FixedColumnWidth(24),
                4: const pw.FixedColumnWidth(72),
              },
              oddRowDecoration: const pw.BoxDecoration(color: _kBg),
              data: sales.expand((s) => s.items.map((item) => [
                    DateFormat('dd/MM/yy').format(s.timestamp),
                    s.customerName,
                    item.productName,
                    '${item.quantity}',
                    'Rs.${(item.price * item.quantity).toStringAsFixed(0)}',
                  ])).toList().cast<List<dynamic>>(),
            ),
            pw.SizedBox(height: 6),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: pw.BoxDecoration(color: _kForest, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text('Sales Sub-total:  Rs.${salesTotal.toStringAsFixed(2)}',
                    style: ts(size: 10, bold: true, color: _kWhite)),
              ),
            ),
            pw.SizedBox(height: 18),
          ],

          // ── Service Records ───────────────────────────────────────────────
          if (services.isNotEmpty) ...[
            secHeader('SERVICE RECORDS', _kAmber),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Customer', 'Device', 'Status', 'Parts Cost', 'Tech Fee', 'Paid'],
              headerStyle: hStyle,
              headerDecoration: hDec(_kAmber),
              cellStyle: cStyle,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
              columnWidths: {
                0: const pw.FixedColumnWidth(38),
                1: const pw.FlexColumnWidth(1.8),
                2: const pw.FlexColumnWidth(1.8),
                3: const pw.FixedColumnWidth(50),
                4: const pw.FixedColumnWidth(55),
                5: const pw.FixedColumnWidth(55),
                6: const pw.FixedColumnWidth(55),
              },
              oddRowDecoration: const pw.BoxDecoration(color: _kBg),
              data: services.map((s) {
                String deviceText = s.mobileModel;
                if (s.complementaryItems.isNotEmpty) {
                  final gifts = s.complementaryItems.map((item) {
                    final name = item['productName'] as String? ?? 'Item';
                    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                    return '$name x$qty';
                  }).join(', ');
                  deviceText += '\n(Gift: $gifts)';
                }
                return [
                  DateFormat('dd/MM/yy').format(s.timestamp),
                  s.customerName,
                  deviceText,
                  s.status,
                  'Rs.${s.partsCost.toStringAsFixed(0)}',
                  'Rs.${s.technicianFee.toStringAsFixed(0)}',
                  'Rs.${s.advanceAmount.toStringAsFixed(0)}',
                ];
              }).toList().cast<List<dynamic>>(),
            ),
            pw.SizedBox(height: 6),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: pw.BoxDecoration(color: _kAmber, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text('Service Sub-total:  Rs.${serviceTotal.toStringAsFixed(2)}',
                    style: ts(size: 10, bold: true, color: _kWhite)),
              ),
            ),
            pw.SizedBox(height: 18),
          ],

          // ── Wastage Records ─────────────────────────────────────────────
          if (wastageList.isNotEmpty) ...[
            secHeader('WASTAGE RECORDS', _kAmber),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Item', 'Qty', 'Loss Amount'],
              headerStyle: hStyle,
              headerDecoration: hDec(_kAmber),
              cellStyle: cStyle,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
              },
              columnWidths: {
                0: const pw.FixedColumnWidth(40),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FixedColumnWidth(30),
                3: const pw.FixedColumnWidth(72),
              },
              oddRowDecoration: const pw.BoxDecoration(color: _kBg),
              data: wastageList.map((e) {
                final parts = e.description.split('|');
                String itemName = e.description;
                String qtyStr = '1';
                
                if (parts.length >= 3 && parts[1].contains('[Item:')) {
                  itemName = parts[1].replaceAll(RegExp(r'\[Item: |\]'), '').trim();
                  qtyStr = parts[2].replaceAll(RegExp(r'\[Qty: |\]'), '').trim();
                } else if (parts.length >= 2) {
                  itemName = parts[1].replaceAll(RegExp(r'[\[\]]'), '').trim();
                }

                return [
                  DateFormat('dd/MM/yy').format(e.timestamp),
                  itemName,
                  qtyStr,
                  'Rs.${e.amount.toStringAsFixed(0)}',
                ];
              }).toList().cast<List<dynamic>>(),
            ),
            pw.SizedBox(height: 6),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: pw.BoxDecoration(color: _kAmber, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text('Wastage Sub-total:  Rs.${wastageTotal.toStringAsFixed(2)}',
                    style: ts(size: 10, bold: true, color: _kWhite)),
              ),
            ),
            pw.SizedBox(height: 18),
          ],

          // ── Expense Records ───────────────────────────────────────────────
          if (allExpensesList.isNotEmpty) ...[
            secHeader('EXPENSE RECORDS (ITEMIZED)', _kRed),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Category', 'Description / Name', 'Mode', 'Amount'],
              headerStyle: hStyle,
              headerDecoration: hDec(_kRed),
              cellStyle: cStyle,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
              columnWidths: {
                0: const pw.FixedColumnWidth(40),
                1: const pw.FlexColumnWidth(1.6),
                2: const pw.FlexColumnWidth(3.0),
                3: const pw.FixedColumnWidth(45),
                4: const pw.FixedColumnWidth(60),
              },
              oddRowDecoration: const pw.BoxDecoration(color: PdfColor(1.0, 0.93, 0.93)),
              data: allExpensesList.map((e) {
                return [
                  DateFormat('dd/MM/yy').format(e.timestamp),
                  e.category,
                  e.description,
                  e.paymentMode.toUpperCase(),
                  'Rs.${e.amount.toStringAsFixed(0)}',
                ];
              }).toList().cast<List<dynamic>>(),
            ),
            pw.SizedBox(height: 6),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (genericExpTotal > 0)
                    pw.Text('General Operational Expenses: Rs.${(genericExpTotal - giftExpensesTotal).toStringAsFixed(0)}', style: ts(size: 8, color: _kGrey)),
                  if (giftExpensesTotal > 0)
                    pw.Text('Complementary Gift Expenses: Rs.${giftExpensesTotal.toStringAsFixed(0)}', style: ts(size: 8, color: _kGrey)),
                  if (partsCostTotal > 0)
                    pw.Text('Service Parts Costs: Rs.${partsCostTotal.toStringAsFixed(0)}', style: ts(size: 8, color: _kGrey)),
                  if (specialistFeeTotal > 0)
                    pw.Text('Service Specialist Fees: Rs.${specialistFeeTotal.toStringAsFixed(0)}', style: ts(size: 8, color: _kGrey)),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: pw.BoxDecoration(color: _kRed, borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Text('Expenses Sub-total:  Rs.${expenses.fold<double>(0, (s, e) => s + e.amount).toStringAsFixed(2)}',
                        style: ts(size: 10, bold: true, color: _kWhite)),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
          ],

          // ── Summary box ───────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: _kForest,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('FINANCIAL SUMMARY',
                      style: ts(size: 11, bold: true, color: _kWhite)),
                  pw.SizedBox(height: 10),

                  // Section 1: Sales
                  pw.Text('PRODUCT SALES', style: ts(size: 8, bold: true, color: const PdfColor(0.8, 0.9, 1.0))),
                  pw.SizedBox(height: 4),
                  _pdfSummaryRow('Sales Revenue',
                      'Rs.${salesTotal.toStringAsFixed(2)}', fontR, fontB),
                  if (cogs > 0)
                    _pdfSummaryRow('Cost of Goods Sold (COGS)',
                        '- Rs.${cogs.toStringAsFixed(2)}', fontR, fontB,
                        valueColor: _kRed),
                  _pdfSummaryRow('Product Sales Net Profit',
                      'Rs.${grossProfit.toStringAsFixed(2)}', fontR, fontB,
                      divider: true,
                      valueColor: grossProfit >= 0 ? const PdfColor(0.5, 1.0, 0.6) : _kRed),
                  pw.SizedBox(height: 10),

                  // Section 2: Services
                  pw.Text('REPAIR SERVICES', style: ts(size: 8, bold: true, color: const PdfColor(0.8, 0.9, 1.0))),
                  pw.SizedBox(height: 4),
                  _pdfSummaryRow('Service Revenue (Collections)',
                      'Rs.${serviceTotal.toStringAsFixed(2)}', fontR, fontB),
                  if (serviceExpenses > 0)
                    _pdfSummaryRow('Service Expenses (Parts & Tech)',
                        '- Rs.${serviceExpenses.toStringAsFixed(2)}', fontR, fontB,
                        valueColor: _kRed),
                  _pdfSummaryRow('Services Net Profit',
                      'Rs.${(serviceTotal - serviceExpenses).toStringAsFixed(2)}', fontR, fontB,
                      divider: true,
                      valueColor: (serviceTotal - serviceExpenses) >= 0 ? const PdfColor(0.5, 1.0, 0.6) : _kRed),
                  pw.SizedBox(height: 10),

                  // Section 3: Shop Operations
                  pw.Text('SHOP OPERATIONS & TAXES', style: ts(size: 8, bold: true, color: const PdfColor(0.8, 0.9, 1.0))),
                  pw.SizedBox(height: 4),
                  _pdfSummaryRow('General Expenses',
                      '- Rs.${(expTotal - giftExpensesTotal).toStringAsFixed(2)}', fontR, fontB,
                      valueColor: _kRed),
                  if (giftExpensesTotal > 0)
                    _pdfSummaryRow('Complementary Gift Expenses',
                        '- Rs.${giftExpensesTotal.toStringAsFixed(2)}', fontR, fontB,
                        valueColor: _kAmber),
                  if (gstCollected > 0)
                    _pdfSummaryRow('GST Collected (CGST + SGST)',
                        'Rs.${gstCollected.toStringAsFixed(2)}', fontR, fontB,
                        valueColor: const PdfColor(0.5, 0.8, 1.0)),
                  pw.SizedBox(height: 10),

                  // Section 4: Cash Drawer Balance
                  pw.Text('CASH DRAWER TALLY', style: ts(size: 8, bold: true, color: const PdfColor(0.8, 0.9, 1.0))),
                  pw.SizedBox(height: 4),
                  if (openingDrawerAmount > 0)
                    _pdfSummaryRow('Opening Drawer Cash',
                        'Rs.${openingDrawerAmount.toStringAsFixed(2)}', fontR, fontB,
                        valueColor: const PdfColor(1.0, 0.88, 0.3)),
                  _pdfSummaryRow('Cash Collected (Sales + Services)',
                      'Rs.${cashTotal.toStringAsFixed(2)}', fontR, fontB,
                      valueColor: const PdfColor(0.5, 1.0, 0.6)),
                  if (cashSpentOnExpenses > 0)
                    _pdfSummaryRow('Cash Spent on Expenses',
                        '- Rs.${cashSpentOnExpenses.toStringAsFixed(2)}', fontR, fontB,
                        valueColor: _kRed),
                  _pdfSummaryRow('Total Drawer Cash',
                      'Rs.${(openingDrawerAmount + cashTotal - cashSpentOnExpenses).toStringAsFixed(2)}', fontR, fontB,
                      divider: true,
                      valueColor: const PdfColor(0.5, 1.0, 0.6)),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 0, vertical: 8),
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(
                            top: pw.BorderSide(
                                color: PdfColor(1, 1, 1, 0.3)))),
                    child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('NET PROFIT',
                              style: ts(size: 12, bold: true, color: _kWhite)),
                          pw.Text(
                              '${netProfit >= 0 ? '+' : ''}Rs.${netProfit.toStringAsFixed(2)}',  
                              style: ts(
                                  size: 15,
                                  bold: true,
                                  color: netProfit >= 0
                                      ? PdfColor(0.5, 1.0, 0.6)
                                      : const PdfColor(1, 0.5, 0.5))),
                        ]),
                  ),
                ]),
          ),
          pw.SizedBox(height: 16),
          pw.Center(
              child: pw.Text('*** End of Report ***',
                  style: ts(size: 9, color: _kGrey))),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _pdfSummaryRow(String label, String value,
      pw.Font fontR, pw.Font fontB,
      {bool divider = false, PdfColor valueColor = _kWhite}) {
    return pw.Column(children: [
      if (divider)
        pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 4),
          height: 0.5,
          color: const PdfColor(1, 1, 1, 0.25),
        ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    font: fontR, fontSize: 10, color: PdfColor(1, 1, 1, 0.8))),
            pw.Text(value,
                style: pw.TextStyle(
                    font: fontB, fontSize: 10, color: valueColor)),
          ],
        ),
      ),
    ]);
  }

  // ── On-screen UI ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SaleModel>>(
      stream: DatabaseService().getSales(shopId),
      builder: (ctx, ss) {
        return StreamBuilder<List<ServiceModel>>(
          stream: DatabaseService().getServices(shopId),
          builder: (ctx, sv) {
            return StreamBuilder<List<ExpenseModel>>(
              stream: DatabaseService().getExpenses(shopId),
              builder: (ctx, ex) {
                return StreamBuilder<GstSettingsModel?>(
                  stream: DatabaseService().streamGstSettings(shopId),
                  builder: (ctx, settingsSnap) {
                    if (ss.connectionState == ConnectionState.waiting ||
                        sv.connectionState == ConnectionState.waiting ||
                        ex.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final initialStartingCash = settingsSnap.data?.openingDrawerAmount ?? 0.0;
                    final cashCollectedBefore = 
                        (ss.data ?? []).where((s) => isBefore(s.timestamp)).fold<double>(0, (sum, s) => sum + s.cashAmount) +
                        (sv.data ?? []).where((s) => isBefore(s.timestamp)).fold<double>(0, (sum, s) => sum + s.cashAmount);
                    final double cashSpentOnExpensesBefore =
                        (ex.data ?? []).where((e) => isBefore(e.timestamp) && e.paymentMode == 'Cash').fold<double>(0, (sum, e) => sum + e.amount);
                    final openingDrawerAmount = initialStartingCash + cashCollectedBefore - cashSpentOnExpensesBefore;

                    final sales    = (ss.data ?? []).where((s) => inRange(s.timestamp)).toList();
                    final services = (sv.data ?? []).where((s) => inRange(s.timestamp)).toList();
                    final expenses = (ex.data ?? []).where((e) => inRange(e.timestamp)).toList();

                    final salesTotal    = sales.fold<double>(0, (s, e) => s + (e.isGstBill ? e.taxableAmount : e.totalPrice));
                    final serviceTotal  = services.fold<double>(0, (s, e) {
                      final double effectiveAdvance = e.advanceAmount.clamp(0.0, e.totalAmount);
                      return s + (e.isGstBill && e.totalAmount > 0 ? (effectiveAdvance * (e.taxableAmount / e.totalAmount)) : effectiveAdvance);
                    });
                    final expTotal      = expenses.where((e) => e.category != 'Specialist Fee' && e.category != 'Parts Cost').fold<double>(0, (s, e) => s + e.amount);
                    final serviceExpenses = services.fold<double>(0, (sum, s) => sum + s.partsCost + s.technicianFee);
                    final gstCollected  = sales.fold<double>(0, (sum, s) => sum + (s.isGstBill ? (s.cgstAmount + s.sgstAmount) : 0.0)) +
                                          services.fold<double>(0, (sum, s) {
                                            final double effectiveAdvance = s.advanceAmount.clamp(0.0, s.totalAmount);
                                            return sum + (s.isGstBill && s.totalAmount > 0 ? (effectiveAdvance * ((s.cgstAmount + s.sgstAmount) / s.totalAmount)) : 0.0);
                                          });
                    // COGS = sum of (costPrice × qty) for every item in every sale this period
                    final cogs          = sales.fold<double>(0, (sum, s) =>
                        sum + s.items.fold<double>(0, (iSum, item) => iSum + (item.costPrice * item.quantity)));
                    final revenue       = salesTotal + serviceTotal;
                    // True net profit: gross profit on products + service income - operational expenses - service expenses
                    final grossProfit   = salesTotal - cogs; // profit from product sales after cost
                    final netProfit     = grossProfit + serviceTotal - expTotal - serviceExpenses;
                    final cashCollected = sales.fold<double>(0, (sum, s) => sum + s.cashAmount) +
                                          services.fold<double>(0, (sum, s) => sum + s.cashAmount);
                    final onlineCollected = sales.fold<double>(0, (sum, s) => sum + s.onlineAmount) +
                                            services.fold<double>(0, (sum, s) => sum + s.onlineAmount);
                    final double onlineSpentOnExpenses =
                        expenses.where((e) => e.paymentMode == 'Online').fold<double>(0, (sum, e) => sum + e.amount);

                    if (sales.isEmpty && services.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.accentForest.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.bar_chart_rounded,
                                  size: 56,
                                  color: AppTheme.accentForest.withValues(alpha: 0.35)),
                            ),
                            const SizedBox(height: 20),
                            Text('No records for $periodLabel',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.charcoalBlack.withValues(alpha: 0.45))),
                            const SizedBox(height: 6),
                            Text('Try a different period',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.graphiteGray.withValues(alpha: 0.5))),
                          ],
                        ),
                      );
                    }

                    final giftExpenses = expenses
                        .where((e) => e.category == 'Complementary Gift')
                        .fold<double>(0.0, (sum, e) => sum + e.amount);

                    final double cashSpentOnExpenses =
                        expenses.where((e) => e.paymentMode == 'Cash').fold<double>(0, (sum, e) => sum + e.amount);

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        // ── Performance card ────────────────────────────────────
                        _PerformanceCard(
                          revenue: revenue,
                          netProfit: netProfit,
                          grossProfit: grossProfit,
                          cogs: cogs,
                          expenses: expTotal,
                          giftExpenses: giftExpenses,
                          gstCollected: gstCollected,
                          serviceExpenses: serviceExpenses,
                          salesCount: sales.length,
                          serviceCount: services.length,
                          periodLabel: periodLabel,
                          filterName: filterName,
                          cashCollected: cashCollected,
                          onlineCollected: onlineCollected,
                          openingDrawerAmount: openingDrawerAmount,
                          cashSpentOnExpenses: cashSpentOnExpenses,
                          onlineSpentOnExpenses: onlineSpentOnExpenses,
                          onPrint: () => _exportPdf(context, sales, services, expenses, netProfit, cogs, openingDrawerAmount),
                          onShare: () => _sharePdf(context, sales, services, expenses, netProfit, cogs, openingDrawerAmount),
                        ),

                        const SizedBox(height: 16),

                        // ── Records list ──────────────────────────────────────
                        if (sales.isNotEmpty) ...[
                          _SectionTitle(
                              title: 'Sales Records',
                              icon: Icons.shopping_bag_outlined,
                              color: AppTheme.accentForest,
                              count: sales.length),
                          const SizedBox(height: 8),
                          ...sales.map((s) => _SaleCard(sale: s)),
                        ],
                        if (services.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _SectionTitle(
                              title: 'Service Records',
                              icon: Icons.build_outlined,
                              color: const Color(0xFFE65100),
                              count: services.length),
                          const SizedBox(height: 8),
                          ...services.map((s) => _ServiceCard(service: s)),
                        ],
                        if (expenses.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _SectionTitle(
                              title: 'Expense Records',
                              icon: Icons.payments_outlined,
                              color: const Color(0xFFD32F2F),
                              count: expenses.length),
                          const SizedBox(height: 8),
                          ...expenses.map((e) => _ExpenseCard(expense: e)),
                        ],
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}


// ─────────────────────────── Performance Card ─────────────────────────────────

class _PerformanceCard extends StatelessWidget {
  final double revenue, netProfit, grossProfit, cogs, expenses, giftExpenses, gstCollected, serviceExpenses, cashCollected, onlineCollected, openingDrawerAmount, cashSpentOnExpenses, onlineSpentOnExpenses;
  final int salesCount, serviceCount;
  final String periodLabel, filterName;
  final VoidCallback onPrint, onShare;

  const _PerformanceCard({
    required this.revenue,
    required this.netProfit,
    required this.grossProfit,
    required this.cogs,
    required this.expenses,
    required this.giftExpenses,
    required this.gstCollected,
    required this.serviceExpenses,
    required this.salesCount,
    required this.serviceCount,
    required this.periodLabel,
    required this.filterName,
    required this.onPrint,
    required this.onShare,
    required this.cashCollected,
    required this.onlineCollected,
    required this.onlineSpentOnExpenses,
    this.openingDrawerAmount = 0.0,
    this.cashSpentOnExpenses = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final double salesRevenue = grossProfit + cogs;
    final double serviceRevenue = revenue - salesRevenue;
    final double salesProfit = grossProfit;
    final double serviceProfit = serviceRevenue - serviceExpenses;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.accentForest, Color(0xFF1E4D35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppTheme.accentForest.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$filterName PERFORMANCE',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 2),
                  Text(periodLabel,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11)),
                ]),
                const Spacer(),
                // Action buttons
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Share PDF',
                        icon: const Icon(Icons.share_outlined,
                            color: Colors.white70, size: 18),
                        onPressed: onShare,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        padding: const EdgeInsets.all(8),
                      ),
                      Container(
                          width: 1,
                          height: 20,
                          color: Colors.white24),
                      IconButton(
                        tooltip: 'Print PDF',
                        icon: const Icon(Icons.print_outlined,
                            color: Colors.white70, size: 18),
                        onPressed: onPrint,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        padding: const EdgeInsets.all(8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Main stats
            Row(
              children: [
                _CardStat(
                    label: 'Revenue',
                    value: '\u20B9${revenue.toStringAsFixed(0)}',
                    color: const Color(0xFF81D4FA)),
                _CardDivider(),
                _CardStat(
                    label: 'Op Expenses',
                    value: '\u20B9${expenses.toStringAsFixed(0)}',
                    color: const Color(0xFFEF9A9A)),
                _CardDivider(),
                _CardStat(
                    label: 'Net Profit',
                    value:
                        '${netProfit >= 0 ? '+' : ''}\u20B9${netProfit.toStringAsFixed(0)}',
                    color: netProfit >= 0
                        ? const Color(0xFFA5D6A7)
                        : const Color(0xFFEF9A9A)),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),

            // Sales breakdown
            const Text(
              'PRODUCT SALES BREAKDOWN',
              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            const SizedBox(height: 6),
            _buildDetailRow('Sales Revenue', '₹${salesRevenue.toStringAsFixed(0)}', const Color(0xFF81D4FA)),
            _buildDetailRow('Product Cost (COGS)', '- ₹${cogs.toStringAsFixed(0)}', const Color(0xFFEF9A9A)),
            _buildDetailRow('Sales Net Profit', salesProfit >= 0 ? '+₹${salesProfit.toStringAsFixed(0)}' : '-₹${salesProfit.abs().toStringAsFixed(0)}', 
                salesProfit >= 0 ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A), isBold: true),

            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),

            // Service breakdown
            const Text(
              'PAYMENT MODE BREAKDOWN',
              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            const SizedBox(height: 6),
            if (openingDrawerAmount > 0)
              _buildDetailRow('Opening Drawer Cash', '₹${openingDrawerAmount.toStringAsFixed(0)}', const Color(0xFFFFE082)),
            _buildDetailRow('Cash Collected', '₹${cashCollected.toStringAsFixed(0)}', const Color(0xFFA5D6A7)),
            if (cashSpentOnExpenses > 0)
              _buildDetailRow('Cash Spent on Expenses', '- ₹${cashSpentOnExpenses.toStringAsFixed(0)}', const Color(0xFFEF9A9A)),
            _buildDetailRow('Total Drawer Cash', '₹${(openingDrawerAmount + cashCollected - cashSpentOnExpenses).toStringAsFixed(0)}', const Color(0xFFA5D6A7), isBold: true),
            const SizedBox(height: 8),
            _buildDetailRow('Online Collected', '₹${onlineCollected.toStringAsFixed(0)}', const Color(0xFF81D4FA)),
            if (onlineSpentOnExpenses > 0)
              _buildDetailRow('Online Spent on Expenses', '- ₹${onlineSpentOnExpenses.toStringAsFixed(0)}', const Color(0xFFEF9A9A)),
            _buildDetailRow('Total Net Online', '₹${(onlineCollected - onlineSpentOnExpenses).toStringAsFixed(0)}', const Color(0xFF81D4FA), isBold: true),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            
            // Operational Expenses / Gift Expenses breakdown
            const Text(
              'OPERATIONAL EXPENSES BREAKDOWN',
              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            const SizedBox(height: 6),
            _buildDetailRow('General Shop Expenses', '₹${(expenses - giftExpenses).toStringAsFixed(0)}', const Color(0xFFEF9A9A)),
            _buildDetailRow('Complementary Gift Expenses', '₹${giftExpenses.toStringAsFixed(0)}', const Color(0xFFFFB74D)),
            _buildDetailRow('Total Operational Expenses', '₹${expenses.toStringAsFixed(0)}', const Color(0xFFEF9A9A), isBold: true),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            const Text(
              'MOBILE SERVICES BREAKDOWN',
              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            const SizedBox(height: 6),
            _buildDetailRow('Service Revenue', '₹${serviceRevenue.toStringAsFixed(0)}', const Color(0xFF81D4FA)),
            _buildDetailRow('Repair Cost (Parts & Tech)', '- ₹${serviceExpenses.toStringAsFixed(0)}', const Color(0xFFEF9A9A)),
            _buildDetailRow('Service Net Profit', serviceProfit >= 0 ? '+₹${serviceProfit.toStringAsFixed(0)}' : '-₹${serviceProfit.abs().toStringAsFixed(0)}', 
                serviceProfit >= 0 ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A), isBold: true),

            if (gstCollected > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('GST Collected (CGST + SGST)',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
                    Text('\u20B9${gstCollected.toStringAsFixed(0)}',
                        style: const TextStyle(color: Color(0xFF81D4FA), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Sub-counts
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MiniStat(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Sales',
                      value: '$salesCount'),
                  Container(
                      width: 1, height: 24, color: Colors.white24),
                  _MiniStat(
                      icon: Icons.build_outlined,
                      label: 'Services',
                      value: '$serviceCount'),
                  Container(
                      width: 1, height: 24, color: Colors.white24),
                  _MiniStat(
                      icon: Icons.trending_up_rounded,
                      label: 'Margin',
                      value: revenue > 0
                          ? '${((netProfit / revenue) * 100).toStringAsFixed(1)}%'
                          : '—'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _CardStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11)),
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: Colors.white24);
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _MiniStat(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Icon(icon, color: Colors.white60, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11)),
        ]),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ],
    );
  }
}

// ─────────────────────────── Section Title ─────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int count;

  const _SectionTitle(
      {required this.title,
      required this.icon,
      required this.color,
      required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 7),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.charcoalBlack)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Text('$count',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Divider(
                color: color.withValues(alpha: 0.2), thickness: 1)),
      ],
    );
  }
}

// ─────────────────────────── Sale Card ────────────────────────────────────────

class _SaleCard extends StatelessWidget {
  final SaleModel sale;
  const _SaleCard({required this.sale});

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primaryIvory,
        title: const Text('Delete Sale?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This will permanently remove this sale record and update reporting metrics. Stock WILL be restored automatically.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Cancel', style: TextStyle(color: AppTheme.graphiteGray))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              SoundHelper.playSuccess();
              DatabaseService().deleteSale(sale.id).catchError((e) {
                debugPrint('Error deleting sale in background: $e');
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale deleted')));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = sale.items.length == 1
        ? sale.items.first.productName
        : '${sale.items.length} Items';
    return RepaintBoundary(child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.secondaryIvory,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentForest.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: AppTheme.accentForest, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.charcoalBlack)),
                  const SizedBox(height: 3),
                  Text(
                      '${sale.customerName}  ·  ${sale.customerPhone}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.graphiteGray)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: sale.items.map((item) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentForest.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item.productName} x${item.quantity}  \u20B9${(item.price * item.quantity).toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.accentForest,
                            fontWeight: FontWeight.w500),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.access_time_outlined,
                        size: 11, color: AppTheme.graphiteGray),
                    const SizedBox(width: 4),
                    Text(
                        DateFormat('dd MMM yyyy, hh:mm a')
                            .format(sale.timestamp),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.graphiteGray)),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.graphiteGray, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  onSelected: (val) {
                    if (val == 'edit') {
                      showDialog(context: context, builder: (_) => EditSaleItemsDialog(sale: sale));
                    } else if (val == 'delete') {
                      _confirmDelete(context);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit', 
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: AppTheme.accentForest),
                          SizedBox(width: 10),
                          Text('Edit Prices', style: TextStyle(fontSize: 13)),
                        ],
                      )
                    ),
                    const PopupMenuItem(
                      value: 'delete', 
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Delete Sale', style: TextStyle(fontSize: 13, color: Colors.red)),
                        ],
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '\u20B9${sale.totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.accentForest),
                ),
                if (sale.isGstBill) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'GST',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ));
  }
}

// ─────────────────────────── Service Card ─────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final ServiceModel service;
  const _ServiceCard({required this.service});

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primaryIvory,
        title: const Text('Delete Service Job?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently remove this service record, its pending specialist fee request, and any associated parts cost/specialist fee expenses. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Cancel', style: TextStyle(color: AppTheme.graphiteGray))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              SoundHelper.playSuccess();
              DatabaseService().deleteService(service.id, service: service).catchError((e) {
                debugPrint('Error deleting service job in background: $e');
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Service job and associated costs deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = service.status.toLowerCase() == 'completed';
    final statusColor = isCompleted
        ? const Color(0xFF2E7D32)
        : const Color(0xFFE65100);

    return RepaintBoundary(child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.secondaryIvory,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.construction_rounded,
                  color: Color(0xFFE65100), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(service.mobileModel,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.charcoalBlack)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(service.status,
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11)),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppTheme.graphiteGray, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      onSelected: (val) {
                        if (val == 'delete') {
                          _confirmDelete(context);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'delete', 
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              SizedBox(width: 10),
                              Text('Delete Service', style: TextStyle(fontSize: 13, color: Colors.red)),
                            ],
                          )
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                      '${service.customerName}  ·  ${service.customerPhone}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.graphiteGray)),
                  if (service.complementaryItems.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: service.complementaryItems.map((item) {
                        final name = item['productName'] as String? ?? 'Item';
                        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade200, width: 0.5),
                          ),
                          child: Text(
                            '🎁 $name x$qty (FREE)',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(children: [
                    _PillInfo(
                        label: 'Paid',
                        value: '\u20B9${service.advanceAmount.toStringAsFixed(0)}',
                        color: const Color(0xFF2E7D32)),
                    const SizedBox(width: 8),
                    _PillInfo(
                        label: 'Remaining',
                        value:
                            '\u20B9${service.remainingAmount.toStringAsFixed(0)}',
                        color: service.remainingAmount > 0
                            ? const Color(0xFFD32F2F)
                            : const Color(0xFF2E7D32)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.access_time_outlined,
                        size: 11, color: AppTheme.graphiteGray),
                    const SizedBox(width: 4),
                    Text(
                        DateFormat('dd MMM yyyy, hh:mm a')
                            .format(service.timestamp),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.graphiteGray)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

class _PillInfo extends StatelessWidget {
  final String label, value;
  final Color color;
  const _PillInfo(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: $value',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────── Expense Card ─────────────────────────────────────

class _ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.secondaryIvory,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.money_off_csred_rounded,
                  color: Color(0xFFD32F2F), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.category,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.charcoalBlack)),
                  if (expense.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(expense.description,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.graphiteGray,
                            height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.access_time_outlined,
                        size: 11, color: AppTheme.graphiteGray),
                    const SizedBox(width: 4),
                    Text(
                        DateFormat('dd MMM yyyy, hh:mm a')
                            .format(expense.timestamp),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.graphiteGray)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: expense.paymentMode == 'Cash' ? Colors.green.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        expense.paymentMode.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: expense.paymentMode == 'Cash' ? Colors.green.shade700 : Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('\u20B9${expense.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFFD32F2F))),
          ],
        ),
      ),
    ));
  }
}

// ─────────────────────────── Month Picker ─────────────────────────────────────

class _MonthPickerDialog extends StatefulWidget {
  final DateTime initial;
  final void Function(DateTime) onSelected;

  const _MonthPickerDialog(
      {required this.initial, required this.onSelected});

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year, _month;
  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  @override
  void initState() {
    super.initState();
    _year  = widget.initial.year;
    _month = widget.initial.month;
  }

  bool _isFuture(int m, int y) {
    final now = DateTime.now();
    return y > now.year || (y == now.year && m > now.month);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.primaryIvory,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Month',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoalBlack)),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left_rounded,
                      color: AppTheme.accentForest)),
              Text('$_year',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentForest)),
              IconButton(
                  onPressed: _year >= DateTime.now().year
                      ? null
                      : () => setState(() => _year++),
                  icon: Icon(Icons.chevron_right_rounded,
                      color: _year >= DateTime.now().year
                          ? Colors.grey.shade400
                          : AppTheme.accentForest)),
            ]),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, childAspectRatio: 1.6),
              itemCount: 12,
              itemBuilder: (_, i) {
                final m = i + 1;
                final disabled = _isFuture(m, _year);
                final selected = m == _month;
                return GestureDetector(
                  onTap: disabled ? null : () => setState(() => _month = m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.accentForest
                          : AppTheme.accentForest.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(_months[i],
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: disabled
                                ? Colors.grey.shade400
                                : selected
                                    ? Colors.white
                                    : AppTheme.accentForest)),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppTheme.graphiteGray))),
              const SizedBox(width: 8),
              ElevatedButton(
                  onPressed: () {
                    widget.onSelected(DateTime(_year, _month));
                    Navigator.pop(context);
                  },
                  child: const Text('Confirm')),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Edit Sale Items Dialog ───────────────────────────

class EditSaleItemsDialog extends StatefulWidget {
  final SaleModel sale;
  const EditSaleItemsDialog({required this.sale});

  @override
  State<EditSaleItemsDialog> createState() => _EditSaleItemsDialogState();
}

class _EditSaleItemsDialogState extends State<EditSaleItemsDialog> {
  late List<CartItem> _items;
  late List<TextEditingController> _controllers;
  late List<TextEditingController> _costControllers;
  late String _paymentMode;
  late TextEditingController _cashController;
  late TextEditingController _onlineController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _paymentMode = widget.sale.paymentMode;
    _cashController = TextEditingController(
        text: widget.sale.cashAmount > 0 ? widget.sale.cashAmount.toStringAsFixed(0) : '0');
    _onlineController = TextEditingController(
        text: widget.sale.onlineAmount > 0 ? widget.sale.onlineAmount.toStringAsFixed(0) : '0');
    _items = List.from(widget.sale.items);
    _controllers = _items.map((item) => 
      TextEditingController(text: (item.price * item.quantity).toStringAsFixed(0))
    ).toList();
    _costControllers = _items.map((item) => 
      TextEditingController(text: item.costPrice.toStringAsFixed(0))
    ).toList();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _onlineController.dispose();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var c in _costControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save an empty bill. Please use "Delete Sale" instead.'))
      );
      return;
    }

    try {
      List<CartItem> updatedItems = [];
      double newTotal = 0;

      for (int i = 0; i < _items.length; i++) {
        final newTotalPrice = double.tryParse(_controllers[i].text) ?? (_items[i].price * _items[i].quantity);
        final newUnitPrice = newTotalPrice / _items[i].quantity;
        final newCostPrice = double.tryParse(_costControllers[i].text) ?? _items[i].costPrice;
        updatedItems.add(_items[i].copyWith(price: newUnitPrice, costPrice: newCostPrice));
        newTotal += newTotalPrice;

        // If the cost price is positive and has changed, propagate it back to the product catalog (stock)
        if (newCostPrice > 0.0 && newCostPrice != _items[i].costPrice) {
          DatabaseService().updateProductCost(_items[i].productId, newCostPrice).catchError((e) {
            debugPrint('Error updating product cost: $e');
          });
        }
      }

      double cgstAmount = 0.0;
      double sgstAmount = 0.0;
      double taxableAmount = newTotal;

      if (widget.sale.isGstBill) {
        final cgstRate = (widget.sale.taxableAmount > 0) ? (widget.sale.cgstAmount / widget.sale.taxableAmount * 100) : 9.0;
        final sgstRate = (widget.sale.taxableAmount > 0) ? (widget.sale.sgstAmount / widget.sale.taxableAmount * 100) : 9.0;
        taxableAmount = newTotal / (1 + (cgstRate + sgstRate) / 100);
        cgstAmount = taxableAmount * cgstRate / 100;
        sgstAmount = taxableAmount * sgstRate / 100;
      }

      double cashAmt = 0.0;
      double onlineAmt = 0.0;

      if (_paymentMode == 'Cash') {
        cashAmt = newTotal;
        onlineAmt = 0.0;
      } else if (_paymentMode == 'Online') {
        cashAmt = 0.0;
        onlineAmt = newTotal;
      } else if (_paymentMode == 'Split') {
        cashAmt = double.tryParse(_cashController.text) ?? 0.0;
        onlineAmt = double.tryParse(_onlineController.text) ?? 0.0;
        if ((cashAmt + onlineAmt - newTotal).abs() > 0.01) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Split amounts (₹${(cashAmt + onlineAmt).toStringAsFixed(0)}) must sum to total bill amount (₹${newTotal.toStringAsFixed(0)})!'),
              backgroundColor: Colors.red,
            )
          );
          return;
        }
      }

      final updatedSale = widget.sale.copyWith(
        items: updatedItems,
        totalPrice: newTotal,
        taxableAmount: taxableAmount,
        cgstAmount: cgstAmount,
        sgstAmount: sgstAmount,
        paymentMode: _paymentMode,
        cashAmount: cashAmt,
        onlineAmount: onlineAmt,
      );

      // Play success sound immediately
      SoundHelper.playSuccess();

      // Update in background
      DatabaseService().updateSale(updatedSale).catchError((e) {
        debugPrint('Error updating sale in background: $e');
      });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.primaryIvory,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Sold Prices & Payment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.charcoalBlack)),
            const SizedBox(height: 8),
            Text('Update prices for bill #${widget.sale.id.substring(0, 8)}...',
                style: const TextStyle(fontSize: 12, color: AppTheme.graphiteGray)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (a, b) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final item = _items[i];
                  return Card(
                    elevation: 0,
                    color: AppTheme.accentForest.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.charcoalBlack,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _items.removeAt(i);
                                    _controllers[i].dispose();
                                    _controllers.removeAt(i);
                                    _costControllers[i].dispose();
                                    _costControllers.removeAt(i);
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  if (item.quantity > 1) {
                                    final singleUnitPrice = (double.tryParse(_controllers[i].text) ?? item.price) / item.quantity;
                                    setState(() {
                                      _items[i] = item.copyWith(quantity: item.quantity - 1);
                                      _controllers[i].text = (singleUnitPrice * _items[i].quantity).toStringAsFixed(0);
                                    });
                                  }
                                },
                                child: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              InkWell(
                                onTap: () {
                                  final singleUnitPrice = (double.tryParse(_controllers[i].text) ?? item.price) / item.quantity;
                                  setState(() {
                                    _items[i] = item.copyWith(quantity: item.quantity + 1);
                                    _controllers[i].text = (singleUnitPrice * _items[i].quantity).toStringAsFixed(0);
                                  });
                                },
                                child: const Icon(Icons.add_circle_outline, color: Colors.green, size: 18),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: _controllers[i],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (val) => setState(() {}),
                                  decoration: InputDecoration(
                                    prefixText: '₹',
                                    labelText: 'Price',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: _costControllers[i],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (val) => setState(() {}),
                                  decoration: InputDecoration(
                                    prefixText: '₹',
                                    labelText: 'Cost',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: AppTheme.accentForest.withValues(alpha: 0.04),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payment Mode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoalBlack)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.accentForest.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _paymentMode,
                              isDense: true,
                              items: ['Cash', 'Online', 'Split'].map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _paymentMode = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_paymentMode == 'Split') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _cashController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixText: '₹',
                                labelText: 'Cash Paid',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _onlineController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixText: '₹',
                                labelText: 'Online Paid',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Updated Grand Total:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoalBlack),
                  ),
                  FutureBuilder<double>(
                    future: Future.value(() {
                      double currentGrandTotal = 0;
                      for (int i = 0; i < _items.length; i++) {
                        final val = double.tryParse(_controllers[i].text) ?? (_items[i].price * _items[i].quantity);
                        currentGrandTotal += val;
                      }
                      return currentGrandTotal;
                    }()),
                    builder: (context, snapshot) {
                      final total = snapshot.data ?? 0.0;
                      return Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.accentForest),
                      );
                    }
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.graphiteGray)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
