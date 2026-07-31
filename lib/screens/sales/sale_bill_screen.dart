import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../models/sale_model.dart';
import '../../models/gst_settings_model.dart';
import '../../models/expense_model.dart';
import '../../models/replacement_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/shop_helper.dart';
import '../../utils/pdf_invoice_helper.dart';
import '../../utils/sound_helper.dart';
import 'package:uuid/uuid.dart';
import '../../models/pending_sale_model.dart';
import '../../widgets/shimmer.dart';

class SaleBillScreen extends StatefulWidget {
  final String shopId;
  final String employeeName;
  final String? prefilledCustomerName;
  final String? prefilledCustomerPhone;
  final List<CartItem>? prefilledCart;
  final String? enquiryId;
  
  // Exchange parameters
  final double? exchangeCredit;
  final String? returnedReplacementId;
  final String? returnedProductId;
  final String? returnedProductName;
  final String? returnedReason;
  final String? returnedSaleId;
  final double? returnedCostPrice;

  const SaleBillScreen({
    super.key,
    required this.shopId,
    required this.employeeName,
    this.prefilledCustomerName,
    this.prefilledCustomerPhone,
    this.prefilledCart,
    this.enquiryId,
    this.exchangeCredit,
    this.returnedReplacementId,
    this.returnedProductId,
    this.returnedProductName,
    this.returnedReason,
    this.returnedSaleId,
    this.returnedCostPrice,
  });

  @override
  State<SaleBillScreen> createState() => _SaleBillScreenState();
}

