import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/replacement_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/shop_helper.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class DealerClaimsScreen extends StatefulWidget {
  final String shopId;

  const DealerClaimsScreen({super.key, required this.shopId});

  @override
  State<DealerClaimsScreen> createState() => _DealerClaimsScreenState();
}

class _DealerClaimsScreenState extends State<DealerClaimsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void _shareToWhatsApp(ReplacementModel claim, String dealerName) async {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('🧾 *D&H MOBILES - WARRANTY CLAIM*');
    buffer.writeln('----------------------------------------');
    buffer.writeln('👤 *Dealer:* $dealerName');
    buffer.writeln('📦 *Product:* ${claim.productName}');
    buffer.writeln('🔧 *Cause of Return:* ${claim.reason.replaceAll("[Warranty] ", "").replaceAll("[Exchange] ", "")}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Please process the warranty replacement. (I will send the product image separately)');

    final String message = buffer.toString();
    final String waUrl = 'https://wa.me/?text=${Uri.encodeComponent(message)}';
    final Uri uri = Uri.parse(waUrl);

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await Share.share(message, subject: 'Dealer Claim - ${claim.productName}');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open WhatsApp: $e')),
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryIvory,
      appBar: AppBar(
        title: Text('Dealer Claims - ${ShopHelper.getDisplayName(widget.shopId)}'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Collected (Pending)'),
            Tab(text: 'Sent to Dealer'),
            Tab(text: 'Resolved / Closed'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by Product or Dealer...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.accentForest),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.accentForest, width: 1.2),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ReplacementModel>>(
              stream: DatabaseService().getDealerClaims(widget.shopId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No dealer claims found for this shop.',
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  );
                }

                final allClaims = snapshot.data!;
                final filteredClaims = allClaims.where((c) {
                  if (_searchQuery.isEmpty) return true;
                  final query = _searchQuery.toLowerCase();
                  final pName = c.productName.toLowerCase();
                  final dName = (c.dealerName ?? '').toLowerCase();
                  return pName.contains(query) || dName.contains(query);
                }).toList();

                final collectedClaims = filteredClaims.where((c) => c.dealerStatus == 'collected').toList();
                final sentClaims = filteredClaims.where((c) => c.dealerStatus == 'sent_to_dealer').toList();
                final resolvedClaims = filteredClaims
                    .where((c) =>
                        c.dealerStatus == 'resolved_replaced' ||
                        c.dealerStatus == 'resolved_refunded' ||
                        c.dealerStatus == 'dealer_rejected')
                    .toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildClaimsList(collectedClaims, 'collected'),
                    _buildClaimsList(sentClaims, 'sent_to_dealer'),
                    _buildClaimsList(resolvedClaims, 'resolved'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimsList(List<ReplacementModel> claims, String tabType) {
    if (claims.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tabType == 'collected'
                  ? Icons.hourglass_empty_rounded
                  : (tabType == 'sent_to_dealer' ? Icons.local_shipping_outlined : Icons.check_circle_outline),
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No items in this section.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: claims.length,
      itemBuilder: (context, index) {
        final claim = claims[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getStatusColor(claim.dealerStatus ?? '').withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getStatusIcon(claim.dealerStatus ?? ''),
                  color: _getStatusColor(claim.dealerStatus ?? ''),
                ),
              ),
              title: Text(
                claim.productName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                'Action: ${claim.returnAction?.toUpperCase() ?? "UNKNOWN"} | Cust: ${claim.customerName}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${(claim.costPrice ?? 0).toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.accentForest),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(claim.dealerStatus ?? '').withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusLabel(claim.dealerStatus ?? ''),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(claim.dealerStatus ?? ''),
                      ),
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildDetailRow('Claim ID', claim.id.substring(0, 8)),
                      _buildDetailRow('Returned on', DateFormat('dd-MM-yyyy hh:mm a').format(claim.timestamp)),
                      _buildDetailRow('Reason for Return', claim.reason),
                      _buildDetailRow('Collected By', claim.employeeName),
                      if (claim.saleId != null)
                        _buildDetailRow('Original Bill ID', claim.saleId!.substring(0, 8)),
                      if (claim.dealerName != null) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'DEALER DETAILS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 4),
                        _buildDetailRow('Dealer Name', claim.dealerName!),
                        if (claim.dealerSentDate != null)
                          _buildDetailRow('Sent Date', DateFormat('dd-MM-yyyy').format(claim.dealerSentDate!)),
                        if (claim.dealerResolvedDate != null)
                          _buildDetailRow('Resolved Date', DateFormat('dd-MM-yyyy').format(claim.dealerResolvedDate!)),
                      ],
                      if (tabType == 'collected' || tabType == 'sent_to_dealer') ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (tabType == 'collected')
                              ElevatedButton.icon(
                                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                                label: const Text('Ship to Dealer'),
                                onPressed: () => _showShipDialog(context, claim),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentForest,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            if (tabType == 'sent_to_dealer')
                              ElevatedButton.icon(
                                icon: const Icon(Icons.done_all, size: 18),
                                label: const Text('Resolve Claim'),
                                onPressed: () => _showResolveDialog(context, claim),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade800,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showShipDialog(BuildContext context, ReplacementModel claim) {
    final dealerController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Send to Dealer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dealerController,
                decoration: const InputDecoration(
                  labelText: 'Dealer / Distributor Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
              ),
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
                      final dealer = dealerController.text.trim();

                      if (dealer.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter dealer name')),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      try {
                        await DatabaseService().sendReplacementToDealer(claim.id, dealer);
                        if (mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Claim status updated: Sent to Dealer'), backgroundColor: Colors.green),
                          );
                          _shareToWhatsApp(claim, dealer);
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentForest, foregroundColor: Colors.white),
              child: isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Mark Sent'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResolveDialog(BuildContext context, ReplacementModel claim) {
    String selectedResolution = 'replaced'; // 'replaced', 'refunded', 'rejected'
    String refundPaymentMode = 'Online'; // only used when selectedResolution == 'refunded'
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Resolve Dealer Claim'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Product: ${claim.productName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Dealer Action/Resolution:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedResolution,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'replaced', child: Text('Replaced (Add Stock)')),
                  DropdownMenuItem(value: 'refunded', child: Text('Refunded (Offset Loss)')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected (Permanent Loss)')),
                ],
                onChanged: (val) {
                  setDialogState(() {
                    selectedResolution = val ?? 'replaced';
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),

              // ── Refund: Cash/Online selector ─────────────────────────────
              if (selectedResolution == 'refunded') ...[
                const SizedBox(height: 14),
                const Text('How did the dealer refund you?',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  children: [
                    ChoiceChip(
                      label: const Text('Online (GPAY/Bank)'),
                      selected: refundPaymentMode == 'Online',
                      selectedColor: Colors.blue.shade100,
                      onSelected: (val) {
                        if (val) setDialogState(() => refundPaymentMode = 'Online');
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Cash'),
                      selected: refundPaymentMode == 'Cash',
                      selectedColor: Colors.green.shade100,
                      onSelected: (val) {
                        if (val) setDialogState(() => refundPaymentMode = 'Cash');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 15, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          refundPaymentMode == 'Online'
                              ? 'Refund will be added to your Online/Bank balance.'
                              : 'Refund will be added to your Cash Drawer balance.',
                          style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Rejected: Permanent loss warning ─────────────────────────
              if (selectedResolution == 'rejected') ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                            children: [
                              const TextSpan(
                                text: 'Permanent Loss! ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: 'The loss of ₹${((claim.costPrice ?? 0) * claim.quantity).toStringAsFixed(0)} '
                                    'for ${claim.productName} will remain as a confirmed business expense. '
                                    'No recovery will be recorded.',
                              ),
                            ],
                          ),
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
                      setDialogState(() => isSubmitting = true);
                      try {
                        await DatabaseService().resolveDealerClaim(
                          claim.id,
                          selectedResolution,
                          refundPaymentMode: refundPaymentMode,
                        );
                        if (mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(selectedResolution == 'rejected'
                                  ? 'Claim marked as rejected. Loss is permanently recorded.'
                                  : 'Dealer claim successfully resolved'),
                              backgroundColor: selectedResolution == 'rejected' ? Colors.red.shade700 : Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedResolution == 'rejected' ? Colors.red.shade700 : Colors.blue.shade800,
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(selectedResolution == 'rejected' ? 'Confirm Permanent Loss' : 'Confirm Resolution'),
            ),
          ],
        ),
      ),
    );
  }


  Color _getStatusColor(String status) {
    switch (status) {
      case 'collected':
        return Colors.amber.shade800;
      case 'sent_to_dealer':
        return Colors.blue.shade700;
      case 'resolved_replaced':
        return Colors.green.shade700;
      case 'resolved_refunded':
        return Colors.teal.shade700;
      case 'dealer_rejected':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'collected':
        return Icons.hourglass_bottom_rounded;
      case 'sent_to_dealer':
        return Icons.local_shipping_rounded;
      case 'resolved_replaced':
        return Icons.add_business_rounded;
      case 'resolved_refunded':
        return Icons.account_balance_wallet_rounded;
      case 'dealer_rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'collected':
        return 'Collected';
      case 'sent_to_dealer':
        return 'Sent to Dealer';
      case 'resolved_replaced':
        return 'Replaced';
      case 'resolved_refunded':
        return 'Refunded';
      case 'dealer_rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }
}
