import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../models/gst_settings_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/shop_helper.dart';
import '../../widgets/shimmer.dart';

class GstSettingsScreen extends StatefulWidget {
  const GstSettingsScreen({super.key});

  @override
  State<GstSettingsScreen> createState() => _GstSettingsScreenState();
}

class _GstSettingsScreenState extends State<GstSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _db = DatabaseService();

  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  // Shop 1 controllers
  final _gstController1 = TextEditingController();
  final _addressController1 = TextEditingController();
  final _phoneController1 = TextEditingController();
  final _emailController1 = TextEditingController();
  final _cgstController1 = TextEditingController(text: '9.0');
  final _sgstController1 = TextEditingController(text: '9.0');
  final _groupLinkController1 = TextEditingController();
  final _openingDrawerController1 = TextEditingController(text: '0');
  String? _logoBase64_1;

  // Shop 2 controllers
  final _gstController2 = TextEditingController();
  final _addressController2 = TextEditingController();
  final _phoneController2 = TextEditingController();
  final _emailController2 = TextEditingController();
  final _cgstController2 = TextEditingController(text: '9.0');
  final _sgstController2 = TextEditingController(text: '9.0');
  final _groupLinkController2 = TextEditingController();
  final _openingDrawerController2 = TextEditingController(text: '0');
  String? _logoBase64_2;

  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          _loadSettings();
        }
      });
    });
  }

  void _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings1 = await _db.getGstSettings('Shop 1');
      if (settings1 != null) {
        _gstController1.text = settings1.gstNumber;
        _addressController1.text = settings1.address;
        _phoneController1.text = settings1.contactNumber;
        _emailController1.text = settings1.email;
        _cgstController1.text = settings1.cgstRate.toString();
        _sgstController1.text = settings1.sgstRate.toString();
        _logoBase64_1 = settings1.logoBase64;
        _groupLinkController1.text = settings1.groupLink ?? '';
        _openingDrawerController1.text = settings1.openingDrawerAmount.toStringAsFixed(0);
      }

      final settings2 = await _db.getGstSettings('Shop 2');
      if (settings2 != null) {
        _gstController2.text = settings2.gstNumber;
        _addressController2.text = settings2.address;
        _phoneController2.text = settings2.contactNumber;
        _emailController2.text = settings2.email;
        _cgstController2.text = settings2.cgstRate.toString();
        _sgstController2.text = settings2.sgstRate.toString();
        _logoBase64_2 = settings2.logoBase64;
        _groupLinkController2.text = settings2.groupLink ?? '';
        _openingDrawerController2.text = settings2.openingDrawerAmount.toStringAsFixed(0);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickLogo(int shopNum) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 200,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        setState(() {
          if (shopNum == 1) {
            _logoBase64_1 = base64String;
          } else {
            _logoBase64_2 = base64String;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _saveSettings(int shopNum) async {
    final formKey = shopNum == 1 ? _formKey1 : _formKey2;
    if (!formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final shopId = shopNum == 1 ? 'Shop 1' : 'Shop 2';
      final gst = shopNum == 1 ? _gstController1.text.trim() : _gstController2.text.trim();
      final address = shopNum == 1 ? _addressController1.text.trim() : _addressController2.text.trim();
      final phone = shopNum == 1 ? _phoneController1.text.trim() : _phoneController2.text.trim();
      final email = shopNum == 1 ? _emailController1.text.trim() : _emailController2.text.trim();
      final cgst = double.tryParse(shopNum == 1 ? _cgstController1.text : _cgstController2.text) ?? 9.0;
      final sgst = double.tryParse(shopNum == 1 ? _sgstController1.text : _sgstController2.text) ?? 9.0;
      final logo = shopNum == 1 ? _logoBase64_1 : _logoBase64_2;
      final groupLink = shopNum == 1 ? _groupLinkController1.text.trim() : _groupLinkController2.text.trim();
      final openingDrawer = double.tryParse(
        (shopNum == 1 ? _openingDrawerController1.text : _openingDrawerController2.text).replaceAll(',', ''),
      ) ?? 0.0;

      final model = GstSettingsModel(
        shopId: shopId,
        shopName: ShopHelper.getDisplayName(shopId),
        gstNumber: gst,
        address: address,
        contactNumber: phone,
        email: email,
        logoBase64: logo,
        cgstRate: cgst,
        sgstRate: sgst,
        groupLink: groupLink.isEmpty ? null : groupLink,
        openingDrawerAmount: openingDrawer,
      );

      await _db.saveGstSettings(model);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ShopHelper.getDisplayName(shopId)} GST Settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _gstController1.dispose();
    _addressController1.dispose();
    _phoneController1.dispose();
    _emailController1.dispose();
    _cgstController1.dispose();
    _sgstController1.dispose();
    _groupLinkController1.dispose();
    _openingDrawerController1.dispose();

    _gstController2.dispose();
    _addressController2.dispose();
    _phoneController2.dispose();
    _emailController2.dispose();
    _cgstController2.dispose();
    _sgstController2.dispose();
    _groupLinkController2.dispose();
    _openingDrawerController2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GST & Bill Settings'),
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
      body: _isLoading
          ? _buildShimmerSkeleton()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildShopSettingsForm(1, _formKey1, _gstController1, _addressController1, _phoneController1, _emailController1, _cgstController1, _sgstController1, _logoBase64_1, _groupLinkController1, _openingDrawerController1),
                _buildShopSettingsForm(2, _formKey2, _gstController2, _addressController2, _phoneController2, _emailController2, _cgstController2, _sgstController2, _logoBase64_2, _groupLinkController2, _openingDrawerController2),
              ],
            ),
    );
  }

  Widget _buildShimmerSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer(
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Shimmer.buttonSkeleton(height: 36, width: 140),
          const SizedBox(height: 24),
          Shimmer(
            child: Container(width: 120, height: 14, color: Colors.grey.shade200),
          ),
          const SizedBox(height: 16),
          Shimmer.fieldSkeleton(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Shimmer.fieldSkeleton()),
              const SizedBox(width: 16),
              Expanded(child: Shimmer.fieldSkeleton()),
            ],
          ),
          const SizedBox(height: 24),
          Shimmer(
            child: Container(width: 150, height: 14, color: Colors.grey.shade200),
          ),
          const SizedBox(height: 16),
          Shimmer.fieldSkeleton(height: 80),
          const SizedBox(height: 16),
          Shimmer.fieldSkeleton(),
          const SizedBox(height: 24),
          Shimmer.buttonSkeleton(height: 50),
        ],
      ),
    );
  }

  Widget _buildShopSettingsForm(
    int shopNum,
    GlobalKey<FormState> formKey,
    TextEditingController gstCtrl,
    TextEditingController addrCtrl,
    TextEditingController phoneCtrl,
    TextEditingController emailCtrl,
    TextEditingController cgstCtrl,
    TextEditingController sgstCtrl,
    String? logoBase64,
    TextEditingController groupLinkCtrl,
    TextEditingController openingDrawerCtrl,
  ) {
    final shopDisplayName = ShopHelper.getDisplayName(shopNum == 1 ? 'Shop 1' : 'Shop 2');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo Picker Section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.accentForest.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text(
                      'SHOP LOGO (BILL HEADER)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 16),
                    if (logoBase64 != null) ...[
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(logoBase64),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.none),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('No logo selected', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => _pickLogo(shopNum),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(logoBase64 != null ? 'CHANGE LOGO' : 'UPLOAD SHOP LOGO'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // GST & Tax Rates Section
            _buildSectionHeader('GST & TAX RATES', Icons.receipt_outlined),
            const SizedBox(height: 16),
            _buildInputField(
              controller: gstCtrl,
              label: 'GSTIN (GST Number) (Optional)',
              hint: 'e.g. 33AAAAA1111A1Z1',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: cgstCtrl,
                    label: 'CGST Rate (%) *',
                    hint: '9.0',
                    icon: Icons.percent_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Required';
                      if (double.tryParse(val) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    controller: sgstCtrl,
                    label: 'SGST Rate (%) *',
                    hint: '9.0',
                    icon: Icons.percent_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Required';
                      if (double.tryParse(val) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Contact & Header Details Section
            _buildSectionHeader('BILL HEADER DETAILS', Icons.business_outlined),
            const SizedBox(height: 16),
            _buildInputField(
              controller: addrCtrl,
              label: 'Store Address *',
              hint: 'Full street address, City, State, ZIP',
              icon: Icons.location_on_outlined,
              maxLines: 2,
              validator: (val) => val == null || val.trim().isEmpty ? 'Address is required' : null,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: phoneCtrl,
              label: 'Contact Number *',
              hint: '10-digit phone number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (val) => val == null || val.trim().isEmpty ? 'Contact number is required' : null,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: emailCtrl,
              label: 'Store Email (Optional)',
              hint: 'e.g. contact@dhkin.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('CUSTOMER INVITE LINK', Icons.group_add_outlined),
            const SizedBox(height: 16),
            _buildInputField(
              controller: groupLinkCtrl,
              label: 'WhatsApp Group Invite Link (Optional)',
              hint: 'e.g. https://chat.whatsapp.com/...',
              icon: Icons.link_rounded,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),

            // Opening Drawer Cash Section
            _buildSectionHeader('CASH DRAWER', Icons.account_balance_wallet_outlined),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Enter the cash amount already present in your drawer before today\'s sales begin. This will be included in your total drawer balance on the dashboard.',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade800, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: openingDrawerCtrl,
              label: 'Opening Drawer Cash (₹)',
              hint: 'e.g. 5000',
              icon: Icons.account_balance_wallet_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (val) {
                if (val != null && val.trim().isNotEmpty) {
                  if (double.tryParse(val.replaceAll(',', '')) == null) return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 36),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _saveSettings(shopNum),
                icon: const Icon(Icons.save_outlined),
                label: Text('SAVE SETTINGS FOR ${shopDisplayName.toUpperCase()}'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
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
}
