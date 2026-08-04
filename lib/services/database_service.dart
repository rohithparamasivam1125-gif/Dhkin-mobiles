import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import '../models/user_model.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/sale_model.dart';
import '../models/service_model.dart';
import '../models/expense_model.dart';
import '../models/replacement_model.dart';
import '../models/specialist_fee_request_model.dart';
import '../models/enquiry_model.dart';
import '../models/gst_settings_model.dart';
import '../models/product_order_model.dart';
import '../models/phone_book_contact_model.dart';
import '../models/pending_sale_model.dart';
import 'dart:async';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // User Operations
  Future<void> updateUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    var doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? UserModel.fromMap(doc.data()!) : null;
  }

  Future<void> deleteUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  Stream<List<UserModel>> getEmployees([String? shopId]) {
    Query query = _db.collection('users').where('role', isEqualTo: 'employee');
    if (shopId != null) {
      query = query.where('shopId', isEqualTo: shopId);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList());
  }

  // Category Operations
  // Category Operation
  Stream<List<CategoryModel>> getCategories() {
    return _db.collection('categories').snapshots().map((snapshot) {
      final cats = snapshot.docs
          .map((doc) => CategoryModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      cats.sort((a, b) => a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase()));
      return cats;
    });
  }

  Future<void> addCategory(CategoryModel category) async {
    await _db.collection('categories').doc(category.id).set(category.toMap());
  }

  // Product Operations
  Stream<List<ProductModel>> getProducts(String? shopId) {
    Query query = _db.collection('products');
    if (shopId != null) {
      query = query.where('shopId', isEqualTo: shopId);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => ProductModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> addProduct(ProductModel product) async {
    await _db.collection('products').doc(product.id).set(product.toMap());
  }

  Future<void> deleteProduct(String productId) async {
    await _db.collection('products').doc(productId).delete();
  }

  Future<void> deleteCategory(String categoryId) async {
    await _db.collection('categories').doc(categoryId).delete();
  }

  Future<void> updateCategoryName(String categoryId, String oldName, String newName) async {
    final batch = _db.batch();

    // 1. Update the category document
    final catRef = _db.collection('categories').doc(categoryId);
    batch.update(catRef, {'name': newName});

    // 2. Fetch all products with the old category name and update them
    final productsQuery = await _db.collection('products').where('category', isEqualTo: oldName).get();
    for (var doc in productsQuery.docs) {
      batch.update(doc.reference, {'category': newName});
    }

    await batch.commit();
  }

  Future<void> updateStock(String productId, int newUnits) async {
    await _db.collection('products').doc(productId).update({'units': newUnits});
  }

  Future<void> updateProductCost(String productId, double cost) async {
    final batch = _db.batch();

    // 1. Queue catalog update in batch
    batch
        .update(_db.collection('products').doc(productId), {'costPrice': cost});

    // 2. Fetch the product to resolve its shopId
    final prodDoc = await _db.collection('products').doc(productId).get();
    if (prodDoc.exists) {
      final shopId = prodDoc.data()?['shopId'] as String?;
      if (shopId != null) {
        // 3. Find past sales in this shop for this product where costPrice is missing or <= 0
        final salesSnapshot = await _db
            .collection('sales')
            .where('shopId', isEqualTo: shopId)
            .get();

        for (var doc in salesSnapshot.docs) {
          final data = doc.data();
          final itemsList = data['items'] as List?;
          if (itemsList != null) {
            bool updated = false;
            final updatedItems = itemsList.map((itemRaw) {
              final item = Map<String, dynamic>.from(itemRaw as Map);
              if (item['productId'] == productId &&
                  (item['costPrice'] == null ||
                      (item['costPrice'] as num) <= 0.0)) {
                item['costPrice'] = cost;
                updated = true;
              }
              return item;
            }).toList();

            if (updated) {
              batch.update(doc.reference, {'items': updatedItems});
            }
          }
        }
      }
    }

    // 4. Commit all updates atomically in a single network request
    await batch.commit();
  }

  Future<List<String>> findCustomerNamesByPhone(String phone) async {
    final Set<String> names = {};
    try {
      final salesSnapshot = await _db
          .collection('sales')
          .where('customerPhone', isEqualTo: phone)
          .get();
      for (var doc in salesSnapshot.docs) {
        final name = doc.data()['customerName'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          names.add(name.trim());
        }
      }

      final enquirySnapshot = await _db
          .collection('enquiries')
          .where('customerPhone', isEqualTo: phone)
          .get();
      for (var doc in enquirySnapshot.docs) {
        final name = doc.data()['customerName'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          names.add(name.trim());
        }
      }

      final servicesSnapshot = await _db
          .collection('services')
          .where('customerPhone', isEqualTo: phone)
          .get();
      for (var doc in servicesSnapshot.docs) {
        final name = doc.data()['customerName'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          names.add(name.trim());
        }
      }
    } catch (_) {}
    return names.toList();
  }

  // Pending Sales Operations
  Future<void> addPendingSale(PendingSaleModel pendingSale) async {
    await _db.collection('pending_sales').doc(pendingSale.id).set(pendingSale.toMap());
    await _sendNotification(
      pendingSale.sale.shopId,
      'Discount Approval ⚠️',
      '${pendingSale.sale.employeeId} requested a discount of ₹${pendingSale.sale.discountAmount}',
    );
  }

  Stream<List<PendingSaleModel>> getPendingSales(String shopId) {
    return _db.collection('pending_sales')
        .where('sale.shopId', isEqualTo: shopId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PendingSaleModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  Future<void> approvePendingSale(String pendingSaleId) async {
    final doc = await _db.collection('pending_sales').doc(pendingSaleId).get();
    if (doc.exists) {
      final pendingSale = PendingSaleModel.fromMap(doc.data()!);
      await addSale(pendingSale.sale); // This adds to sales and deducts stock
      await _db.collection('pending_sales').doc(pendingSaleId).update({'status': 'approved'});
      
      await _sendNotification(
        pendingSale.sale.shopId,
        'Discount Approved ✅',
        'Discount of ₹${pendingSale.sale.discountAmount} approved.',
      );
    }
  }

  Future<void> rejectPendingSale(String pendingSaleId) async {
    await _db.collection('pending_sales').doc(pendingSaleId).update({'status': 'rejected'});
    
    final doc = await _db.collection('pending_sales').doc(pendingSaleId).get();
    if (doc.exists) {
       final pendingSale = PendingSaleModel.fromMap(doc.data()!);
       await _sendNotification(
        pendingSale.sale.shopId,
        'Discount Rejected ❌',
        'Discount request for ${pendingSale.sale.customerName} was rejected.',
      );
    }
  }

  // Sales Operations
  Future<void> addSale(SaleModel sale) async {
    try {
      // Set a 30-second timeout for the entire operation
      await _db
          .collection('sales')
          .doc(sale.id)
          .set(sale.toMap())
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException(
            'Firestore connection timed out. Check your internet or Firebase config.');
      });

      // Reduce stock for EVERY item in the bill
      for (var item in sale.items) {
        if (item.productId.startsWith('temp_')) continue;
        var productDoc =
            await _db.collection('products').doc(item.productId).get();
        if (productDoc.exists) {
          var product =
              ProductModel.fromMap(productDoc.data() as Map<String, dynamic>);
          int remainingStock = product.units - item.quantity;
          await updateStock(
              item.productId, remainingStock < 0 ? 0 : remainingStock);

          if (remainingStock < 2) {
            await _sendNotification(sale.shopId, 'Low Stock Alert ⚠️',
                '${product.name} is running low ($remainingStock units left)');
          }
        }
      }

      String itemSummary = sale.items.length == 1
          ? sale.items.first.productName
          : '${sale.items.length} items (${sale.items.first.productName}...)';

      await _sendNotification(sale.shopId, 'New Sale 💰',
          '₹${sale.totalPrice} - $itemSummary by ${sale.employeeId}');
    } catch (e) {
      print('Error in addSale: $e');
      rethrow;
    }
  }

  Stream<List<SaleModel>> getSales(String? shopId) {
    Query<Map<String, dynamic>> query = _db.collection('sales');
    if (shopId != null) {
      query = query.where('shopId', isEqualTo: shopId);
    }
    return query.snapshots().map((snapshot) {
      final list =
          snapshot.docs.map((doc) => SaleModel.fromMap(doc.data())).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Future<void> deleteSale(String saleId) async {
    final doc = await _db.collection('sales').doc(saleId).get();
    if (doc.exists) {
      final sale = SaleModel.fromMap(doc.data()!);
      for (var item in sale.items) {
        final productDoc =
            await _db.collection('products').doc(item.productId).get();
        if (productDoc.exists) {
          final product = ProductModel.fromMap(productDoc.data()!);
          await updateStock(item.productId, product.units + item.quantity);
        }
      }
    }
    await _db.collection('sales').doc(saleId).delete();
  }

  Future<void> updateSale(SaleModel sale) async {
    final oldDoc = await _db.collection('sales').doc(sale.id).get();
    if (oldDoc.exists) {
      final oldSale = SaleModel.fromMap(oldDoc.data()!);
      for (var oldItem in oldSale.items) {
        final newItemOpt =
            sale.items.where((i) => i.productId == oldItem.productId);
        int newQty = newItemOpt.isNotEmpty ? newItemOpt.first.quantity : 0;

        int qtyDiff = oldItem.quantity - newQty;
        if (qtyDiff != 0) {
          final productDoc =
              await _db.collection('products').doc(oldItem.productId).get();
          if (productDoc.exists) {
            final product = ProductModel.fromMap(productDoc.data()!);
            await updateStock(oldItem.productId, product.units + qtyDiff);
          }
        }
      }
    }
    await _db.collection('sales').doc(sale.id).update(sale.toMap());
  }

  // Mobile Services Operations
  Future<void> addService(ServiceModel service) async {
    await _db.collection('services').doc(service.id).set(service.toMap());

    if (service.isExpenseRecorded) {
      // Automatically create the expense entries for partsCost and technicianFee since they are entered on creation
      if (service.technicianFee > 0) {
        final expense = ExpenseModel(
          id: 'EXP_SVC_${service.id}',
          shopId: service.shopId,
          category: 'Specialist Fee',
          amount: service.technicianFee,
          description:
              '[Cust: ${service.customerName}] | [Model: ${service.mobileModel}] | [Delivered by: ${service.employeeName}]',
          timestamp: service.timestamp,
          paymentMode: service.technicianPaymentMode,
        );
        await addExpense(expense);
      }

      if (service.partsCost > 0) {
        final expense = ExpenseModel(
          id: 'EXP_PART_${service.id}',
          shopId: service.shopId,
          category: 'Parts Cost',
          amount: service.partsCost,
          description:
              '[Cust: ${service.customerName}] | [Model: ${service.mobileModel}] | [Wholesaler Part]',
          timestamp: service.timestamp,
          paymentMode: service.partsPaymentMode,
        );
        await addExpense(expense);
      }
    } else {
      // Auto-create a pending Specialist Fee request for the Owner to approve/enter
      final request = SpecialistFeeRequestModel(
        id: 'SF_${service.id}',
        serviceId: service.id,
        customerName: service.customerName,
        mobileModel: service.mobileModel,
        shopId: service.shopId,
        deliveredBy: service.employeeName,
        timestamp: service.timestamp,
        status: 'pending',
      );
      await addSpecialistFeeRequest(request);
    }

    if (service.employeeName != 'Owner') {
      await _sendNotification(service.shopId, 'New Service Entry 📱',
          '${service.customerName} - ${service.mobileModel}');
    }
  }

  Future<void> updateServiceStatus(String serviceId, String status) async {
    await _db.collection('services').doc(serviceId).update({'status': status});
  }

  Future<void> updateServicePayment(
      String serviceId,
      double additionalAmount,
      double currentAdvance,
      double totalAmount,
      double cashPaid,
      double onlinePaid) async {
    final double newAdvance = currentAdvance + additionalAmount;
    // NOTE: Status is intentionally NOT changed here.
    // Payment progress and repair status are tracked independently.
    await _db.collection('services').doc(serviceId).update({
      'remainingAmount': (totalAmount - newAdvance).clamp(0.0, double.infinity),
      'cashAmount': FieldValue.increment(cashPaid),
      'onlineAmount': FieldValue.increment(onlinePaid),
    });

    final serviceDoc = await _db.collection('services').doc(serviceId).get();
    if (serviceDoc.exists) {
      final shopId = serviceDoc.data()?['shopId'] ?? 'Shop 1';
      final customer = serviceDoc.data()?['customerName'] ?? 'Customer';
      final model = serviceDoc.data()?['mobileModel'] ?? 'Mobile';
      await _sendNotification(
        shopId,
        'Service Payment Update 💸',
        '$customer - $model: ₹$additionalAmount collected.',
      );
    }
  }

  Stream<List<ServiceModel>> getServices(String? shopId) {
    Query<Map<String, dynamic>> query = _db.collection('services');
    if (shopId != null) {
      query = query.where('shopId', isEqualTo: shopId);
    }
    return query.snapshots().map((snapshot) {
      final list =
          snapshot.docs.map((doc) => ServiceModel.fromMap(doc.data())).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Future<void> updateService(ServiceModel service) async {
    // Determine final isExpenseRecorded flag
    bool isExpenseRecorded = service.isExpenseRecorded ||
        service.partsCost > 0 ||
        service.technicianFee > 0;

    // Create copy with isExpenseRecorded set to true if needed
    final serviceToSave = isExpenseRecorded != service.isExpenseRecorded
        ? service.copyWith(isExpenseRecorded: isExpenseRecorded)
        : service;

    // 2. Perform the update
    await _db
        .collection('services')
        .doc(service.id)
        .update(serviceToSave.toMap());

    // 3. If expenses are recorded, manage expense entries and pending requests
    if (isExpenseRecorded) {
      if (service.technicianFee > 0) {
        final expense = ExpenseModel(
          id: 'EXP_SVC_${service.id}',
          shopId: service.shopId,
          category: 'Specialist Fee',
          amount: service.technicianFee,
          description:
              '[Cust: ${service.customerName}] | [Model: ${service.mobileModel}] | [Delivered by: ${service.employeeName}]',
          timestamp: service.timestamp,
          paymentMode: service.technicianPaymentMode,
        );
        await addExpense(expense);
      } else {
        await _db
            .collection('expenses')
            .doc('EXP_SVC_${service.id}')
            .delete()
            .catchError((_) {});
      }

      if (service.partsCost > 0) {
        final expense = ExpenseModel(
          id: 'EXP_PART_${service.id}',
          shopId: service.shopId,
          category: 'Parts Cost',
          amount: service.partsCost,
          description:
              '[Cust: ${service.customerName}] | [Model: ${service.mobileModel}] | [Wholesaler Part]',
          timestamp: service.timestamp,
          paymentMode: service.partsPaymentMode,
        );
        await addExpense(expense);
      } else {
        await _db
            .collection('expenses')
            .doc('EXP_PART_${service.id}')
            .delete()
            .catchError((_) {});
      }

      // Resolve the pending request if it exists
      final reqDoc = await _db
          .collection('specialistFeeRequests')
          .doc('SF_${service.id}')
          .get();
      if (reqDoc.exists) {
        final status = reqDoc.data()?['status'] ?? 'pending';
        if (status == 'pending') {
          await _db
              .collection('specialistFeeRequests')
              .doc('SF_${service.id}')
              .update({
            'status': 'recorded',
          });
        }
      }
    }
  }

  Future<void> deleteService(String serviceId, {ServiceModel? service}) async {
    // If service object is not passed, fetch it before deletion (fallback for safety)
    final ServiceModel? svc = service ??
        await _db.collection('services').doc(serviceId).get().then((doc) {
          return doc.exists ? ServiceModel.fromMap(doc.data()!) : null;
        });

    // ── Step 1: Delete the service document IMMEDIATELY ─────────────────────
    // This triggers the Firestore stream update instantly so the card
    // disappears from the UI with zero perceived delay.
    final deleteServiceFuture =
        _db.collection('services').doc(serviceId).delete();

    // ── Step 2: Run ALL cleanup in the background (non-blocking) ────────────
    _cleanupServiceData(serviceId, svc).catchError((e) {
      print('Background service cleanup error: $e');
    });

    // Await only the service doc deletion (already fast — just a network write)
    await deleteServiceFuture;
  }

  Future<void> _cleanupServiceData(
      String serviceId, ServiceModel? service) async {
    // 1. Delete known expense IDs (predictable, no scan needed)
    await Future.wait([
      _db
          .collection('expenses')
          .doc('EXP_SVC_$serviceId')
          .delete()
          .catchError((_) {}),
      _db
          .collection('expenses')
          .doc('EXP_PART_$serviceId')
          .delete()
          .catchError((_) {}),
      _db
          .collection('specialistFeeRequests')
          .doc('SF_$serviceId')
          .delete()
          .catchError((_) {}),
    ]);

    // 2. Find and delete all re-repair replacement records linked to this service
    //    (productId == serviceId for service-type replacements)
    final repSnap = await _db
        .collection('replacements')
        .where('productId', isEqualTo: serviceId)
        .get();

    final repCleanupFutures = <Future>[];
    for (final doc in repSnap.docs) {
      final repId = doc.id;
      // Delete the associated expense record for this re-repair
      repCleanupFutures.add(
        _db
            .collection('expenses')
            .doc('EXP_REP_$repId')
            .delete()
            .catchError((_) {}),
      );
      // Delete the replacement record itself
      repCleanupFutures.add(doc.reference.delete().catchError((_) {}));
    }
    if (repCleanupFutures.isNotEmpty) {
      await Future.wait(repCleanupFutures);
    }

    // 3. Delete complementary gift expenses linked to this service & restore stock
    if (service != null && service.complementaryItems.isNotEmpty) {
      final compFutures = <Future>[];
      for (final item in service.complementaryItems) {
        final productId = item['productId'] as String? ?? '';
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        if (productId.isNotEmpty) {
          // Delete expense record
          compFutures.add(
            _db
                .collection('expenses')
                .doc('EXP_COMP_${serviceId}_$productId')
                .delete()
                .catchError((_) {}),
          );
          // Restore stock
          compFutures.add(
              _db.collection('products').doc(productId).get().then((doc) async {
            if (doc.exists) {
              final currentUnits = (doc.data()?['units'] as num?)?.toInt() ?? 0;
              await updateStock(productId, currentUnits + qty);
            }
          }).catchError((_) {}));
        }
      }
      if (compFutures.isNotEmpty) await Future.wait(compFutures);
    }

    // 4. Sweep for any legacy expenses matched by description (older records)
    if (service != null) {
      final legacyPattern =
          '[Cust: ${service.customerName}] | [Model: ${service.mobileModel}]';
      final expensesSnapshot = await _db
          .collection('expenses')
          .where('shopId', isEqualTo: service.shopId)
          .get();
      final legacyFutures = <Future>[];
      for (final doc in expensesSnapshot.docs) {
        final desc = doc.data()['description'] as String? ?? '';
        if (desc.contains(legacyPattern)) {
          legacyFutures.add(doc.reference.delete().catchError((_) {}));
        }
      }
      if (legacyFutures.isNotEmpty) await Future.wait(legacyFutures);
    }
  }

  // ── Discount Request Operations removed ──

  // Expense Operations
  Future<void> addExpense(ExpenseModel expense) async {
    await _db.collection('expenses').doc(expense.id).set(expense.toMap());
  }

  /// Records complementary (free gift) products given at service delivery.
  /// Deducts stock for each item and creates an expense at cost price.
  Future<void> recordComplementaryItems(ServiceModel service) async {
    for (final item in service.complementaryItems) {
      final String productId = item['productId'] as String? ?? '';
      final String productName = item['productName'] as String? ?? 'Product';
      final int qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final double costPrice = (item['costPrice'] as num?)?.toDouble() ?? 0.0;

      if (productId.isEmpty) continue;

      // 1. Deduct stock
      try {
        final productDoc =
            await _db.collection('products').doc(productId).get();
        if (productDoc.exists) {
          final currentUnits =
              (productDoc.data()?['units'] as num?)?.toInt() ?? 0;
          final newUnits = (currentUnits - qty).clamp(0, currentUnits);
          await updateStock(productId, newUnits);
        }
      } catch (e) {
        print('Error deducting stock for complement $productId: $e');
      }

      // 2. Record expense at cost price only
      if (costPrice > 0) {
        final expense = ExpenseModel(
          id: 'EXP_COMP_${service.id}_$productId',
          shopId: service.shopId,
          category: 'Complementary Gift',
          amount: costPrice * qty,
          description:
              '[Complement] $productName × $qty | Service: ${service.customerName} - ${service.mobileModel}',
          timestamp: DateTime.now(),
          paymentMode: 'Stock',
        );
        await addExpense(expense);
      }
    }
  }

  Stream<List<ExpenseModel>> getExpenses(String shopId) {
    return _db
        .collection('expenses')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) {
      final list =
          snapshot.docs.map((doc) => ExpenseModel.fromMap(doc.data())).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Future<void> deleteExpense(String id) async {
    // 1. Delete the expense document immediately so the UI streams update instantly
    final deleteExpenseFuture = _db.collection('expenses').doc(id).delete();

    // 2. Run the stock restoration and replacement cleaning in the background asynchronously
    if (id.startsWith('EXP_REP_')) {
      final replacementId = id.substring(8);
      _restoreStockAndCleanReplacement(replacementId).catchError((e) {
        print('Error restoring stock in background: $e');
      });
    }

    await deleteExpenseFuture;
  }

  Future<void> _restoreStockAndCleanReplacement(String replacementId) async {
    final repDoc =
        await _db.collection('replacements').doc(replacementId).get();
    if (repDoc.exists) {
      final replacement = ReplacementModel.fromMap(repDoc.data()!);

      // Determine the target product ID to restore stock
      String? targetProductId;
      if (replacement.isService && replacement.stockProductId != null) {
        targetProductId = replacement.stockProductId;
      } else if (!replacement.isService) {
        targetProductId = replacement.productId;
      }

      if (targetProductId != null) {
        final productDoc =
            await _db.collection('products').doc(targetProductId).get();
        if (productDoc.exists) {
          final product = ProductModel.fromMap(productDoc.data()!);
          int restoredStock = product.units + replacement.quantity;
          await updateStock(targetProductId, restoredStock);
        }
      }

      // Delete the replacement record as well
      await _db.collection('replacements').doc(replacementId).delete();
    }
  }

  Future<ProductModel?> getProduct(String productId) async {
    try {
      final doc = await _db.collection('products').doc(productId).get();
      if (doc.exists) {
        return ProductModel.fromMap(doc.data()!);
      }
    } catch (e) {
      print('Error getting product: $e');
    }
    return null;
  }

  // Replacement Operations (Wastage/Installation Errors)
  Future<void> addReplacementRequest(ReplacementModel replacement) async {
    await _db
        .collection('replacements')
        .doc(replacement.id)
        .set(replacement.toMap());

    // If this is a service re-repair, revert the linked service back to Pending.
    // The phone needs more work — it is NOT ready for delivery.
    if (replacement.isService && replacement.productId.isNotEmpty) {
      _db.collection('services').doc(replacement.productId).update({
        'status': 'Pending',
      }).catchError((e) => print('Re-repair status revert error: $e'));
    }

    _sendNotification(
      replacement.shopId,
      replacement.isService ? 'Re-Repair Request 🔧' : 'Replacement Request 🚨',
      '${replacement.employeeName} reported ${replacement.isService ? "re-repair" : "wastage"} for ${replacement.productName}',
    );
  }

  Future<void> addAndApproveReplacement(
      ReplacementModel replacement, double costValue) async {
    // 1. Resolve product cost price if not manually provided
    double resolvedCostPrice = costValue;
    final productId = replacement.productId;
    final int qty = replacement.quantity;
    String? targetProductId;

    if (replacement.isService && replacement.stockProductId != null) {
      targetProductId = replacement.stockProductId;
    } else if (!replacement.isService) {
      targetProductId = productId;
    }

    if (targetProductId != null && resolvedCostPrice <= 0.0) {
      final productDoc =
          await _db.collection('products').doc(targetProductId).get();
      if (productDoc.exists) {
        final product = ProductModel.fromMap(productDoc.data()!);
        if (!replacement.isService && product.costPrice > 0) {
          resolvedCostPrice = product.costPrice;
        }
      }
    }

    // 2. Set the replacement model directly as accepted
    final updatedReplacement = ReplacementModel(
      id: replacement.id,
      productId: replacement.productId,
      productName: replacement.productName,
      employeeName: replacement.employeeName,
      shopId: replacement.shopId,
      reason: replacement.reason,
      status: 'accepted',
      timestamp: replacement.timestamp,
      costPrice: resolvedCostPrice,
      saleId: replacement.saleId,
      isService: replacement.isService,
      stockProductId: replacement.stockProductId,
      customerName: replacement.customerName,
      quantity: replacement.quantity,
      returnAction: replacement.returnAction,
      dealerStatus: replacement.returnAction != null ? 'collected' : null,
      dealerName: replacement.dealerName,
      dealerDocketNo: replacement.dealerDocketNo,
      dealerSentDate: replacement.dealerSentDate,
      dealerResolvedDate: replacement.dealerResolvedDate,
      paymentMode: replacement.paymentMode,
    );

    // Write the replacement to Firestore (combining add + approve status change)
    await _db
        .collection('replacements')
        .doc(updatedReplacement.id)
        .set(updatedReplacement.toMap());

    // 3. Reduce product stock (only if 'replace' or null returnAction)
    final bool shouldReduceStock = (updatedReplacement.returnAction == null ||
        updatedReplacement.returnAction == 'replace');
    if (shouldReduceStock && targetProductId != null) {
      final productDoc =
          await _db.collection('products').doc(targetProductId).get();
      if (productDoc.exists) {
        final product = ProductModel.fromMap(productDoc.data()!);
        int newStock = product.units - qty;
        await updateStock(targetProductId, newStock >= 0 ? newStock : 0);
      }
    }

    // 4. Create Expense Entry if there's a financial loss
    final double totalLoss = resolvedCostPrice * qty;
    if (totalLoss > 0) {
      final expenseId = 'EXP_REP_${updatedReplacement.id}';
      final String category = updatedReplacement.isService
          ? 'Service Re-Repair Loss'
          : 'Replacement Loss';
      final String description = '[Cust: ${updatedReplacement.customerName}] | '
          '[Item: ${updatedReplacement.productName.replaceAll("Service: ", "")}] | '
          '[Qty: $qty] | [By: ${updatedReplacement.employeeName}]';

      final expense = ExpenseModel(
        id: expenseId,
        shopId: updatedReplacement.shopId,
        category: category,
        amount: totalLoss,
        description: description,
        timestamp: DateTime.now(),
        paymentMode: updatedReplacement.isService
            ? updatedReplacement.paymentMode
            : 'Stock',
      );
      await addExpense(expense);

      if (updatedReplacement.isService) {
        final serviceDocRef =
            _db.collection('services').doc(updatedReplacement.productId);
        final serviceDoc = await serviceDocRef.get();
        if (serviceDoc.exists) {
          final double existingReRepair =
              (serviceDoc.data()?['reRepairCost'] ?? 0.0).toDouble();
          await serviceDocRef.update({
            'reRepairCost': existingReRepair + totalLoss,
          });
        }
      }
    }

    // Send success notification (fire-and-forget in background)
    String actionText = 'Stock reduced';
    if (updatedReplacement.returnAction == 'refund') {
      actionText = 'Refund logged';
    } else if (updatedReplacement.returnAction == 'exchange') {
      actionText = 'Exchange logged';
    }
    final String notificationTitle = updatedReplacement.isService
        ? 'Re-Repair Approved ✅'
        : 'Replacement Approved ✅';
    final String notificationBody = updatedReplacement.isService
        ? 'Re-repair logged for ${updatedReplacement.productName}'
        : '$actionText by $qty for ${updatedReplacement.productName}. Total Loss: \u20B9${totalLoss.toStringAsFixed(0)}';

    _sendNotification(
        updatedReplacement.shopId, notificationTitle, notificationBody);
  }

  Stream<List<ReplacementModel>> getReplacementRequests(String shopId,
      {String? status}) {
    return _db
        .collection('replacements')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ReplacementModel.fromMap(doc.data()))
          .where((r) => status == null || r.status == status)
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Stream<List<ReplacementModel>> getDealerClaims(String shopId) {
    return _db
        .collection('replacements')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ReplacementModel.fromMap(doc.data()))
          .where((r) => r.returnAction != null && r.status == 'accepted')
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Future<void> approveReplacement(String replacementId, double manualCostPrice,
      {String paymentMode = 'Cash'}) async {
    final docRef = _db.collection('replacements').doc(replacementId);
    final doc = await docRef.get();

    if (doc.exists) {
      final replacement = ReplacementModel.fromMap(doc.data()!);
      final productId = replacement.productId;
      final int qty = replacement.quantity;

      // 2. Reduce Product Stock & resolve actualCostPrice (Unit Cost)
      String? targetProductId;
      double unitCostPrice = manualCostPrice;

      if (replacement.isService && replacement.stockProductId != null) {
        targetProductId = replacement.stockProductId;
      } else if (!replacement.isService) {
        targetProductId = productId;
      }

      // Resolve unitCostPrice (Unit Cost)
      if (targetProductId != null && unitCostPrice <= 0.0) {
        final productDoc =
            await _db.collection('products').doc(targetProductId).get();
        if (productDoc.exists) {
          final product = ProductModel.fromMap(productDoc.data()!);
          if (!replacement.isService && product.costPrice > 0) {
            unitCostPrice = product.costPrice;
          }
        }
      }

      // 1. Mark replacement as accepted and store resolved unit cost first so UI updates instantly
      Map<String, dynamic> updates = {
        'status': 'accepted',
        'costPrice': unitCostPrice,
        'paymentMode': paymentMode,
      };
      if (replacement.returnAction != null) {
        updates['dealerStatus'] = 'collected';
      }
      await docRef.update(updates);

      // 2. Subsequently reduce product stock (ONLY if returnAction is 'replace' or null)
      final bool shouldReduceStock = (replacement.returnAction == null ||
          replacement.returnAction == 'replace');
      if (shouldReduceStock && targetProductId != null) {
        final productDoc =
            await _db.collection('products').doc(targetProductId).get();
        if (productDoc.exists) {
          final product = ProductModel.fromMap(productDoc.data()!);
          int newStock = product.units - qty;
          await updateStock(targetProductId, newStock >= 0 ? newStock : 0);
        }
      }

      // 3. Create Expense Entry if there's a financial loss (Total = Unit x Qty)
      final double totalLoss = unitCostPrice * qty;
      if (totalLoss > 0) {
        final expenseId = 'EXP_REP_$replacementId';
        final String category = replacement.isService
            ? 'Service Re-Repair Loss'
            : 'Replacement Loss';

        // Structured description for professional PDF reporting
        final String description = '[Cust: ${replacement.customerName}] | '
            '[Item: ${replacement.productName.replaceAll("Service: ", "")}] | '
            '[Qty: $qty] | [By: ${replacement.employeeName}]';

        final expense = ExpenseModel(
          id: expenseId,
          shopId: replacement.shopId,
          category: category,
          amount: totalLoss,
          description: description,
          timestamp: replacement.timestamp,
          paymentMode: replacement.isService ? paymentMode : 'Stock',
        );
        await addExpense(expense);

        // Update the service re-repair cost if this is a service-related re-repair
        if (replacement.isService) {
          final serviceDocRef =
              _db.collection('services').doc(replacement.productId);
          final serviceDoc = await serviceDocRef.get();
          if (serviceDoc.exists) {
            final double existingReRepair =
                (serviceDoc.data()?['reRepairCost'] ?? 0.0).toDouble();
            await serviceDocRef.update({
              'reRepairCost': existingReRepair + totalLoss,
            });
          }
        }
      }

      final String notificationTitle = replacement.isService
          ? 'Re-Repair Approved ✅'
          : 'Replacement Approved ✅';

      String actionText = 'Stock reduced';
      if (replacement.returnAction == 'refund') {
        actionText = 'Refund logged';
      } else if (replacement.returnAction == 'exchange') {
        actionText = 'Exchange logged';
      }

      final String notificationBody = replacement.isService
          ? 'Re-repair logged for ${replacement.productName}'
          : '$actionText by $qty for ${replacement.productName}. Total Loss: \u20B9${totalLoss.toStringAsFixed(0)}';

      await _sendNotification(
          replacement.shopId, notificationTitle, notificationBody);
    }
  }

  Future<void> sendReplacementToDealer(
      String replacementId, String dealerName) async {
    await _db.collection('replacements').doc(replacementId).update({
      'dealerStatus': 'sent_to_dealer',
      'dealerName': dealerName,
      'dealerDocketNo': '',
      'dealerSentDate': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> resolveDealerClaim(String replacementId, String resolution,
      {String refundPaymentMode = 'Online'}) async {
    final docRef = _db.collection('replacements').doc(replacementId);
    final doc = await docRef.get();
    if (doc.exists) {
      final replacement = ReplacementModel.fromMap(doc.data()!);
      final double cost = replacement.costPrice ?? 0.0;
      final int qty = replacement.quantity;
      final double totalValue = cost * qty;

      if (resolution == 'replaced') {
        // Increment the active stock of the product by the quantity replaced
        final productId = replacement.productId;
        final productDoc =
            await _db.collection('products').doc(productId).get();
        if (productDoc.exists) {
          final product = ProductModel.fromMap(productDoc.data()!);
          await updateStock(productId, product.units + qty);
        }

        // Log a negative expense to offset the loss
        if (totalValue > 0) {
          final expenseId = 'EXP_REP_RESOLVED_$replacementId';
          final expense = ExpenseModel(
            id: expenseId,
            shopId: replacement.shopId,
            category: replacement.isService
                ? 'Service Re-Repair Loss'
                : 'Replacement Loss',
            amount: -totalValue,
            description:
                '[Dealer Replaced] Offset for claim on ${replacement.productName} | Ref: ${replacement.dealerDocketNo ?? "N/A"}',
            timestamp: DateTime.now(),
            paymentMode: replacement.paymentMode,
          );
          await addExpense(expense);
        }

        await docRef.update({
          'dealerStatus': 'resolved_replaced',
          'dealerResolvedDate': Timestamp.fromDate(DateTime.now()),
        });
      } else if (resolution == 'refunded') {
        // Log a negative expense to offset the loss
        if (totalValue > 0) {
          final expenseId = 'EXP_REP_RESOLVED_$replacementId';
          final expense = ExpenseModel(
            id: expenseId,
            shopId: replacement.shopId,
            category: replacement.isService
                ? 'Service Re-Repair Loss'
                : 'Replacement Loss',
            amount: -totalValue,
            description:
                '[Dealer Refunded] Offset for claim on ${replacement.productName} | Ref: ${replacement.dealerDocketNo ?? "N/A"}',
            timestamp: DateTime.now(),
            paymentMode: refundPaymentMode,
          );
          await addExpense(expense);
        }

        await docRef.update({
          'dealerStatus': 'resolved_refunded',
          'dealerResolvedDate': Timestamp.fromDate(DateTime.now()),
        });
      } else if (resolution == 'rejected') {
        await docRef.update({
          'dealerStatus': 'dealer_rejected',
          'dealerResolvedDate': Timestamp.fromDate(DateTime.now()),
        });
      }
    }
  }

  Future<void> rejectReplacement(String replacementId) async {
    await _db
        .collection('replacements')
        .doc(replacementId)
        .update({'status': 'rejected'});
  }

  // Warranty/Search Operations - Unified Sales & Services
  Future<List<dynamic>> searchSales(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];
    final lowerQuery = cleanQuery.toLowerCase();

    final salePhoneFuture = _db
        .collection('sales')
        .where('customerPhone', isGreaterThanOrEqualTo: cleanQuery)
        .where('customerPhone', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
        .get();

    final saleNameFuture = _db
        .collection('sales')
        .where('customerNameLower', isGreaterThanOrEqualTo: lowerQuery)
        .where('customerNameLower', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
        .get();

    final servicePhoneFuture = _db
        .collection('services')
        .where('customerPhone', isGreaterThanOrEqualTo: cleanQuery)
        .where('customerPhone', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
        .get();

    final serviceNameFuture = _db
        .collection('services')
        .where('customerNameLower', isGreaterThanOrEqualTo: lowerQuery)
        .where('customerNameLower', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
        .get();

    final querySnapshots = await Future.wait([
      salePhoneFuture,
      saleNameFuture,
      servicePhoneFuture,
      serviceNameFuture,
    ]);

    final salePhoneQuery = querySnapshots[0];
    final saleNameQuery = querySnapshots[1];
    final servicePhoneQuery = querySnapshots[2];
    final serviceNameQuery = querySnapshots[3];

    // Merge and deduplicate
    Map<String, dynamic> uniqueRecords = {};

    for (var doc in salePhoneQuery.docs)
      uniqueRecords[doc.id] = SaleModel.fromMap(doc.data());
    for (var doc in saleNameQuery.docs)
      uniqueRecords[doc.id] = SaleModel.fromMap(doc.data());
    for (var doc in servicePhoneQuery.docs)
      uniqueRecords[doc.id] = ServiceModel.fromMap(doc.data());
    for (var doc in serviceNameQuery.docs)
      uniqueRecords[doc.id] = ServiceModel.fromMap(doc.data());

    List<dynamic> combined = uniqueRecords.values.toList();

    // Sort by timestamp (both models have a timestamp field)
    combined.sort((a, b) {
      DateTime timeA =
          (a is SaleModel) ? a.timestamp : (a as ServiceModel).timestamp;
      DateTime timeB =
          (b is SaleModel) ? b.timestamp : (b as ServiceModel).timestamp;
      return timeB.compareTo(timeA);
    });

    return combined;
  }

  // One-time migration to fix older records lacking the search field
  Future<void> syncSearchIndices() async {
    // 1. Repair Sales
    final salesSnapshot = await _db.collection('sales').get();
    for (var doc in salesSnapshot.docs) {
      final data = doc.data();
      if (data['customerNameLower'] == null) {
        await doc.reference.update({
          'customerNameLower': (data['customerName'] ?? 'walk-in customer')
              .toString()
              .toLowerCase()
        });
      }
    }

    // 2. Repair Services
    final servicesSnapshot = await _db.collection('services').get();
    for (var doc in servicesSnapshot.docs) {
      final data = doc.data();
      if (data['customerNameLower'] == null) {
        await doc.reference.update({
          'customerNameLower':
              (data['customerName'] ?? 'customer').toString().toLowerCase()
        });
      }
    }
  }

  // Internal notification helper
  Future<void> _sendNotification(
      String shopId, String title, String body) async {
    print('Notification trigger: $title - $body');
    NotificationService().sendOneSignalNotification(title, body);
    await _db.collection('notifications').add({
      'title': title,
      'body': body,
      'shopId': shopId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  // ── Specialist Fee Requests ────────────────────────────────────────────────

  /// Called when a staff member delivers a service — creates a pending request
  /// for the owner to enter the specialist fee.
  Future<void> addSpecialistFeeRequest(
      SpecialistFeeRequestModel request) async {
    await _db
        .collection('specialistFeeRequests')
        .doc(request.id)
        .set(request.toMap());
    await _sendNotification(
      request.shopId,
      'Specialist Fee Pending',
      '${request.deliveredBy} delivered ${request.mobileModel} for ${request.customerName}. Enter specialist fee.',
    );
  }

  /// Stream of all pending specialist fee requests for a shop.
  Stream<List<SpecialistFeeRequestModel>> getPendingSpecialistFeeRequests(
      String shopId) {
    return _db
        .collection('specialistFeeRequests')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => SpecialistFeeRequestModel.fromMap(d.data()))
          .where((r) => r.status == 'pending')
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  /// Owner submits the specialist fee and display cost for a delivered service.
  /// Creates an expense entry and marks the request as recorded.
  Future<void> recordSpecialistFee(
    SpecialistFeeRequestModel request,
    double fee,
    double partsCost, {
    String feePaymentMode = 'Cash',
    String partsPaymentMode = 'Cash',
  }) async {
    if (fee > 0) {
      final expense = ExpenseModel(
        id: 'EXP_SVC_${request.serviceId}',
        shopId: request.shopId,
        category: 'Specialist Fee',
        amount: fee,
        description:
            '[Cust: ${request.customerName}] | [Model: ${request.mobileModel}] | [Delivered by: ${request.deliveredBy}]',
        timestamp: request.timestamp,
        paymentMode: feePaymentMode,
      );
      await addExpense(expense);
    }

    if (partsCost > 0) {
      final expense = ExpenseModel(
        id: 'EXP_PART_${request.serviceId}',
        shopId: request.shopId,
        category: 'Parts Cost',
        amount: partsCost,
        description:
            '[Cust: ${request.customerName}] | [Model: ${request.mobileModel}] | [Wholesaler Part]',
        timestamp: request.timestamp,
        paymentMode: partsPaymentMode,
      );
      await addExpense(expense);
    }

    // Update the service document with both the partsCost and technicianFee
    await _db.collection('services').doc(request.serviceId).update({
      'partsCost': partsCost,
      'technicianFee': fee,
      'partsPaymentMode': partsPaymentMode,
      'technicianPaymentMode': feePaymentMode,
      'isExpenseRecorded': true,
    });

    await _db
        .collection('specialistFeeRequests')
        .doc(request.id)
        .update({'status': 'recorded'});
  }

  // Enquiry Operations
  Future<void> addEnquiry(EnquiryModel enquiry) async {
    await _db.collection('enquiries').doc(enquiry.id).set(enquiry.toMap());
  }

  Stream<List<EnquiryModel>> getEnquiries(String? shopId) {
    Query<Map<String, dynamic>> query = _db.collection('enquiries');
    if (shopId != null) {
      query = query.where('shopId', isEqualTo: shopId);
    }
    return query.snapshots().map((snapshot) {
      final list =
          snapshot.docs.map((doc) => EnquiryModel.fromMap(doc.data())).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> updateEnquiry(EnquiryModel enquiry) async {
    await _db.collection('enquiries').doc(enquiry.id).update(enquiry.toMap());
  }

  Future<void> updateEnquiryStatus(String id, String status) async {
    await _db.collection('enquiries').doc(id).update({'status': status});
  }

  Future<void> deleteEnquiry(String id) async {
    await _db.collection('enquiries').doc(id).delete();
  }

  // Product Order Operations
  Future<void> addProductOrder(ProductOrderModel order) async {
    await _db.collection('product_orders').doc(order.id).set(order.toMap());
  }

  Stream<List<ProductOrderModel>> getProductOrders(String? shopId) {
    Query<Map<String, dynamic>> query = _db.collection('product_orders');
    if (shopId != null) {
      query = query.where('shopId', isEqualTo: shopId);
    }
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) =>
              ProductOrderModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> updateProductOrder(ProductOrderModel order) async {
    await _db.collection('product_orders').doc(order.id).update(order.toMap());
  }

  Future<void> markOrdersAsOrdered(
      List<String> orderItemIds, String orderId) async {
    final batch = _db.batch();
    final now = DateTime.now();
    for (final id in orderItemIds) {
      batch.update(_db.collection('product_orders').doc(id), {
        'status': 'ordered',
        'orderId': orderId,
        'orderedAt': now.toIso8601String(),
      });
    }
    await batch.commit();
  }

  Future<void> markOrderAsReceived(String orderId) async {
    final snapshot = await _db
        .collection('product_orders')
        .where('orderId', isEqualTo: orderId)
        .get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'status': 'completed'});
    }
    await batch.commit();
  }

  Future<void> deleteProductOrder(String id) async {
    await _db.collection('product_orders').doc(id).delete();
  }

  // GST Settings Operations
  Future<GstSettingsModel?> getGstSettings(String shopId) async {
    final doc = await _db.collection('settings').doc('gst_$shopId').get();
    if (doc.exists && doc.data() != null) {
      return GstSettingsModel.fromMap(doc.data()!, shopId);
    }
    return null;
  }

  Stream<GstSettingsModel?> streamGstSettings(String shopId) {
    return _db.collection('settings').doc('gst_$shopId').snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return GstSettingsModel.fromMap(doc.data()!, shopId);
      }
      return null;
    });
  }

  Future<void> saveGstSettings(GstSettingsModel settings) async {
    _db
        .collection('settings')
        .doc('gst_${settings.shopId}')
        .set(settings.toMap());
  }

  Future<void> clearAllTransactionData() async {
    final collections = [
      'sales',
      'services',
      'expenses',
      'specialistFeeRequests',
      'replacements',
      'enquiries',
      'notifications',
      'product_orders'
    ];
    for (final col in collections) {
      final snap = await _db.collection(col).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }
  }

  // Phone Book Operations
  Future<void> addPhoneBookContact(PhoneBookContact contact) async {
    await _db.collection('phone_book').doc(contact.id).set(contact.toMap());
  }

  Stream<List<PhoneBookContact>> getPhoneBookContacts() {
    return _db.collection('phone_book')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => PhoneBookContact.fromMap(doc.data())).toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        });
  }

  Future<void> deletePhoneBookContact(String id) async {
    await _db.collection('phone_book').doc(id).delete();
  }

  // WhatsApp Added Numbers Operations
  Stream<Set<String>> getAddedWhatsAppNumbers() {
    return _db.collection('whatsapp_added_numbers')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  Future<void> markMultipleAsAdded(List<String> phones, bool isAdded) async {
    final batch = _db.batch();
    for (var phone in phones) {
      final docRef = _db.collection('whatsapp_added_numbers').doc(phone);
      if (isAdded) {
        batch.set(docRef, {
          'addedAt': FieldValue.serverTimestamp(),
        });
      } else {
        batch.delete(docRef);
      }
    }
    await batch.commit();
  }
}
