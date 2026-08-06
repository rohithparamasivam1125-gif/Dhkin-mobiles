import 'package:flutter/material.dart';

import 'package:uuid/uuid.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/database_service.dart';

import '../../models/service_model.dart';

import '../../models/replacement_model.dart';

import '../../models/category_model.dart';

import '../../models/product_model.dart';

import '../../utils/app_theme.dart';

import '../owner/sales_reports.dart';

import 'package:flutter/services.dart';

import 'package:intl/intl.dart';

import '../../models/gst_settings_model.dart';

import '../../utils/pdf_invoice_helper.dart';
import '../../utils/whatsapp_bill_helper.dart';

import '../../utils/shop_helper.dart';

import '../../utils/sound_helper.dart';

import 'package:url_launcher/url_launcher.dart';

class ServiceManagementScreen extends StatefulWidget {
  final String shopId;

  final String employeeName;

  const ServiceManagementScreen(
      {super.key, required this.shopId, required this.employeeName});

  @override
  State<ServiceManagementScreen> createState() =>
      _ServiceManagementScreenState();
}

class _ServiceManagementScreenState extends State<ServiceManagementScreen> {
  GstSettingsModel? _gstSettings;

  late Stream<List<ServiceModel>> _servicesStream;

  @override
  void initState() {
    super.initState();

    _loadGstSettings();

    _servicesStream = DatabaseService().getServices(widget.shopId);
  }

