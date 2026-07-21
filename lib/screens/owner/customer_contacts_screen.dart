import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../models/phone_book_contact_model.dart';
import '../../models/sale_model.dart';
import '../../models/service_model.dart';
import '../../models/enquiry_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class ContactItem {
  final String id;
  final String name;
  final String phone;
  final String normalizedPhone;
  final String source; // "Bill", "Service", "Enquiry", "Phone Book"
  final String? notes; // For phone book entries
  final DateTime timestamp;

  ContactItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.normalizedPhone,
    required this.source,
    this.notes,
    required this.timestamp,
  });
}

class CustomerContactsScreen extends StatefulWidget {
  final bool isOwner;
  final String? shopId;

  const CustomerContactsScreen({
    super.key,
    required this.isOwner,
    this.shopId,
  });

  @override
  State<CustomerContactsScreen> createState() => _CustomerContactsScreenState();
}

class _CustomerContactsScreenState extends State<CustomerContactsScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late TabController _tabController;

  // Search & Filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedShop = "All Shops"; // "All Shops", "Shop 1", "Shop 2"
  
  // Sources Filter
  bool _filterSales = true;
  bool _filterServices = true;
  bool _filterEnquiries = true;
  bool _filterPhoneBook = true;

  // WhatsApp Group Link
  final TextEditingController _groupLinkController = TextEditingController();

  // Selection
  final Set<String> _selectedPhones = {};

  // Database Data States
  List<SaleModel> _sales = [];
  List<ServiceModel> _services = [];
  List<EnquiryModel> _enquiries = [];
  List<PhoneBookContact> _phoneBook = [];
  Set<String> _addedWhatsAppPhones = {};
  bool _isLoading = true;

  // Stream listeners
  final List<dynamic> _streams = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedPhones.clear();
      });
    });
    if (!widget.isOwner && widget.shopId != null) {
      _selectedShop = widget.shopId!;
    }
    _loadGroupLink();
    _listenToStreams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _groupLinkController.dispose();
    for (var sub in _streams) {
      sub.cancel();
    }
    super.dispose();
  }

  void _loadGroupLink() async {
    final prefs = await SharedPreferences.getInstance();
    final shopKey = _selectedShop == "All Shops" ? "global" : _selectedShop;
    String? savedLink = prefs.getString('whatsapp_group_invite_link_$shopKey');
    if (savedLink == null || savedLink.isEmpty) {
      if (_selectedShop != "All Shops") {
        final settings = await _db.getGstSettings(_selectedShop);
        savedLink = settings?.groupLink;
      } else {
        final gstSettings1 = await _db.getGstSettings('Shop 1');
        if (gstSettings1?.groupLink != null && gstSettings1!.groupLink!.isNotEmpty) {
          savedLink = gstSettings1.groupLink;
        } else {
          final gstSettings2 = await _db.getGstSettings('Shop 2');
          if (gstSettings2?.groupLink != null && gstSettings2!.groupLink!.isNotEmpty) {
            savedLink = gstSettings2.groupLink;
          }
        }
      }
    }
    setState(() {
      _groupLinkController.text = savedLink ?? '';
    });
  }

  void _saveGroupLink(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final shopKey = _selectedShop == "All Shops" ? "global" : _selectedShop;
    await prefs.setString('whatsapp_group_invite_link_$shopKey', value.trim());
  }

  void _listenToStreams() {
    // 1. Sales stream
    final salesSub = _db.getSales(null).listen((data) {
      if (mounted) {
        setState(() {
          _sales = data;
          _isLoading = false;
        });
      }
    });
    _streams.add(salesSub);

    // 2. Services stream
    final servicesSub = _db.getServices(null).listen((data) {
      if (mounted) {
        setState(() {
          _services = data;
        });
      }
    });
    _streams.add(servicesSub);

    // 3. Enquiries stream
    final enquiriesSub = _db.getEnquiries(null).listen((data) {
      if (mounted) {
        setState(() {
          _enquiries = data;
        });
      }
    });
    _streams.add(enquiriesSub);

    // 4. Phone Book stream
    final phoneBookSub = _db.getPhoneBookContacts().listen((data) {
      if (mounted) {
        setState(() {
          _phoneBook = data;
        });
      }
    });
    _streams.add(phoneBookSub);

    // 5. WhatsApp Status stream
    final addedSub = _db.getAddedWhatsAppNumbers().listen((data) {
      if (mounted) {
        setState(() {
          _addedWhatsAppPhones = data;
        });
      }
    });
    _streams.add(addedSub);
  }

  // Normalizes phone numbers to standard 12-digit Indian format (e.g. 91xxxxxxxxxx)
  String _normalizePhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 10) {
      return '91$cleaned';
    }
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      return '91${cleaned.substring(1)}';
    }
    return cleaned;
  }

  // Merges and deduplicates contacts based on rules
  List<ContactItem> _getFilteredContacts() {
    final Map<String, ContactItem> merged = {};

    // Helper to merge contact
    void addOrMerge(String id, String name, String phone, String source, DateTime time, [String? notes]) {
      if (phone.trim().isEmpty) return;
      final normalized = _normalizePhone(phone);
      if (normalized.length < 10) return; // Ignore invalid short numbers

      final displayName = name.trim().isEmpty ? 'Customer' : name.trim();

      final existing = merged[normalized];
      if (existing == null || time.isAfter(existing.timestamp)) {
        merged[normalized] = ContactItem(
          id: id,
          name: displayName,
          phone: phone.trim(),
          normalizedPhone: normalized,
          source: source,
          notes: notes,
          timestamp: time,
        );
      }
    }

    // Process from source streams if enabled
    if (_filterSales) {
      for (var sale in _sales) {
        // Filter by shop if selected
        if (_selectedShop != "All Shops" && sale.shopId != _selectedShop) continue;
        addOrMerge(sale.id, sale.customerName, sale.customerPhone, "Bill", sale.timestamp);
      }
    }

    if (_filterServices) {
      for (var service in _services) {
        if (_selectedShop != "All Shops" && service.shopId != _selectedShop) continue;
        addOrMerge(service.id, service.customerName, service.customerPhone, "Service", service.timestamp);
      }
    }

    if (_filterEnquiries) {
      for (var enquiry in _enquiries) {
        if (_selectedShop != "All Shops" && enquiry.shopId != _selectedShop) continue;
        addOrMerge(enquiry.id, enquiry.customerName, enquiry.customerPhone, "Enquiry", enquiry.createdAt);
      }
    }

    if (_filterPhoneBook) {
      for (var contact in _phoneBook) {
        addOrMerge(contact.id, contact.name, contact.phone, "Phone Book", contact.timestamp, contact.notes);
      }
    }

    // Convert map to list
    List<ContactItem> list = merged.values.toList();

    // Filter by Tab: Pending (index 0), Added (index 1), All (index 2)
    if (_tabController.index == 0) {
      // Pending: not added to WhatsApp group
      list = list.where((item) => !_addedWhatsAppPhones.contains(item.normalizedPhone)).toList();
    } else if (_tabController.index == 1) {
      // Added: already in WhatsApp group
      list = list.where((item) => _addedWhatsAppPhones.contains(item.normalizedPhone)).toList();
    }

    // Filter by Search Query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((item) {
        return item.name.toLowerCase().contains(q) ||
            item.phone.contains(q) ||
            item.normalizedPhone.contains(q);
      }).toList();
    }

    // Sort alphabetically by name
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return list;
  }

  // Launch direct WhatsApp chat with unsaved number
  Future<void> _launchWhatsAppInvite(String phone, String name) async {
    final groupLink = _groupLinkController.text.trim();
    final normalized = _normalizePhone(phone);
    
    String message = "Hello $name!";
    if (groupLink.isNotEmpty) {
      message += " Join our D&H Mobiles WhatsApp group to receive updates on exciting offers and discounts: $groupLink";
    } else {
      message += " Get updates on exciting offers and discounts from D&H Mobiles.";
    }

    final encodedMsg = Uri.encodeComponent(message);
    final url = Uri.parse("https://wa.me/$normalized?text=$encodedMsg");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch WhatsApp. Make sure it is installed.")),
        );
      }
    }
  }

  // Copy selected numbers to clipboard
  void _copySelected() {
    if (_selectedPhones.isEmpty) return;
    
    // Sort selected numbers to make the copied output clean
    final copyList = _selectedPhones.toList()..sort();
    final csv = copyList.join(", ");
    
    Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${_selectedPhones.length} numbers copied to clipboard!"),
        backgroundColor: AppTheme.accentForest,
      ),
    );
  }

  // Export selected contacts as a CSV report file
  Future<void> _exportCSV() async {
    if (_selectedPhones.isEmpty) return;

    final allFiltered = _getFilteredContacts();
    final selectedItems = allFiltered.where((i) => _selectedPhones.contains(i.normalizedPhone)).toList();

    if (selectedItems.isEmpty) return;

    // Build CSV Content
    final StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln("Name,Phone Number,Source,Normalized Phone");
    
    for (var item in selectedItems) {
      // Escape name double quotes if any
      final escapedName = item.name.replaceAll('"', '""');
      csvBuffer.writeln('"$escapedName","${item.phone}","${item.source}","${item.normalizedPhone}"');
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final path = "${tempDir.path}/customer_contacts_report.csv";
      final file = File(path);
      await file.writeAsString(csvBuffer.toString());

      // Share using share_plus
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'D&H Mobiles Customer Contacts Report (${selectedItems.length} contacts)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error generating report: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Mark selected contacts as Added/Pending in Firestore
  Future<void> _markSelectedStatus(bool isAdded, {bool copy = false}) async {
    if (_selectedPhones.isEmpty) return;

    if (copy) {
      // Sort selected numbers to make the copied output clean
      final copyList = _selectedPhones.toList()..sort();
      final csv = copyList.join(", ");
      await Clipboard.setData(ClipboardData(text: csv));
    }

    setState(() => _isLoading = true);
    try {
      final count = _selectedPhones.length;
      await _db.markMultipleAsAdded(_selectedPhones.toList(), isAdded);
      setState(() {
        _selectedPhones.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(copy
                ? "$count numbers copied & marked as ${isAdded ? 'Added' : 'Pending'}!"
                : "Marked $count contacts as ${isAdded ? 'Added' : 'Pending'}!"),
            backgroundColor: AppTheme.accentForest,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Database error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Add a manual contact to the Phone Book
  void _showAddContactDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.primaryIvory,
          title: const Text(
            'Add Friend/Visitor Contact',
            style: TextStyle(color: AppTheme.accentForest, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Contact Name (Optional)',
                      hintText: 'Enter name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '10-digit number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Phone required';
                      final normalized = _normalizePhone(v);
                      if (normalized.length < 10) return 'Invalid phone number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Relationship/Notes',
                      hintText: 'e.g., Friend of Amit',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newContact = PhoneBookContact(
                    id: const Uuid().v4(),
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                    timestamp: DateTime.now(),
                  );
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  await _db.addPhoneBookContact(newContact);
                  setState(() => _isLoading = false);
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  // Delete manual contact from phone book (with confirmation)
  void _confirmDeletePhoneBook(ContactItem item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.primaryIvory,
          title: const Text('Delete Contact'),
          content: Text('Are you sure you want to delete "${item.name}" from your Phone Book?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                await _db.deletePhoneBookContact(item.id);
                setState(() => _isLoading = false);
              },
              child: const Text('DELETE', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredContacts = _getFilteredContacts();
    final allPhones = filteredContacts.map((i) => i.normalizedPhone).toSet();
    final isAllSelected = filteredContacts.isNotEmpty &&
        filteredContacts.every((c) => _selectedPhones.contains(c.normalizedPhone));

    return Scaffold(
      backgroundColor: AppTheme.primaryIvory,
      appBar: AppBar(
        title: const Text('Customer Numbers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Add Contact Manually',
            onPressed: _showAddContactDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Settings & Search Filter Panel
          Container(
            color: AppTheme.secondaryIvory,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Group Invite settings
                Row(
                  children: [
                    const Icon(Icons.link, color: AppTheme.accentForest),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _groupLinkController,
                        style: const TextStyle(fontSize: 13, color: AppTheme.charcoalBlack),
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp Group Invite Link',
                          hintText: 'https://chat.whatsapp.com/...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                        onChanged: _saveGroupLink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                
                // Search Bar
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppTheme.charcoalBlack),
                  decoration: InputDecoration(
                    labelText: 'Search Customer Name or Phone',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.accentForest),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = "";
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // Shop & Source Filters
                Row(
                  children: [
                    // Shop Dropdown (visible to both owner and employees)
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        value: _selectedShop,
                        style: const TextStyle(color: AppTheme.charcoalBlack, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Shop Filter',
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        items: ['All Shops', 'Shop 1', 'Shop 2'].map((String shop) {
                          return DropdownMenuItem<String>(
                            value: shop,
                            child: Text(shop),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedShop = val;
                              _selectedPhones.clear();
                            });
                            _loadGroupLink(); // Update WhatsApp link to match selected shop settings
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Source Filter chips opener
                    Expanded(
                      flex: 5,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.filter_list_rounded, size: 16, color: AppTheme.accentForest),
                        label: const Text('Filter Sources', style: TextStyle(fontSize: 12, color: AppTheme.accentForest)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppTheme.accentForest),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showSourcesFilterModal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Tab selection
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.accentForest,
            unselectedLabelColor: AppTheme.graphiteGray,
            indicatorColor: AppTheme.accentForest,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Pending'),
                    const SizedBox(width: 4),
                    _buildBadgeCount(0),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Added'),
                    const SizedBox(width: 4),
                    _buildBadgeCount(1),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('All'),
                    const SizedBox(width: 4),
                    _buildBadgeCount(2),
                  ],
                ),
              ),
            ],
          ),

          // 3. Selection Summary Header
          if (filteredContacts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: isAllSelected,
                    activeColor: AppTheme.accentForest,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedPhones.addAll(allPhones);
                        } else {
                          _selectedPhones.clear();
                        }
                      });
                    },
                  ),
                  Text(
                    isAllSelected ? 'Unselect All' : 'Select All',
                    style: const TextStyle(fontSize: 13, color: AppTheme.charcoalBlack),
                  ),
                  const Spacer(),
                  if (_selectedPhones.isNotEmpty)
                    Text(
                      '${_selectedPhones.length} Selected',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentForest,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),

          // 4. Main list or Loader
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accentForest))
                : filteredContacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.contact_phone_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No contacts found',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredContacts.length,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemBuilder: (context, index) {
                          final item = filteredContacts[index];
                          final isSelected = _selectedPhones.contains(item.normalizedPhone);
                          final isAdded = _addedWhatsAppPhones.contains(item.normalizedPhone);

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: AppTheme.accentForest,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedPhones.add(item.normalizedPhone);
                                        } else {
                                          _selectedPhones.remove(item.normalizedPhone);
                                        }
                                      });
                                    },
                                  ),
                                  CircleAvatar(
                                    backgroundColor: AppTheme.accentForest,
                                    radius: 18,
                                    child: Text(
                                      item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                          color: AppTheme.primaryIvory,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.charcoalBlack,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSourceBadge(item.source),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    item.phone,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppTheme.graphiteGray),
                                  ),
                                  if (item.source == "Phone Book" && item.notes != null && item.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Note: ${item.notes}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Mark added status button
                                  IconButton(
                                    icon: Icon(
                                      isAdded ? Icons.check_circle : Icons.check_circle_outline,
                                      color: isAdded ? Colors.green : Colors.grey,
                                      size: 22,
                                    ),
                                    tooltip: isAdded ? 'Mark Pending' : 'Mark Added',
                                    onPressed: () {
                                      _db.markMultipleAsAdded([item.normalizedPhone], !isAdded);
                                    },
                                  ),
                                  // Send WA invite chat button
                                  IconButton(
                                    icon: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: Colors.green,
                                      size: 22,
                                    ),
                                    tooltip: 'Invite via WhatsApp',
                                    onPressed: () => _launchWhatsAppInvite(item.phone, item.name),
                                  ),
                                  // Delete if from phone book
                                  if (item.source == "Phone Book")
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      tooltip: 'Delete Contact',
                                      onPressed: () => _confirmDeletePhoneBook(item),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),

      // 5. Bulk Action Panel (at the bottom)
      bottomNavigationBar: _selectedPhones.isEmpty
          ? null
          : SafeArea(
              child: Container(
                color: AppTheme.accentForest,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selectedPhones.length} items',
                        style: const TextStyle(
                          color: AppTheme.primaryIvory,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Action: Copy Numbers
                    IconButton(
                      icon: const Icon(Icons.copy, color: AppTheme.primaryIvory),
                      tooltip: 'Copy Selected Numbers',
                      onPressed: _copySelected,
                    ),
                    const SizedBox(width: 8),
                    // Action: Export CSV
                    IconButton(
                      icon: const Icon(Icons.file_download, color: AppTheme.primaryIvory),
                      tooltip: 'Export CSV/Excel Report',
                      onPressed: _exportCSV,
                    ),
                    const SizedBox(width: 16),
                    // Action: Mark status
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryIvory,
                        foregroundColor: AppTheme.accentForest,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _markSelectedStatus(_tabController.index != 1, copy: true),
                      child: Text(
                        _tabController.index == 1 ? 'Copy & Mark Pending' : 'Copy & Mark Added',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Count helper for tabs
  Widget _buildBadgeCount(int tabIndex) {
    // Calculate size in real-time
    int count = 0;
    final allFiltered = _getFilteredContactsWithoutTabFilter();

    if (tabIndex == 0) {
      count = allFiltered.where((i) => !_addedWhatsAppPhones.contains(i.normalizedPhone)).length;
    } else if (tabIndex == 1) {
      count = allFiltered.where((i) => _addedWhatsAppPhones.contains(i.normalizedPhone)).length;
    } else {
      count = allFiltered.length;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accentForest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentForest),
      ),
    );
  }

  // Raw filtered list without the tab filter, used to compute badge counts accurately
  List<ContactItem> _getFilteredContactsWithoutTabFilter() {
    final Map<String, ContactItem> merged = {};

    void addOrMerge(String id, String name, String phone, String source, DateTime time, [String? notes]) {
      if (phone.trim().isEmpty) return;
      final normalized = _normalizePhone(phone);
      if (normalized.length < 10) return;

      final displayName = name.trim().isEmpty ? 'Customer' : name.trim();

      final existing = merged[normalized];
      if (existing == null || time.isAfter(existing.timestamp)) {
        merged[normalized] = ContactItem(
          id: id,
          name: displayName,
          phone: phone.trim(),
          normalizedPhone: normalized,
          source: source,
          notes: notes,
          timestamp: time,
        );
      }
    }

    if (_filterSales) {
      for (var sale in _sales) {
        if (_selectedShop != "All Shops" && sale.shopId != _selectedShop) continue;
        addOrMerge(sale.id, sale.customerName, sale.customerPhone, "Bill", sale.timestamp);
      }
    }
    if (_filterServices) {
      for (var service in _services) {
        if (_selectedShop != "All Shops" && service.shopId != _selectedShop) continue;
        addOrMerge(service.id, service.customerName, service.customerPhone, "Service", service.timestamp);
      }
    }
    if (_filterEnquiries) {
      for (var enquiry in _enquiries) {
        if (_selectedShop != "All Shops" && enquiry.shopId != _selectedShop) continue;
        addOrMerge(enquiry.id, enquiry.customerName, enquiry.customerPhone, "Enquiry", enquiry.createdAt);
      }
    }
    if (_filterPhoneBook) {
      for (var contact in _phoneBook) {
        addOrMerge(contact.id, contact.name, contact.phone, "Phone Book", contact.timestamp, contact.notes);
      }
    }

    List<ContactItem> list = merged.values.toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((item) {
        return item.name.toLowerCase().contains(q) ||
            item.phone.contains(q) ||
            item.normalizedPhone.contains(q);
      }).toList();
    }

    return list;
  }

  // Badges showing the contact source
  Widget _buildSourceBadge(String source) {
    Color bg;
    Color fg;
    switch (source) {
      case "Bill":
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        break;
      case "Service":
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade800;
        break;
      case "Enquiry":
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
      case "Phone Book":
        bg = Colors.purple.shade100;
        fg = Colors.purple.shade800;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        source,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  // Bottom modal sheet to toggle source filters
  void _showSourcesFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.primaryIvory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Contact Sources',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentForest,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Bills (Sales)', style: TextStyle(color: AppTheme.charcoalBlack)),
                    value: _filterSales,
                    activeColor: AppTheme.accentForest,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _filterSales = val);
                        setModalState(() {});
                      }
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Services', style: TextStyle(color: AppTheme.charcoalBlack)),
                    value: _filterServices,
                    activeColor: AppTheme.accentForest,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _filterServices = val);
                        setModalState(() {});
                      }
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Enquiries', style: TextStyle(color: AppTheme.charcoalBlack)),
                    value: _filterEnquiries,
                    activeColor: AppTheme.accentForest,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _filterEnquiries = val);
                        setModalState(() {});
                      }
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Phone Book (Visitors/Friends)', style: TextStyle(color: AppTheme.charcoalBlack)),
                    value: _filterPhoneBook,
                    activeColor: AppTheme.accentForest,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _filterPhoneBook = val);
                        setModalState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('APPLY FILTERS'),
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
}
