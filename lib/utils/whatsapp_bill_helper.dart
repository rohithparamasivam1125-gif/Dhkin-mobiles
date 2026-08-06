import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sale_model.dart';
import '../models/service_model.dart';
import '../models/gst_settings_model.dart';

class WhatsAppBillHelper {
  /// Formats a complete rich text bill for Sales with warranty and pricing details.
  static String generateSaleBillText(SaleModel sale, GstSettingsModel gstSettings) {
    final buffer = StringBuffer();
    final dateStr =
        "${sale.timestamp.day.toString().padLeft(2, '0')}-${sale.timestamp.month.toString().padLeft(2, '0')}-${sale.timestamp.year}";

    buffer.writeln('🧾 *${gstSettings.shopName.toUpperCase()}*');
    if (gstSettings.address.trim().isNotEmpty && gstSettings.address != 'Store Address') {
      buffer.writeln('📍 ${gstSettings.address.trim()}');
    }
    if (gstSettings.contactNumber.trim().isNotEmpty && gstSettings.contactNumber != 'Phone') {
      buffer.writeln('📞 Ph: ${gstSettings.contactNumber.trim()}');
    }
    if (sale.isGstBill &&
        gstSettings.gstNumber.trim().isNotEmpty &&
        gstSettings.gstNumber != 'N/A') {
      buffer.writeln('📄 *GSTIN:* ${gstSettings.gstNumber.trim()}');
    }

    buffer.writeln('');
    buffer.writeln('👤 *Customer:* ${sale.customerName}');
    buffer.writeln('📞 *Phone:* ${sale.customerPhone}');
    buffer.writeln('📅 *Date:* $dateStr');
    buffer.writeln('🔢 *Invoice:* INV-${sale.id.substring(0, 8).toUpperCase()}');
    if (sale.employeeId.trim().isNotEmpty) {
      buffer.writeln('👤 *Billed By:* ${sale.employeeId}');
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('*ITEMS:*');

    bool hasAnyWarranty = false;

    for (int i = 0; i < sale.items.length; i++) {
      final item = sale.items[i];
      final double itemTotal = item.price * item.quantity;
      buffer.writeln('${i + 1}. *${item.productName}*');
      buffer.writeln('   Qty: ${item.quantity} x ₹${item.price.toStringAsFixed(0)} = ₹${itemTotal.toStringAsFixed(0)}');

      if (item.hasWarranty && item.warrantyPeriod > 0) {
        hasAnyWarranty = true;
        DateTime endDate = sale.timestamp;
        if (item.warrantyType == 'Days') {
          endDate = endDate.add(Duration(days: item.warrantyPeriod));
        } else if (item.warrantyType == 'Months') {
          int newMonth = endDate.month + item.warrantyPeriod;
          int newYear = endDate.year + (newMonth - 1) ~/ 12;
          newMonth = (newMonth - 1) % 12 + 1;
          int day = endDate.day;
          final lastDayOfNewMonth = DateTime(newYear, newMonth + 1, 0).day;
          if (day > lastDayOfNewMonth) day = lastDayOfNewMonth;
          endDate = DateTime(newYear, newMonth, day);
        } else if (item.warrantyType == 'Years') {
          endDate = DateTime(endDate.year + item.warrantyPeriod, endDate.month, endDate.day);
        }
        String formattedEndDate =
            "${endDate.day.toString().padLeft(2, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.year}";
        buffer.writeln('   🛡️ *Warranty:* ${item.warrantyPeriod} ${item.warrantyType} (Ends: $formattedEndDate)');
      } else {
        buffer.writeln('   🛡️ *Warranty:* No Warranty');
      }
    }

    buffer.writeln('----------------------------------------');
    if (sale.isGstBill) {
      buffer.writeln('💵 *Subtotal:* ₹${sale.taxableAmount.toStringAsFixed(2)}');
      buffer.writeln('📈 *CGST (${gstSettings.cgstRate.toStringAsFixed(0)}%):* ₹${sale.cgstAmount.toStringAsFixed(2)}');
      buffer.writeln('📈 *SGST (${gstSettings.sgstRate.toStringAsFixed(0)}%):* ₹${sale.sgstAmount.toStringAsFixed(2)}');
      buffer.writeln('----------------------------------------');
    }

    if (sale.discountAmount > 0) {
      buffer.writeln('🏷️ *Discount:* ₹${sale.discountAmount.toStringAsFixed(2)}');
    }

    buffer.writeln('💰 *Total Amount:* ₹${sale.totalPrice.toStringAsFixed(0)}');
    if (sale.paymentMode.trim().isNotEmpty) {
      buffer.writeln('💳 *Payment Mode:* ${sale.paymentMode} (Paid)');
    }
    buffer.writeln('----------------------------------------');

    if (hasAnyWarranty) {
      buffer.writeln('📜 *Warranty & Store Policy:*');
      buffer.writeln('• Warranty claims require original proof of purchase bill.');
      buffer.writeln('• Physical, water, or screen damage voids warranty.');
      buffer.writeln('----------------------------------------');
    }

    buffer.writeln('Thank you for shopping with us! 🙏');
    if (gstSettings.groupLink != null && gstSettings.groupLink!.trim().isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('📲 *Join our WhatsApp Group:* ${gstSettings.groupLink!.trim()}');
    }

    return buffer.toString();
  }

  /// Formats a complete rich text bill for Service Invoices with warranty and service charges.
  static String generateServiceBillText(ServiceModel service, GstSettingsModel gstSettings) {
    final buffer = StringBuffer();
    final dateStr =
        "${service.timestamp.day.toString().padLeft(2, '0')}-${service.timestamp.month.toString().padLeft(2, '0')}-${service.timestamp.year}";

    buffer.writeln('🛠️ *${gstSettings.shopName.toUpperCase()} - SERVICE INVOICE*');
    if (gstSettings.address.trim().isNotEmpty && gstSettings.address != 'Store Address') {
      buffer.writeln('📍 ${gstSettings.address.trim()}');
    }
    if (gstSettings.contactNumber.trim().isNotEmpty && gstSettings.contactNumber != 'Phone') {
      buffer.writeln('📞 Ph: ${gstSettings.contactNumber.trim()}');
    }
    if (service.isGstBill &&
        gstSettings.gstNumber.trim().isNotEmpty &&
        gstSettings.gstNumber != 'N/A') {
      buffer.writeln('📄 *GSTIN:* ${gstSettings.gstNumber.trim()}');
    }

    buffer.writeln('');
    buffer.writeln('👤 *Customer:* ${service.customerName}');
    buffer.writeln('📞 *Phone:* ${service.customerPhone}');
    buffer.writeln('📅 *Date:* $dateStr');
    buffer.writeln('🔢 *Service ID:* SRV-${service.id.substring(0, 8).toUpperCase()}');
    buffer.writeln('📱 *Device:* ${service.mobileModel}');
    if (service.mobileDetails.trim().isNotEmpty) {
      buffer.writeln('🔧 *Problem / Notes:* ${service.mobileDetails}');
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('*SERVICE & SPARE DETAILS:*');
    buffer.writeln('• Service & Labor Charges: ₹${service.totalAmount.toStringAsFixed(0)}');

    if (service.complementaryItems.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('🎁 *Complimentary Items:*');
      for (final item in service.complementaryItems) {
        final name = item['productName'] as String? ?? 'Item';
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        buffer.writeln('  • $name x $qty (No Charge)');
      }
    }

    buffer.writeln('----------------------------------------');
    if (service.isGstBill) {
      buffer.writeln('💵 *Subtotal:* ₹${service.taxableAmount.toStringAsFixed(2)}');
      buffer.writeln('📈 *CGST (${gstSettings.cgstRate.toStringAsFixed(0)}%):* ₹${service.cgstAmount.toStringAsFixed(2)}');
      buffer.writeln('📈 *SGST (${gstSettings.sgstRate.toStringAsFixed(0)}%):* ₹${service.sgstAmount.toStringAsFixed(2)}');
      buffer.writeln('----------------------------------------');
    }

    buffer.writeln('💰 *Total Charges:* ₹${service.totalAmount.toStringAsFixed(0)}');
    if (service.status == 'Delivered') {
      if (service.remainingAmount == 0) {
        if (service.advanceAmount > 0 && service.advanceAmount < service.totalAmount) {
          buffer.writeln('💵 *Advance Paid:* ₹${service.advanceAmount.toStringAsFixed(0)}');
          buffer.writeln('💵 *Balance Paid at Delivery:* ₹${(service.totalAmount - service.advanceAmount).toStringAsFixed(0)}');
        } else {
          buffer.writeln('💵 *Amount Paid:* ₹${service.totalAmount.toStringAsFixed(0)}');
        }
        buffer.writeln('🟢 *Status:* Fully Settled');
      } else {
        buffer.writeln('💵 *Advance Paid:* ₹${service.advanceAmount.toStringAsFixed(0)}');
        buffer.writeln('🔴 *Remaining Balance:* ₹${service.remainingAmount.toStringAsFixed(0)}');
      }
    } else {
      buffer.writeln('💵 *Advance Paid:* ₹${service.advanceAmount.toStringAsFixed(0)}');
      buffer.writeln('🔴 *Estimated Balance Due:* ₹${service.remainingAmount.toStringAsFixed(0)}');
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('📜 *Service Policy:*');
    buffer.writeln('• Warranty applicable only on repaired components/spares if specified.');
    buffer.writeln('• Physical, liquid, or burn damage voids service warranty.');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Thank you! 🙏');
    if (gstSettings.groupLink != null && gstSettings.groupLink!.trim().isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('📲 *Join our WhatsApp Group:* ${gstSettings.groupLink!.trim()}');
    }

    return buffer.toString();
  }

  /// Directly launches WhatsApp chat with pre-populated message for both saved and unsaved contacts.
  static Future<void> launchWhatsApp(String phone, String message, {BuildContext? context}) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      cleanPhone = cleanPhone.substring(1);
    }
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    final String whatsappScheme =
        'whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}';
    final Uri whatsappUri = Uri.parse(whatsappScheme);

    final String waMeUrl =
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
    final Uri waMeUri = Uri.parse(waMeUrl);

    final String apiUrl =
        'https://api.whatsapp.com/send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}';
    final Uri apiUri = Uri.parse(apiUrl);

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else if (await canLaunchUrl(waMeUri)) {
        await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(apiUri)) {
        await launchUrl(apiUri, mode: LaunchMode.externalApplication);
      } else {
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch WhatsApp. Make sure it is installed.')),
          );
        }
      }
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching WhatsApp: $e')),
        );
      }
    }
  }

  /// Convenience method to generate sale text bill and launch WhatsApp directly.
  static Future<void> shareSaleBillWhatsApp(
    SaleModel sale,
    GstSettingsModel gstSettings, {
    BuildContext? context,
  }) async {
    final text = generateSaleBillText(sale, gstSettings);
    await launchWhatsApp(sale.customerPhone, text, context: context);
  }

  /// Convenience method to generate service text bill and launch WhatsApp directly.
  static Future<void> shareServiceBillWhatsApp(
    ServiceModel service,
    GstSettingsModel gstSettings, {
    BuildContext? context,
  }) async {
    final text = generateServiceBillText(service, gstSettings);
    await launchWhatsApp(service.customerPhone, text, context: context);
  }
}
