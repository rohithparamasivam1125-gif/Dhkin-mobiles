import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../models/product_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/shop_helper.dart';
import '../../utils/sound_helper.dart';

class LowStockReorderScreen extends StatefulWidget {
  const LowStockReorderScreen({super.key});

  @override
  State<LowStockReorderScreen> createState() => _LowStockReorderScreenState();
}

class _LowStockReorderScreenState extends State<LowStockReorderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Low Stock Reorder'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryIvory,
          unselectedLabelColor: AppTheme.primaryIvory.withValues(alpha: 0.5),
          indicatorColor: AppTheme.primaryIvory,
          tabs: [
            Tab(text: ShopHelper.getDisplayName('Shop 1')),
            Tab(text: ShopHelper.getDisplayName('Shop 2')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ShopLowStockList(shopId: 'Shop 1'),
          _ShopLowStockList(shopId: 'Shop 2'),
        ],
      ),
    );
  }
}

class _ShopLowStockList extends StatefulWidget {
  final String shopId;

  const _ShopLowStockList({required this.shopId});

  @override
  State<_ShopLowStockList> createState() => _ShopLowStockListState();
}

class _ShopLowStockListState extends State<_ShopLowStockList> {
  final Set<String> _selectedProductIds = {};
  final Map<String, TextEditingController> _qtyControllers = {};

