import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/sale_model.dart';
import '../../models/service_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/shop_helper.dart';
import '../../utils/sound_helper.dart';
import '../login_screen.dart';
import 'sale_bill_screen.dart';
import '../services/service_management.dart';
import '../../models/product_model.dart';
import '../../models/replacement_model.dart';
import '../../models/category_model.dart';
import 'warranty_search.dart';
import '../stock_search_screen.dart';
import '../owner/enquiry_management_screen.dart';
import '../owner/customer_contacts_screen.dart';
import '../../widgets/shimmer.dart';
import '../../utils/app_update_helper.dart';

class EmployeeHomeScreen extends StatefulWidget {
  final String shopId;
  final String employeeName;

  const EmployeeHomeScreen({super.key, required this.shopId, required this.employeeName});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  String get shopId => widget.shopId;
  String get employeeName => widget.employeeName;

  DateTime _selectedSalesDate = DateTime.now();
  DateTime _selectedServicesDate = DateTime.now();
  late Stream<List<SaleModel>> _salesStream;
  late Stream<List<ServiceModel>> _servicesStream;

  @override
  void initState() {
    super.initState();
    _salesStream = DatabaseService().getSales(widget.shopId);
    _servicesStream = DatabaseService().getServices(widget.shopId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateHelper.checkAndShowUpdateDialog(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final shopId = widget.shopId;
    final employeeName = widget.employeeName;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Terminal: ${ShopHelper.getDisplayName(shopId)}'),
                Text('Authorized: $employeeName', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: AppTheme.primaryIvory.withValues(alpha: 0.7))),
              ],
            ),
          ],
        ),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('QUICK ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            _buildQuickActions(context),
            const SizedBox(height: 32),
            const Text('SHOP PERFORMANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            _buildTodayStats(context),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('RECENT SALES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined, size: 16, color: Colors.green),
                  label: Text(
                    DateFormat('dd MMM yyyy').format(_selectedSalesDate),
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedSalesDate,
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
                        _selectedSalesDate = picked;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildRecentSales(context),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('RECENT SERVICES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined, size: 16, color: Colors.orange),
                  label: Text(
                    DateFormat('dd MMM yyyy').format(_selectedServicesDate),
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedServicesDate,
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
                        _selectedServicesDate = picked;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildRecentServices(context),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionShortcut(
                title: 'New Sale',
                icon: Icons.add_shopping_cart,
                color: Colors.green,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaleBillScreen(shopId: shopId, employeeName: employeeName))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StreamBuilder<List<ServiceModel>>(
                stream: _servicesStream,
                builder: (context, snapshot) {
                  final pendingCount = snapshot.hasData
                      ? snapshot.data!.where((s) => s.status == 'Pending').length
                      : 0;
                  return _ActionShortcut(
                    title: 'Service',
                    icon: Icons.build,
                    color: Colors.orange,
                    badgeCount: pendingCount,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceManagementScreen(shopId: shopId, employeeName: employeeName))),
                  );
                }
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionShortcut(
                title: 'Wastage',
                icon: Icons.unarchive_rounded,
                color: Colors.red,
                onTap: () => _showReplacementDialog(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionShortcut(
                title: 'Search',
                icon: Icons.person_search_rounded,
                color: Colors.blueAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WarrantySearchScreen(shopId: shopId, employeeName: employeeName, isOwner: false))),
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
                color: AppTheme.accentForest.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppTheme.accentForest.withOpacity(0.2)),
                ),
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockSearchScreen(shopId: shopId, isOwner: false))),
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
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EnquiryManagementScreen(shopId: shopId, isOwner: false))),
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
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                elevation: 0,
                color: Colors.indigo.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.indigo.withOpacity(0.2)),
                ),
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerContactsScreen(isOwner: false, shopId: shopId))),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.contact_phone_outlined, color: Colors.indigo, size: 18),
                        SizedBox(width: 6),
                        Text('Contacts', style: TextStyle(color: Colors.indigo, fontSize: 12, fontWeight: FontWeight.bold)),
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

  void _showReplacementDialog(BuildContext context) {
    final reasonController = TextEditingController();
    final costController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    ProductModel? selectedProduct;
    String? selectedCategory;
    final databaseService = DatabaseService();
    final bool isOwner = employeeName.toLowerCase() == 'owner';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isOwner ? 'Record Direct Wastage' : 'Report Replacement/Wastage'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isOwner 
                  ? 'As an owner, you can record this immediately without approval.'
                  : 'Use this when a product is damaged during installation. Requires owner approval.', 
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                // Category Filter
                StreamBuilder<List<CategoryModel>>(
                  stream: databaseService.getCategories(),
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
                // Product Selection
                 StreamBuilder<List<ProductModel>>(
                  stream: databaseService.getProducts(shopId),
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
                          if (isOwner && val != null) {
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
                        enabled: isOwner,
                        decoration: InputDecoration(
                          labelText: isOwner ? 'Unit Cost (₹)' : 'Est. Loss (Owner fills)', 
                          prefixText: '₹ ',
                          border: const OutlineInputBorder(),
                          suffixIcon: isOwner ? const Icon(Icons.auto_awesome, size: 14, color: Colors.green) : null,
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
                if (selectedProduct == null || reasonController.text.isEmpty || (isOwner && costController.text.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                  return;
                }
                
                setState(() => isSubmitting = true);

                try {
                  final String requestId = const Uuid().v4();
                  final qty = int.tryParse(qtyController.text) ?? 1;
                  final unitCost = isOwner ? (double.tryParse(costController.text) ?? 0.0) : 0.0;

                  final replacement = ReplacementModel(
                    id: requestId,
                    productId: selectedProduct!.id,
                    productName: selectedProduct!.name,
                    employeeName: employeeName,
                    shopId: shopId,
                    reason: reasonController.text,
                    status: isOwner ? 'accepted' : 'pending',
                    timestamp: DateTime.now(),
                    costPrice: isOwner ? unitCost : null,
                    quantity: qty,
                  );

                  SoundHelper.playSuccess();
                  if (isOwner) {
                    databaseService.addReplacementRequest(replacement).then((_) {
                      databaseService.approveReplacement(requestId, unitCost).catchError((e) {
                        debugPrint('Error approving replacement: $e');
                      });
                    }).catchError((e) {
                      debugPrint('Error adding replacement: $e');
                    });
                  } else {
                    databaseService.addReplacementRequest(replacement).catchError((e) {
                      debugPrint('Error adding replacement: $e');
                    });
                  }

                  await Future.delayed(const Duration(milliseconds: 500));

                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isOwner ? 'Wastage recorded & stock updated' : 'Request submitted for approval'),
                      backgroundColor: isOwner ? Colors.green : AppTheme.accentForest,
                    ));
                  }
                } catch (e) {
                   if (context.mounted) {
                    setState(() => isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isOwner ? AppTheme.accentForest : AppTheme.primaryIvory,
                foregroundColor: isOwner ? Colors.white : AppTheme.accentForest,
              ),
              child: isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(isOwner ? 'Save & Record' : 'Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayStats(BuildContext context) {
    return StreamBuilder<List<SaleModel>>(
      stream: _salesStream,
      builder: (context, salesSnapshot) {
        return StreamBuilder<List<ServiceModel>>(
          stream: _servicesStream,
          builder: (context, servicesSnapshot) {
            if (salesSnapshot.hasError || servicesSnapshot.hasError) {
              return const Center(child: Text('Error loading stats'));
            }
            if (salesSnapshot.connectionState == ConnectionState.waiting ||
                servicesSnapshot.connectionState == ConnectionState.waiting) {
              return Shimmer.statsSkeleton();
            }
            
            final now = DateTime.now();
            bool isToday(DateTime dt) =>
                dt.year == now.year && dt.month == now.month && dt.day == now.day;

            double total = 0;
            int count = 0;
            if (salesSnapshot.hasData) {
              final todaySales = salesSnapshot.data!.where((s) => isToday(s.timestamp)).toList();
              total += todaySales.fold(0.0, (sum, item) => sum + item.totalPrice);
              count = todaySales.length;
            }
            if (servicesSnapshot.hasData) {
              final todayServices = servicesSnapshot.data!.where((s) => isToday(s.timestamp)).toList();
              total += todayServices.fold(0.0, (sum, item) => sum + item.advanceAmount);
            }

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(label: 'Today Revenue', value: '₹${total.toStringAsFixed(0)}', icon: Icons.payments_outlined, color: Colors.green),
                    const VerticalDivider(),
                    _StatItem(label: 'Total Bills', value: count.toString(), icon: Icons.receipt_long_outlined, color: AppTheme.accentForest),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentSales(BuildContext context) {
    return StreamBuilder<List<SaleModel>>(
      stream: _salesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 12)),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Shimmer.listSkeleton(count: 3);
        }
        final sales = snapshot.data ?? [];
        final daySales = sales.where((s) {
          return s.timestamp.year == _selectedSalesDate.year &&
                 s.timestamp.month == _selectedSalesDate.month &&
                 s.timestamp.day == _selectedSalesDate.day;
        }).toList();

        if (daySales.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  'No sales recorded on ${DateFormat('dd MMM yyyy').format(_selectedSalesDate)}', 
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),
          );
        }
        
        return ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: daySales.length,
          itemBuilder: (context, index) {
            final sale = daySales[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Colors.green, size: 20),
                ),
                title: Text(
                  sale.items.length == 1 
                    ? sale.items.first.productName 
                    : '${sale.items.length} Items', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                ),
                subtitle: Text('₹${sale.totalPrice}', style: const TextStyle(color: AppTheme.accentForest, fontWeight: FontWeight.w600)),
                trailing: Text(
                  DateFormat('hh:mm a').format(sale.timestamp),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentServices(BuildContext context) {
    return StreamBuilder<List<ServiceModel>>(
      stream: _servicesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 12)),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Shimmer.listSkeleton(count: 3);
        }
        final services = snapshot.data ?? [];
        final dayServices = services.where((s) {
          return s.timestamp.year == _selectedServicesDate.year &&
                 s.timestamp.month == _selectedServicesDate.month &&
                 s.timestamp.day == _selectedServicesDate.day;
        }).toList();

        if (dayServices.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  'No services recorded on ${DateFormat('dd MMM yyyy').format(_selectedServicesDate)}', 
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),
          );
        }
        
        return ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: dayServices.length,
          itemBuilder: (context, index) {
            final service = dayServices[index];
            final Color statusColor = service.status == 'Completed' 
                ? Colors.green 
                : (service.status == 'Delivered' ? Colors.deepPurple : Colors.orange);
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    service.status == 'Completed' 
                        ? Icons.check_circle_outline 
                        : (service.status == 'Delivered' ? Icons.local_shipping_outlined : Icons.build_circle_outlined), 
                    color: statusColor, 
                    size: 20
                  ),
                ),
                title: Text(
                  service.mobileModel, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                ),
                subtitle: Text('${service.customerName} | ₹${service.totalAmount}', style: const TextStyle(color: Colors.black54)),
                trailing: Text(
                  service.status,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            );
          },
        );
      },
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

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color.withOpacity(0.5), size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
      ],
    );
  }
}