  void _sendServiceWhatsAppNotification(ServiceModel service) {
    final String dateStr =
        DateFormat('dd-MM-yyyy hh:mm a').format(service.timestamp);
    final String shopName = ShopHelper.getDisplayName(service.shopId).toUpperCase();

    final buffer = StringBuffer();

    if (service.status == 'Completed') {
      buffer.writeln('🔔 *$shopName - SERVICE COMPLETED*');
      buffer.writeln('----------------------------------------');
      buffer.writeln('Hello ${service.customerName},');
      buffer.writeln('Your device *${service.mobileModel}* is successfully repaired and ready for collection! 📱✅');
    } else {
      buffer.writeln('🧾 *$shopName - SERVICE DELIVERED*');
      buffer.writeln('----------------------------------------');
      buffer.writeln('Hello ${service.customerName},');
      buffer.writeln('Your device *${service.mobileModel}* has been successfully delivered. Thank you! 📱🤝');
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('🛠️ *Details:* ${service.mobileDetails}');
    buffer.writeln('📅 *Date:* $dateStr');
    buffer.writeln('----------------------------------------');
    buffer.writeln('💰 *Total Amount:* ₹${service.totalAmount.toStringAsFixed(0)}');

    if (service.status == 'Completed') {
      if (service.remainingAmount == 0) {
        if (service.advanceAmount > 0 && service.advanceAmount < service.totalAmount) {
          buffer.writeln('💵 *Initial Advance Paid:* ₹${service.advanceAmount.toStringAsFixed(0)}');
          buffer.writeln('💵 *Balance Paid at Collection:* ₹${(service.totalAmount - service.advanceAmount).toStringAsFixed(0)}');
        } else {
          buffer.writeln('💵 *Amount Paid:* ₹${service.totalAmount.toStringAsFixed(0)}');
        }
        buffer.writeln('🟢 *Payment Status:* FULLY PAID');
      } else {
        buffer.writeln('💵 *Advance Paid:* ₹${service.advanceAmount.toStringAsFixed(0)}');
        buffer.writeln('🔴 *Remaining Balance:* ₹${service.remainingAmount.toStringAsFixed(0)}');
        buffer.writeln('----------------------------------------');
        buffer.writeln('🔴 *Please pay the remaining balance of ₹${service.remainingAmount.toStringAsFixed(0)} during collection.*');
      }
    } else {
      if (service.remainingAmount == 0) {
        if (service.advanceAmount > 0 && service.advanceAmount < service.totalAmount) {
          buffer.writeln('💵 *Initial Advance Paid:* ₹${service.advanceAmount.toStringAsFixed(0)}');
          buffer.writeln('💵 *Balance Paid at Delivery:* ₹${(service.totalAmount - service.advanceAmount).toStringAsFixed(0)}');
        } else {
          buffer.writeln('💵 *Amount Paid:* ₹${service.totalAmount.toStringAsFixed(0)}');
        }
        buffer.writeln('🟢 *Remaining Balance:* ₹0 (Fully Settled)');
      } else {
        buffer.writeln('💵 *Advance Paid:* ₹${service.advanceAmount.toStringAsFixed(0)}');
        buffer.writeln('🔴 *Remaining Balance:* ₹${service.remainingAmount.toStringAsFixed(0)}');
      }
    }

    // Complementary items section
    if (service.complementaryItems.isNotEmpty) {
      buffer.writeln('----------------------------------------');
      buffer.writeln('🎁 *Complimentary Item(s):*');
      for (final item in service.complementaryItems) {
        final name = item['productName'] as String? ?? 'Item';
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        buffer.writeln('  • $name × $qty');
      }
      buffer.writeln('_(Complimentary — No Charge)_');
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('Thank you! 🙏');

    final settings = _gstSettings ??
        GstSettingsModel(
          shopId: service.shopId,
          shopName: ShopHelper.getDisplayName(service.shopId),
          gstNumber: 'N/A',
          address: 'Store Address',
          contactNumber: 'Phone',
          email: '',
          cgstRate: 9.0,
          sgstRate: 9.0,
        );

    WhatsAppBillHelper.shareServiceBillWhatsApp(service, settings, context: context);
  }

  Future<void> _loadGstSettings() async {
    try {
      final settings = await DatabaseService().getGstSettings(widget.shopId);

      if (mounted) {
        setState(() {
          _gstSettings = settings;
        });
      }
    } catch (_) {}
  }

  void _launchWhatsApp(String phone, String message) async {
    String finalMessage = message;

    try {
      final settings =
          _gstSettings ?? await DatabaseService().getGstSettings(widget.shopId);

      if (settings != null &&
          settings.groupLink != null &&
          settings.groupLink!.trim().isNotEmpty) {
        finalMessage =
            "$message\n\nJoin our WhatsApp Group: ${settings.groupLink!.trim()}";
      }
    } catch (_) {}

    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      cleanPhone = cleanPhone.substring(1);
    }

    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    final String whatsappScheme =
        'whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(finalMessage)}';

    final Uri whatsappUri = Uri.parse(whatsappScheme);

    final String waMeUrl =
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(finalMessage)}';

    final Uri waMeUri = Uri.parse(waMeUrl);

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else if (await canLaunchUrl(waMeUri)) {
        await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Could not launch WhatsApp. Make sure it is installed.')));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error launching WhatsApp.')));
      }
    }
  }

  void _callCustomer(String phone) async {
    final String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) return;
    final Uri uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open phone dialer.')));
        }
      }
    } catch (e) {
      debugPrint('Error launching phone dialer: $e');
    }
  }

  void _showServiceBillOptionsDialog(
      BuildContext context, ServiceModel service) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: Colors.green.shade600, size: 28),
              const SizedBox(width: 10),
              const Text('Service Completed'),
            ],
          ),
          content: Text(service.remainingAmount == 0
              ? 'The service is completed and fully paid. Send a confirmation message or receipt to the customer.'
              : 'The service is completed with a remaining balance of ₹${service.remainingAmount.toStringAsFixed(0)}. Send a pending balance message or receipt to the customer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CLOSE'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.share_rounded),
              label: const Text('SEND WHATSAPP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(dialogContext); // close dialog
                _sendServiceWhatsAppNotification(service);
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.print_rounded),
              label: const Text('PRINT/PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext); // close dialog

                final settings = _gstSettings ??
                    GstSettingsModel(
                      shopId: service.shopId,
                      shopName: ShopHelper.getDisplayName(service.shopId),
                      gstNumber: 'N/A',
                      address: 'Store Address',
                      contactNumber: 'Phone',
                      email: '',
                      cgstRate: 9.0,
                      sgstRate: 9.0,
                    );

                  await PdfInvoiceHelper.generateAndPrintServiceInvoice(
                      service, settings);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mobile Services (${widget.shopId})'),
        actions: [
          if (widget.employeeName == 'Owner')
            IconButton(
              icon: const Icon(Icons.analytics),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SalesReportsScreen())),
              tooltip: 'View Reports',
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddServiceDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<ServiceModel>>(
        stream: _servicesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                    'Error: ${snapshot.error}\n\nThis usually means a Firestore index is missing.',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final services = snapshot.data ?? [];

          if (services.isEmpty)
            return const Center(child: Text('No service records found'));

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];

              final bool isCompleted = service.remainingAmount == 0;

              return RepaintBoundary(
                  child: Card(
                color: _getStatusBgColor(service.status),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _getStatusColor(service.status).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: ExpansionTile(
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  collapsedShape:
                      const RoundedRectangleBorder(side: BorderSide.none),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(service.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_getStatusIconData(service.status),
                        color: _getStatusColor(service.status), size: 20),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${service.customerName} - ${service.mobileModel}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      if (service.isGstBill)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: Colors.blue.shade300, width: 0.5),
                          ),
                          child: Text(
                            'GST',
                            style: TextStyle(
                                color: Colors.blue.shade800,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (service.status == 'Completed' || service.status == 'Delivered') ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {}, // absorbs tap to prevent expanding/collapsing tile
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.phone, size: 18, color: Colors.blue),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _callCustomer(service.customerPhone),
                                tooltip: 'Call Customer',
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: const Icon(Icons.chat_outlined, size: 18, color: Colors.green),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _sendServiceWhatsAppNotification(service),
                                tooltip: 'Send WhatsApp Notification',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      const Text('Status: ', style: TextStyle(fontSize: 13)),
                      Text(
                        service.status,
                        style: TextStyle(
                          color: _getStatusColor(service.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        ' | By: ${service.employeeName}',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Details: ${service.mobileDetails}',
                              style: const TextStyle(fontSize: 14)),
                          Row(
                            children: [
                              Text('Phone: ${service.customerPhone}',
                                  style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _callCustomer(service.customerPhone),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Call',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('Payment Progress',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: service.totalAmount > 0
                                ? service.advanceAmount / service.totalAmount
                                : 0,
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                isCompleted
                                    ? Colors.green
                                    : Theme.of(context).primaryColor),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Amount: ₹${service.totalAmount}'),
                              Text('Advance: ₹${service.advanceAmount}',
                                  style: const TextStyle(color: Colors.green)),
                            ],
                          ),
                          Text('Remaining: ₹${service.remainingAmount}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red)),
                          if (widget.employeeName == 'Owner') ...[
                            const SizedBox(height: 8),
                            const Divider(),
                            const Text('Financial Breakdown (Owner Only)',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    'Parts Cost: ₹${service.partsCost.toStringAsFixed(0)}'),
                                Text(
                                    'Tech Fee: ₹${service.technicianFee.toStringAsFixed(0)}'),
                              ],
                            ),
                            if (service.reRepairCost > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                    'Re-repair Cost: ₹${service.reRepairCost.toStringAsFixed(0)}',
                                    style:
                                        const TextStyle(color: Colors.orange)),
                              ),
                            const SizedBox(height: 4),
                            Builder(builder: (context) {
                              final netRevenue = service.isGstBill
                                  ? service.taxableAmount
                                  : service.totalAmount;

                              final profit = netRevenue -
                                  service.partsCost -
                                  service.technicianFee -
                                  service.reRepairCost -
                                  service.complementaryCost;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Net Profit: ₹${profit.toStringAsFixed(0)}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: profit >= 0
                                            ? Colors.green
                                            : Colors.red),
                                  ),
                                  if (service.complementaryCost > 0)
                                    Text(
                                      'Complement Cost: -₹${service.complementaryCost.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange),
                                    ),
                                ],
                              );
                            }),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (service.status != 'Pending')
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.share_outlined,
                                      size: 18),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () =>
                                      _showServiceBillOptionsDialog(
                                          context, service),
                                  label: const Text('Receipt'),
                                ),

                              ElevatedButton.icon(
                                icon: const Icon(Icons.edit_note, size: 18),
                                onPressed: () =>
                                    _showStatusDialog(context, service),
                                label: const Text('Update Status'),
                              ),

                              if (service.remainingAmount > 0) ...[
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.payment, size: 18),
                                  onPressed: () =>
                                      _showAddPaymentDialog(context, service),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentForest,
                                    foregroundColor: Colors.white,
                                  ),
                                  label: const Text('Add Payment'),
                                ),
                              ],

                              // Staff/Owner: Re-repair — available to both staff and owner

                              ElevatedButton.icon(
                                icon: const Icon(Icons.build_circle_outlined,
                                    size: 18),
                                onPressed: () =>
                                    _showReRepairDialog(context, service),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                label: const Text('Re-Repair'),
                              ),

                              // Owner-only actions

                              if (widget.employeeName == 'Owner') ...[
                                OutlinedButton.icon(
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () =>
                                      _showEditServiceDialog(context, service),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blue.shade700,
                                    side:
                                        BorderSide(color: Colors.blue.shade300),
                                  ),
                                  label: const Text('Edit'),
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                  onPressed: () =>
                                      _confirmDeleteService(context, service),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                    side:
                                        BorderSide(color: Colors.red.shade300),
                                  ),
                                  label: const Text('Delete'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ));
            },
          );
        },
      ),
    );
  }

  // ── Discount Request Dialog removed ──

  void _showStatusDialog(BuildContext context, ServiceModel service) {
    final allowedStatuses = ['Pending', 'Completed', 'Delivered'];

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: allowedStatuses.map((status) {
            return ListTile(
              title: Text(status),
              subtitle: status == 'Completed'
                  ? const Text('Mobile is ready to deliver',
                      style: TextStyle(fontSize: 11, color: Colors.grey))
                  : status == 'Delivered'
                      ? const Text('Customer collects & pays',
                          style: TextStyle(fontSize: 11, color: Colors.grey))
                      : null,
              onTap: () {
                Navigator.pop(dialogCtx);

                if (status == 'Completed') {
                  if (widget.employeeName == 'Owner' &&
                      !service.isExpenseRecorded) {
                    // Owner: ask for CP/TC if not already entered

                    _showServiceExpensesCompletedDialog(context, service);
                  } else {
                    // Staff OR owner with costs already recorded: just update status and show bill

                    SoundHelper.playSuccess();

                    final updated = service.copyWith(status: 'Completed');

                    DatabaseService()
                        .updateServiceStatus(service.id, 'Completed')
                        .catchError((e) {
                      debugPrint('Error updating status: $e');
                    });

                    if (mounted)
                      _showServiceBillOptionsDialog(context, updated);
                  }
                } else if (status == 'Delivered') {
                  // Both Staff and Owner use the same validated delivery flow

                  _checkAndDeliver(context, service);
                } else {
                  // Pending — just update status

                  SoundHelper.playSuccess();

                  DatabaseService()
                      .updateServiceStatus(service.id, status)
                      .catchError((e) {
                    debugPrint('Error updating status: $e');
                  });
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Check for pending re-repair before proceeding with delivery.

  Future<void> _checkAndDeliver(
      BuildContext context, ServiceModel service) async {
    try {
      final pendingRepairs = await FirebaseFirestore.instance
          .collection('replacements')
          .where('productId', isEqualTo: service.id)
          .where('status', isEqualTo: 'pending')
          .get();

      if (!mounted) return;

      if (pendingRepairs.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Re-repair request is still pending. Cannot deliver until it is resolved.'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );

        return;
      }

      // All clear — proceed with delivery

      if (service.remainingAmount > 0) {
        _showDeliveryPaymentDialog(context, service);
      } else {
        // Zero balance — show delivery dialog with complement toggle
        _showZeroBalanceDeliveryDialog(context, service);
      }
    } catch (e) {
      debugPrint('Error checking re-repairs: $e');

      // Proceed anyway on error

      if (service.remainingAmount > 0) {
        _showDeliveryPaymentDialog(context, service);
      } else {
        _showZeroBalanceDeliveryDialog(context, service);
      }
    }
  }

  // ── Zero-Balance Delivery Dialog (with complement toggle) ────────────────

  void _showZeroBalanceDeliveryDialog(
      BuildContext context, ServiceModel service) {
    bool addComplements = false;
    List<Map<String, dynamic>> complementItems = [];
    String? selectedCategory;
    ProductModel? selectedProduct;
    final qtyController = TextEditingController(text: '1');
    String productSearchQuery = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setDialogState) {
          return AlertDialog(
            scrollable: true,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.local_shipping_outlined,
                    color: Colors.green.shade700, size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Deliver Device',
                    style: TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${service.customerName} — ${service.mobileModel}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text('Payment Fully Settled',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Complement toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Add Complementary Products?',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Free gift from stock',
                      style: TextStyle(fontSize: 11)),
                  value: addComplements,
                  activeColor: Colors.deepOrange,
                  onChanged: (val) =>
                      setDialogState(() => addComplements = val),
                ),
                if (addComplements) ...[
                  const Divider(),
                  _buildComplementSection(
                    context: innerCtx,
                    setDialogState: setDialogState,
                    complementItems: complementItems,
                    selectedCategory: selectedCategory,
                    selectedProduct: selectedProduct,
                    qtyController: qtyController,
                    productSearchQuery: productSearchQuery,
                    onCategoryChanged: (val) => setDialogState(() {
                      selectedCategory = val;
                      selectedProduct = null;
                    }),
                    onProductChanged: (val) =>
                        setDialogState(() => selectedProduct = val),
                    onSearchChanged: (val) =>
                        setDialogState(() => productSearchQuery = val),
                    onItemRemoved: (idx) =>
                        setDialogState(() => complementItems.removeAt(idx)),
                    shopId: service.shopId,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  SoundHelper.playSuccess();

                  final double totalCompCost = complementItems.fold(
                      0.0,
                      (sum, item) =>
                          sum +
                          ((item['costPrice'] as num?)?.toDouble() ?? 0.0) *
                              ((item['quantity'] as num?)?.toInt() ?? 1));

                  final updated = service.copyWith(
                    status: 'Delivered',
                    complementaryItems: List<Map<String, dynamic>>.from(
                        complementItems),
                    complementaryCost: totalCompCost,
                  );

                  // Save service + record complement stock/expenses
                  DatabaseService().updateService(updated).catchError((e) {
                    debugPrint('Error updating service: $e');
                  });

                  if (complementItems.isNotEmpty) {
                    DatabaseService()
                        .recordComplementaryItems(updated)
                        .catchError((e) {
                      debugPrint('Error recording complements: $e');
                    });
                  }

                  if (mounted) _showServiceBillOptionsDialog(context, updated);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Deliver'),
              ),
            ],
          );
        },
      ),
    ).then((_) => qtyController.dispose());
  }

  // ── Shared Complement Product Picker Section ─────────────────────────────

  Widget _buildComplementSection({
    required BuildContext context,
    required StateSetter setDialogState,
    required List<Map<String, dynamic>> complementItems,
    required String? selectedCategory,
    required ProductModel? selectedProduct,
    required TextEditingController qtyController,
    required String productSearchQuery,
    required ValueChanged<String?> onCategoryChanged,
    required ValueChanged<ProductModel?> onProductChanged,
    required ValueChanged<String> onSearchChanged,
    required ValueChanged<int> onItemRemoved,
    required String shopId,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Complementary Products',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        // Category dropdown
        StreamBuilder<List<CategoryModel>>(
          stream: DatabaseService().getCategories(),
          builder: (ctx, catSnap) {
            if (!catSnap.hasData) {
              return const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
            }
            final cats = catSnap.data!.map((c) => c.name.trim()).toSet().toList();
            final dropVal =
                selectedCategory != null && cats.contains(selectedCategory)
                    ? selectedCategory
                    : null;
            return DropdownButtonFormField<String>(
              value: dropVal,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Select Category',
                prefixIcon:
                    const Icon(Icons.category_outlined, size: 18),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: cats
                  .map((n) => DropdownMenuItem(
                      value: n,
                      child: Text(n, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: onCategoryChanged,
            );
          },
        ),
        const SizedBox(height: 10),
        // Product selector
        StreamBuilder<List<ProductModel>>(
          stream: DatabaseService().getProducts(shopId),
          builder: (ctx, prodSnap) {
            if (!prodSnap.hasData) {
              return const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
            }
            final products = selectedCategory == null
                ? <ProductModel>[]
                : prodSnap.data!
                    .where((p) => p.category == selectedCategory)
                    .toList();

            return TextFormField(
              key: ValueKey(
                  'comp_prod_${selectedProduct?.id}_$selectedCategory'),
              decoration: InputDecoration(
                labelText: selectedCategory == null
                    ? 'Select Category First'
                    : 'Select Product',
                hintText: selectedProduct != null
                    ? '${selectedProduct!.name} (Stock: ${selectedProduct!.units})'
                    : 'Tap to search...',
                hintStyle: TextStyle(
                  color: selectedProduct != null
                      ? Colors.black87
                      : Colors.grey,
                  fontWeight: selectedProduct != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                  fontSize: 13,
                ),
                prefixIcon:
                    const Icon(Icons.shopping_bag_outlined, size: 18),
                suffixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              readOnly: true,
              onTap: selectedCategory == null
                  ? null
                  : () {
                      String query = '';
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => StatefulBuilder(
                          builder: (sheetCtx, setSheet) {
                            final filtered = products.where((p) {
                              return p.name
                                  .toLowerCase()
                                  .contains(query.toLowerCase());
                            }).toList();
                            return Container(
                              height:
                                  MediaQuery.of(context).size.height * 0.6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20)),
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 8),
                                  Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius:
                                              BorderRadius.circular(2))),
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: TextField(
                                      autofocus: true,
                                      decoration: InputDecoration(
                                        hintText: 'Search product...',
                                        prefixIcon:
                                            const Icon(Icons.search),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10),
                                      ),
                                      onChanged: (v) =>
                                          setSheet(() => query = v),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: filtered.isEmpty
                                        ? const Center(
                                            child: Text('No products found'))
                                        : ListView.separated(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 4),
                                            itemCount: filtered.length,
                                            separatorBuilder: (_, __) =>
                                                const Divider(height: 1),
                                            itemBuilder: (_, i) {
                                              final p = filtered[i];
                                              final bool outOfStock =
                                                  p.units <= 0;
                                              return ListTile(
                                                title: Text(p.name,
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: outOfStock
                                                            ? Colors.grey
                                                            : Colors.black87)),
                                                trailing: Text(
                                                  'Stock: ${p.units}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: outOfStock
                                                        ? Colors.red
                                                        : Colors.green,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                ),
                                                onTap: () {
                                                  if (outOfStock) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(SnackBar(
                                                      content: Text(
                                                          '${p.name} is not available in stock. Cannot add as complement.'),
                                                      backgroundColor:
                                                          Colors.red.shade700,
                                                    ));
                                                    return;
                                                  }
                                                  onProductChanged(p);
                                                  Navigator.pop(sheetCtx);
                                                },
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Qty',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('ADD'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: selectedProduct == null
                    ? null
                    : () {
                        final qty =
                            int.tryParse(qtyController.text.trim()) ?? 1;
                        if (qty <= 0) return;
                        if (qty > selectedProduct!.units) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'Only ${selectedProduct!.units} units available for ${selectedProduct!.name}.'),
                            backgroundColor: Colors.red.shade700,
                          ));
                          return;
                        }
                        // Check if already added
                        final existing = complementItems.indexWhere(
                            (e) => e['productId'] == selectedProduct!.id);
                        setDialogState(() {
                          if (existing != -1) {
                            complementItems[existing]['quantity'] =
                                (complementItems[existing]['quantity'] as int) +
                                    qty;
                          } else {
                            complementItems.add({
                              'productId': selectedProduct!.id,
                              'productName': selectedProduct!.name,
                              'quantity': qty,
                              'costPrice': selectedProduct!.costPrice,
                            });
                          }
                          // Reset for next product
                          onProductChanged(null);
                          qtyController.text = '1';
                        });
                      },
              ),
            ),
          ],
        ),
        if (complementItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🎁 Items to Gift:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.deepOrange)),
                const SizedBox(height: 6),
                ...complementItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '• ${item['productName']} × ${item['quantity']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        InkWell(
                          onTap: () => onItemRemoved(idx),
                          child: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Shown when status changes to Completed — only saves CP/TC and marks expense recorded.

  /// Does NOT change payment amounts (remaining/advance).

  void _showServiceExpensesCompletedDialog(
      BuildContext context, ServiceModel service) {
    final partsCostController = TextEditingController(
        text:
            service.partsCost > 0 ? service.partsCost.toStringAsFixed(0) : '');

    final technicianFeeController = TextEditingController(
        text: service.technicianFee > 0
            ? service.technicianFee.toStringAsFixed(0)
            : '');

    String partsPaymentMode = service.partsPaymentMode;
    String feePaymentMode = service.technicianPaymentMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (innerCtx, setDialogState) {
            double partsCost = double.tryParse(partsCostController.text) ?? 0.0;

            double technicianFee =
                double.tryParse(technicianFeeController.text) ?? 0.0;

            final netRevenue =
                service.isGstBill ? service.taxableAmount : service.totalAmount;

            double profit =
                netRevenue - partsCost - technicianFee - service.reRepairCost;

            return AlertDialog(
              scrollable: true,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Colors.amber.shade700, size: 28),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Mark as Completed',
                      style: TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${service.customerName} — ${service.mobileModel}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Total Bill: ₹${service.totalAmount.toStringAsFixed(0)}',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Enter cost details now (optional). Payment will be collected when customer delivers.',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ),
                  if (service.reRepairCost > 0)
                    Text(
                        'Re-repair Cost: -₹${service.reRepairCost.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.orange)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: partsCostController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Display / Part Cost (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('Parts Payment Mode: ',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                      ChoiceChip(
                        label: const Text('Cash'),
                        selected: partsPaymentMode == 'Cash',
                        onSelected: (val) {
                          if (val)
                            setDialogState(() => partsPaymentMode = 'Cash');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Online'),
                        selected: partsPaymentMode == 'Online',
                        onSelected: (val) {
                          if (val)
                            setDialogState(() => partsPaymentMode = 'Online');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: technicianFeeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Technician Fee (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('Tech Fee Payment Mode: ',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                      ChoiceChip(
                        label: const Text('Cash'),
                        selected: feePaymentMode == 'Cash',
                        onSelected: (val) {
                          if (val)
                            setDialogState(() => feePaymentMode = 'Cash');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Online'),
                        selected: feePaymentMode == 'Online',
                        onSelected: (val) {
                          if (val)
                            setDialogState(() => feePaymentMode = 'Online');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estimated Net Profit:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('₹${profit.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: profit >= 0 ? Colors.green : Colors.red,
                              fontSize: 16)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Skip entering costs — just mark Completed

                    Navigator.pop(dialogCtx);

                    SoundHelper.playSuccess();

                    final updated = service.copyWith(status: 'Completed');

                    DatabaseService()
                        .updateServiceStatus(service.id, 'Completed')
                        .catchError((e) {
                      debugPrint('Error updating status: $e');
                    });

                    if (mounted)
                      _showServiceBillOptionsDialog(context, updated);
                  },
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final double pCost =
                        double.tryParse(partsCostController.text.trim()) ?? 0.0;

                    final double tFee =
                        double.tryParse(technicianFeeController.text.trim()) ??
                            0.0;

                    // Save CP/TC + mark Completed. Payment amounts are NOT changed.

                    final updated = service.copyWith(
                      status: 'Completed',
                      partsCost: pCost,
                      technicianFee: tFee,
                      partsPaymentMode: partsPaymentMode,
                      technicianPaymentMode: feePaymentMode,
                      isExpenseRecorded: true,
                    );

                    Navigator.pop(dialogCtx);

                    SoundHelper.playSuccess();

                    DatabaseService().updateService(updated).catchError((e) {
                      debugPrint('Error saving service: $e');
                    });

                    if (mounted)
                      _showServiceBillOptionsDialog(context, updated);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save & Complete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeliveryPaymentDialog(BuildContext context, ServiceModel service) {
    final amountController = TextEditingController();

    final cashPaidController = TextEditingController();

    final onlinePaidController = TextEditingController();

    String paymentMode = 'Cash';

    // Complement state
    bool addComplements = false;
    List<Map<String, dynamic>> complementItems = [];
    String? selectedCategory;
    ProductModel? selectedProduct;
    final compQtyController = TextEditingController(text: '1');
    String productSearchQuery = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setDialogState) {
          final double collected =
              double.tryParse(amountController.text.trim()) ?? 0.0;

          final bool isAmountEqual = (collected == service.remainingAmount);

          return AlertDialog(
            scrollable: true,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.local_shipping_outlined,
                    color: Colors.deepPurple.shade700, size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Collect Payment & Deliver',
                    style: TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${service.customerName} — ${service.mobileModel}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Remaining Balance:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('₹${service.remainingAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.red)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  onChanged: (val) {
                    setDialogState(() {
                      final collectedAmt = double.tryParse(val.trim()) ?? 0.0;

                      if (paymentMode == 'Split') {
                        cashPaidController.text =
                            (collectedAmt / 2).toStringAsFixed(0);

                        onlinePaidController.text =
                            (collectedAmt - (collectedAmt / 2).floor())
                                .toStringAsFixed(0);
                      }
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Amount Collected Now (₹)',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    errorText: amountController.text.trim().isNotEmpty &&
                            !isAmountEqual
                        ? 'Amount must be exactly equal to the remaining balance: ₹${service.remainingAmount.toStringAsFixed(0)}'
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: paymentMode,
                  decoration: const InputDecoration(
                      labelText: 'Payment Mode', border: OutlineInputBorder()),
                  items: ['Cash', 'Online', 'Split']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        paymentMode = val;

                        if (val == 'Split') {
                          cashPaidController.text =
                              (collected / 2).toStringAsFixed(0);

                          onlinePaidController.text =
                              (collected - (collected / 2).floor())
                                  .toStringAsFixed(0);
                        } else {
                          cashPaidController.clear();

                          onlinePaidController.clear();
                        }
                      });
                    }
                  },
                ),
                if (paymentMode == 'Split') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cashPaidController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Cash Paid (₹)',
                              border: OutlineInputBorder()),
                          onChanged: (v) {
                            final cash = double.tryParse(v) ?? 0.0;

                            if (cash <= collected) {
                              onlinePaidController.text =
                                  (collected - cash).toStringAsFixed(0);
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: onlinePaidController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Online Paid (₹)',
                              border: OutlineInputBorder()),
                          onChanged: (v) {
                            final online = double.tryParse(v) ?? 0.0;

                            if (online <= collected) {
                              cashPaidController.text =
                                  (collected - online).toStringAsFixed(0);
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
                // ── Complement Toggle Section ─────────────────────────────
                const SizedBox(height: 16),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Add Complementary Products?',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Free gift from stock',
                      style: TextStyle(fontSize: 11)),
                  value: addComplements,
                  activeColor: Colors.deepOrange,
                  onChanged: (val) =>
                      setDialogState(() => addComplements = val),
                ),
                if (addComplements) ...[
                  const Divider(),
                  _buildComplementSection(
                    context: innerCtx,
                    setDialogState: setDialogState,
                    complementItems: complementItems,
                    selectedCategory: selectedCategory,
                    selectedProduct: selectedProduct,
                    qtyController: compQtyController,
                    productSearchQuery: productSearchQuery,
                    onCategoryChanged: (val) => setDialogState(() {
                      selectedCategory = val;
                      selectedProduct = null;
                    }),
                    onProductChanged: (val) =>
                        setDialogState(() => selectedProduct = val),
                    onSearchChanged: (val) =>
                        setDialogState(() => productSearchQuery = val),
                    onItemRemoved: (idx) =>
                        setDialogState(() => complementItems.removeAt(idx)),
                    shopId: service.shopId,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: !isAmountEqual
                    ? null
                    : () {
                        final double collectedAmt =
                            double.parse(amountController.text.trim());

                        double cashAmt = 0.0;

                        double onlineAmt = 0.0;

                        if (paymentMode == 'Cash') {
                          cashAmt = collectedAmt;
                        } else if (paymentMode == 'Online') {
                          onlineAmt = collectedAmt;
                        } else {
                          cashAmt =
                              double.tryParse(cashPaidController.text) ?? 0.0;

                          onlineAmt =
                              double.tryParse(onlinePaidController.text) ?? 0.0;

                          if ((cashAmt + onlineAmt - collectedAmt).abs() >
                              0.01) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Split amounts must sum to balance collected!'),
                                    backgroundColor: Colors.red));

                            return;
                          }
                        }

                        final double newAdvance =
                            service.advanceAmount + collectedAmt;

                        final double newCash = service.cashAmount + cashAmt;

                        final double newOnline =
                            service.onlineAmount + onlineAmt;

                        final double totalCompCost = complementItems.fold(
                            0.0,
                            (sum, item) =>
                                sum +
                                ((item['costPrice'] as num?)?.toDouble() ??
                                        0.0) *
                                    ((item['quantity'] as num?)?.toInt() ?? 1));

                        final updated = service.copyWith(
                          status: 'Delivered',
                          remainingAmount: 0.0,
                          cashAmount: newCash,
                          onlineAmount: newOnline,
                          complementaryItems:
                              List<Map<String, dynamic>>.from(complementItems),
                          complementaryCost: totalCompCost,
                        );

                        Navigator.pop(dialogCtx);

                        SoundHelper.playSuccess();

                        DatabaseService()
                            .updateService(updated)
                            .catchError((e) {
                          debugPrint('Error: $e');
                        });

                        if (complementItems.isNotEmpty) {
                          DatabaseService()
                              .recordComplementaryItems(updated)
                              .catchError((e) {
                            debugPrint('Error recording complements: $e');
                          });
                        }

                        if (mounted)
                          _showServiceBillOptionsDialog(context, updated);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Collect & Deliver'),
              ),
            ],
          );
        },
      ),
    ).then((_) => compQtyController.dispose());
  }

  // ── Edit Service ─────────────────────────────────────────────────────────

  void _showEditServiceDialog(BuildContext context, ServiceModel service) {
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: service.customerName);

    final phoneController = TextEditingController(text: service.customerPhone);

    final modelController = TextEditingController(text: service.mobileModel);

    final detailsController =
        TextEditingController(text: service.mobileDetails);

    // For Owner, totalController represents the base amount (before discount)

    final double initialBaseAmount = widget.employeeName == 'Owner'
        ? service.totalAmount + service.discountAmount
        : service.totalAmount;

    final totalController =
        TextEditingController(text: initialBaseAmount.toStringAsFixed(0));

    final advanceController =
        TextEditingController(text: service.advanceAmount.toStringAsFixed(0));

    final partsCostController = TextEditingController(
        text:
            service.partsCost > 0 ? service.partsCost.toStringAsFixed(0) : '');

    final technicianFeeController = TextEditingController(
        text: service.technicianFee > 0
            ? service.technicianFee.toStringAsFixed(0)
            : '');

    final discountController =
        TextEditingController(text: service.discountAmount.toStringAsFixed(0));

    final cashPaidController =
        TextEditingController(text: service.cashAmount.toStringAsFixed(0));

    final onlinePaidController =
        TextEditingController(text: service.onlineAmount.toStringAsFixed(0));

    bool isGstBill = service.isGstBill;
    String partsPaymentMode = service.partsPaymentMode;
    String feePaymentMode = service.technicianPaymentMode;
    String paymentMode = 'Cash';
    if (service.cashAmount > 0 && service.onlineAmount > 0) {
      paymentMode = 'Split';
    } else if (service.onlineAmount > 0) {
      paymentMode = 'Online';
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          scrollable: true,
          title: const Text('Edit Service Record'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.characters,
                  decoration:
                      const InputDecoration(labelText: 'Customer Name *'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                      labelText: 'Phone (10 digits, Optional)'),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;

                    if (v.length != 10) return 'Must be exactly 10 digits';

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Generate GST Bill'),
                  value: isGstBill,
                  activeColor: AppTheme.accentForest,
                  onChanged: (val) {
                    setState(() {
                      isGstBill = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: modelController,
                  textCapitalization: TextCapitalization.characters,
                  decoration:
                      const InputDecoration(labelText: 'Mobile Model *'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: detailsController,
                  textCapitalization: TextCapitalization.characters,
                  decoration:
                      const InputDecoration(labelText: 'Service Details'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: totalController,
                  decoration: const InputDecoration(
                      labelText: 'Total Amount (₹) *', prefixText: '₹ '),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => setState(() {}),
                  validator: (v) => (v == null || double.tryParse(v) == null)
                      ? 'Invalid amount'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: advanceController,
                  decoration: const InputDecoration(
                      labelText: 'Advance Paid (₹) *', prefixText: '₹ '),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    setState(() {
                      final adv = double.tryParse(val) ?? 0.0;
                      if (paymentMode == 'Split') {
                        cashPaidController.text =
                            (adv / 2).toStringAsFixed(0);
                        onlinePaidController.text =
                            (adv - (adv / 2).floor()).toStringAsFixed(0);
                      }
                    });
                  },
                  validator: (v) => (v != null &&
                          v.isNotEmpty &&
                          double.tryParse(v) == null)
                      ? 'Invalid amount'
                      : null,
                ),
                Builder(builder: (context) {
                  final double adv =
                      double.tryParse(advanceController.text) ?? 0.0;

                  if (adv <= 0) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Advance Payment Mode',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: paymentMode,
                          decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              border: OutlineInputBorder()),
                          items: ['Cash', 'Online', 'Split']
                              .map((m) =>
                                  DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                paymentMode = val;

                                if (val == 'Split') {
                                  cashPaidController.text =
                                      (adv / 2).toStringAsFixed(0);

                                  onlinePaidController.text =
                                      (adv - (adv / 2).floor())
                                          .toStringAsFixed(0);
                                } else {
                                  cashPaidController.clear();

                                  onlinePaidController.clear();
                                }
                              });
                            }
                          },
                        ),
                        if (paymentMode == 'Split') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: cashPaidController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Cash Paid (₹)',
                                      border: OutlineInputBorder()),
                                  onChanged: (v) {
                                    final cash = double.tryParse(v) ?? 0.0;

                                    if (cash <= adv) {
                                      onlinePaidController.text =
                                          (adv - cash).toStringAsFixed(0);
                                    }
                                  },
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'Required';

                                    final val = double.tryParse(v);

                                    if (val == null || val < 0)
                                      return 'Invalid';

                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: onlinePaidController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Online Paid (₹)',
                                      border: OutlineInputBorder()),
                                  onChanged: (v) {
                                    final online = double.tryParse(v) ?? 0.0;

                                    if (online <= adv) {
                                      cashPaidController.text =
                                          (adv - online).toStringAsFixed(0);
                                    }
                                  },
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'Required';

                                    final val = double.tryParse(v);

                                    if (val == null || val < 0)
                                      return 'Invalid';

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
                }),
                if (widget.employeeName == 'Owner') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: partsCostController,
                    decoration: const InputDecoration(
                        labelText: 'Display / Part Cost (₹)'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => setState(() {}),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12.0,
                    runSpacing: 6.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Parts Mode: ',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: [
                          ChoiceChip(
                            label: const Text('Cash'),
                            selected: partsPaymentMode == 'Cash',
                            onSelected: (val) {
                              if (val) setState(() => partsPaymentMode = 'Cash');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Online'),
                            selected: partsPaymentMode == 'Online',
                            onSelected: (val) {
                              if (val) setState(() => partsPaymentMode = 'Online');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: technicianFeeController,
                    decoration:
                        const InputDecoration(labelText: 'Technician Fee (₹)'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => setState(() {}),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12.0,
                    runSpacing: 6.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Tech Fee Mode: ',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: [
                          ChoiceChip(
                            label: const Text('Cash'),
                            selected: feePaymentMode == 'Cash',
                            onSelected: (val) {
                              if (val) setState(() => feePaymentMode = 'Cash');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Online'),
                            selected: feePaymentMode == 'Online',
                            onSelected: (val) {
                              if (val) setState(() => feePaymentMode = 'Online');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: discountController,
                    decoration:
                        const InputDecoration(labelText: 'Discount Given (₹)'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Builder(builder: (context) {
                    double partsCost =
                        double.tryParse(partsCostController.text) ?? 0.0;

                    double technicianFee =
                        double.tryParse(technicianFeeController.text) ?? 0.0;

                    double baseTotal =
                        double.tryParse(totalController.text) ?? 0.0;

                    double discount =
                        double.tryParse(discountController.text) ?? 0.0;

                    double netTotal =
                        (baseTotal - discount).clamp(0.0, double.infinity);

                    double taxableAmount = netTotal;

                    if (isGstBill) {
                      final cgstRate = _gstSettings?.cgstRate ?? 9.0;

                      final sgstRate = _gstSettings?.sgstRate ?? 9.0;

                      taxableAmount =
                          netTotal / (1 + (cgstRate + sgstRate) / 100);
                    }

                    final profit = taxableAmount -
                        partsCost -
                        technicianFee -
                        service.reRepairCost;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Estimated Net Profit:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('₹${profit.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: profit >= 0 ? Colors.green : Colors.red,
                                fontSize: 14)),
                      ],
                    );
                  }),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final baseTotal = double.parse(totalController.text);

                final discount = widget.employeeName == 'Owner'
                    ? (double.tryParse(discountController.text.trim()) ?? 0.0)
                    : service.discountAmount;

                final netTotal =
                    (baseTotal - discount).clamp(0.0, double.infinity);

                final advance = double.tryParse(advanceController.text.trim()) ?? 0.0;
                double cashAmt = 0.0;
                double onlineAmt = 0.0;

                if (advance > 0) {
                  if (paymentMode == 'Cash') {
                    cashAmt = advance;
                  } else if (paymentMode == 'Online') {
                    onlineAmt = advance;
                  } else {
                    cashAmt = double.tryParse(cashPaidController.text) ?? 0.0;
                    onlineAmt = double.tryParse(onlinePaidController.text) ?? 0.0;

                    if ((cashAmt + onlineAmt - advance).abs() > 0.01) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content:
                              Text('Split amounts must sum to advance paid!'),
                          backgroundColor: Colors.red));
                      return;
                    }
                  }
                }
                final remaining =
                    (netTotal - advance).clamp(0.0, double.infinity);
                double taxableAmount = netTotal;
                double cgstAmount = 0.0;
                double sgstAmount = 0.0;
                if (isGstBill) {
                  final cgstRate = _gstSettings?.cgstRate ?? 9.0;
                  final sgstRate = _gstSettings?.sgstRate ?? 9.0;
                  taxableAmount = netTotal / (1 + (cgstRate + sgstRate) / 100);
                  cgstAmount = taxableAmount * cgstRate / 100;
                  sgstAmount = taxableAmount * sgstRate / 100;
                }
                final updated = ServiceModel(
                  id: service.id,
                  customerName: nameController.text.trim(),
                  customerNameLower: nameController.text.trim().toLowerCase(),
                  customerPhone: phoneController.text.trim(),
                  mobileModel: modelController.text.trim(),
                  mobileDetails: detailsController.text.trim(),
                  totalAmount: netTotal,
                  advanceAmount: advance,
                  remainingAmount: remaining,
                  status: service.status == 'Delivered'
                      ? 'Delivered'
                      : (remaining <= 0 ? 'Completed' : 'Pending'),
                  timestamp: service.timestamp,
                  shopId: service.shopId,
                  employeeName: service.employeeName,
                  isGstBill: isGstBill,
                  taxableAmount: taxableAmount,
                  cgstAmount: cgstAmount,
                  sgstAmount: sgstAmount,
                  partsCost: double.tryParse(partsCostController.text) ?? 0.0,
                  technicianFee:
                      double.tryParse(technicianFeeController.text) ?? 0.0,
                  reRepairCost: service.reRepairCost,
                  discountAmount: discount,
                  isExpenseRecorded: service.isExpenseRecorded ||
                      (double.tryParse(partsCostController.text) ?? 0.0) > 0 ||
                      (double.tryParse(technicianFeeController.text) ?? 0.0) >
                          0,
                  cashAmount: cashAmt,
                  onlineAmount: onlineAmt,
                  partsPaymentMode: partsPaymentMode,
                  technicianPaymentMode: feePaymentMode,
                );
                SoundHelper.playSuccess();
                DatabaseService().updateService(updated).catchError((e) {
                  debugPrint('Error updating service in background: $e');
                });
                await Future.delayed(const Duration(milliseconds: 500));
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Service record updated successfully')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentForest,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete Service ────────────────────────────────────────────────────────
  void _confirmDeleteService(BuildContext context, ServiceModel service) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Service Record?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${service.customerName} — ${service.mobileModel}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will permanently delete the service record.\nThis action cannot be undone.',
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              SoundHelper.playSuccess();
              Navigator.pop(dialogCtx);
              DatabaseService()
                  .deleteService(service.id, service: service)
                  .catchError((e) {
                debugPrint('Error deleting service: $e');
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Service record deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Re-Repair Dialog ──────────────────────────────────────────────────────
  void _showReRepairDialog(BuildContext context, ServiceModel service) {
    final reasonController = TextEditingController();
    final costController = TextEditingController(text: '0');
    bool isSubmitting = false;
    final isOwner = widget.employeeName == 'Owner';
    String paymentMode = 'Online';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setDialogState) {
          costController.addListener(() => setDialogState(() {}));
          return AlertDialog(
            scrollable: true,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.build_circle_outlined,
                      color: Colors.orange.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                      isOwner ? 'Log Re-Repair Loss' : 'Request Re-Repair'),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.phone_android,
                          color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(service.customerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(service.mobileModel,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (isOwner) ...[
                  const Text('External Specialist Cost',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.black54)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: costController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0',
                      prefixText: '\u20B9 ',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      'Enter 0 if no specialist fee was paid.',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.black45,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Payment Mode',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.black54)),
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
                  const SizedBox(height: 12),
                ],
                const Text('Reason / Notes',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.black54)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  textCapitalization: TextCapitalization.characters,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g. Same issue returned after 3 days...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                if (!isOwner) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Your request will be sent to the owner for approval.',
                            style: TextStyle(fontSize: 12),
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
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (reasonController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please enter a reason')),
                          );
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        try {
                          final requestId = const Uuid().v4();
                          final cost = isOwner
                              ? (double.tryParse(costController.text.trim()) ??
                                  0.0)
                              : 0.0;
                          final replacement = ReplacementModel(
                            id: requestId,
                            productId: service.id,
                            productName: 'Service: ' + service.mobileModel,
                            employeeName: widget.employeeName,
                            shopId: widget.shopId,
                            reason: reasonController.text.trim(),
                            status: isOwner ? 'accepted' : 'pending',
                            timestamp: DateTime.now(),
                            isService: true,
                            costPrice: isOwner ? cost : null,
                            customerName: service.customerName,
                            paymentMode: paymentMode,
                          );
                          final db = DatabaseService();
                          await db.addReplacementRequest(replacement);
                          if (isOwner) {
                            await db.approveReplacement(requestId, cost,
                                paymentMode: paymentMode);
                          }
                          if (mounted) {
                            Navigator.pop(dialogCtx);
                            SoundHelper.playSuccess();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(isOwner
                                  ? 'Re-repair loss of \u20B9' +
                                      cost.toStringAsFixed(0) +
                                      ' recorded'
                                  : 'Re-repair request sent to owner for approval'),
                              backgroundColor: isOwner
                                  ? Colors.orange.shade700
                                  : AppTheme.accentForest,
                            ));
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Error: ' + e.toString()),
                                  backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(isOwner
                        ? (costController.text.trim() == '0' ||
                                costController.text.trim().isEmpty
                            ? 'Save / Skip'
                            : 'Record Loss')
                        : 'Send Request'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context, ServiceModel service) {
    final amountController = TextEditingController();
    final cashPaidController = TextEditingController();
    final onlinePaidController = TextEditingController();
    String paymentMode = 'Cash';
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setDialogState) {
          final double amount =
              double.tryParse(amountController.text.trim()) ?? 0.0;
          return AlertDialog(
            scrollable: true,
            title: const Text('Add Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Remaining: \u20B9' +
                        service.remainingAmount.toStringAsFixed(0),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(
                      labelText: 'Amount Paid Now (\u20B9)',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    setDialogState(() {
                      final collectedAmt = double.tryParse(val.trim()) ?? 0.0;

                      if (paymentMode == 'Split') {
                        cashPaidController.text =
                            (collectedAmt / 2).toStringAsFixed(0);

                        onlinePaidController.text =
                            (collectedAmt - (collectedAmt / 2).floor())
                                .toStringAsFixed(0);
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: paymentMode,
                  decoration: const InputDecoration(
                      labelText: 'Payment Mode', border: OutlineInputBorder()),
                  items: ['Cash', 'Online', 'Split']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        paymentMode = val;

                        if (val == 'Split') {
                          cashPaidController.text =
                              (amount / 2).toStringAsFixed(0);

                          onlinePaidController.text =
                              (amount - (amount / 2).floor())
                                  .toStringAsFixed(0);
                        } else {
                          cashPaidController.clear();

                          onlinePaidController.clear();
                        }
                      });
                    }
                  },
                ),
                if (paymentMode == 'Split') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cashPaidController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Cash Paid (₹)',
                              border: OutlineInputBorder()),
                          onChanged: (v) {
                            final cash = double.tryParse(v) ?? 0.0;

                            if (cash <= amount) {
                              onlinePaidController.text =
                                  (amount - cash).toStringAsFixed(0);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: onlinePaidController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Online Paid (₹)',
                              border: OutlineInputBorder()),
                          onChanged: (v) {
                            final online = double.tryParse(v) ?? 0.0;

                            if (online <= amount) {
                              cashPaidController.text =
                                  (amount - online).toStringAsFixed(0);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amountPaid =
                      double.tryParse(amountController.text.trim()) ?? 0;

                  if (amountPaid <= 0 || amountPaid > service.remainingAmount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid amount')));

                    return;
                  }

                  double cashAmt = 0.0;

                  double onlineAmt = 0.0;

                  if (paymentMode == 'Cash') {
                    cashAmt = amountPaid;
                  } else if (paymentMode == 'Online') {
                    onlineAmt = amountPaid;
                  } else {
                    cashAmt = double.tryParse(cashPaidController.text) ?? 0.0;

                    onlineAmt =
                        double.tryParse(onlinePaidController.text) ?? 0.0;

                    if ((cashAmt + onlineAmt - amountPaid).abs() > 0.01) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content:
                              Text('Split amounts must sum to amount paid!'),
                          backgroundColor: Colors.red));

                      return;
                    }
                  }

                  final remaining = service.remainingAmount - amountPaid;

                  final updated = service.copyWith(
                    advanceAmount: service.advanceAmount + amountPaid,
                    remainingAmount: remaining,
                    status: remaining <= 0 ? 'Completed' : service.status,
                    cashAmount: service.cashAmount + cashAmt,
                    onlineAmount: service.onlineAmount + onlineAmt,
                  );

                  Navigator.pop(dialogCtx);

                  _showServiceBillOptionsDialog(context, updated);

                  SoundHelper.playSuccess();

                  DatabaseService().updateServicePayment(
                      service.id,
                      amountPaid,
                      service.advanceAmount,
                      service.totalAmount,
                      cashAmt,
                      onlineAmt);
                },
                child: const Text('Save Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.red.shade700;

      case 'Completed':
        return Colors.amber.shade800;

      case 'Delivered':
        return Colors.green.shade700;

      default:
        return Colors.blueGrey;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.red.shade50;

      case 'Completed':
        return Colors.amber.shade50;

      case 'Delivered':
        return Colors.green.shade50;

      default:
        return Colors.grey.shade50;
    }
  }

  IconData _getStatusIconData(String status) {
    switch (status) {
      case 'Pending':
        return Icons.timer_outlined;

      case 'Completed':
        return Icons.check_circle;

      default:
        return Icons.local_shipping;
    }
  }

  void _showAddServiceDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController();

    final phoneController = TextEditingController();

    final modelController = TextEditingController();

    final detailsController = TextEditingController();

    final totalController = TextEditingController();

    final advanceController = TextEditingController();

    final partsCostController = TextEditingController();

    final technicianFeeController = TextEditingController();

    final cashPaidController = TextEditingController();

    final onlinePaidController = TextEditingController();

    String paymentMode = 'Cash';

    bool isGstBill = false;

    String partsPaymentMode = 'Cash';
    String feePaymentMode = 'Cash';

    List<String> suggestedNames = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
          title: const Text('Add Service Entry'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.characters,
                  decoration:
                      const InputDecoration(labelText: 'Customer Name *'),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                      labelText: 'Phone (10 digits, Optional)'),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onChanged: (val) async {
                    final cleaned = val.trim();

                    if (cleaned.length == 10) {
                      final names = await DatabaseService()
                          .findCustomerNamesByPhone(cleaned);

                      setState(() {
                        suggestedNames = names;

                        if (names.length == 1 &&
                            nameController.text.trim().isEmpty) {
                          nameController.text = names.first;
                        }
                      });
                    } else {
                      if (suggestedNames.isNotEmpty) {
                        setState(() {
                          suggestedNames = [];
                        });
                      }
                    }
                  },
                  validator: (val) {
                    if (val == null || val.isEmpty) return null;

                    if (val.length != 10) return 'Must be exactly 10 digits';

                    return null;
                  },
                ),
                if (suggestedNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select from previous customer names:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: suggestedNames.map((name) {
                        return ActionChip(
                          label: Text(name),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          onPressed: () {
                            setState(() {
                              nameController.text = name;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Generate GST Bill'),
                  value: isGstBill,
                  activeColor: AppTheme.accentForest,
                  onChanged: (val) {
                    setState(() {
                      isGstBill = val;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: modelController,
                  textCapitalization: TextCapitalization.characters,
                  decoration:
                      const InputDecoration(labelText: 'Mobile Model *'),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: detailsController,
                  textCapitalization: TextCapitalization.characters,
                  decoration:
                      const InputDecoration(labelText: 'Service Details'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: totalController,
                  decoration: const InputDecoration(
                      labelText: 'Total Estimated Amount *'),
                  keyboardType: TextInputType.number,
                  validator: (val) =>
                      (val == null || double.tryParse(val) == null)
                          ? 'Invalid amount'
                          : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: advanceController,
                  decoration: const InputDecoration(labelText: 'Advance Paid'),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    setState(() {
                      final adv = double.tryParse(val) ?? 0;

                      if (paymentMode == 'Split') {
                        cashPaidController.text = (adv / 2).toStringAsFixed(0);

                        onlinePaidController.text =
                            (adv - (adv / 2).floor()).toStringAsFixed(0);
                      }
                    });
                  },
                  validator: (val) => (val != null &&
                          val.isNotEmpty &&
                          double.tryParse(val) == null)
                      ? 'Invalid amount'
                      : null,
                ),
                Builder(builder: (context) {
                  final double adv =
                      double.tryParse(advanceController.text) ?? 0.0;

                  if (adv <= 0) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Advance Payment Mode',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: paymentMode,
                          decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              border: OutlineInputBorder()),
                          items: ['Cash', 'Online', 'Split']
                              .map((m) =>
                                  DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                paymentMode = val;

                                if (val == 'Split') {
                                  cashPaidController.text =
                                      (adv / 2).toStringAsFixed(0);

                                  onlinePaidController.text =
                                      (adv - (adv / 2).floor())
                                          .toStringAsFixed(0);
                                } else {
                                  cashPaidController.clear();

                                  onlinePaidController.clear();
                                }
                              });
                            }
                          },
                        ),
                        if (paymentMode == 'Split') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: cashPaidController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Cash Paid (₹)',
                                      border: OutlineInputBorder()),
                                  onChanged: (v) {
                                    final cash = double.tryParse(v) ?? 0.0;

                                    if (cash <= adv) {
                                      onlinePaidController.text =
                                          (adv - cash).toStringAsFixed(0);
                                    }
                                  },
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'Required';

                                    final val = double.tryParse(v);

                                    if (val == null || val < 0)
                                      return 'Invalid';

                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: onlinePaidController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Online Paid (₹)',
                                      border: OutlineInputBorder()),
                                  onChanged: (v) {
                                    final online = double.tryParse(v) ?? 0.0;

                                    if (online <= adv) {
                                      cashPaidController.text =
                                          (adv - online).toStringAsFixed(0);
                                    }
                                  },
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'Required';

                                    final val = double.tryParse(v);

                                    if (val == null || val < 0)
                                      return 'Invalid';

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
                }),
                if (widget.employeeName == 'Owner') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: partsCostController,
                    decoration: const InputDecoration(
                        labelText: 'Display / Part Cost (\u20B9)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12.0,
                    runSpacing: 6.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Parts Mode: ',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: [
                          ChoiceChip(
                            label: const Text('Cash'),
                            selected: partsPaymentMode == 'Cash',
                            onSelected: (val) {
                              if (val) setState(() => partsPaymentMode = 'Cash');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Online'),
                            selected: partsPaymentMode == 'Online',
                            onSelected: (val) {
                              if (val) setState(() => partsPaymentMode = 'Online');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: technicianFeeController,
                    decoration: const InputDecoration(
                        labelText: 'Technician Fee (\u20B9)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12.0,
                    runSpacing: 6.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Tech Fee Mode: ',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: [
                          ChoiceChip(
                            label: const Text('Cash'),
                            selected: feePaymentMode == 'Cash',
                            onSelected: (val) {
                              if (val) setState(() => feePaymentMode = 'Cash');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Online'),
                            selected: feePaymentMode == 'Online',
                            onSelected: (val) {
                              if (val) setState(() => feePaymentMode = 'Online');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;

                final total = double.parse(totalController.text);

                final advance = double.tryParse(advanceController.text) ?? 0;

                double cashAmt = 0.0;

                double onlineAmt = 0.0;

                if (advance > 0) {
                  if (paymentMode == 'Cash') {
                    cashAmt = advance;
                  } else if (paymentMode == 'Online') {
                    onlineAmt = advance;
                  } else {
                    cashAmt = double.tryParse(cashPaidController.text) ?? 0.0;

                    onlineAmt =
                        double.tryParse(onlinePaidController.text) ?? 0.0;

                    if ((cashAmt + onlineAmt - advance).abs() > 0.01) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content:
                              Text('Split amounts must sum to advance paid!'),
                          backgroundColor: Colors.red));

                      return;
                    }
                  }
                }

                double taxableAmount = total;

                double cgstAmount = 0.0;

                double sgstAmount = 0.0;

                if (isGstBill) {
                  final cgstRate = _gstSettings?.cgstRate ?? 9.0;

                  final sgstRate = _gstSettings?.sgstRate ?? 9.0;

                  taxableAmount = total / (1 + (cgstRate + sgstRate) / 100);

                  cgstAmount = taxableAmount * cgstRate / 100;

                  sgstAmount = taxableAmount * sgstRate / 100;
                }

                final pCost =
                    double.tryParse(partsCostController.text.trim()) ?? 0.0;

                final tFee =
                    double.tryParse(technicianFeeController.text.trim()) ?? 0.0;

                final service = ServiceModel(
                  id: const Uuid().v4(),
                  customerName: nameController.text.trim(),
                  customerNameLower: nameController.text.trim().toLowerCase(),
                  customerPhone: phoneController.text.trim(),
                  mobileModel: modelController.text.trim(),
                  mobileDetails: detailsController.text.trim(),
                  totalAmount: total,
                  advanceAmount: advance,
                  remainingAmount: total - advance,
                  status: 'Pending',
                  timestamp: DateTime.now(),
                  shopId: widget.shopId,
                  employeeName: widget.employeeName,
                  isGstBill: isGstBill,
                  taxableAmount: taxableAmount,
                  cgstAmount: cgstAmount,
                  sgstAmount: sgstAmount,
                  partsCost: pCost,
                  technicianFee: tFee,
                  isExpenseRecorded: pCost > 0 || tFee > 0,
                  cashAmount: cashAmt,
                  onlineAmount: onlineAmt,
                  partsPaymentMode: partsPaymentMode,
                  technicianPaymentMode: feePaymentMode,
                );

                Navigator.pop(context); // Close add service dialog immediately

                SoundHelper.playSuccess();

                DatabaseService().addService(service);
              },
              child: const Text('Save Entry'),
            ),
          ],
        ),
      ),
    );
  }
}