  @override
  void dispose() {
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(ProductModel product) {
    if (!_qtyControllers.containsKey(product.id)) {
      // Default initial wanted units to 10
      _qtyControllers[product.id] = TextEditingController(text: '10');
    }
    return _qtyControllers[product.id]!;
  }

  void _toggleSelectAll(List<ProductModel> lowStockProducts) {
    setState(() {
      if (_selectedProductIds.length == lowStockProducts.length) {
        _selectedProductIds.clear();
      } else {
        _selectedProductIds.clear();
        for (var p in lowStockProducts) {
          _selectedProductIds.add(p.id);
          _getController(p); // ensure controller exists
        }
      }
    });
  }

  Future<void> _shareToWhatsApp(List<ProductModel> lowStockProducts) async {
    final selectedProducts = lowStockProducts.where((p) => _selectedProductIds.contains(p.id)).toList();
    if (selectedProducts.isEmpty) return;

    SoundHelper.playSuccess();
    final String dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final shopName = ShopHelper.getDisplayName(widget.shopId).toUpperCase();

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('📦 *$shopName - LOW STOCK REORDER*');
    buffer.writeln('📅 Date: $dateStr');
    buffer.writeln('----------------------------------------');

    int index = 1;
    for (var prod in selectedProducts) {
      final wantedUnits = _getController(prod).text.trim();
      final qty = (wantedUnits.isEmpty || int.tryParse(wantedUnits) == null) ? '10' : wantedUnits;

      buffer.writeln('$index. *${prod.name}*');
      if (prod.category.isNotEmpty) {
        buffer.writeln('   • Category: ${prod.category}');
      }
      buffer.writeln('   • *Wanted Units:* $qty units');
      buffer.writeln('');
      index++;
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('Please dispatch these items as soon as possible. Thank you!');

    final String text = buffer.toString();
    final String encodedText = Uri.encodeComponent(text);
    final Uri whatsappUri = Uri.parse('whatsapp://send?text=$encodedText');
    final Uri webWhatsappUri = Uri.parse('https://wa.me/?text=$encodedText');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else if (await canLaunchUrl(webWhatsappUri)) {
        await launchUrl(webWhatsappUri, mode: LaunchMode.externalApplication);
      } else {
        await Share.share(text, subject: '$shopName - Low Stock Reorder');
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp, falling back to Share: $e');
      await Share.share(text, subject: '$shopName - Low Stock Reorder');
    }
  }

  Future<void> _shareGeneralText(List<ProductModel> lowStockProducts) async {
    final selectedProducts = lowStockProducts.where((p) => _selectedProductIds.contains(p.id)).toList();
    if (selectedProducts.isEmpty) return;

    SoundHelper.playSuccess();
    final String dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final shopName = ShopHelper.getDisplayName(widget.shopId).toUpperCase();

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('📦 *$shopName - LOW STOCK REORDER*');
    buffer.writeln('📅 Date: $dateStr');
    buffer.writeln('----------------------------------------');

    int index = 1;
    for (var prod in selectedProducts) {
      final wantedUnits = _getController(prod).text.trim();
      final qty = (wantedUnits.isEmpty || int.tryParse(wantedUnits) == null) ? '10' : wantedUnits;

      buffer.writeln('$index. *${prod.name}*');
      if (prod.category.isNotEmpty) {
        buffer.writeln('   • Category: ${prod.category}');
      }
      buffer.writeln('   • *Wanted Units:* $qty units');
      buffer.writeln('');
      index++;
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('Please dispatch these items as soon as possible. Thank you!');

    await Share.share(buffer.toString(), subject: '$shopName - Low Stock Reorder');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProductModel>>(
      stream: DatabaseService().getProducts(widget.shopId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allProducts = snapshot.data ?? [];
        // Filter products with stock < 2
        final lowStockProducts = allProducts.where((p) => p.units < 2).toList();

        if (lowStockProducts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'All Stock Levels Optimal!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No products in ${ShopHelper.getDisplayName(widget.shopId)} are below 2 units.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        final bool isAllSelected = _selectedProductIds.length == lowStockProducts.length && lowStockProducts.isNotEmpty;

        return Column(
          children: [
            // Master Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  Checkbox(
                    value: isAllSelected,
                    activeColor: AppTheme.accentForest,
                    onChanged: (_) => _toggleSelectAll(lowStockProducts),
                  ),
                  Expanded(
                    child: Text(
                      isAllSelected ? 'Deselect All (${lowStockProducts.length})' : 'Select All (${lowStockProducts.length} low stock items)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.charcoalBlack,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${lowStockProducts.length} LOW',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            // Product List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 100, left: 12, right: 12),
                itemCount: lowStockProducts.length,
                itemBuilder: (context, index) {
                  final product = lowStockProducts[index];
                  final isSelected = _selectedProductIds.contains(product.id);
                  final controller = _getController(product);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    elevation: isSelected ? 3 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected ? AppTheme.accentForest : Colors.grey.shade200,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: isSelected,
                                activeColor: AppTheme.accentForest,
                                onChanged: (bool? val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedProductIds.add(product.id);
                                    } else {
                                      _selectedProductIds.remove(product.id);
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppTheme.charcoalBlack,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    if (product.category.isNotEmpty)
                                      Text(
                                        product.category,
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          'Sell: ₹${product.price.toStringAsFixed(0)}',
                                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                                        ),
                                        if (product.costPrice > 0) ...[
                                          const SizedBox(width: 12),
                                          Text(
                                            'Cost: ₹${product.costPrice.toStringAsFixed(0)}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Units Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: product.units == 0 ? Colors.red.shade100 : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${product.units} Left',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: product.units == 0 ? Colors.red.shade900 : Colors.orange.shade900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Manual Wanted Units Section (shown when product is selected)
                          if (isSelected) ...[
                            const Divider(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.shopping_cart_outlined, size: 18, color: AppTheme.accentForest),
                                const SizedBox(width: 8),
                                const Text(
                                  'Wanted Units:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.charcoalBlack,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 22),
                                  onPressed: () {
                                    int current = int.tryParse(controller.text) ?? 10;
                                    if (current > 1) {
                                      controller.text = (current - 1).toString();
                                    }
                                  },
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 65,
                                  height: 38,
                                  child: TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                      hintText: 'Qty',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey.shade400),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppTheme.accentForest, width: 2),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: AppTheme.accentForest, size: 22),
                                  onPressed: () {
                                    int current = int.tryParse(controller.text) ?? 10;
                                    controller.text = (current + 1).toString();
                                  },
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Action Bar for WhatsApp Sharing
            if (_selectedProductIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _shareToWhatsApp(lowStockProducts),
                          icon: const Icon(Icons.send_rounded, color: Colors.white),
                          label: Text(
                            'SHARE TO WHATSAPP (${_selectedProductIds.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _shareGeneralText(lowStockProducts),
                        icon: const Icon(Icons.share, color: AppTheme.accentForest),
                        tooltip: 'Share via other apps',
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.accentForest.withValues(alpha: 0.1),
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
