import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/shop_helper.dart';

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
                      final bool isLowStock = product.units < 5;
                      final bool isOutOfStock = product.units == 0;

                      return Card(
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
                                    child: Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: AppTheme.charcoalBlack,
                                      ),
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
}
