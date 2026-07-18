import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/enquiry_model.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../models/sale_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/shop_helper.dart';
import '../../utils/sound_helper.dart';
import '../sales/sale_bill_screen.dart';

class EnquiryManagementScreen extends StatefulWidget {
  final String? shopId; // If null, the user is the Owner and can toggle/see both shops
  final bool isOwner;

  const EnquiryManagementScreen({super.key, this.shopId, required this.isOwner});

  @override
  State<EnquiryManagementScreen> createState() => _EnquiryManagementScreenState();
}

class _EnquiryManagementScreenState extends State<EnquiryManagementScreen> {
  late String _selectedShop;
  String _statusFilter = 'All'; // 'All', 'pending', 'ordered', 'received', 'completed'
  final Set<String> _selectedEnquiryIds = {};
  late Stream<List<CategoryModel>> _categoriesStream;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedShop = widget.shopId ?? 'Shop 1';
    _categoriesStream = DatabaseService().getCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _launchWhatsApp(String phone, String message, {String? shopId}) async {
    String finalMessage = message;
    try {
      final settings = await DatabaseService().getGstSettings(shopId ?? _selectedShop);
      if (settings != null && settings.groupLink != null && settings.groupLink!.trim().isNotEmpty) {
        finalMessage = "$message\n\nJoin our WhatsApp Group: ${settings.groupLink!.trim()}";
      }
    } catch (_) {}

    // Normalize phone number (digits only)
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    // If they typed a leading '0' (e.g. 09566671183), remove it to get the 10-digit number
    if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      cleanPhone = cleanPhone.substring(1);
    }

    // Prepend '91' country code if only 10 digits are present
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    final String whatsappScheme = 'whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(finalMessage)}';
    final Uri whatsappUri = Uri.parse(whatsappScheme);
    
