import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/shop_helper.dart';
import '../../utils/sound_helper.dart';

class StockSearchScreen extends StatefulWidget {
  final String? shopId; // If null, defaults to Shop 1 and allows toggling for Owner
  final bool isOwner;

  const StockSearchScreen({super.key, this.shopId, required this.isOwner});

  @override
  State<StockSearchScreen> createState() => _StockSearchScreenState();
}

class _StockSearchScreenState extends State<StockSearchScreen> {
  late String _selectedShop;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedShop = widget.shopId ?? 'Shop 1';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFuzzy(String productName, String query) {
    if (query.trim().isEmpty) return true;
    
    // Normalize both strings
    String normalizedProduct = productName.toLowerCase();
    String normalizedQuery = query.toLowerCase();

    // Split the query into words/tokens
    List<String> queryWords = normalizedQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (queryWords.isEmpty) return true;

    // All query tokens must match in some way in the product name
    return queryWords.every((word) {
      // 1. Direct substring match
      if (normalizedProduct.contains(word)) return true;

      // 2. Word prefix check or small typo check (Levenshtein distance)
      List<String> productWords = normalizedProduct.split(RegExp(r'[^a-zA-Z0-9]')).where((w) => w.isNotEmpty).toList();
      return productWords.any((pWord) {
        if (pWord.startsWith(word)) return true;
        
        // Levenshtein distance check (only check if word has at least 3 characters)
        if (word.length >= 3 && pWord.length >= 3) {
          int distance = _levenshtein(word, pWord);
          int allowedDistance = word.length <= 4 ? 1 : 2;
          if (distance <= allowedDistance) return true;
        }
        return false;
      });
    });
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((a, b) => a < b ? a : b);
      }
      v0 = List<int>.from(v1);
    }
    return v0[t.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Availability'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          children: [
            // Search Input
            TextField(
              controller: _searchController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Search Phone Model or Product',
                hintText: 'e.g. SAM M21',
                prefixIcon: const Icon(Icons.search, color: AppTheme.accentForest),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.accentForest),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Shop toggle for Owner
            if (widget.isOwner) ...[
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'Shop 1', label: Text(ShopHelper.getDisplayName('Shop 1')), icon: const Icon(Icons.store)),
                  ButtonSegment(value: 'Shop 2', label: Text(ShopHelper.getDisplayName('Shop 2')), icon: const Icon(Icons.storefront)),
                ],
                selected: {_selectedShop},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedShop = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIvory,
                  selectedBackgroundColor: AppTheme.accentForest,
                  selectedForegroundColor: AppTheme.primaryIvory,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Results List
            Expanded(
              child: StreamBuilder<List<ProductModel>>(
                stream: DatabaseService().getProducts(_selectedShop),
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
                  final filteredProducts = allProducts.where((p) => _matchesFuzzy(p.name, _searchQuery)).toList();

                  if (filteredProducts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'No matching products found',
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      final bool isLowStock = product.units < 2;
                      final bool isOutOfStock = product.units == 0;

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _showUpdateStockDialog(context, product),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product Name and Stock Units
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              product.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: AppTheme.charcoalBlack,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.edit_note_rounded,
                                            size: 20,
                                            color: AppTheme.accentForest,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isOutOfStock
                                            ? Colors.red.withValues(alpha: 0.1)
                                            : (isLowStock
                                                ? Colors.orange.withValues(alpha: 0.1)
                                                : Colors.green.withValues(alpha: 0.1)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isOutOfStock
                                            ? 'Out of Stock'
                                            : '${product.units} Units',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isOutOfStock
                                              ? Colors.red
                                              : (isLowStock ? Colors.orange : Colors.green),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                
                                // Category
                                Text(
                                  product.category.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.graphiteGray,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Divider and Details
                                const Divider(height: 1, color: Colors.black12),
                                const SizedBox(height: 12),
                                
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Location info (Tray/Shelf)
                                    if (product.location.isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.accentForest),
                                          const SizedBox(width: 4),
                                          Text(
                                            product.location,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.accentForest,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      const Row(
                                        children: [
                                          Icon(Icons.location_off_outlined, size: 18, color: Colors.grey),
                                          SizedBox(width: 4),
                                          Text(
                                            'No Location Set',
                                            style: TextStyle(color: Colors.grey, fontSize: 13),
                                          ),
                                        ],
                                      ),

                                    // Price Display
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'SP: \u20B9${product.price.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.accentForest,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (widget.isOwner && product.costPrice > 0) ...[
                                          Text(
                                            'CP: \u20B9${product.costPrice.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            'Margin: \u20B9${(product.price - product.costPrice).toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: (product.price - product.costPrice) >= 0
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateStockDialog(BuildContext context, ProductModel product) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: product.name);
    final priceController = TextEditingController(text: product.price.toStringAsFixed(0));
    final costPriceController = TextEditingController(
      text: product.costPrice > 0 ? product.costPrice.toStringAsFixed(0) : '',
    );
    final addQtyController = TextEditingController();
    final totalUnitsController = TextEditingController(text: product.units.toString());
    final locationController = TextEditingController(text: product.location);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final int currentStock = product.units;
          final int addQty = int.tryParse(addQtyController.text.trim()) ?? 0;
          final int calculatedTotal = currentStock + addQty;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: AppTheme.accentForest),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Re-Stock / Edit: ${product.name}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Product Name *'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Selling Price *', prefixText: '\u20B9 '),
                      keyboardType: TextInputType.number,
                      validator: (val) => (val == null || double.tryParse(val) == null) ? 'Invalid price' : null,
                    ),
                    if (widget.isOwner) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: costPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Purchase / Cost Price *',
                          prefixText: '\u20B9 ',
                          helperText: 'What you paid to buy this item',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) => (val == null || double.tryParse(val) == null) ? 'Invalid cost price' : null,
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Stock Management & Re-Stocking Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentForest.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accentForest.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Current Available Stock:',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentForest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$currentStock Units',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: addQtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '+ Add New Quantity (Re-Stock)',
                              hintText: 'e.g. 4',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.add_circle_outline, color: AppTheme.accentForest),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (val) {
                              setDialogState(() {
                                final added = int.tryParse(val.trim()) ?? 0;
                                totalUnitsController.text = (currentStock + added).toString();
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: totalUnitsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Final Total Stock Units *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.inventory, color: AppTheme.accentForest),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            validator: (val) => (val == null || int.tryParse(val) == null) ? 'Invalid units' : null,
                          ),
                          if (addQty > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Calculation: $currentStock current + $addQty new = $calculatedTotal total units',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentForest,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: locationController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Location (Optional)',
                        hintText: 'e.g. Tray 1, Shelf B',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isOwner)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Delete Product',
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmDeleteProduct(context, product);
                          },
                        ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentForest,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final costPriceVal = widget.isOwner
                              ? (double.tryParse(costPriceController.text) ?? product.costPrice)
                              : product.costPrice;
                          final updatedUnits = int.parse(totalUnitsController.text);
                          final updatedProduct = product.copyWith(
                            name: nameController.text.trim(),
                            price: double.parse(priceController.text),
                            costPrice: costPriceVal,
                            units: updatedUnits,
                            location: locationController.text.trim(),
                          );
                          SoundHelper.playSuccess();
                          DatabaseService().addProduct(updatedProduct).catchError((e) {
                            debugPrint('Error saving product changes in background: $e');
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Updated "${updatedProduct.name}" to ${updatedProduct.units} units!'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: const Text('Save Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to remove ${product.name}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              SoundHelper.playSuccess();
              DatabaseService().deleteProduct(product.id).catchError((e) {
                debugPrint('Error deleting product: $e');
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
