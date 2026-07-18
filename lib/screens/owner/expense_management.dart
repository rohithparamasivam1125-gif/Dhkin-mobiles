import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/expense_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/shop_helper.dart';
import '../../utils/sound_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'expense_report_screen.dart';

enum ExpenseFilter { today, weekly, monthly }

class ExpenseManagementScreen extends StatefulWidget {
  final String shopId;

  const ExpenseManagementScreen({super.key, required this.shopId});

  @override
  State<ExpenseManagementScreen> createState() =>
      _ExpenseManagementScreenState();
}

class _ExpenseManagementScreenState extends State<ExpenseManagementScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  late TabController _tabController;

  // Today
  DateTime _selectedDay = DateTime.now();

  // Weekly – start of the selected week (Monday)
  late DateTime _weekStart;

  // Monthly
  late DateTime _selectedMonth; // year + month only

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));

    final now = DateTime.now();
    _weekStart = _startOfWeek(now);
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  DateTime _startOfWeek(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  DateTime _endOfWeek(DateTime start) => start.add(const Duration(days: 6));

  List<ExpenseModel> _filterExpenses(List<ExpenseModel> all) {
    switch (_tabController.index) {
      case 0: // Today
        return all.where((e) {
          return e.timestamp.year == _selectedDay.year &&
              e.timestamp.month == _selectedDay.month &&
              e.timestamp.day == _selectedDay.day;
        }).toList();

      case 1: // Weekly
        final end = _endOfWeek(_weekStart);
        return all.where((e) {
          final d = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
          return !d.isBefore(_weekStart) &&
              !d.isAfter(DateTime(end.year, end.month, end.day));
        }).toList();

      case 2: // Monthly
        return all.where((e) {
          return e.timestamp.year == _selectedMonth.year &&
              e.timestamp.month == _selectedMonth.month;
        }).toList();

      default:
        return all;
    }
  }

  // ── Period label (for summary card & report) ─────────────────────────────

  String get _periodLabel {
    switch (_tabController.index) {
      case 0:
        return DateFormat('EEEE, dd MMM yyyy').format(_selectedDay);
      case 1:
        final end = _endOfWeek(_weekStart);
        return '${DateFormat('dd MMM').format(_weekStart)} – ${DateFormat('dd MMM yyyy').format(end)}';
      case 2:
        return DateFormat('MMMM yyyy').format(_selectedMonth);
      default:
        return '';
    }
  }

  // ── Picker actions ──────────────────────────────────────────────────────

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: _datePickerTheme,
    );
    if (picked != null) setState(() => _selectedDay = picked);
  }

  void _stepWeek(int delta) {
    setState(() => _weekStart = _weekStart.add(Duration(days: 7 * delta)));
  }

  Future<void> _pickMonth() async {
    DateTime temp = _selectedMonth;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPickerDialog(initial: temp),
    );
    if (picked != null) setState(() => _selectedMonth = picked);
  }

  Widget _datePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppTheme.accentForest,
          onPrimary: Colors.white,
          surface: AppTheme.secondaryIvory,
        ),
      ),
      child: child!,
    );
  }

  // ── Period selector widget ──────────────────────────────────────────────

  Widget _buildPeriodSelector() {
    switch (_tabController.index) {
      case 0:
        return _PeriodChip(
          label: DateFormat('dd MMM yyyy').format(_selectedDay),
          icon: Icons.calendar_today_outlined,
          onTap: _pickDay,
        );

      case 1:
        final end = _endOfWeek(_weekStart);
        final isCurrentWeek =
            _weekStart.isAtSameMomentAs(_startOfWeek(DateTime.now()));
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NavButton(
              icon: Icons.chevron_left_rounded,
              onTap: () => _stepWeek(-1),
            ),
            const SizedBox(width: 8),
            _PeriodChip(
              label:
                  '${DateFormat('dd MMM').format(_weekStart)} – ${DateFormat('dd MMM').format(end)}',
              icon: Icons.date_range_outlined,
              onTap: () {}, // tapping the chip does nothing; use arrows
            ),
            const SizedBox(width: 8),
            _NavButton(
              icon: Icons.chevron_right_rounded,
              onTap: isCurrentWeek ? null : () => _stepWeek(1),
            ),
          ],
        );

      case 2:
        return _PeriodChip(
          label: DateFormat('MMMM yyyy').format(_selectedMonth),
          icon: Icons.calendar_month_outlined,
          onTap: _pickMonth,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ── Add Expense dialog ──────────────────────────────────────────────────

  void _showAddExpenseDialog() {
    final categoryController = TextEditingController();
    final amountController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now();
    String paymentMode = 'Cash';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppTheme.primaryIvory,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentForest.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_circle_outline,
                          color: AppTheme.accentForest, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Add Expense',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoalBlack),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Category'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: categoryController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Rent, Electricity, Supplies',
                          prefixIcon:
                              Icon(Icons.category_outlined, size: 20),
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      _fieldLabel('Amount (₹)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: amountController,
                        style: const TextStyle(fontSize: 16, color: AppTheme.charcoalBlack),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          prefixText: '₹ ',
                          prefixStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentForest,
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) =>
                            (v == null || double.tryParse(v) == null)
                                ? 'Enter valid amount'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      _fieldLabel('Payment Mode'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: paymentMode,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.payment_outlined, size: 20),
                        ),
                        items: ['Cash', 'Online']
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => paymentMode = v);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      _fieldLabel('Description (Optional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: descController,
                        decoration: const InputDecoration(
                          hintText: 'Add a note...',
                          prefixIcon: Icon(Icons.notes_outlined, size: 20),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      _fieldLabel('Date'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            builder: _datePickerTheme,
                          );
                          if (p != null) {
                            setDialogState(() => selectedDate = p);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.accentForest
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 18,
                                  color: AppTheme.accentForest
                                      .withValues(alpha: 0.7)),
                              const SizedBox(width: 10),
                              Text(
                                DateFormat('dd MMM yyyy')
                                    .format(selectedDate),
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.charcoalBlack),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_drop_down,
                                  color: AppTheme.graphiteGray),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel',
                          style:
                              TextStyle(color: AppTheme.graphiteGray)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          final expense = ExpenseModel(
                            id: const Uuid().v4(),
                            shopId: widget.shopId,
                            category: categoryController.text.trim(),
                            amount:
                                double.parse(amountController.text),
                            description: descController.text.trim(),
                            timestamp: selectedDate,
                            paymentMode: paymentMode,
                          );
                          _db.addExpense(expense);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Add Expense'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.graphiteGray,
          letterSpacing: 0.5,
        ),
      );

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryIvory,
      appBar: AppBar(
        title: Text('Expenses — ${ShopHelper.getDisplayName(widget.shopId)}'),
        actions: [
          StreamBuilder<List<ExpenseModel>>(
            stream: _db.getExpenses(widget.shopId),
            builder: (context, snapshot) {
              final expenses = snapshot.data ?? [];
              return IconButton(
                tooltip: 'Expense Report',
                icon: const Icon(Icons.bar_chart_rounded),
                onPressed: () {
                  final filtered = _filterExpenses(expenses);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExpenseReportScreen(
                        shopId: widget.shopId,
                        expenses: filtered,
                        periodLabel: _periodLabel,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              color: AppTheme.accentForest.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              labelColor: AppTheme.accentForest,
              unselectedLabelColor: AppTheme.primaryIvory,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Today'),
                Tab(text: 'Weekly'),
                Tab(text: 'Monthly'),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<ExpenseModel>>(
        stream: _db.getExpenses(widget.shopId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final filtered = _filterExpenses(snapshot.data!);
          final total =
              filtered.fold<double>(0, (s, e) => s + e.amount);

          return Column(
            children: [
              // Period selector
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _buildPeriodSelector(),
              ),

              // Summary card
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: _SummaryCard(
                  total: total,
                  count: filtered.length,
                  periodLabel: _periodLabel,
                ),
              ),

              // List
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(tabIndex: _tabController.index)
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final exp = filtered[i];
                          return _ExpenseCard(
                            expense: exp,
                            onDelete: () => _db.deleteExpense(exp.id),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        backgroundColor: AppTheme.accentForest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ─────────────────────── Period Chip ────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PeriodChip(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.accentForest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: AppTheme.accentForest.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more_rounded,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: onTap != null
              ? AppTheme.accentForest
              : AppTheme.accentForest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            color: onTap != null ? Colors.white : Colors.white38, size: 20),
      ),
    );
  }
}

// ─────────────────────── Summary Card ───────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double total;
  final int count;
  final String periodLabel;

  const _SummaryCard(
      {required this.total,
      required this.count,
      required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.accentForest, Color(0xFF1E4D35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppTheme.accentForest.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(periodLabel,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4)),
                const SizedBox(height: 6),
                Text('₹${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    '$count ${count == 1 ? 'entry' : 'entries'} recorded',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Expense Card ───────────────────────────────────────

class _ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onDelete;

  const _ExpenseCard({required this.expense, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.money_off_csred_rounded,
                    color: Color(0xFFD32F2F), size: 22),
              ),
            ),
            const SizedBox(width: 14),

            // Text section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(expense.category,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.charcoalBlack)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: expense.paymentMode == 'Cash' ? Colors.green.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
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
                    ],
                  ),
                  if (expense.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(expense.description,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.graphiteGray,
                            height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 11,
                        color: AppTheme.graphiteGray
                            .withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                        DateFormat('dd MMM yyyy')
                            .format(expense.timestamp),
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.graphiteGray
                                .withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500)),
                  ]),
                ],
              ),
            ),

            // Amount + delete
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('₹${expense.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD32F2F),
                        fontSize: 16)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _confirmDelete(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.grey, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Expense?'),
        content: Text(
            'Remove "${expense.category}" (₹${expense.amount.toStringAsFixed(0)}) from records?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              SoundHelper.playSuccess();
              Navigator.pop(context);
              onDelete();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Empty State ────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final int tabIndex;

  const _EmptyState({required this.tabIndex});

  String get _message {
    switch (tabIndex) {
      case 0:
        return 'No expenses on this day';
      case 1:
        return 'No expenses for this week';
      case 2:
        return 'No expenses for this month';
      default:
        return 'No expenses found';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.accentForest.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_outlined,
                size: 56,
                color: AppTheme.accentForest.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          Text(_message,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.charcoalBlack.withValues(alpha: 0.5))),
          const SizedBox(height: 8),
          Text('Tap + to record a new expense',
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.graphiteGray.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

// ─────────────────────── Month Picker Dialog ─────────────────────────────────

class _MonthPickerDialog extends StatefulWidget {
  final DateTime initial;

  const _MonthPickerDialog({required this.initial});

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;
  late int _month;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
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
            // Title
            const Text('Select Month',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoalBlack)),
            const SizedBox(height: 16),

            // Year row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: AppTheme.accentForest,
                ),
                Text('$_year',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentForest)),
                IconButton(
                  onPressed: _year >= DateTime.now().year
                      ? null
                      : () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: _year >= DateTime.now().year
                      ? Colors.grey.shade400
                      : AppTheme.accentForest,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Month grid
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
                          : AppTheme.accentForest.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _months[i],
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: disabled
                              ? Colors.grey.shade400
                              : selected
                                  ? Colors.white
                                  : AppTheme.accentForest),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppTheme.graphiteGray)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(context, DateTime(_year, _month)),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
