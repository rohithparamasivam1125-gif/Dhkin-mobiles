import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import 'app_theme.dart';

class AppUpdateHelper {
  static bool _isDialogShowing = false;

  static Future<void> checkAndShowUpdateDialog(BuildContext context) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_config')
          .doc('app_status')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final dynamic rawLatestCode = data['latestVersionCode'];
        final int latestVersionCode = (rawLatestCode is int)
            ? rawLatestCode
            : (int.tryParse(rawLatestCode?.toString() ?? '1') ?? 1);
        final String latestVersionName = data['latestVersionName'] ?? '1.0.1';
        final String updateUrl = data['updateUrl'] ??
            'https://github.com/rohithparamasivam1125-gif/Dhkin-mobiles/raw/main/apks/app-release.apk';

        if (latestVersionCode > kCurrentVersionCode) {
          if (context.mounted && !_isDialogShowing) {
            _showUpdateAvailableDialog(context, latestVersionName, updateUrl);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking developer update: $e');
    }
  }

  static void _showUpdateAvailableDialog(
      BuildContext context, String version, String updateUrl) {
    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.accentForest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update,
                  color: AppTheme.primaryIvory, size: 50),
              const SizedBox(height: 16),
              const Text(
                'NEW UPDATE AVAILABLE',
                style: TextStyle(
                  color: AppTheme.primaryIvory,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'A new version ($version) with new features is ready for download.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  _isDialogShowing = false;
                  try {
                    final uri = Uri.parse(updateUrl);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    debugPrint('Could not launch update URL: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIvory,
                  foregroundColor: AppTheme.accentForest,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('DOWNLOAD NEW APK',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _isDialogShowing = false;
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('LATER',
                    style: TextStyle(color: Colors.white60)),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      _isDialogShowing = false;
    });
  }
}
