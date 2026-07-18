import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../../services/database_service.dart';
import '../../models/sale_model.dart';
import '../../models/service_model.dart';
import '../../models/replacement_model.dart';
import '../../utils/app_theme.dart';
import 'sale_bill_screen.dart';

class WarrantySearchScreen extends StatefulWidget {
  final String shopId;
  final String employeeName;
  final bool isOwner;

  const WarrantySearchScreen({
    super.key,
    required this.shopId,
    required this.employeeName,
    required this.isOwner,
  });

  @override
  State<WarrantySearchScreen> createState() => _WarrantySearchScreenState();
}

class _WarrantySearchScreenState extends State<WarrantySearchScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  final Set<String> _processedItemIds = {}; // Tracker for processed items

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isEmpty) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        return;
      }
      _performSearch(query);
    });
  }

  void _performSearch(String query) async {
    setState(() => _isSearching = true);
    final results = await DatabaseService().searchSales(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryIvory,
      appBar: AppBar(title: const Text('Warranty & Purchase Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Enter Customer Name or Phone Number',
                hintText: 'Type to search...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            })
                        : null,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_isSearching && _searchResults.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (_searchResults.isEmpty &&
              _searchController.text.isNotEmpty &&
              !_isSearching)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('No records found for this customer',
                  style: TextStyle(
                      color: Colors.grey, fontStyle: FontStyle.italic)),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final record = _searchResults[index];

                  if (record is SaleModel) {
                    return _buildSaleCard(record);
                  } else if (record is ServiceModel) {
                    return _buildServiceCard(record);
                  }
                  return const SizedBox();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(SaleModel sale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            tileColor: AppTheme.accentForest.withOpacity(0.05),
            leading: const Icon(Icons.shopping_bag_outlined,
                color: AppTheme.accentForest),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale.customerName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(sale.customerPhone,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.accentForest,
                        letterSpacing: 1.0)),
              ],
            ),
            subtitle: Text(
                'Date: ${sale.timestamp.toString().substring(0, 16)} | ID: ${sale.id.substring(0, 8)}',
                style: const TextStyle(fontSize: 11)),
            trailing: Text('₹${sale.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.accentForest)),
          ),
          ...sale.items
              .map((item) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined,
                            size: 20, color: AppTheme.accentForest),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.productName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              Text(
                                  'Qty: ${item.quantity} | Cat: ${item.category}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              _showWarrantyDialog(context, sale, item),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentForest,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(60, 30),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Replace',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildServiceCard(ServiceModel service) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.build_circle_outlined, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.customerName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(service.customerPhone,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.blue,
                              letterSpacing: 1.0)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Total: ₹${service.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (service.remainingAmount > 0)
                      Text(
                          'Due: ₹${service.remainingAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold))
                    else
                      const Text('Paid Full',
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${service.mobileModel} | Status: ${service.status}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontSize: 13)),
                      Text(
                          'Date: ${service.timestamp.toString().substring(0, 16)}',
                          style: const TextStyle(
                              fontSize: 11, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                if (!_processedItemIds.contains(service.id))
                  ElevatedButton(
                    onPressed: () =>
                        _showServiceReplacementDialog(context, service),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      minimumSize: const Size(60, 30),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Re-Repair',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showServiceReplacementDialog(
      BuildContext context, ServiceModel service) {
    final reasonController = TextEditingController();
    final costController = TextEditingController(text: '0');
    bool isSubmitting = false;
    final isOwner = widget.isOwner;
    String paymentMode = 'Online';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setDialogState) {
          // Rebuild when cost is typed for dynamic button text
          costController.addListener(() => setDialogState(() {}));

          return AlertDialog(
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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service info summary
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
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
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
                  // Cost field — only for owner
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
                            if (val)
                              setDialogState(() => paymentMode = 'Online');
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
                        // Mandatory cost check removed to allow 0/empty

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
                            productName: 'Service: ${service.mobileModel}',
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
                            setState(() => _processedItemIds.add(service.id));
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(isOwner
                                  ? 'Re-repair loss of \u20B9${cost.toStringAsFixed(0)} recorded'
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
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                style: isOwner
                    ? ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                      )
                    : null,
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
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

  void _showWarrantyDialog(
      BuildContext context, SaleModel sale, CartItem item) async {
    final reasonController =
        TextEditingController(text: 'Warranty Replacement');
    final costController = TextEditingController();
    bool isSubmitting = false;
    bool isFetchingCost = false;
    String returnAction = 'replace'; // 'replace', 'refund', 'exchange'

    // Fetch cost price automatically if owner
    if (widget.isOwner) {
      isFetchingCost = true;
      try {
        final product = await DatabaseService().getProduct(item.productId);
        if (product != null && product.costPrice > 0) {
          costController.text = product.costPrice.toStringAsFixed(0);
        }
      } catch (e) {
        debugPrint('Error fetching auto-cost: $e');
      } finally {
        isFetchingCost = false;
      }
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Defective Return / Warranty'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Item: ${item.productName}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Original Bill: ${sale.id.substring(0, 8)}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 16),
                const Text('Return Action',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.black54)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: returnAction,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                        value: 'replace', child: Text('Replace from Stock')),
                    DropdownMenuItem(
                        value: 'refund', child: Text('Refund Customer')),
                    DropdownMenuItem(
                        value: 'exchange', child: Text('Exchange Item')),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      returnAction = val ?? 'replace';
                    });
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.isOwner && returnAction != 'exchange') ...[
                  const Text('Loss Cost Price',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.black54)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: costController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: isFetchingCost ? 'Fetching...' : '0',
                      prefixText: '\u20B9 ',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      suffixIcon: isFetchingCost
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)))
                          : const Icon(Icons.auto_awesome,
                              size: 16, color: Colors.green),
                    ),
                  ),
                  Text(
                    'Auto-filled from inventory cost',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Reason for return',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.black54)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: 'Reason...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final reasonText = reasonController.text.trim();
                      final costText = costController.text.trim();

                      if (reasonText.isEmpty ||
                          (widget.isOwner &&
                              costText.isEmpty &&
                              returnAction != 'exchange')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please fill all fields')));
                        return;
                      }

                      if (returnAction == 'exchange') {
                        final String requestId = const Uuid().v4();
                        final double costValue = widget.isOwner
                            ? (double.tryParse(costText) ?? 0.0)
                            : 0.0;

                        Navigator.pop(dialogCtx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SaleBillScreen(
                              shopId: widget.shopId,
                              employeeName: widget.employeeName,
                              prefilledCustomerName: sale.customerName,
                              prefilledCustomerPhone: sale.customerPhone,
                              exchangeCredit: item.price,
                              returnedReplacementId: requestId,
                              returnedProductId: item.productId,
                              returnedProductName: item.productName,
                              returnedReason: '[Exchange] $reasonText',
                              returnedSaleId: sale.id,
                              returnedCostPrice: costValue,
                            ),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      try {
                        final String requestId = const Uuid().v4();
                        final double costValue = widget.isOwner
                            ? (double.tryParse(costText) ?? 0.0)
                            : 0.0;

                        final replacement = ReplacementModel(
                          id: requestId,
                          productId: item.productId,
                          productName: item.productName,
                          employeeName: widget.employeeName,
                          shopId: widget.shopId,
                          reason: '[Warranty] $reasonText',
                          status: widget.isOwner ? 'accepted' : 'pending',
                          timestamp: DateTime.now(),
                          costPrice: widget.isOwner ? costValue : null,
                          saleId: sale.id,
                          customerName: sale.customerName,
                          returnAction: returnAction,
                        );

                        final db = DatabaseService();
                        if (widget.isOwner) {
                          await db.addAndApproveReplacement(
                              replacement, costValue);
                        } else {
                          await db.addReplacementRequest(replacement);
                        }

                        if (mounted) {
                          setState(() {
                            _processedItemIds
                                .add('${sale.id}_${item.productName}');
                          });
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(widget.isOwner
                                ? (returnAction == 'refund'
                                    ? 'Warranty refund recorded'
                                    : 'Warranty replacement recorded')
                                : 'Warranty request sent to owner'),
                            backgroundColor: widget.isOwner
                                ? Colors.orange.shade800
                                : AppTheme.accentForest,
                          ));
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red));
                        }
                      }
                    },
              style: widget.isOwner
                  ? ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white)
                  : null,
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(returnAction == 'exchange'
                      ? 'Proceed to Exchange'
                      : (widget.isOwner
                          ? 'Confirm & Process'
                          : 'Send Request')),
            ),
          ],
        ),
      ),
    );
  }
}