class _SaleBillScreenState extends State<SaleBillScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategory;
  ProductModel? _selectedProduct;
  String _productSearchQuery = '';
  final _quantityController = TextEditingController(text: '1');
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  List<String> _suggestedNames = [];
  
  final List<CartItem> _cart = [];
  bool _isLoading = false;
  bool _isGstBill = false;
  GstSettingsModel? _gstSettings;
  Stream<List<CategoryModel>>? _categoriesStream;
  Stream<List<ProductModel>>? _productsStream;

  String _paymentMode = 'Cash';
  final _cashPaidController = TextEditingController();
  final _onlinePaidController = TextEditingController();
  final _discountAmountController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _cashPaidController.dispose();
    _onlinePaidController.dispose();
    _discountAmountController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.prefilledCustomerName != null) {
      _customerNameController.text = widget.prefilledCustomerName!;
    }
    if (widget.prefilledCustomerPhone != null) {
      _customerPhoneController.text = widget.prefilledCustomerPhone!;
    }
    if (widget.prefilledCart != null) {
      _cart.addAll(widget.prefilledCart!);
    }

    // Delay database fetching and stream subscriptions to keep transition animation smooth
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() {
            _loadGstSettings();
            _categoriesStream = DatabaseService().getCategories();
            _productsStream = DatabaseService().getProducts(widget.shopId);
          });
        }
      });
    });
  }

  void _loadGstSettings() async {
    try {
      final settings = await DatabaseService().getGstSettings(widget.shopId);
      setState(() {
        _gstSettings = settings;
      });
    } catch (_) {
      // Fail silently
    }
  }

  void _addToCart() {
    if (_selectedProduct == null) return;
    
    final qty = int.tryParse(_quantityController.text) ?? 1;
    
    // Check if product already exists in cart
    final existingIndex = _cart.indexWhere((item) => item.productId == _selectedProduct!.id);
    
    if (existingIndex != -1) {
      final existingItem = _cart[existingIndex];
      final totalQty = existingItem.quantity + qty;
      
      if (totalQty > _selectedProduct!.units) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient stock for total quantity!'), backgroundColor: Colors.red)
        );
        return;
      }
      
      setState(() {
        _cart[existingIndex] = existingItem.copyWith(quantity: totalQty);
        
        // Reset product selection for next item
        _selectedProduct = null;
        _quantityController.text = '1';
      });
    } else {
      if (qty > _selectedProduct!.units) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient stock!'), backgroundColor: Colors.red)
        );
        return;
      }

      setState(() {
        _cart.add(CartItem(
          productId: _selectedProduct!.id,
          productName: _selectedProduct!.name,
          category: _selectedProduct!.category,
          quantity: qty,
          price: _selectedProduct!.price,
          costPrice: _selectedProduct!.costPrice,
        ));
        
        // Reset product selection for next item
        _selectedProduct = null;
        _quantityController.text = '1';
      });
    }
  }

  void _removeFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }

  double get _totalCartPrice => _cart.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  void _showProductSearchSheet(BuildContext context, List<ProductModel> products) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = products.where((p) {
              final query = _productSearchQuery.toLowerCase();
              return p.name.toLowerCase().contains(query) ||
                  p.location.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: AppTheme.primaryIvory,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text(
                          'Select Product',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.charcoalBlack,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${filtered.length} found',
                          style: const TextStyle(fontSize: 12, color: AppTheme.graphiteGray),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search by name or location...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _productSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setSheetState(() {
                                    _productSearchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) {
                        setSheetState(() {
                          _productSearchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No products found',
                              style: TextStyle(color: AppTheme.graphiteGray),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final p = filtered[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                title: Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.charcoalBlack,
                                  ),
                                ),
                                subtitle: p.location.isNotEmpty
                                    ? Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          margin: const EdgeInsets.only(top: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 0.5),
                                          ),
                                          child: Text(
                                            p.location,
                                            style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      )
                                    : null,
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${p.price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.accentForest,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Qty: ${p.units}',
                                      style: TextStyle(
                                        color: p.units > 0 ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedProduct = p;
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bill Generation - ${ShopHelper.getDisplayName(widget.shopId)}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.exchangeCredit != null && widget.exchangeCredit! > 0) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.accentForest.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentForest.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz, color: AppTheme.accentForest, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EXCHANGE IN PROGRESS',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentForest.withOpacity(0.8),
                                  letterSpacing: 1.2),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Returning: ${widget.returnedProductName ?? "Defective Product"}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Applied Credit: ₹${widget.exchangeCredit!.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentForest),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              _buildSectionHeader('CUSTOMER INFORMATION', Icons.person_outline),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _customerPhoneController,
                label: 'Phone Number (10 digits, Optional)',
                hint: 'e.g. 9566671183',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (val) async {
                  final cleaned = val.trim();
                  if (cleaned.length == 10) {
                    final names = await DatabaseService().findCustomerNamesByPhone(cleaned);
                    setState(() {
                      _suggestedNames = names;
                      if (names.length == 1 && _customerNameController.text.trim().isEmpty) {
                        _customerNameController.text = names.first;
                      }
                    });
                  } else {
                    if (_suggestedNames.isNotEmpty) {
                      setState(() {
                        _suggestedNames = [];
                      });
                    }
                  }
                },
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return null;
                  }
                  if (val.trim().length != 10) {
                    return 'Must be exactly 10 digits';
                  }
                  return null;
                },
              ),
              if (_suggestedNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Select from previous customer names:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _suggestedNames.map((name) {
                    return ActionChip(
                      label: Text(name),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      onPressed: () {
                        setState(() {
                          _customerNameController.text = name;
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              _buildTextField(
                controller: _customerNameController,
                label: 'Customer Name (Optional)',
                hint: 'Full Name',
                icon: Icons.badge_outlined,
                capitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Generate GST Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Add CGST/SGST tax values and print dynamic tax invoice'),
                value: _isGstBill,
                activeColor: AppTheme.accentForest,
                onChanged: (val) {
                  if (val && _gstSettings == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Warning: GST Settings not configured for this shop in Owner panel.'),
                        backgroundColor: Colors.orange,
                      )
                    );
                  }
                  setState(() {
                    _isGstBill = val;
                  });
                },
              ),
              const Divider(height: 48),
              _buildSectionHeader('ADD PRODUCTS TO BILL', Icons.add_shopping_cart_rounded),
              const SizedBox(height: 16),
              _categoriesStream == null
                  ? Shimmer.fieldSkeleton()
                  : StreamBuilder<List<CategoryModel>>(
                      stream: _categoriesStream,
                      builder: (context, catSnapshot) {
                        if (!catSnapshot.hasData) return Shimmer.fieldSkeleton();
                        final uniqueCategoryNames = catSnapshot.data!.map((c) => c.name.trim()).toSet().toList();
                        String? dropdownValue = _selectedCategory;
                        if (dropdownValue != null && !uniqueCategoryNames.contains(dropdownValue)) {
                          dropdownValue = null;
                        }
                        return Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return uniqueCategoryNames;
                            }
                            return uniqueCategoryNames.where((String option) {
                              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                            });
                          },
                          onSelected: (String selection) {
                            setState(() {
                              _selectedCategory = selection;
                              _selectedProduct = null;
                            });
                          },
                          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                            if (dropdownValue != null && textEditingController.text.isEmpty) {
                              textEditingController.text = dropdownValue;
                            }
                            return TextFormField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Select Category',
                                hintText: 'Search category...',
                                prefixIcon: const Icon(Icons.category_outlined, size: 20),
                                suffixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _selectedCategory = val.trim();
                                  _selectedProduct = null;
                                });
                              },
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Required';
                                if (!uniqueCategoryNames.contains(val.trim())) return 'Select valid category';
                                return null;
                              },
                            );
                          },
                        );
                      },
                    ),
              const SizedBox(height: 16),
              _productsStream == null
                  ? Shimmer.fieldSkeleton()
                  : StreamBuilder<List<ProductModel>>(
                      stream: _productsStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return Shimmer.fieldSkeleton();
                        final allProducts = snapshot.data!;
                        final products = _selectedCategory == null 
                          ? <ProductModel>[] 
                          : allProducts.where((p) => p.category == _selectedCategory).toList();

                        return TextFormField(
                          key: ValueKey('prod_field_${_selectedProduct?.id}_$_selectedCategory'),
                          decoration: InputDecoration(
                            labelText: _selectedCategory == null ? 'Select Category First' : 'Select Product',
                            hintText: _selectedProduct != null 
                                ? '${_selectedProduct!.name} (Qty: ${_selectedProduct!.units})' 
                                : 'Tap to search product...',
                            hintStyle: TextStyle(
                              color: _selectedProduct != null 
                                  ? AppTheme.charcoalBlack 
                                  : AppTheme.graphiteGray,
                              fontWeight: _selectedProduct != null 
                                  ? FontWeight.w600 
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(Icons.shopping_bag_outlined, size: 20),
                            suffixIcon: const Icon(Icons.search_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          readOnly: true,
                          onTap: _selectedCategory == null 
                            ? null 
                            : () {
                                setState(() {
                                  _productSearchQuery = '';
                                });
                                _showProductSearchSheet(context, products);
                              },
                        );
                      },
                    ),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(
                     flex: 2,
                     child: _buildTextField(
                      controller: _quantityController,
                      label: 'Quantity',
                      hint: 'Units',
                      icon: Icons.numbers_outlined,
                      keyboardType: TextInputType.number,
                    ),
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     flex: 3,
                     child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        onPressed: _selectedProduct == null ? null : _addToCart,
                        label: const Text('ADD TO LIST'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                     ),
                   ),
                ],
              ),
              const SizedBox(height: 32),
              if (_cart.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSectionHeader('CURRENT BILL', Icons.list_alt_rounded),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _cart.length,
                  itemBuilder: (context, index) {
                    final item = _cart[index];
                    return Card(
                      child: ListTile(
                        title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Qty: ${item.quantity} x ₹${item.price}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₹${(item.price * item.quantity).toStringAsFixed(0)}', 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => _removeFromCart(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              if (_cart.isNotEmpty || _selectedProduct != null) ...[
                const Divider(height: 48),
                _buildTextField(
                  controller: _discountAmountController,
                  label: 'Discount Amount (₹)',
                  hint: 'Enter discount amount',
                  icon: Icons.discount_outlined,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() {}),
                ),
                const SizedBox(height: 16),
                _buildOrderSummary(),
                Builder(
                  builder: (context) {
                    double subtotal = 0;
                    if (_cart.isNotEmpty) {
                      subtotal = _totalCartPrice;
                    } else if (_selectedProduct != null) {
                      final qty = int.tryParse(_quantityController.text) ?? 1;
                      subtotal = _selectedProduct!.price * qty;
                    }
                    final double discount = double.tryParse(_discountAmountController.text) ?? 0.0;
                    final double exchangeCredit = widget.exchangeCredit ?? 0.0;
                    final double netPayable = (subtotal - discount - exchangeCredit).clamp(0.0, double.infinity);
                    
                    if (netPayable <= 0.0 && (exchangeCredit > 0 || discount > 0)) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.green),
                            SizedBox(width: 12),
                            Expanded(child: Text('Exchange credit covers this purchase. No customer payment required.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                          ],
                        ),
                      );
                    }
                    return _buildPaymentModeSelector(netPayable);
                  }
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.receipt_long_rounded),
                          onPressed: _issueFullBill,
                          label: Text(widget.employeeName != 'Owner' && (double.tryParse(_discountAmountController.text) ?? 0.0) > 0
                              ? 'REQUEST APPROVAL'
                              : (widget.exchangeCredit != null && widget.exchangeCredit! > 0 
                                  ? 'COMPLETE EXCHANGE' 
                                  : (_cart.isEmpty ? 'GENERATE BILL' : 'GENERATE FULL BILL'))),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                            backgroundColor: widget.exchangeCredit != null && widget.exchangeCredit! > 0 
                              ? AppTheme.accentForest 
                              : null,
                            foregroundColor: widget.exchangeCredit != null && widget.exchangeCredit! > 0 
                              ? Colors.white 
                              : null,
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentModeSelector(double totalAmount) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECT PAYMENT MODE',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _paymentMode,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: ['Cash', 'Online', 'Split'].map((mode) => DropdownMenuItem<String>(
              value: mode,
              child: Text(mode),
            )).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _paymentMode = val;
                  if (val == 'Split') {
                    _cashPaidController.text = (totalAmount / 2).toStringAsFixed(0);
                    _onlinePaidController.text = (totalAmount - (totalAmount / 2).floor()).toStringAsFixed(0);
                  } else {
                    _cashPaidController.clear();
                    _onlinePaidController.clear();
                  }
                });
              }
            },
          ),
          if (_paymentMode == 'Split') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cashPaidController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cash Paid (₹)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final cash = double.tryParse(val) ?? 0.0;
                      if (cash <= totalAmount) {
                        _onlinePaidController.text = (totalAmount - cash).toStringAsFixed(0);
                      }
                    },
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final val = double.tryParse(v);
                      if (val == null || val < 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _onlinePaidController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Online Paid (₹)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final online = double.tryParse(val) ?? 0.0;
                      if (online <= totalAmount) {
                        _cashPaidController.text = (totalAmount - online).toStringAsFixed(0);
                      }
                    },
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final val = double.tryParse(v);
                      if (val == null || val < 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      validator: validator,
    );
  }

  Widget _buildOrderSummary() {
    double subtotal = 0;
    int itemCount = 0;

    if (_cart.isNotEmpty) {
      subtotal = _totalCartPrice;
      itemCount = _cart.length;
    } else if (_selectedProduct != null) {
      final qty = int.tryParse(_quantityController.text) ?? 1;
      subtotal = _selectedProduct!.price * qty;
      itemCount = 1;
    }

    final double discount = double.tryParse(_discountAmountController.text) ?? 0.0;
    final double exchangeCredit = widget.exchangeCredit ?? 0.0;
    final double netPayable = (subtotal - discount - exchangeCredit).clamp(0.0, double.infinity);
    final double refundDue = (exchangeCredit - (subtotal - discount)).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL ORDER SUMMARY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text('$itemCount Items', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          _buildSummaryRow('Total Items', '$itemCount', false),
          const SizedBox(height: 8),
          _buildSummaryRow('Subtotal', '₹${subtotal.toStringAsFixed(2)}', false),
          if (discount > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow('Discount', '-₹${discount.toStringAsFixed(2)}', false),
          ],
          if (exchangeCredit > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow('Exchange Credit', '-₹${exchangeCredit.toStringAsFixed(2)}', false),
            const SizedBox(height: 8),
            if (refundDue > 0)
              _buildSummaryRow('Refund Due Customer', '₹${refundDue.toStringAsFixed(2)}', true)
            else
              _buildSummaryRow('Net Payable', '₹${netPayable.toStringAsFixed(2)}', true),
          ] else
            _buildSummaryRow('Total Payable', '₹${subtotal.toStringAsFixed(2)}', true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          fontSize: isTotal ? 16 : 14, 
          fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
        )),
        Text(value, style: TextStyle(
          fontSize: isTotal ? 20 : 14, 
          fontWeight: isTotal ? FontWeight.bold : FontWeight.bold,
          color: isTotal ? Colors.green : null,
        )),
      ],
    );
  }

  void _launchWhatsApp(String phone, String message) async {
    String finalMessage = message;
    try {
      final settings = _gstSettings ?? await DatabaseService().getGstSettings(widget.shopId);
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
        await Share.share(finalMessage, subject: ShopHelper.getDisplayName(widget.shopId));
      }
    }
  }

  void _issueFullBill() async {
    if (_cart.isEmpty && _selectedProduct == null) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      List<CartItem> finalItems = [];
      
      if (_cart.isNotEmpty) {
        finalItems = List.from(_cart);
      } else if (_selectedProduct != null) {
        // Handle instant single item sale
        final qty = int.tryParse(_quantityController.text) ?? 1;
        if (qty > _selectedProduct!.units) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient stock!'), backgroundColor: Colors.red));
          setState(() => _isLoading = false);
          return;
        }
        finalItems = [
          CartItem(
            productId: _selectedProduct!.id,
            productName: _selectedProduct!.name,
            category: _selectedProduct!.category,
            quantity: qty,
            price: _selectedProduct!.price,
            costPrice: _selectedProduct!.costPrice,
          )
        ];
      }

      double discountAmount = double.tryParse(_discountAmountController.text) ?? 0.0;
      double finalTotal = (finalItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity)) - discountAmount).clamp(0.0, double.infinity);
      double cgstAmount = 0.0;
      double sgstAmount = 0.0;
      double taxableAmount = finalTotal;

      if (_isGstBill) {
        final cgstRate = _gstSettings?.cgstRate ?? 9.0;
        final sgstRate = _gstSettings?.sgstRate ?? 9.0;
        taxableAmount = finalTotal / (1 + (cgstRate + sgstRate) / 100);
        cgstAmount = taxableAmount * cgstRate / 100;
        sgstAmount = taxableAmount * sgstRate / 100;
      }

      double cashAmt = 0.0;
      double onlineAmt = 0.0;
      final double exchangeCredit = widget.exchangeCredit ?? 0.0;
      final double exchangeAmount = exchangeCredit > finalTotal ? finalTotal : exchangeCredit;
      final double netDue = (finalTotal - exchangeCredit).clamp(0.0, double.infinity);
      final double refundDue = (exchangeCredit - finalTotal).clamp(0.0, double.infinity);

      if (netDue > 0) {
        if (_paymentMode == 'Cash') {
          cashAmt = netDue;
        } else if (_paymentMode == 'Online') {
          onlineAmt = netDue;
        } else {
          cashAmt = double.tryParse(_cashPaidController.text) ?? 0.0;
          onlineAmt = double.tryParse(_onlinePaidController.text) ?? 0.0;
          if ((cashAmt + onlineAmt - netDue).abs() > 0.01) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Split amounts must sum to net due!'), backgroundColor: Colors.red)
            );
            setState(() => _isLoading = false);
            return;
          }
        }
      } else {
        cashAmt = 0.0;
        onlineAmt = 0.0;
      }

      final sale = SaleModel(
        id: const Uuid().v4(),
        items: finalItems,
        totalPrice: finalTotal,
        timestamp: DateTime.now(),
        employeeId: widget.employeeName,
        shopId: widget.shopId,
        customerName: _customerNameController.text.isEmpty ? 'Walk-in Customer' : _customerNameController.text,
        customerNameLower: _customerNameController.text.isEmpty ? 'walk-in customer' : _customerNameController.text.toLowerCase(),
        customerPhone: _customerPhoneController.text.trim(),
        isGstBill: _isGstBill,
        taxableAmount: taxableAmount,
        cgstAmount: cgstAmount,
        sgstAmount: sgstAmount,
        paymentMode: netDue > 0 ? _paymentMode : 'Discount/Exchange',
        cashAmount: cashAmt,
        onlineAmount: onlineAmt,
        exchangeAmount: exchangeAmount,
        returnedReplacementId: widget.returnedReplacementId,
        discountAmount: discountAmount,
      );

      // Play success sound immediately
      SoundHelper.playSuccess();

      // Save sale to database in background
      if (widget.employeeName != 'Owner' && discountAmount > 0) {
        final pendingSale = PendingSaleModel(
          id: sale.id,
          sale: sale,
          timestamp: DateTime.now(),
        );
        DatabaseService().addPendingSale(pendingSale).catchError((e) {
          debugPrint('Error in addPendingSale background task: $e');
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Discount requested! Sent for Owner Approval.'), backgroundColor: Colors.orange)
          );
          Navigator.pop(context);
        }
        return; // exit early
      }

      DatabaseService().addSale(sale).catchError((e) {
        debugPrint('Error in addSale background task: $e');
      });

      // If this is an exchange, log the returned item and create a replacement request
      if (widget.returnedReplacementId != null) {
        final replacement = ReplacementModel(
          id: widget.returnedReplacementId!,
          productId: widget.returnedProductId ?? '',
          productName: widget.returnedProductName ?? 'Exchanged Item',
          employeeName: widget.employeeName,
          shopId: widget.shopId,
          reason: widget.returnedReason ?? 'Exchange Return',
          status: widget.returnedCostPrice != null && widget.returnedCostPrice! > 0 ? 'accepted' : 'pending',
          timestamp: DateTime.now(),
          costPrice: widget.returnedCostPrice,
          saleId: widget.returnedSaleId,
          customerName: sale.customerName,
          returnAction: 'exchange',
        );

        DatabaseService().addReplacementRequest(replacement).then((_) {
          if (widget.returnedCostPrice != null && widget.returnedCostPrice! > 0) {
            DatabaseService().approveReplacement(widget.returnedReplacementId!, widget.returnedCostPrice!).catchError((e) {
              debugPrint('Error approving exchange replacement in background: $e');
            });
          }
        }).catchError((e) {
          debugPrint('Error adding exchange replacement in background: $e');
        });
      }

      // Log difference refund if refundDue > 0
      if (refundDue > 0) {
        final refundExpense = ExpenseModel(
          id: 'EXP_REFUND_${const Uuid().v4()}',
          shopId: widget.shopId,
          category: 'Replacement Cash Refund',
          amount: refundDue,
          description: '[Cust: ${sale.customerName}] | Refund difference of exchange for ${widget.returnedProductName}',
          timestamp: DateTime.now(),
        );
        DatabaseService().addExpense(refundExpense).catchError((e) {
          debugPrint('Error logging refund expense in background: $e');
        });
      }

      if (widget.enquiryId != null) {
        DatabaseService().updateEnquiryStatus(widget.enquiryId!, 'completed').catchError((e) {
          debugPrint('Error completing enquiry in background: $e');
        });
      }

      // Snappy 0.5s visual feedback
      await Future.delayed(const Duration(milliseconds: 500));

      // Build structured bill details message
      final String dateStr = DateFormat('dd-MM-yyyy hh:mm a').format(sale.timestamp);
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('🧾 *${ShopHelper.getDisplayName(sale.shopId).toUpperCase()} - SALE INVOICE*');
      buffer.writeln('----------------------------------------');
      buffer.writeln('📍 *Shop:* ${ShopHelper.getDisplayName(sale.shopId)}');
      if (sale.isGstBill && _gstSettings != null) {
        buffer.writeln('📄 *GSTIN:* ${_gstSettings!.gstNumber}');
      }
      buffer.writeln('👤 *Customer:* ${sale.customerName}');
      buffer.writeln('📞 *Phone:* ${sale.customerPhone}');
      buffer.writeln('📅 *Date:* $dateStr');
      buffer.writeln('👤 *Billed By:* ${sale.employeeId}');
      buffer.writeln('----------------------------------------');
      buffer.writeln('*ITEMS:*');
      
      for (int i = 0; i < finalItems.length; i++) {
        final item = finalItems[i];
        final double itemTotal = item.price * item.quantity;
        buffer.writeln('${i + 1}. *${item.productName}*');
        buffer.writeln('   Qty: ${item.quantity} x ₹${item.price.toStringAsFixed(0)} = ₹${itemTotal.toStringAsFixed(0)}');
      }
      
      buffer.writeln('----------------------------------------');
      if (sale.isGstBill) {
        buffer.writeln('💵 *Subtotal:* ₹${sale.taxableAmount.toStringAsFixed(2)}');
        buffer.writeln('📈 *CGST:* ₹${sale.cgstAmount.toStringAsFixed(2)}');
        buffer.writeln('📈 *SGST:* ₹${sale.sgstAmount.toStringAsFixed(2)}');
        buffer.writeln('----------------------------------------');
      }
      buffer.writeln('💰 *Total Amount:* ₹${finalTotal.toStringAsFixed(0)}');
      buffer.writeln('----------------------------------------');
      buffer.writeln('Thank you for shopping with us! 🙏');
      
      final String message = buffer.toString();

      if (mounted) {
        setState(() => _isLoading = false);
        
        // Show share option dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.primary, size: 28),
                  const SizedBox(width: 10),
                  const Text('Bill Generated'),
                ],
              ),
              content: const Text('The bill has been successfully generated. Select an option to proceed:'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext); // close dialog
                    Navigator.pop(context); // close billing screen
                  },
                  child: const Text('CLOSE'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('WHATSAPP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogContext); // close dialog
                    Navigator.pop(context); // close billing screen
                    final settings = _gstSettings ?? GstSettingsModel(
                      shopId: sale.shopId,
                      shopName: ShopHelper.getDisplayName(sale.shopId),
                      gstNumber: 'N/A',
                      address: 'Store Address',
                      contactNumber: 'Phone',
                      email: '',
                      cgstRate: 9.0,
                      sgstRate: 9.0,
                    );
                    await PdfInvoiceHelper.shareInvoicePdf(sale, settings, textMessage: message);
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('PRINT INVOICE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogContext); // close dialog
                    Navigator.pop(context); // close billing screen
                    
                    final settings = _gstSettings ?? GstSettingsModel(
                      shopId: sale.shopId,
                      shopName: ShopHelper.getDisplayName(sale.shopId),
                      gstNumber: 'N/A',
                      address: 'Store Address',
                      contactNumber: 'Phone',
                      email: '',
                      cgstRate: 9.0,
                      sgstRate: 9.0,
                    );
                    await PdfInvoiceHelper.generateAndPrintInvoice(sale, settings);
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
