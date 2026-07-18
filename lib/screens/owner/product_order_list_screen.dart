import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/product_order_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/shop_helper.dart';
import '../../utils/sound_helper.dart';

class ProductOrderListScreen extends StatefulWidget {
  final String shopId;

  const ProductOrderListScreen({super.key, required this.shopId});

  @override
  State<ProductOrderListScreen> createState() => _ProductOrderListScreenState();
}

class _ProductOrderListScreenState extends State<ProductOrderListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedOrderIds = {};
  List<String> _existingProductNames = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Listen to existing products to populate autocomplete options
    DatabaseService().getProducts(widget.shopId).listen((products) {
      if (mounted) {
        setState(() {
          _existingProductNames = products.map((p) => p.name.trim()).toSet().toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _shareWithDealer(List<ProductOrderModel> selectedOrders) async {
    if (selectedOrders.isEmpty) return;

    final String dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('📋 *${ShopHelper.getDisplayName(widget.shopId).toUpperCase()} - ORDER REQUEST* ($dateStr)');
    buffer.writeln('----------------------------------------');
    
    int index = 1;
    for (var ord in selectedOrders) {
      buffer.writeln('$index. *${ord.productName}*');
      buffer.writeln('   • *Qty:* ${ord.quantity}');
      if (ord.note != null && ord.note!.isNotEmpty) {
        buffer.writeln('   • *Note:* ${ord.note}');
      }
      buffer.writeln('');
      index++;
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('Please dispatch these items as soon as possible. Thank you!');

    await Share.share(buffer.toString(), subject: '${ShopHelper.getDisplayName(widget.shopId).toUpperCase()} - New Order Request');

    // Prompt to mark as Ordered
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Status?'),
        content: Text('Would you like to mark these ${selectedOrders.length} items as "Ordered" and group them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep as Pending'),
          ),
          ElevatedButton(
            onPressed: () {
              SoundHelper.playSuccess();
              final String orderId = const Uuid().v4();
              final List<String> ids = selectedOrders.map((e) => e.id).toList();
              DatabaseService().markOrdersAsOrdered(ids, orderId).catchError((e) {
                debugPrint('Error marking orders: $e');
              });
              
              setState(() {
                _selectedOrderIds.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('Mark as Ordered'),
          ),
        ],
      ),
    );
  }

  void _markAsReceived(BuildContext context, String orderId, List<ProductOrderModel> items) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Delivery'),
        content: Text('Have all ${items.length} items in this order arrived? Status will be updated to completed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              SoundHelper.playSuccess();
              DatabaseService().markOrderAsReceived(orderId).catchError((e) {
                debugPrint('Error marking order received: $e');
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order marked as received! Add new stock inside Stock Management.')),
              );
            },
            child: const Text('Mark Received'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteOrder(BuildContext context, ProductOrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Need?'),
        content: Text('Are you sure you want to remove "${order.productName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              SoundHelper.playSuccess();
              DatabaseService().deleteProductOrder(order.id).catchError((e) {
                debugPrint('Error deleting product order: $e');
              });
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCombinedOrder(BuildContext context, List<ProductOrderModel> items) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Order?'),
        content: Text('Are you sure you want to delete this combined order containing ${items.length} items?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              SoundHelper.playSuccess();
              for (final item in items) {
                DatabaseService().deleteProductOrder(item.id).catchError((e) {
                  debugPrint('Error deleting combined order item: $e');
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddOrderDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateProductOrdersDialog(
        shopId: widget.shopId,
        existingProductNames: _existingProductNames,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order List - ${ShopHelper.getDisplayName(widget.shopId)}'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryIvory,
          unselectedLabelColor: AppTheme.primaryIvory.withValues(alpha: 0.5),
          indicatorColor: AppTheme.primaryIvory,
          tabs: const [
            Tab(text: 'Pending', icon: Icon(Icons.hourglass_empty_rounded)),
            Tab(text: 'Ordered', icon: Icon(Icons.local_shipping_rounded)),
            Tab(text: 'Completed', icon: Icon(Icons.check_circle_rounded)),
          ],
        ),
      ),
      body: StreamBuilder<List<ProductOrderModel>>(
        stream: DatabaseService().getProductOrders(widget.shopId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allOrders = snapshot.data ?? [];
          return TabBarView(
            controller: _tabController,
            children: [
              _buildPendingTab(allOrders),
              _buildOrderedTab(allOrders),
              _buildCompletedTab(allOrders),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOrderDialog,
        backgroundColor: AppTheme.accentForest,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPendingTab(List<ProductOrderModel> allOrders) {
    final pendingOrders = allOrders.where((o) => o.status == 'pending').toList();

    if (pendingOrders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No pending items. Click + to add needed products.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_selectedOrderIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppTheme.secondaryIvory,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedOrderIds.length} Selected',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentForest),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final selectedList = pendingOrders.where((o) => _selectedOrderIds.contains(o.id)).toList();
                    _shareWithDealer(selectedList);
                  },
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Share to Dealer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentForest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: pendingOrders.length,
            itemBuilder: (context, index) {
              final ord = pendingOrders[index];
              final isSelected = _selectedOrderIds.contains(ord.id);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: CheckboxListTile(
                  value: isSelected,
                  activeColor: AppTheme.accentForest,
                  checkColor: Colors.white,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedOrderIds.add(ord.id);
                      } else {
                        _selectedOrderIds.remove(ord.id);
                      }
                    });
                  },
                  title: Text(
                    ord.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Quantity Need: ${ord.quantity}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.accentForest)),
                      if (ord.note != null && ord.note!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Note: ${ord.note}', style: const TextStyle(color: Colors.black54, fontStyle: FontStyle.italic)),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Created: ${DateFormat('dd MMM yyyy, hh:mm a').format(ord.createdAt)}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _confirmDeleteOrder(context, ord),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderedTab(List<ProductOrderModel> allOrders) {
    final orderedOrders = allOrders.where((o) => o.status == 'ordered').toList();

    if (orderedOrders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No active orders. Share pending items to dealers.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Group items by orderId
    final Map<String, List<ProductOrderModel>> groups = {};
    for (final item in orderedOrders) {
      final key = item.orderId ?? 'un-grouped';
      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(item);
    }

    final keys = groups.keys.toList();
    keys.sort((a, b) {
      final timeA = groups[a]!.first.orderedAt ?? groups[a]!.first.createdAt;
      final timeB = groups[b]!.first.orderedAt ?? groups[b]!.first.createdAt;
      return timeB.compareTo(timeA);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final orderId = keys[index];
        final items = groups[orderId]!;
        final firstItem = items.first;
        final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(firstItem.orderedAt ?? firstItem.createdAt);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Combined Order Request',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.accentForest),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _confirmDeleteCombinedOrder(context, items),
                    ),
                  ],
                ),
                Text('Ordered: $dateStr', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const Divider(height: 20),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5.0),
                        child: Icon(Icons.circle, size: 8, color: AppTheme.accentForest),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.productName} (Qty: ${item.quantity})',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            if (item.note != null && item.note!.isNotEmpty)
                              Text(
                                'Note: ${item.note}',
                                style: const TextStyle(color: Colors.black54, fontStyle: FontStyle.italic, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => _markAsReceived(context, orderId, items),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Mark Received'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentForest,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompletedTab(List<ProductOrderModel> allOrders) {
    final completedOrders = allOrders.where((o) => o.status == 'completed').toList();

    if (completedOrders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No completed orders found.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Group items by orderId
    final Map<String, List<ProductOrderModel>> groups = {};
    for (final item in completedOrders) {
      final key = item.orderId ?? 'un-grouped';
      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(item);
    }

    final keys = groups.keys.toList();
    keys.sort((a, b) {
      final timeA = groups[a]!.first.orderedAt ?? groups[a]!.first.createdAt;
      final timeB = groups[b]!.first.orderedAt ?? groups[b]!.first.createdAt;
      return timeB.compareTo(timeA);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final orderId = keys[index];
        final items = groups[orderId]!;
        final firstItem = items.first;
        final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(firstItem.orderedAt ?? firstItem.createdAt);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.green.shade50.withValues(alpha: 0.8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Order Arrived',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _confirmDeleteCombinedOrder(context, items),
                    ),
                  ],
                ),
                Text('Ordered: $dateStr', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const Divider(height: 20),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5.0),
                        child: Icon(Icons.circle, size: 8, color: Colors.green),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.productName} (Qty: ${item.quantity})',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            if (item.note != null && item.note!.isNotEmpty)
                              Text(
                                'Note: ${item.note}',
                                style: const TextStyle(color: Colors.black54, fontStyle: FontStyle.italic, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Dialog to support entering multiple product orders dynamically
class CreateProductOrdersDialog extends StatefulWidget {
  final String shopId;
  final List<String> existingProductNames;

  const CreateProductOrdersDialog({
    super.key,
    required this.shopId,
    required this.existingProductNames,
  });

  @override
  State<CreateProductOrdersDialog> createState() => _CreateProductOrdersDialogState();
}

class _CreateProductOrdersDialogState extends State<CreateProductOrdersDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<DraftOrderItem> _drafts = [];

  @override
  void initState() {
    super.initState();
    // Start with 1 row
    _addRow();
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _drafts.add(DraftOrderItem());
    });
  }

  void _removeRow(int index) {
    if (_drafts.length <= 1) return;
    setState(() {
      _drafts[index].dispose();
      _drafts.removeAt(index);
    });
  }

  void _saveList() {
    if (!_formKey.currentState!.validate()) return;

    SoundHelper.playSuccess();
    final now = DateTime.now();
    for (final draft in _drafts) {
      final productName = draft.nameController?.text.trim() ?? '';
      final qty = int.tryParse(draft.qtyController.text) ?? 1;
      final note = draft.noteController.text.trim();

      if (productName.isNotEmpty) {
        final order = ProductOrderModel(
          id: const Uuid().v4(),
          productName: productName,
          quantity: qty,
          status: 'pending',
          createdAt: now,
          shopId: widget.shopId,
          note: note.isNotEmpty ? note : null,
        );
        DatabaseService().addProductOrder(order).catchError((e) {
          debugPrint('Error saving order: $e');
        });
      }
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product order list saved successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Needed Products'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: _saveList,
              child: const Text('SAVE LIST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Add one or multiple products needed for stock. You can type any name, and details can be shared with the dealer.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _drafts.length,
                  itemBuilder: (context, index) {
                    final draft = _drafts[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Product #${index + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentForest),
                                ),
                                if (_drafts.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () => _removeRow(index),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Autocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return const Iterable<String>.empty();
                                }
                                return widget.existingProductNames.where((String option) {
                                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                });
                              },
                              onSelected: (String selection) {
                                if (draft.nameController != null) {
                                  draft.nameController!.text = selection;
                                }
                              },
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                draft.nameController = controller;
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: const InputDecoration(
                                    labelText: 'Product Name *',
                                    hintText: 'Type product name...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter product name' : null,
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: draft.qtyController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Qty *',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    validator: (val) {
                                      if (val == null || int.tryParse(val) == null || int.parse(val) <= 0) {
                                        return 'Invalid Qty';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 4,
                                  child: TextFormField(
                                    controller: draft.noteController,
                                    textCapitalization: TextCapitalization.sentences,
                                    decoration: const InputDecoration(
                                      labelText: 'Notes (optional)',
                                      hintText: 'e.g. Blue color, urgent',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add, color: AppTheme.accentForest),
                    label: const Text('Add Another Product', style: TextStyle(color: AppTheme.accentForest, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.accentForest),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DraftOrderItem {
  TextEditingController? nameController;
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController noteController = TextEditingController();

  void dispose() {
    qtyController.dispose();
    noteController.dispose();
  }
}