    final String waMeUrl = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(finalMessage)}';
    final Uri waMeUri = Uri.parse(waMeUrl);

    try {
      // 1. Try direct WhatsApp protocol (opens instantly)
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        // 2. Fallback to web link
        await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // 3. Fallback to share sheet
        await Share.share(finalMessage, subject: shopId != null ? ShopHelper.getDisplayName(shopId) : ShopHelper.getDisplayName('Shop 1'));
      }
    }
  }

  void _shareWithDealer(List<EnquiryModel> selectedEnquiries) async {
    if (selectedEnquiries.isEmpty) return;

    final String dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('📋 *${ShopHelper.getDisplayName(_selectedShop).toUpperCase()} - ORDER REQUEST* ($dateStr)');
    buffer.writeln('----------------------------------------');
    
    int index = 1;
    for (var eq in selectedEnquiries) {
      buffer.writeln('$index. *${eq.productName}*');
      buffer.writeln('   • *Qty:* ${eq.quantity}');
      if (eq.note != null && eq.note!.isNotEmpty) {
        buffer.writeln('   • *Note:* ${eq.note}');
      }
      buffer.writeln(''); // Neat spacing between items
      index++;
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('Please dispatch these items as soon as possible. Thank you!');

    await Share.share(buffer.toString(), subject: '${ShopHelper.getDisplayName(_selectedShop).toUpperCase()} - New Order Request');

    // Prompt to mark as Ordered
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Status?'),
          content: Text('Would you like to mark these ${selectedEnquiries.length} items as "Ordered"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep as Pending'),
            ),
            ElevatedButton(
              onPressed: () async {
                SoundHelper.playSuccess();
                for (var eq in selectedEnquiries) {
                  DatabaseService().updateEnquiry(eq.copyWith(status: 'ordered')).catchError((e) {
                    debugPrint('Error marking enquiry ordered in background: $e');
                  });
                }
                setState(() {
                  _selectedEnquiryIds.clear();
                });
                await Future.delayed(const Duration(milliseconds: 500));
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Mark as Ordered'),
            ),
          ],
        ),
      );
    }
  }

  void _notifyCustomer(EnquiryModel enquiry) {
    final String message = 
        'Hello ${enquiry.customerName},\n\n'
        'Great news! The item you enquired about: *${enquiry.productName}* '
        'has arrived at *${ShopHelper.getDisplayName(enquiry.shopId)}*! 📱🎉\n\n'
        'Please visit our shop at your convenience to collect it. Thank you!';

    _launchWhatsApp(enquiry.customerPhone, message, shopId: enquiry.shopId);
  }

  void _callCustomer(String phone) async {
    final String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) return;
    final Uri uri = Uri.parse('tel:$cleanPhone');
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('Error launching phone dialer: $e');
    }
  }

  void _markAsReceived(BuildContext context, EnquiryModel enquiry) async {
    final qtyController = TextEditingController(text: enquiry.quantity.toString());
    final formKey = GlobalKey<FormState>();

    final actualQty = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark Received from Dealer'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How many units of "${enquiry.productName}" did the dealer actually deliver?'),
              const SizedBox(height: 16),
              TextFormField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Received Quantity',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => (val == null || int.tryParse(val) == null || int.parse(val) <= 0) ? 'Enter valid quantity' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, int.parse(qtyController.text));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentForest, foregroundColor: Colors.white),
            child: const Text('Next'),
          ),
        ],
      ),
    );

    if (actualQty == null) return;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    // Get current products in the shop
    final products = await DatabaseService().getProducts(enquiry.shopId).first;
    if (mounted) Navigator.pop(context);

    // Search for a product with matching name (case-insensitive)
    ProductModel? existingProduct;
    for (var prod in products) {
      if (prod.name.toLowerCase().trim() == enquiry.productName.toLowerCase().trim()) {
        existingProduct = prod;
        break;
      }
    }

    if (existingProduct != null) {
      // Product exists -> Ask to add to stock
      if (mounted) {
        final ProductModel product = existingProduct;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Product Exists in Stock'),
            content: Text(
              'The product "${product.name}" was found in ${enquiry.shopId} stock '
              'with ${product.units} units.\n\n'
              'Would you like to add it to stock or deliver it directly?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              OutlinedButton(
                onPressed: () async {
                  SoundHelper.playSuccess();
                  DatabaseService().updateStock(product.id, product.units + actualQty).catchError((e) {
                    debugPrint('Error updating stock in background: $e');
                  });
                  DatabaseService().updateEnquiry(enquiry.copyWith(status: 'received')).catchError((e) {
                    debugPrint('Error updating enquiry in background: $e');
                  });
                  await Future.delayed(const Duration(milliseconds: 500));
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added $actualQty units to "${product.name}" stock!')),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentForest),
                child: const Text('Add to Stock'),
              ),
              ElevatedButton(
                onPressed: () async {
                  SoundHelper.playSuccess();
                  Navigator.pop(context);
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SaleBillScreen(
                          shopId: enquiry.shopId,
                          employeeName: widget.isOwner ? 'Owner' : 'Staff',
                          prefilledCustomerName: enquiry.customerName,
                          prefilledCustomerPhone: enquiry.customerPhone,
                          enquiryId: enquiry.id,
                          prefilledCart: [
                            CartItem(
                              productId: 'temp_${product.id}',
                              productName: product.name,
                              category: product.category,
                              quantity: actualQty,
                              price: product.price,
                              costPrice: product.costPrice,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentForest, foregroundColor: Colors.white),
                child: const Text('Direct Delivery'),
              ),
            ],
          ),
        );
      }
    } else {
      // Product does not exist -> Suggest creating it
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('New Product Required'),
            content: Text(
              'The product "${enquiry.productName}" is not registered in ${enquiry.shopId} stock.\n\n'
              'Would you like to register it to stock or deliver it directly?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddProductDialog(
                    context, 
                    prefilledName: enquiry.productName.toUpperCase(), 
                    prefilledUnits: actualQty,
                    targetEnquiry: enquiry,
                    isDirectDelivery: false,
                  );
                },
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentForest),
                child: const Text('Register to Stock'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddProductDialog(
                    context, 
                    prefilledName: enquiry.productName.toUpperCase(), 
                    prefilledUnits: actualQty,
                    targetEnquiry: enquiry,
                    isDirectDelivery: true,
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentForest, foregroundColor: Colors.white),
                child: const Text('Direct Delivery'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showAddProductDialog(
    BuildContext context, {
    required String prefilledName, 
    required int prefilledUnits,
    required EnquiryModel targetEnquiry,
    bool isDirectDelivery = false,
  }) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: prefilledName);
    final priceController = TextEditingController();
    final costPriceController = TextEditingController();
    final unitsController = TextEditingController(text: prefilledUnits.toString());
    final locationController = TextEditingController();
    String? selectedCategory;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isDirectDelivery ? 'Register & Deliver Product' : 'Register New Product'),
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
                  if (widget.isOwner) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: costPriceController, 
                      decoration: const InputDecoration(labelText: 'Purchase / Cost Price *', prefixText: '\u20B9 '),
                      keyboardType: TextInputType.number,
                      validator: (val) => (val == null || double.tryParse(val) == null) ? 'Invalid cost price' : null,
                    ),
                  ],
                  if (!isDirectDelivery) ...[
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
                  ],
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
                  name: nameController.text.trim(),
                  category: selectedCategory!,
                  price: double.parse(priceController.text),
                  costPrice: widget.isOwner ? (double.tryParse(costPriceController.text) ?? 0.0) : 0.0,
                  units: isDirectDelivery ? prefilledUnits : int.parse(unitsController.text),
                  shopId: targetEnquiry.shopId,
                  location: isDirectDelivery ? '' : locationController.text.trim(),
                );
                SoundHelper.playSuccess();
                if (!isDirectDelivery) {
                  DatabaseService().addProduct(product).catchError((e) {
                    debugPrint('Error registering product in background: $e');
                  });
                }
                
                if (!isDirectDelivery) {
                  DatabaseService().updateEnquiry(
                    targetEnquiry.copyWith(status: 'received')
                  ).catchError((e) {
                    debugPrint('Error updating enquiry status in background: $e');
                  });
                }
                
                Navigator.pop(context);
                
                if (isDirectDelivery) {
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SaleBillScreen(
                          shopId: targetEnquiry.shopId,
                          employeeName: widget.isOwner ? 'Owner' : 'Staff',
                          prefilledCustomerName: targetEnquiry.customerName,
                          prefilledCustomerPhone: targetEnquiry.customerPhone,
                          enquiryId: targetEnquiry.id,
                          prefilledCart: [
                            CartItem(
                              productId: 'temp_${product.id}',
                              productName: product.name,
                              category: product.category,
                              quantity: product.units,
                              price: product.price,
                              costPrice: product.costPrice,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                } else {
                  await Future.delayed(const Duration(milliseconds: 500));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Registered "${product.name}" and marked enquiry as Received!')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentForest, foregroundColor: Colors.white),
              child: Text(isDirectDelivery ? 'Deliver Product' : 'Add Product'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEnquiryDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final productController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final noteController = TextEditingController();
    String targetShop = widget.shopId ?? _selectedShop;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    List<ProductModel> allProducts = [];
    try {
      allProducts = await DatabaseService().getProducts(targetShop).first;
    } catch (_) {}

    if (context.mounted) {
      Navigator.pop(context);
    } else {
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Record New Customer Enquiry'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RawAutocomplete<ProductModel>(
                      textEditingController: productController,
                      focusNode: FocusNode(),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.trim().isEmpty) {
                          return const Iterable<ProductModel>.empty();
                        }
                        final query = textEditingValue.text.toLowerCase().trim();
                        final queryTokens = query.split(RegExp(r'\s+'));
                        return allProducts.where((prod) {
                          final name = prod.name.toLowerCase();
                          return queryTokens.every((token) => name.contains(token));
                        });
                      },
                      displayStringForOption: (ProductModel option) => option.name,
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Requested Product / Model *',
                            hintText: 'e.g. SAMSUNG M21 CASE',
                            prefixIcon: Icon(Icons.phone_android_outlined),
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 280,
                              color: Colors.white,
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final p = options.elementAt(index);
                                  final label = widget.isOwner 
                                      ? '${p.name} (${p.units} in stock | Cost: ₹${p.costPrice.toStringAsFixed(0)})'
                                      : '${p.name} (${p.units} in stock)';
                                  return ListTile(
                                    leading: const Icon(Icons.shopping_bag_outlined, color: Colors.orange, size: 16),
                                    title: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    dense: true,
                                    onTap: () => onSelected(p),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: qtyController,
                    decoration: const InputDecoration(labelText: 'Quantity Needed *', prefixIcon: Icon(Icons.numbers)),
                    keyboardType: TextInputType.number,
                    validator: (val) => (val == null || int.tryParse(val) == null || int.parse(val) <= 0) ? 'Invalid qty' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Customer Name *', prefixIcon: Icon(Icons.person_outline)),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Phone (10 digits, Optional)', 
                      prefixIcon: Icon(Icons.phone_outlined),
                      hintText: 'e.g. 9566671183',
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (val) {
                      if (val == null || val.isEmpty) return null;
                      if (val.length != 10) return 'Must be exactly 10 digits';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes / Comments (Optional)', prefixIcon: Icon(Icons.edit_note_outlined)),
                  ),
                  if (widget.shopId == null) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: targetShop,
                      items: [
                        DropdownMenuItem(value: 'Shop 1', child: Text(ShopHelper.getDisplayName('Shop 1'))),
                        DropdownMenuItem(value: 'Shop 2', child: Text(ShopHelper.getDisplayName('Shop 2'))),
                      ],
                      onChanged: (val) async {
                        targetShop = val!;
                        final list = await DatabaseService().getProducts(targetShop).first;
                        setDialogState(() {
                          allProducts = list;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Target Shop'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final enquiry = EnquiryModel(
                  id: const Uuid().v4(),
                  customerName: nameController.text.trim(),
                  customerPhone: phoneController.text.trim(),
                  productName: productController.text.trim().toUpperCase(),
                  quantity: int.parse(qtyController.text),
                  createdAt: DateTime.now(),
                  shopId: targetShop,
                  status: 'pending',
                  note: noteController.text.trim(),
                );
                SoundHelper.playSuccess();
                DatabaseService().addEnquiry(enquiry).catchError((e) {
                  debugPrint('Error saving enquiry in background: $e');
                });
                await Future.delayed(const Duration(milliseconds: 500));
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save Enquiry'),
            ),
          ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String value, {String? label}) {
    final isSelected = _statusFilter == value;
    final displayLabel = label ?? value;
    return FilterChip(
      selected: isSelected,
      label: Text(
        displayLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isSelected ? AppTheme.primaryIvory : AppTheme.accentForest,
        ),
      ),
      selectedColor: AppTheme.accentForest,
      backgroundColor: AppTheme.primaryIvory,
      checkmarkColor: AppTheme.primaryIvory,
      onSelected: (selected) {
        setState(() {
          _statusFilter = value;
          _selectedEnquiryIds.clear(); // Clear selections when filtering
        });
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.accentForest, width: 1),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = Colors.red;
        label = 'Pending';
        break;
      case 'ordered':
        color = Colors.orange;
        label = 'Ordered';
        break;
      case 'received':
        color = Colors.green;
        label = 'Received';
        break;
      case 'completed':
      default:
        color = Colors.grey;
        label = 'Closed';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppTheme.primaryIvory),
                cursorColor: AppTheme.primaryIvory,
                decoration: InputDecoration(
                  hintText: 'Search by name or phone...',
                  hintStyle: TextStyle(color: AppTheme.primaryIvory.withValues(alpha: 0.6)),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.primaryIvory),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text('Customer Enquiries'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Shop Toggle for Owner
          if (widget.isOwner) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 20, right: 20),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'Shop 1', label: Text(ShopHelper.getDisplayName('Shop 1')), icon: const Icon(Icons.store)),
                  ButtonSegment(value: 'Shop 2', label: Text(ShopHelper.getDisplayName('Shop 2')), icon: const Icon(Icons.storefront)),
                ],
                selected: {_selectedShop},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedShop = newSelection.first;
                    _selectedEnquiryIds.clear(); // Clear selections when switching shops
                  });
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIvory,
                  selectedBackgroundColor: AppTheme.accentForest,
                  selectedForegroundColor: AppTheme.primaryIvory,
                ),
              ),
            ),
          ],

          // Filter scrollable chips
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('pending', label: 'Pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('ordered', label: 'Ordered'),
                  const SizedBox(width: 8),
                  _buildFilterChip('received', label: 'Received'),
                  const SizedBox(width: 8),
                  _buildFilterChip('completed', label: 'Closed'),
                ],
              ),
            ),
          ),

          // List content
          Expanded(
            child: StreamBuilder<List<EnquiryModel>>(
              stream: DatabaseService().getEnquiries(widget.isOwner ? _selectedShop : widget.shopId),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final allEnquiries = snapshot.data ?? [];
                final filteredEnquiries = allEnquiries.where((e) {
                  if (_statusFilter != 'All' && e.status != _statusFilter) return false;
                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase().trim();
                    final nameMatch = e.customerName.toLowerCase().contains(query);
                    final phoneMatch = e.customerPhone.toLowerCase().contains(query);
                    return nameMatch || phoneMatch;
                  }
                  return true;
                }).toList();

                if (filteredEnquiries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mark_as_unread_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No enquiries found',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Bulk share panel for Pending items selection
                    if (_selectedEnquiryIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        color: AppTheme.secondaryIvory,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_selectedEnquiryIds.length} Selected',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentForest),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                final selectedList = filteredEnquiries.where((e) => _selectedEnquiryIds.contains(e.id)).toList();
                                _shareWithDealer(selectedList);
                              },
                              icon: const Icon(Icons.share, size: 16),
                              label: const Text('Share to Dealer'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        itemCount: filteredEnquiries.length,
                        itemBuilder: (context, index) {
                          final eq = filteredEnquiries[index];
                          final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(eq.createdAt);
                          final isSelected = _selectedEnquiryIds.contains(eq.id);

                          return Card(
                            elevation: isSelected ? 4 : 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected ? AppTheme.accentForest : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header: Selection / Product Name
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (eq.status == 'pending')
                                        Checkbox(
                                          value: isSelected,
                                          activeColor: AppTheme.accentForest,
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedEnquiryIds.add(eq.id);
                                              } else {
                                                _selectedEnquiryIds.remove(eq.id);
                                              }
                                            });
                                          },
                                        ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              eq.productName,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.charcoalBlack,
                                              ),
                                            ),
                                            Text(
                                              'Qty Required: ${eq.quantity}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.graphiteGray,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      if (widget.isOwner)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                          onPressed: () async {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Delete Enquiry?'),
                                                content: const Text('Are you sure you want to delete this enquiry?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      SoundHelper.playSuccess();
                                                      DatabaseService().deleteEnquiry(eq.id).catchError((e) {
                                                        debugPrint('Error deleting enquiry in background: $e');
                                                      });
                                                      await Future.delayed(const Duration(milliseconds: 500));
                                                      if (context.mounted) Navigator.pop(context);
                                                    },
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Details Section
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        eq.customerName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoalBlack),
                                      ),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(eq.customerPhone, style: const TextStyle(color: Colors.black54)),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.phone, size: 16, color: Colors.blue),
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _callCustomer(eq.customerPhone),
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        icon: const Icon(Icons.chat_outlined, size: 16, color: Colors.green),
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _notifyCustomer(eq),
                                      ),
                                    ],
                                  ),
                                  
                                  if (eq.note != null && eq.note!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white70,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.black12),
                                      ),
                                      child: Text(
                                        'Note: ${eq.note}',
                                        style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppTheme.graphiteGray),
                                      ),
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),
                                  
                                  // Footer Layout: Date + Status Badge (Line 1)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dateStr,
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      _statusBadge(eq.status),
                                    ],
                                  ),
                                  
                                  // Action Buttons (Line 2) - Rendered only if action is pending
                                  if (eq.status != 'completed') ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (eq.status == 'pending')
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              SoundHelper.playSuccess();
                                              DatabaseService().updateEnquiry(eq.copyWith(status: 'ordered')).catchError((e) {
                                                debugPrint('Error marking ordered in background: $e');
                                              });
                                            },
                                            icon: const Icon(Icons.local_shipping_outlined, size: 14),
                                            label: const Text('Mark Ordered', style: TextStyle(fontSize: 11)),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                          ),
                                        if (eq.status == 'ordered')
                                          ElevatedButton.icon(
                                            onPressed: () => _markAsReceived(context, eq),
                                            icon: const Icon(Icons.move_to_inbox, size: 14),
                                            label: const Text('Mark Received', style: TextStyle(fontSize: 11)),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                          ),
                                        if (eq.status == 'received') ...[
                                           OutlinedButton.icon(
                                             onPressed: () => _callCustomer(eq.customerPhone),
                                             icon: const Icon(Icons.phone_outlined, size: 14),
                                             label: const Text('Call', style: TextStyle(fontSize: 11)),
                                             style: OutlinedButton.styleFrom(
                                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                             ),
                                           ),
                                           const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: () => _notifyCustomer(eq),
                                            icon: const Icon(Icons.chat_outlined, size: 14),
                                            label: const Text('Notify', style: TextStyle(fontSize: 11)),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              final createBill = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  title: const Text('Complete Enquiry'),
                                                  content: const Text('Would you like to complete this enquiry and generate a sales bill now?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: const Text('No, just close'),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.pop(context, true),
                                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentForest, foregroundColor: Colors.white),
                                                      child: const Text('Yes, create bill'),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (createBill == null) return;
                                              SoundHelper.playSuccess();
                                              if (!createBill) {
                                                DatabaseService().updateEnquiry(eq.copyWith(status: 'completed')).catchError((e) {
                                                  debugPrint('Error completing enquiry in background: $e');
                                                });
                                              }

                                              if (context.mounted) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => SaleBillScreen(
                                                      shopId: eq.shopId,
                                                      employeeName: widget.isOwner ? 'Owner' : 'Staff',
                                                      prefilledCustomerName: eq.customerName,
                                                      prefilledCustomerPhone: eq.customerPhone,
                                                      enquiryId: eq.id,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            icon: const Icon(Icons.check, size: 14),
                                            label: const Text('Complete', style: TextStyle(fontSize: 11)),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                          ),
                                        ],
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
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEnquiryDialog(context),
        backgroundColor: AppTheme.accentForest,
        foregroundColor: AppTheme.primaryIvory,
        child: const Icon(Icons.add),
      ),
    );
  }
}
