import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/shop_helper.dart';
import '../../utils/sound_helper.dart';
import 'package:uuid/uuid.dart';
import '../stock_search_screen.dart';

class StockManagementScreen extends StatefulWidget {
  const StockManagementScreen({super.key});

  @override
  State<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Stream<List<CategoryModel>> _categoriesStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _categoriesStream = DatabaseService().getCategories();
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
        title: const Text('Stock Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockSearchScreen(isOwner: true))),
            tooltip: 'Search Stock',
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            onPressed: () => _showCategoryManagementDialog(context),
            tooltip: 'Manage Categories',
          ),
        ],
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
        children: [
          _buildStockList('Shop 1'),
          _buildStockList('Shop 2'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProductDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStockList(String shopId) {
    return StreamBuilder<List<ProductModel>>(
      stream: DatabaseService().getProducts(shopId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No products found in this shop', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final bool lowStock = product.units < 5;
            
            return Card(
              child: InkWell(
                onTap: () => _showUpdateStockDialog(context, product),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.accentForest.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.inventory_2, color: AppTheme.accentForest),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoalBlack),
                            ),
                            Row(
                              children: [
                                Text(
                                  product.category,
                                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                                ),
                                if (product.location.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentForest.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      product.location,
                                      style: const TextStyle(
                                        color: AppTheme.accentForest,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '\u20B9${product.price.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.accentForest),
                                ),
                                if (product.costPrice > 0) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cost: \u20B9${product.costPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Margin: \u20B9${(product.price - product.costPrice).toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: (product.price - product.costPrice) >= 0 ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: lowStock ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${product.units} units',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: lowStock ? Colors.red : Colors.green,
                              ),
                            ),
                          ),
                           const SizedBox(height: 4),
                           Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Icon(
                                 lowStock ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                 size: 16,
                                 color: lowStock ? Colors.red : Colors.green,
                               ),
                               const SizedBox(width: 12),
                               IconButton(
                                 constraints: const BoxConstraints(),
                                 padding: EdgeInsets.zero,
                                 icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                 onPressed: () => _confirmDeleteProduct(context, product),
                               ),
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
                debugPrint('Error deleting product in background: $e');
              });
              await Future.delayed(const Duration(milliseconds: 500));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCategoryManagementDialog(BuildContext context) {
    final List<TextEditingController> controllers = [TextEditingController()];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Categories'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: StreamBuilder<List<CategoryModel>>(
              stream: _categoriesStream,
              builder: (context, snapshot) {
                final categories = snapshot.data ?? [];
                return StatefulBuilder(
                  builder: (context, setDialogState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...List.generate(controllers.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controllers[index],
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: InputDecoration(
                                      labelText: 'Category Name ${index + 1}',
                                      hintText: 'e.g. BATTERY',
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                if (controllers.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () {
                                      setDialogState(() {
                                        controllers[index].dispose();
                                        controllers.removeAt(index);
                                      });
                                    },
                                  ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 4),
                        TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Another Category'),
                          onPressed: () {
                            setDialogState(() {
                              controllers.add(TextEditingController());
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.maxFinite,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('Save Categories'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentForest,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              final List<String> enteredNames = controllers
                                  .map((c) => c.text.trim())
                                  .where((text) => text.isNotEmpty)
                                  .toList();
                                  
                              if (enteredNames.isNotEmpty) {
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                
                                SoundHelper.playSuccess();
                                Navigator.pop(context);

                                int addedCount = 0;
                                int duplicateCount = 0;
                                final seenNames = <String>{};
                                
                                for (var name in enteredNames) {
                                  if (seenNames.contains(name.toLowerCase())) {
                                    duplicateCount++;
                                    continue;
                                  }
                                  seenNames.add(name.toLowerCase());
                                  
                                  final isDuplicate = categories.any((cat) => cat.name.trim().toLowerCase() == name.toLowerCase());
                                  if (isDuplicate) {
                                    duplicateCount++;
                                    continue;
                                  }
                                  final cat = CategoryModel(id: const Uuid().v4(), name: name);
                                  await DatabaseService().addCategory(cat);
                                  addedCount++;
                                }
                                
                                if (addedCount > 0) {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(content: Text('Successfully added $addedCount categories!')),
                                  );
                                }
                                if (duplicateCount > 0) {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(content: Text('Skipped $duplicateCount duplicate entries.')),
                                  );
                                }

                                for (var c in controllers) {
                                  c.dispose();
                                }
                              }
                            },
                          ),
                        ),
                        const Divider(),
                    if (snapshot.hasError)
                      Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 10))
                    else if (snapshot.connectionState == ConnectionState.waiting)
                      const LinearProgressIndicator()
                    else if (categories.isEmpty)
                      const Center(child: Text('No categories yet', style: TextStyle(fontSize: 12, color: Colors.grey)))
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          return ListTile(
                            title: Text(cat.name),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () async {
                                SoundHelper.playSuccess();
                                DatabaseService().deleteCategory(cat.id).catchError((e) {
                                  debugPrint('Error deleting category in background: $e');
                                });
                              },
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final costPriceController = TextEditingController();
    final unitsController = TextEditingController();
    final locationController = TextEditingController();
    String? selectedCategory;
    String selectedShop = _tabController.index == 0 ? 'Shop 1' : 'Shop 2';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Product'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController, 
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Product Name *'),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<CategoryModel>>(
                    stream: _categoriesStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 10));
                      final categories = snapshot.data ?? [];
                      final uniqueCategoryNames = categories.map((cat) => cat.name.trim()).toSet().toList();
                      String? dropdownValue = selectedCategory;
                      if (dropdownValue != null && !uniqueCategoryNames.contains(dropdownValue)) {
                        dropdownValue = null;
                      }
                      return DropdownButtonFormField<String>(
                        value: dropdownValue,
                        decoration: const InputDecoration(labelText: 'Category *'),
                        items: uniqueCategoryNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                        onChanged: (val) => setDialogState(() => selectedCategory = val),
                        validator: (val) => val == null ? 'Required' : null,
                        hint: const Text('Select Category'),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: priceController, 
                    decoration: const InputDecoration(labelText: 'Selling Price *', prefixText: '\u20B9 '),
                    keyboardType: TextInputType.number,
                    validator: (val) => (val == null || double.tryParse(val) == null) ? 'Invalid' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: costPriceController, 
                    decoration: const InputDecoration(labelText: 'Purchase / Cost Price *', prefixText: '\u20B9 ', helperText: 'What you paid to buy this item'),
                    keyboardType: TextInputType.number,
                    validator: (val) => (val == null || double.tryParse(val) == null) ? 'Invalid cost price' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: unitsController, 
                    decoration: const InputDecoration(labelText: 'Initial Units *'),
                    keyboardType: TextInputType.number,
                    validator: (val) => (val == null || int.tryParse(val) == null) ? 'Invalid units' : null,
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
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedShop,
                    items: [
                      DropdownMenuItem(value: 'Shop 1', child: Text(ShopHelper.getDisplayName('Shop 1'))),
                      DropdownMenuItem(value: 'Shop 2', child: Text(ShopHelper.getDisplayName('Shop 2'))),
                    ],
                    onChanged: (val) => selectedShop = val!,
                    decoration: const InputDecoration(labelText: 'Target Shop'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate() || selectedCategory == null) return;
                final product = ProductModel(
                  id: const Uuid().v4(),
                  name: nameController.text,
                  category: selectedCategory!,
                  price: double.parse(priceController.text),
                  costPrice: double.parse(costPriceController.text),
                  units: int.parse(unitsController.text),
                  shopId: selectedShop,
                  location: locationController.text.trim(),
                );
                SoundHelper.playSuccess();
                DatabaseService().addProduct(product).catchError((e) {
                  debugPrint('Error adding product in background: $e');
                });
                await Future.delayed(const Duration(milliseconds: 500));
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add Product'),
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
                    'Edit Product: ${product.name}',
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
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Selling Price *', prefixText: '\u20B9 '),
                      keyboardType: TextInputType.number,
                      validator: (val) => (val == null || double.tryParse(val) == null) ? 'Invalid price' : null,
                    ),
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
                          final updatedProduct = product.copyWith(
                            name: nameController.text.trim(),
                            price: double.parse(priceController.text),
                            costPrice: double.parse(costPriceController.text),
                            units: int.parse(totalUnitsController.text),
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
}
