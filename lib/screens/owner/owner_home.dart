import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/sale_model.dart';
import '../../models/product_model.dart';
import '../../models/service_model.dart';
import '../../models/specialist_fee_request_model.dart';
import '../../models/gst_settings_model.dart';
import '../../utils/app_theme.dart';
import 'employee_management.dart';
import 'stock_management.dart';
import 'sales_reports.dart';
import '../sales/sale_bill_screen.dart';
import '../services/service_management.dart';
import '../../services/notification_service.dart';
import '../login_screen.dart';
import 'expense_management.dart';
import 'security_settings.dart';
import 'gst_settings_screen.dart';
import 'dealer_claims.dart';
import 'product_order_list_screen.dart';
import '../../models/expense_model.dart';
import '../../models/replacement_model.dart';
import '../../models/category_model.dart';
import '../sales/warranty_search.dart';
import '../stock_search_screen.dart';
import 'enquiry_management_screen.dart';
import 'customer_contacts_screen.dart';
import '../../utils/shop_helper.dart';
import '../../utils/sound_helper.dart';
import '../../widgets/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, DateTime> _selectedSalesDates = {};
  final Map<String, DateTime> _selectedServicesDates = {};

  final Map<String, String> _profitFilterMode = {};
  final Map<String, DateTimeRange> _profitCustomRange = {};

  // ── Real-time state variables (populated by initState subscriptions) ──────
  final Map<String, List<SaleModel>> _salesByShop = {};
  final Map<String, List<ServiceModel>> _servicesByShop = {};
  final Map<String, List<ExpenseModel>> _expensesByShop = {};
  final Map<String, List<ProductModel>> _productsByShop = {};
  final Map<String, List<SpecialistFeeRequestModel>> _feeRequestsByShop = {};
  final Map<String, List<ReplacementModel>> _replacementsByShop = {};

  // One subscription per (shopId × dataType), all cancelled in dispose
  final List<StreamSubscription<dynamic>> _subs = [];

  Stream<List<CategoryModel>>? _categoriesStream;

  Stream<List<CategoryModel>> _getCategoriesStream() {
    _categoriesStream ??= DatabaseService().getCategories();
    return _categoriesStream!;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initDataStreams();
    _setupNotifications();
    _cleanupOrphanedSpecialistRequests();
    _checkForDeveloperUpdate();
  }

  void _checkForDeveloperUpdate() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_config')
          .doc('app_status')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final int latestVersionCode = data['latestVersionCode'] ?? 1;
        final String latestVersionName = data['latestVersionName'] ?? '1.0.1';
        final String updateUrl = data['updateUrl'] ?? 'https://github.com/rohithparamasivam1125-gif/Dhkin-mobiles/raw/main/apks/app-release.apk';

        if (latestVersionCode > kCurrentVersionCode) {
          if (mounted) {
            _showUpdateAvailableDialog(latestVersionName, updateUrl);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking developer update: $e');
    }
  }

  void _showUpdateAvailableDialog(String version, String updateUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.accentForest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update, color: AppTheme.primaryIvory, size: 50),
              const SizedBox(height: 16),
              const Text(
                'NEW UPDATE AVAILABLE',
                style: TextStyle(
                  color: AppTheme.primaryIvory,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'A new version ($version) with new features is ready for download.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final uri = Uri.parse(updateUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  } catch (e) {
                    debugPrint('Could not launch update URL: $e');
                  }
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIvory,
                  foregroundColor: AppTheme.accentForest,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('DOWNLOAD NEW APK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('LATER', style: TextStyle(color: Colors.white60)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Subscribe ONCE per (shopId × dataType). setState is called on every
  /// Firestore event so ALL widgets in the tree see the update immediately.
  void _initDataStreams() {
    for (final shopId in ['Shop 1', 'Shop 2']) {
      _subs.add(DatabaseService().getSales(shopId).listen((data) {
        if (mounted) setState(() => _salesByShop[shopId] = data);
      }));
      _subs.add(DatabaseService().getServices(shopId).listen((data) {
        if (mounted) setState(() => _servicesByShop[shopId] = data);
      }));
      _subs.add(DatabaseService().getExpenses(shopId).listen((data) {
        if (mounted) setState(() => _expensesByShop[shopId] = data);
      }));
      _subs.add(DatabaseService().getProducts(shopId).listen((data) {
        if (mounted) setState(() => _productsByShop[shopId] = data);
      }));
      _subs.add(DatabaseService().getPendingSpecialistFeeRequests(shopId).listen((data) {
        if (mounted) setState(() => _feeRequestsByShop[shopId] = data);
      }));
      _subs.add(DatabaseService().getReplacementRequests(shopId, status: 'pending').listen((data) {
        if (mounted) setState(() => _replacementsByShop[shopId] = data);
      }));
    }
  }

  void _setupNotifications() async {
    final ns = NotificationService();
    await ns.init();
    await ns.saveTokenToFirestore();
    
    // Start real-time listener for all shops (Spark Plan)
    ns.startListeningToNotifications(['Shop 1', 'Shop 2']);
  }

  void _cleanupOrphanedSpecialistRequests() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('specialistFeeRequests')
          .where('status', isEqualTo: 'pending')
          .get();

      for (var doc in snap.docs) {
        final req = SpecialistFeeRequestModel.fromMap(doc.data());
        final serviceDoc = await FirebaseFirestore.instance
            .collection('services')
            .doc(req.serviceId)
            .get();

        if (serviceDoc.exists) {
          final service = ServiceModel.fromMap(serviceDoc.data()!);
          if (service.isExpenseRecorded || service.partsCost > 0 || service.technicianFee > 0) {
            // 1. Mark request as recorded so it disappears from the dashboard approvals list
            await doc.reference.update({'status': 'recorded'});
            
            // 2. Safely create any missing expense entries for this service
            if (service.technicianFee > 0) {
              final expId = 'EXP_SVC_${service.id}';
              final expDoc = await FirebaseFirestore.instance.collection('expenses').doc(expId).get();
              if (!expDoc.exists) {
                final expense = ExpenseModel(
                  id: expId,
                  shopId: service.shopId,
                  category: 'Specialist Fee',
                  amount: service.technicianFee,
                  description: '[Cust: ${service.customerName}] | [Model: ${service.mobileModel}] | [Delivered by: ${service.employeeName}]',
                  timestamp: service.timestamp,
                  paymentMode: service.technicianPaymentMode,
                );
                await DatabaseService().addExpense(expense);
              }
            }
            if (service.partsCost > 0) {
              final expId = 'EXP_PART_${service.id}';
              final expDoc = await FirebaseFirestore.instance.collection('expenses').doc(expId).get();
              if (!expDoc.exists) {
                final expense = ExpenseModel(
                  id: expId,
                  shopId: service.shopId,
                  category: 'Parts Cost',
                  amount: service.partsCost,
                  description: '[Cust: ${service.customerName}] | [Model: ${service.mobileModel}] | [Wholesaler Part]',
                  timestamp: service.timestamp,
                  paymentMode: service.partsPaymentMode,
                );
                await DatabaseService().addExpense(expense);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up specialist requests: $e');
    }
  }

  @override
  void dispose() {
    for (final sub in _subs) sub.cancel();
    NotificationService().stopListening();
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTabHeader(String shopId, String name) {
    final feeRequests = _feeRequestsByShop[shopId] ?? [];
    final replacements = _replacementsByShop[shopId] ?? [];
    final sales       = _salesByShop[shopId] ?? [];
    final products    = _productsByShop[shopId] ?? [];
    final services    = _servicesByShop[shopId] ?? [];

    final pendingFeeCount  = feeRequests.length;
    final pendingReplCount = replacements.length;
    final pendingSalesCount = sales
        .where((sale) => sale.items.any((item) => item.costPrice <= 0.0))
        .length;
    final pendingProductsCount =
        products.where((prod) => prod.costPrice <= 0.0).length;
    final pendingServicesCount = services
        .where((s) => s.employeeName != 'Owner' && !s.isExpenseRecorded)
        .length;

    final totalPending = pendingFeeCount + pendingReplCount +
        pendingSalesCount + pendingProductsCount + pendingServicesCount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name),
        if (totalPending > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$totalPending',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryIvory,
          unselectedLabelColor: AppTheme.primaryIvory.withValues(alpha: 0.5),
          indicatorColor: AppTheme.primaryIvory,
          tabs: [
            Tab(
              child: _buildTabHeader('Shop 1', ShopHelper.getDisplayName('Shop 1')),
            ),
            Tab(
              child: _buildTabHeader('Shop 2', ShopHelper.getDisplayName('Shop 2')),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.accentForest),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 6, spreadRadius: 1),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 60,
                          width: 60,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'D&H MOBILES',
                      style: TextStyle(color: AppTheme.primaryIvory, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                   _buildDrawerTile(Icons.people_outline, 'Manage Employees', Colors.blue, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeManagementScreen()));
                  }),
                  _buildDrawerTile(Icons.inventory_2_outlined, 'Stock Management', Colors.purple, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const StockManagementScreen()));
                  }),
                  _buildDrawerTile(Icons.analytics_outlined, 'Sales Reports', Colors.indigo, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReportsScreen()));
                  }),
                  _buildDrawerTile(Icons.contact_phone_outlined, 'Customer Numbers', Colors.teal, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerContactsScreen(isOwner: true)));
                  }),
                  _buildDrawerTile(Icons.security_outlined, 'Security Settings', Colors.teal, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()));
                  }),
                  _buildDrawerTile(Icons.receipt_long_outlined, 'GST & Bill Settings', Colors.amber, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GstSettingsScreen()));
                  }),
                  const Divider(indent: 20, endIndent: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('TRANSACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  _buildDrawerTile(Icons.local_shipping_outlined, 'Dealer Claims', Colors.blueAccent, () {
                    _showShopSelectionDialog(context, (shopId) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => DealerClaimsScreen(shopId: shopId)));
                    });
                  }),
                  _buildDrawerTile(Icons.list_alt_rounded, 'Order List', Colors.teal, () {
                    _showShopSelectionDialog(context, (shopId) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProductOrderListScreen(shopId: shopId)));
                    });
                  }),
                  _buildDrawerTile(Icons.add_shopping_cart_rounded, 'New Sale', Colors.green, () {
                    _showShopSelectionDialog(context, (shopId) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => SaleBillScreen(shopId: shopId, employeeName: 'Owner')));
                    });
                  }),
                  _buildDrawerTile(Icons.construction_rounded, 'New Service', Colors.orange, () {
                    _showShopSelectionDialog(context, (shopId) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceManagementScreen(shopId: shopId, employeeName: 'Owner')));
                    });
                  }),
                  _buildDrawerTile(Icons.unarchive_rounded, 'New Replacement', Colors.red, () {
                    _showShopSelectionDialog(context, (shopId) {
                       _showReplacementDialog(context, shopId);
                    });
                  }),
                  _buildDrawerTile(Icons.person_search_rounded, 'Search/Warranty', Colors.blueAccent, () {
                    _showShopSelectionDialog(context, (shopId) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => WarrantySearchScreen(shopId: shopId, employeeName: 'Owner', isOwner: true)));
                    });
                  }),
                  _buildDrawerTile(Icons.account_balance_wallet_outlined, 'Expense Tracker', Colors.red, () {
                    _showShopSelectionDialog(context, (shopId) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseManagementScreen(shopId: shopId)));
                    });
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildShopOverview('Shop 1'),
          _buildShopOverview('Shop 2'),
        ],
      ),
    );
  }

  void _showShopSelectionDialog(BuildContext context, Function(String) onSelected) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Shop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(ShopHelper.getDisplayName('Shop 1')),
              onTap: () { Navigator.pop(context); onSelected('Shop 1'); },
            ),
            ListTile(
              title: Text(ShopHelper.getDisplayName('Shop 2')),
              onTap: () { Navigator.pop(context); onSelected('Shop 2'); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        Future.delayed(const Duration(milliseconds: 100), () {
          onTap();
        });
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildShopOverview(String shopId) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('QUICK ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          _buildQuickActions(context, shopId),
          const SizedBox(height: 28),
          _buildStatCard(shopId),
          const SizedBox(height: 28),
          _buildSectionHeader('Specialist Fee Approvals', Icons.receipt_long_outlined, Colors.deepPurple),
          _buildSpecialistFeeApprovals(shopId),
          const SizedBox(height: 28),
          _buildSectionHeader('Wastage Approvals', Icons.rule_rounded, Colors.deepOrange),
          _buildWastageApprovals(shopId),
          _buildPendingCostAlerts(shopId),
          const SizedBox(height: 28),
          _buildSectionHeader('Stock Alerts', Icons.warning_amber_rounded, Colors.red),
          _buildStockAlerts(shopId),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Recent Services', Icons.build_circle_outlined, Colors.orange),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    if (_selectedServicesDates.containsKey(shopId) &&
                        !_isToday(_selectedServicesDates[shopId]!))
                      TextButton(
                        onPressed: () => setState(() => _selectedServicesDates.remove(shopId)),
                        style: TextButton.styleFrom(foregroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 6)),
                        child: const Text('Today', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_month_outlined, size: 16, color: Colors.orange),
                      label: Text(
                        _isToday(_selectedServicesDates[shopId] ?? DateTime.now())
                            ? 'Today'
                            : DateFormat('dd MMM yyyy').format(_selectedServicesDates[shopId] ?? DateTime.now()),
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedServicesDates[shopId] ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppTheme.accentForest,
                                  onPrimary: Colors.white,
                                  onSurface: AppTheme.charcoalBlack,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedServicesDates[shopId] = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildRecentServices(shopId),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Recent Sales', Icons.shopping_bag_outlined, Colors.green),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    if (_selectedSalesDates.containsKey(shopId) &&
                        !_isToday(_selectedSalesDates[shopId]!))
                      TextButton(
                        onPressed: () => setState(() => _selectedSalesDates.remove(shopId)),
                        style: TextButton.styleFrom(foregroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 6)),
                        child: const Text('Today', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_month_outlined, size: 16, color: Colors.green),
                      label: Text(
                        _isToday(_selectedSalesDates[shopId] ?? DateTime.now())
                            ? 'Today'
                            : DateFormat('dd MMM yyyy').format(_selectedSalesDates[shopId] ?? DateTime.now()),
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedSalesDates[shopId] ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppTheme.accentForest,
                                  onPrimary: Colors.white,
                                  onSurface: AppTheme.charcoalBlack,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedSalesDates[shopId] = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildRecentSales(shopId),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String shopId) {
    final allSales     = _salesByShop[shopId];
    final allServices  = _servicesByShop[shopId];
    final allExpenses  = _expensesByShop[shopId];

    // Show skeleton shimmer until the first Firestore event arrives for all three
    if (allSales == null || allServices == null || allExpenses == null) {
      return Shimmer.cardSkeleton();
    }

    final filterMode = _profitFilterMode[shopId] ?? 'This Month';
    final customRange = _profitCustomRange[shopId];
    final now = DateTime.now();

    bool matchesFilter(DateTime dt) {
      if (filterMode == 'Today') {
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      } else if (filterMode == 'This Month') {
        return dt.year == now.year && dt.month == now.month;
      } else if (filterMode == 'Custom Range' && customRange != null) {
        final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
        final end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59);
        return dt.isAfter(start) && dt.isBefore(end);
      }
      return dt.year == now.year && dt.month == now.month;
    }

    bool isBeforeFilter(DateTime dt) {
      if (filterMode == 'Today') {
        final startOfToday = DateTime(now.year, now.month, now.day);
        return dt.isBefore(startOfToday);
      } else if (filterMode == 'This Month') {
        final startOfThisMonth = DateTime(now.year, now.month, 1);
        return dt.isBefore(startOfThisMonth);
      } else if (filterMode == 'Custom Range' && customRange != null) {
        final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
        return dt.isBefore(start);
      }
      final startOfThisMonth = DateTime(now.year, now.month, 1);
      return dt.isBefore(startOfThisMonth);
    }

    final double cashCollectedBefore = 
        allSales.where((s) => isBeforeFilter(s.timestamp)).fold(0.0, (sum, s) => sum + s.cashAmount) +
        allServices.where((s) => isBeforeFilter(s.timestamp)).fold(0.0, (sum, s) => sum + s.cashAmount);

    final double cashSpentOnExpensesBefore = 
        allExpenses.where((e) => isBeforeFilter(e.timestamp) && e.paymentMode == 'Cash').fold(0.0, (sum, e) => sum + e.amount);

    final filteredSales = allSales.where((s) => matchesFilter(s.timestamp)).toList();
    final filteredServices = allServices.where((s) => matchesFilter(s.timestamp)).toList();
    final filteredExpenses = allExpenses.where((e) => matchesFilter(e.timestamp)).toList();

    final double cashSpentOnExpenses = 
        filteredExpenses.where((e) => e.paymentMode == 'Cash').fold(0.0, (sum, e) => sum + e.amount);

    final double onlineSpentOnExpenses = 
        filteredExpenses.where((e) => e.paymentMode == 'Online').fold(0.0, (sum, e) => sum + e.amount);

    double salesRevenue  = 0;
    double serviceRevenue = 0;
    double totalExpenses  = 0;
    double totalCOGS      = 0;
    double gstCollected   = 0;
    double cashCollected  = 0;
    double onlineCollected = 0;

    salesRevenue  = filteredSales.fold(0.0, (sum, s) => sum + (s.isGstBill ? s.taxableAmount : s.totalPrice));
    gstCollected  = filteredSales.fold(0.0, (sum, s) => sum + (s.isGstBill ? (s.cgstAmount + s.sgstAmount) : 0.0));
    totalCOGS     = filteredSales.fold(0.0, (sum, s) =>
        sum + s.items.fold(0.0, (iSum, item) => iSum + (item.costPrice * item.quantity)));
    cashCollected  = filteredSales.fold(0.0, (sum, s) => sum + s.cashAmount);
    onlineCollected = filteredSales.fold(0.0, (sum, s) => sum + s.onlineAmount);

    serviceRevenue = filteredServices.fold(0.0, (sum, s) {
      final double effectiveAdvance = s.advanceAmount.clamp(0.0, s.totalAmount);
      if (s.isGstBill && s.totalAmount > 0) return sum + (effectiveAdvance * (s.taxableAmount / s.totalAmount));
      return sum + effectiveAdvance;
    });
    gstCollected += filteredServices.fold(0.0, (sum, s) {
      final double effectiveAdvance = s.advanceAmount.clamp(0.0, s.totalAmount);
      if (s.isGstBill && s.totalAmount > 0) return sum + (effectiveAdvance * ((s.cgstAmount + s.sgstAmount) / s.totalAmount));
      return sum;
    });
    final serviceExpenses = filteredServices.fold(0.0, (sum, s) => sum + s.partsCost + s.technicianFee);
    cashCollected  += filteredServices.fold(0.0, (sum, s) => sum + s.cashAmount);
    onlineCollected += filteredServices.fold(0.0, (sum, s) => sum + s.onlineAmount);

    totalExpenses = filteredExpenses
        .where((e) => e.category != 'Specialist Fee' && e.category != 'Parts Cost')
        .fold(0.0, (sum, e) => sum + e.amount);

    final double totalRevenue = salesRevenue + serviceRevenue;
    final double netProfit = (salesRevenue - totalCOGS) + serviceRevenue - totalExpenses - serviceExpenses;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [AppTheme.accentForest, AppTheme.accentForest.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: filterMode,
                  dropdownColor: AppTheme.accentForest,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  underline: Container(height: 1, color: Colors.white54),
                  iconEnabledColor: Colors.white70,
                  items: ['Today', 'This Month', 'Custom Range'].map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m, style: const TextStyle(color: Colors.white)),
                  )).toList(),
                  onChanged: (val) async {
                    if (val == 'Custom Range') {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDateRange: customRange ?? DateTimeRange(
                          start: DateTime.now().subtract(const Duration(days: 7)),
                          end: DateTime.now(),
                        ),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppTheme.accentForest,
                                onPrimary: Colors.white,
                                onSurface: AppTheme.charcoalBlack,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          _profitFilterMode[shopId] = val!;
                          _profitCustomRange[shopId] = picked;
                        });
                      }
                    } else if (val != null) {
                      setState(() {
                        _profitFilterMode[shopId] = val;
                      });
                    }
                  },
                ),
                Icon(Icons.auto_graph_rounded, color: AppTheme.primaryIvory.withValues(alpha: 0.5), size: 20),
              ],
            ),
            if (filterMode == 'Custom Range' && customRange != null) ...[
              const SizedBox(height: 4),
              Text(
                '${DateFormat('dd MMM yyyy').format(customRange.start)} - ${DateFormat('dd MMM yyyy').format(customRange.end)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  const Text('NET PROFIT', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text(
                    netProfit >= 0 ? '₹${netProfit.toStringAsFixed(0)}' : '-₹${netProfit.abs().toStringAsFixed(0)}',
                    style: TextStyle(
                      color: netProfit >= 0 ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.arrow_downward_rounded, color: Colors.greenAccent, size: 16),
                          SizedBox(width: 4),
                          Text('INCOME', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 6),
                        Text('₹${totalRevenue.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Sales: ₹${salesRevenue.toStringAsFixed(0)}\nServ: ₹${serviceRevenue.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white54, fontSize: 10, height: 1.3)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.arrow_upward_rounded, color: Colors.orangeAccent, size: 16),
                          SizedBox(width: 4),
                          Text('EXPENSES', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 6),
                        Text('₹${(totalExpenses + totalCOGS).toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Other: ₹${totalExpenses.toStringAsFixed(0)}\nCOGS: ₹${totalCOGS.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white54, fontSize: 10, height: 1.3)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<GstSettingsModel?>(
              stream: DatabaseService().streamGstSettings(shopId),
              builder: (context, settingsSnap) {
                final initialStartingCash = settingsSnap.data?.openingDrawerAmount ?? 0.0;
                final openingAmt = initialStartingCash + cashCollectedBefore - cashSpentOnExpensesBefore;
                final totalDrawer = openingAmt + cashCollected - cashSpentOnExpenses;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      // Opening drawer cash
                      if (openingAmt > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.account_balance_wallet_outlined, color: Colors.yellowAccent, size: 20),
                                SizedBox(width: 8),
                                Text('OPENING DRAWER', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              ],
                            ),
                            Text('₹${openingAmt.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 16, color: Colors.white10),
                      ],
                      // Cash collected
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.monetization_on_outlined, color: Colors.greenAccent, size: 20),
                              SizedBox(width: 8),
                              Text('CASH COLLECTED', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ],
                          ),
                          Text('₹${cashCollected.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      // Cash expenses
                      if (cashSpentOnExpenses > 0) ...[
                        const Divider(height: 16, color: Colors.white10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.money_off_outlined, color: Colors.redAccent, size: 20),
                                SizedBox(width: 8),
                                Text('CASH EXPENSES', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              ],
                            ),
                            Text('₹${cashSpentOnExpenses.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                      const Divider(height: 16, color: Colors.white10),
                      // Cash drawer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.local_atm_rounded, color: Colors.greenAccent, size: 20),
                              SizedBox(width: 8),
                              Text('TOTAL DRAWER CASH', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ],
                          ),
                          Text('₹${totalDrawer.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 16, color: Colors.white10),
                      // Online collected
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.account_balance_outlined, color: Colors.blueAccent, size: 20),
                              SizedBox(width: 8),
                              Text('ONLINE COLLECTED', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ],
                          ),
                          Text('₹${onlineCollected.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      // Online expenses
                      if (onlineSpentOnExpenses > 0) ...[
                        const Divider(height: 16, color: Colors.white10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.money_off_outlined, color: Colors.redAccent, size: 20),
                                SizedBox(width: 8),
                                Text('ONLINE EXPENSES', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              ],
                            ),
                            Text('₹${onlineSpentOnExpenses.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                      // Net online amount
                      const Divider(height: 16, color: Colors.white10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, color: Colors.blueAccent, size: 20),
                              SizedBox(width: 8),
                              Text('NET ONLINE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ],
                          ),
                          Text('₹${(onlineCollected - onlineSpentOnExpenses).toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            if (gstCollected > 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, color: Colors.blueAccent, size: 20),
                    const SizedBox(width: 8),
                    const Text('GST COLLECTED', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const Spacer(),
                    Text('₹${gstCollected.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Specialist Fee Approvals ─────────────────────────────────────────────

  Widget _buildSpecialistFeeApprovals(String shopId) {
    final requests = _feeRequestsByShop[shopId] ?? [];

    if (requests.isEmpty) {
      return Card(
        color: Colors.deepPurple.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.deepPurple, size: 20),
              SizedBox(width: 10),
              Text('No pending specialist fee approvals', style: TextStyle(color: Colors.deepPurple)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return Card(
          color: Colors.deepPurple.shade50,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.deepPurple.shade200)),
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_outlined, color: Colors.deepPurple, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${req.customerName} — ${req.mobileModel}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text('Delivered by: ${req.deliveredBy}',
                          style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade400)),
                      Text('${req.timestamp.day}/${req.timestamp.month}/${req.timestamp.year}',
                          style: const TextStyle(fontSize: 11, color: Colors.black45)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _showSpecialistFeeEntryDialog(context, req),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Enter Fee', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSpecialistFeeEntryDialog(
      BuildContext context, SpecialistFeeRequestModel request) {
    final feeController = TextEditingController();
    final partsCostController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('services').doc(request.serviceId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          final serviceDoc = snapshot.data;
          ServiceModel? service;
          if (serviceDoc != null && serviceDoc.exists) {
            service = ServiceModel.fromMap(serviceDoc.data() as Map<String, dynamic>);
          }

          if (service != null) {
            if (partsCostController.text.isEmpty && service.partsCost > 0) {
              partsCostController.text = service.partsCost.toStringAsFixed(0);
            }
            if (feeController.text.isEmpty && service.technicianFee > 0) {
              feeController.text = service.technicianFee.toStringAsFixed(0);
            }
          }
          String partsPaymentMode = 'Cash';
          String feePaymentMode = 'Cash';
          bool initialized = false;

          return StatefulBuilder(
            builder: (innerCtx, setDialogState) {
              if (!initialized && service != null) {
                partsPaymentMode = service.partsPaymentMode;
                feePaymentMode = service.technicianPaymentMode;
                initialized = true;
              }

              final totalBill = service?.totalAmount ?? 0.0;
              final netRevenue = service != null ? (service.isGstBill ? service.taxableAmount : service.totalAmount) : 0.0;
              final reRepair = service?.reRepairCost ?? 0.0;
              final double pCost = double.tryParse(partsCostController.text) ?? 0.0;
              final double tFee = double.tryParse(feeController.text) ?? 0.0;
              final profit = netRevenue - pCost - tFee - reRepair;

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.receipt_long_outlined,
                          color: Colors.deepPurple.shade700, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Text('Enter Service Expenses',
                            style: TextStyle(fontSize: 17))),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${request.customerName} — ${request.mobileModel}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('Delivered by: ${request.deliveredBy}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.deepPurple.shade400)),
                            const SizedBox(height: 4),
                            Text('Total Bill: ₹${totalBill.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            if (reRepair > 0)
                              Text('Re-repair Cost: -₹${reRepair.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Display / Part Cost (\u20B9)',
                          style: TextStyle(fontSize: 13, color: Colors.black54)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: partsCostController,
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setDialogState(() {}),
                        decoration: InputDecoration(
                          prefixText: '\u20B9 ',
                          hintText: '0',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text('Cash'),
                            selected: partsPaymentMode == 'Cash',
                            selectedColor: Colors.deepPurple.shade100,
                            onSelected: (val) {
                              if (val) setDialogState(() => partsPaymentMode = 'Cash');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Online'),
                            selected: partsPaymentMode == 'Online',
                            selectedColor: Colors.deepPurple.shade100,
                            onSelected: (val) {
                              if (val) setDialogState(() => partsPaymentMode = 'Online');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Specialist / Technician Fee (\u20B9)',
                          style: TextStyle(fontSize: 13, color: Colors.black54)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: feeController,
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setDialogState(() {}),
                        decoration: InputDecoration(
                          prefixText: '\u20B9 ',
                          hintText: '0',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text('Cash'),
                            selected: feePaymentMode == 'Cash',
                            selectedColor: Colors.deepPurple.shade100,
                            onSelected: (val) {
                              if (val) setDialogState(() => feePaymentMode = 'Cash');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Online'),
                            selected: feePaymentMode == 'Online',
                            selectedColor: Colors.deepPurple.shade100,
                            onSelected: (val) {
                              if (val) setDialogState(() => feePaymentMode = 'Online');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Estimated Net Profit:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('₹${profit.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: profit >= 0 ? Colors.green : Colors.red,
                                  fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final fee = double.tryParse(feeController.text.trim()) ?? 0.0;
                      final pCost = double.tryParse(partsCostController.text.trim()) ?? 0.0;
                      
                      Navigator.pop(dialogCtx);
                      SoundHelper.playSuccess();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Service expenses updated successfully'),
                          backgroundColor: Colors.deepPurple,
                        ),
                      );
                      DatabaseService().recordSpecialistFee(
                        request,
                        fee,
                        pCost,
                        feePaymentMode: feePaymentMode,
                        partsPaymentMode: partsPaymentMode,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save Expenses'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStockAlerts(String shopId) {
    final products = _productsByShop[shopId] ?? [];
    final lowStockItems = products.where((p) => p.units < 5).toList();

    if (lowStockItems.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('All stock levels are optimal', textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lowStockItems.length,
      itemBuilder: (context, index) {
        final item = lowStockItems[index];
        return Card(
          color: Colors.red.shade50,
          child: ListTile(
            leading: const Icon(Icons.warning, color: Colors.red),
            title: Text(item.name, style: const TextStyle(color: AppTheme.charcoalBlack, fontWeight: FontWeight.bold)),
            subtitle: Text(item.category, style: const TextStyle(color: Colors.black54)),
            trailing: Text('${item.units} units', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ),
        );
      },
    );
  }

  Widget _buildRecentServices(String shopId) {
    final services = _servicesByShop[shopId];
    if (services == null) {
      return Shimmer.listSkeleton(count: 3);
    }
    final selectedDate = _selectedServicesDates[shopId] ?? DateTime.now();
    final dayServices = services.where((s) {
      return s.timestamp.year == selectedDate.year &&
             s.timestamp.month == selectedDate.month &&
             s.timestamp.day == selectedDate.day;
    }).toList();

    if (dayServices.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No services recorded on ${DateFormat('dd MMM yyyy').format(selectedDate)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dayServices.length,
      itemBuilder: (context, index) {
        final service = dayServices[index];
        return Card(
          child: ListTile(
            leading: Icon(
              service.status == 'Completed' ? Icons.check_circle : (service.status == 'Delivered' ? Icons.local_shipping : Icons.build),
              color: service.status == 'Completed' ? Colors.green : (service.status == 'Delivered' ? Colors.deepPurple : Colors.orange),
            ),
            title: Text(service.mobileModel),
            subtitle: Text('${service.customerName} | ₹${service.totalAmount}'),
            trailing: Text(service.status, style: TextStyle(
              color: service.status == 'Completed' ? Colors.green : (service.status == 'Delivered' ? Colors.deepPurple : Colors.orange),
              fontWeight: FontWeight.bold,
            )),
          ),
        );
      },
    );
  }

  Widget _buildRecentSales(String shopId) {
    final sales = _salesByShop[shopId];
    if (sales == null) {
      return Shimmer.listSkeleton(count: 3);
    }
    final selectedDate = _selectedSalesDates[shopId] ?? DateTime.now();
    final daySales = sales.where((s) {
      return s.timestamp.year == selectedDate.year &&
             s.timestamp.month == selectedDate.month &&
             s.timestamp.day == selectedDate.day;
    }).toList();

    if (daySales.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No sales recorded on ${DateFormat('dd MMM yyyy').format(selectedDate)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: daySales.length,
      itemBuilder: (context, index) {
        final sale = daySales[index];
        final itemNames = sale.items.map((i) => i.productName).join(', ');
        return Card(
          child: ListTile(
            title: Text(sale.items.length == 1 ? sale.items.first.productName : '${sale.items.length} Items'),
            subtitle: Text(sale.items.length == 1 ? sale.customerName : '${sale.customerName} | $itemNames', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${sale.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(DateFormat('hh:mm a').format(sale.timestamp), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWastageApprovals(String shopId) {
    final requests = _replacementsByShop[shopId] ?? [];
    final products  = _productsByShop[shopId] ?? [];

    if (requests.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16.0), child: Text('No pending wastage requests')),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        final bool isService = request.isService;

        return Card(
          child: ListTile(
            leading: Icon(
              isService ? Icons.build_circle_outlined : Icons.shopping_bag_outlined,
              color: isService ? Colors.blue : Colors.green,
            ),
            title: Text(request.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Type: ${isService ? "Service" : "Sale"} | By ${request.employeeName}\nReason: ${request.reason}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () {
                    double defaultCost = 0.0;
                    for (final p in products) {
                      if (p.id == request.productId) {
                        defaultCost = p.costPrice;
                        break;
                      }
                    }
                    _showApproveDialog(context, request, defaultCost);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () => DatabaseService().rejectReplacement(request.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingCostAlerts(String shopId) {
    final sales    = _salesByShop[shopId] ?? [];
    final products = _productsByShop[shopId] ?? [];

    final pendingSales = sales
        .where((sale) => sale.items.any((item) => item.costPrice <= 0.0))
        .toList();
    final pendingProducts = products
        .where((prod) => prod.costPrice <= 0.0)
        .toList();

    if (pendingSales.isEmpty && pendingProducts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pendingProducts.isNotEmpty) ...[
          const SizedBox(height: 28),
          _buildSectionHeader('Stock Cost Alerts', Icons.inventory_2_outlined, Colors.teal.shade800),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.teal.shade300, width: 1.5),
            ),
            color: Colors.teal.shade50.withValues(alpha: 0.7),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: pendingProducts.map((prod) => ListTile(
                  leading: const Icon(Icons.storefront_rounded, color: Colors.teal, size: 24),
                  title: Text(prod.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoalBlack)),
                  subtitle: const Text('Missing cost price in product catalog/stock', style: TextStyle(fontSize: 11, color: AppTheme.graphiteGray)),
                  trailing: ElevatedButton(
                    onPressed: () => _showUpdateProductCostDialog(context, prod),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('SET STOCK COST'),
                  ),
                )).toList(),
              ),
            ),
          ),
        ],
        if (pendingSales.isNotEmpty) ...[
          const SizedBox(height: 28),
          _buildSectionHeader('Bill Cost Alerts', Icons.warning_amber_rounded, Colors.amber.shade800),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.amber.shade300, width: 1.5),
            ),
            color: Colors.amber.shade50.withValues(alpha: 0.7),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: pendingSales.map((sale) {
                  final missingCostItems = sale.items
                      .where((item) => item.costPrice <= 0.0)
                      .map((i) => i.productName)
                      .join(', ');
                  return ListTile(
                    leading: const Icon(Icons.receipt_long_rounded, color: Colors.amber, size: 24),
                    title: Text('Bill #${sale.id.substring(0, 8)} - ${sale.customerName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoalBlack)),
                    subtitle: Text('Sold items missing cost: $missingCostItems',
                        style: const TextStyle(fontSize: 11, color: AppTheme.graphiteGray)),
                    trailing: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => EditSaleItemsDialog(sale: sale),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('SET BILL COST'),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showUpdateProductCostDialog(BuildContext context, ProductModel product) {
    final costController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Set Product Purchase Cost\n${product.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: costController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Purchase / Cost Price (₹)',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
            validator: (val) => (val == null || double.tryParse(val) == null || double.parse(val) < 0) ? 'Enter valid cost price' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final cost = double.parse(costController.text);
              await DatabaseService().updateProductCost(product.id, cost);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cost price updated for "${product.name}"!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentForest, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(BuildContext context, ReplacementModel request, [double defaultCost = 0.0]) {
    final bool isService = request.isService;
    final costController = TextEditingController(
      text: (!isService && defaultCost > 0) 
          ? (defaultCost * request.quantity).toStringAsFixed(0) 
          : '',
    );
    bool isSubmitting = false;
    String paymentMode = request.paymentMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isService ? 'Approve Re-Repair (External)' : 'Approve Product Replacement'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (request.quantity > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Text('Quantity Requested: ${request.quantity}', 
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800, fontSize: 13)),
                    ),
                  ),
                Text(isService 
                  ? 'Enter TOTAL EXTERNAL COST paid (Specialist fee + Transport):'
                  : 'Confirm the TOTAL COST for ${request.quantity} x ${request.productName} to record loss:'),
                const SizedBox(height: 12),
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: isService ? 'Total External Loss (₹)' : 'Total Cost Price (₹)',
                    prefixText: '₹',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    suffixIcon: !isService ? const Icon(Icons.auto_awesome, size: 16, color: Colors.green) : null,
                    hintText: '0',
                  ),
                ),
                if (!isService)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      'Value auto-fetched from stock inventory',
                      style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontStyle: FontStyle.italic),
                    ),
                  ),
                const SizedBox(height: 12),
                if (isService) ...[
                  const Text('Payment Mode:', style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Cash'),
                        selected: paymentMode == 'Cash',
                        selectedColor: Colors.orange.shade100,
                        onSelected: (val) {
                          if (val) setDialogState(() => paymentMode = 'Cash');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Online'),
                        selected: paymentMode == 'Online',
                        selectedColor: Colors.orange.shade100,
                        onSelected: (val) {
                          if (val) setDialogState(() => paymentMode = 'Online');
                        },
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Loss logged as Stock write-off. Will not affect cash or online balances.',
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx), 
                child: const Text('Cancel')
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  final costStr = costController.text.trim();
                  final totalCost = costStr.isEmpty ? 0.0 : double.tryParse(costStr);
                  
                  if (totalCost == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount')));
                    return;
                  }
                  
                  final unitCost = totalCost / request.quantity;
                  
                  setDialogState(() => isSubmitting = true);
                  try {
                    SoundHelper.playSuccess();
                    DatabaseService().approveReplacement(
                      request.id,
                      unitCost,
                      paymentMode: paymentMode,
                    ).catchError((e) {
                      debugPrint('Error approving replacement: $e');
                    });
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Replacement approved and stock updated'),
                        backgroundColor: Colors.green,
                      ));
                    }
                  } catch (e) {
                    setDialogState(() => isSubmitting = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isService ? Colors.orange.shade800 : AppTheme.accentForest,
                  foregroundColor: Colors.white,
                ),
                child: isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Approve'),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, String shopId) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionShortcut(
                title: 'New Sale',
                icon: Icons.add_shopping_cart,
                color: Colors.green,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaleBillScreen(shopId: shopId, employeeName: 'Owner'))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionShortcut(
                title: 'Service',
                icon: Icons.build,
                color: Colors.orange,
                badgeCount: (_servicesByShop[shopId] ?? [])
                    .where((s) => s.status == 'Pending')
                    .length,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceManagementScreen(shopId: shopId, employeeName: 'Owner'))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionShortcut(
                title: 'Wastage',
                icon: Icons.unarchive_rounded,
                color: Colors.red,
                onTap: () => _showReplacementDialog(context, shopId),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionShortcut(
                title: 'Search',
                icon: Icons.person_search_rounded,
                color: Colors.blueAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WarrantySearchScreen(shopId: shopId, employeeName: 'Owner', isOwner: true))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Card(
                elevation: 0,
                color: Colors.deepPurple.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.deepPurple.withOpacity(0.2)),
                ),
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseManagementScreen(shopId: shopId))),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.account_balance_wallet_rounded, color: Colors.deepPurple, size: 18),
                        SizedBox(width: 6),
                        Text('Expenses', style: TextStyle(color: Colors.deepPurple, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                elevation: 0,
                color: AppTheme.accentForest.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppTheme.accentForest.withOpacity(0.2)),
                ),
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockSearchScreen(shopId: shopId, isOwner: true))),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.inventory_2_outlined, color: AppTheme.accentForest, size: 18),
                        SizedBox(width: 6),
                        Text('Stock', style: TextStyle(color: AppTheme.accentForest, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                elevation: 0,
                color: Colors.teal.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.teal.withOpacity(0.2)),
                ),
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EnquiryManagementScreen(shopId: shopId, isOwner: true))),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.mark_as_unread_rounded, color: Colors.teal, size: 18),
                        SizedBox(width: 6),
                        Text('Enquiries', style: TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

      ],
    );
  }

  void _showReplacementDialog(BuildContext context, String shopId) {
    final reasonController = TextEditingController();
    final costController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    ProductModel? selectedProduct;
    String? selectedCategory;
    final databaseService = DatabaseService();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Record Direct Wastage'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('As an owner, you can record this immediately without approval.', 
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                StreamBuilder<List<CategoryModel>>(
                  stream: _getCategoriesStream(),
                  builder: (context, snapshot) {
                    final categories = snapshot.data ?? [];
                    final uniqueCategoryNames = categories.map((c) => c.name.trim()).toSet().toList();
                    String? dropdownValue = selectedCategory;
                    if (dropdownValue != null && !uniqueCategoryNames.contains(dropdownValue)) {
                      dropdownValue = null;
                    }
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Filter by Category', border: OutlineInputBorder()),
                      isExpanded: true,
                      value: dropdownValue,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Categories', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                        ...uniqueCategoryNames.map((name) => DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (val) {
                        setState(() {
                          selectedCategory = val;
                          selectedProduct = null;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<ProductModel>>(
                  stream: DatabaseService().getProducts(shopId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(),
                      );
                    }
                    final filteredProducts = selectedCategory == null 
                      ? snapshot.data! 
                      : snapshot.data!.where((p) => p.category == selectedCategory).toList();

                    ProductModel? dropdownValue = selectedProduct;
                    if (dropdownValue != null && !filteredProducts.contains(dropdownValue)) {
                      dropdownValue = null;
                    }

                    return DropdownButtonFormField<ProductModel>(
                      decoration: const InputDecoration(labelText: 'Select Product', border: OutlineInputBorder()),
                      isExpanded: true,
                      value: dropdownValue,
                      items: filteredProducts.map((p) => DropdownMenuItem(
                        value: p,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppTheme.charcoalBlack,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 0.5),
                              ),
                              child: Text(
                                'Qty: ${p.units}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (p.location.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 0.5),
                                ),
                                child: Text(
                                  p.location,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedProduct = val;
                          if (val != null) {
                            costController.text = val.costPrice.toStringAsFixed(0);
                          }
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: costController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Unit Cost (₹)', 
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.auto_awesome, size: 14, color: Colors.green),
                        ),
                      ),
                    ),
                  ],
                ),
                Builder(
                  builder: (context) {
                    final int qty = int.tryParse(qtyController.text) ?? 0;
                    final double unitCost = double.tryParse(costController.text) ?? 0.0;
                    final double total = qty * unitCost;
                    if (total <= 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Estimated Loss:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                            Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red)),
                          ],
                        ),
                      ),
                    );
                  }
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason (e.g. Installation Failed)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                if (selectedProduct == null || reasonController.text.isEmpty || costController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                  return;
                }
                
                setState(() => isSubmitting = true);
                try {
                  final String requestId = const Uuid().v4();
                  final unitCost = double.tryParse(costController.text) ?? 0.0;
                  final qty = int.tryParse(qtyController.text) ?? 1;
                  
                  final replacement = ReplacementModel(
                    id: requestId,
                    productId: selectedProduct!.id,
                    productName: selectedProduct!.name,
                    employeeName: 'Owner',
                    shopId: shopId,
                    reason: reasonController.text,
                    status: 'accepted',
                    timestamp: DateTime.now(),
                    costPrice: unitCost,
                    quantity: qty,
                  );

                  SoundHelper.playSuccess();
                  databaseService.addReplacementRequest(replacement).then((_) {
                    databaseService.approveReplacement(requestId, unitCost).catchError((e) {
                      debugPrint('Error approving replacement: $e');
                    });
                  }).catchError((e) {
                    debugPrint('Error adding replacement: $e');
                  });

                  await Future.delayed(const Duration(milliseconds: 500));

                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Wastage recorded & stock updated'),
                      backgroundColor: Colors.green,
                    ));
                  }
                } catch (e) {
                   if (context.mounted) {
                    setState(() => isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentForest, foregroundColor: Colors.white),
              child: isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save & Record'),
            ),
          ],
        ),
      ),
    );
  }

}

class _ActionShortcut extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? badgeCount;

  const _ActionShortcut({required this.title, required this.icon, required this.color, required this.onTap, this.badgeCount});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: Card(
        elevation: 0,
        color: color.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.2))),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, color: color, size: 26),
                    if (badgeCount != null && badgeCount! > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReplacementHistoryScreen extends StatelessWidget {
  final String shopId;
  const ReplacementHistoryScreen({super.key, required this.shopId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Wastage History - $shopId')),
      body: StreamBuilder<List<ReplacementModel>>(
        stream: DatabaseService().getReplacementRequests(shopId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final list = snapshot.data!;
          if (list.isEmpty) return const Center(child: Text('No history found'));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              final color = item.status == 'accepted' ? Colors.green : (item.status == 'rejected' ? Colors.red : Colors.orange);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(item.productName),
                  subtitle: Text('By ${item.employeeName} | ${item.status.toUpperCase()}'),
                  trailing: Text(item.costPrice != null ? 'Loss: ₹${item.costPrice}' : 'No cost set', 
                    style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RevenueItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _RevenueItem({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
