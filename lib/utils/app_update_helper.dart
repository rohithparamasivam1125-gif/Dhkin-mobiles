import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
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
        final String latestVersionName = data['latestVersionName'] ?? '1.0.3';
        final String updateUrl = data['updateUrl'] ??
            'https://raw.githubusercontent.com/rohithparamasivam1125-gif/Dhkin-mobiles/main/apks/app-release.apk';

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
                'A new version ($version) with new features is ready for installation.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _isDialogShowing = false;
                  startInAppUpdate(context, updateUrl);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIvory,
                  foregroundColor: AppTheme.accentForest,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_rounded),
                    SizedBox(width: 8),
                    Text('INSTALL UPDATE NOW',
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

  static void startInAppUpdate(BuildContext context, String updateUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return _InAppDownloadDialog(updateUrl: updateUrl);
      },
    );
  }
}

class _InAppDownloadDialog extends StatefulWidget {
  final String updateUrl;

  const _InAppDownloadDialog({required this.updateUrl});

  @override
  State<_InAppDownloadDialog> createState() => _InAppDownloadDialogState();
}

class _InAppDownloadDialogState extends State<_InAppDownloadDialog> {
  double _progressVal = 0.0;
  String _progressStr = '0%';
  String _statusText = 'Preparing update package...';
  bool _isDownloaded = false;
  bool _isError = false;
  String _errorMessage = '';
  bool _isStarted = false;
  String _directUrl = '';

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<String> _resolveDirectUrl(String originalUrl) async {
    String targetUrl = originalUrl;
    if (targetUrl.contains('github.com') && targetUrl.contains('/raw/')) {
      targetUrl = targetUrl
          .replaceFirst('github.com', 'raw.githubusercontent.com')
          .replaceFirst('/raw/', '/');
    }

    try {
      final client = http.Client();
      final req = http.Request('GET', Uri.parse(targetUrl))..followRedirects = true;
      final res = await client.send(req).timeout(const Duration(seconds: 5));
      if (res.request?.url != null) {
        targetUrl = res.request!.url.toString();
      }
      client.close();
    } catch (e) {
      debugPrint('Notice: Redirect resolution skipped ($e)');
    }
    return targetUrl;
  }

  void _triggerInstallation() {
    if (_directUrl.isEmpty) return;
    try {
      OtaUpdate().execute(
        _directUrl,
        destinationFilename: 'dhkin_mobiles_update.apk',
      ).listen(
        (event) {},
        onError: (e) => debugPrint('Re-trigger installer error: $e'),
      );
    } catch (e) {
      debugPrint('Error triggering installer: $e');
    }
  }

  void _startDownload() async {
    if (_isStarted) return;
    _isStarted = true;

    try {
      _directUrl = await _resolveDirectUrl(widget.updateUrl);

      if (!mounted) return;
      setState(() {
        _statusText = 'Downloading update package...';
      });

      OtaUpdate().execute(
        _directUrl,
        destinationFilename: 'dhkin_mobiles_update.apk',
      ).listen(
        (OtaEvent event) {
          if (!mounted) return;
          if (event.status == OtaStatus.DOWNLOADING) {
            final progress = int.tryParse(event.value ?? '0') ?? 0;
            setState(() {
              _progressVal = (progress / 100.0).clamp(0.0, 1.0);
              _progressStr = '$progress%';
              _statusText = 'Downloading update package...';
              if (progress >= 99) {
                _isDownloaded = true;
                _statusText = 'Ready to install!';
              }
            });
          } else if (event.status == OtaStatus.INSTALLING) {
            setState(() {
              _progressVal = 1.0;
              _progressStr = '100%';
              _statusText = 'Ready to install!';
              _isDownloaded = true;
            });
          } else if (event.status == OtaStatus.ALREADY_RUNNING_ERROR) {
            setState(() {
              _statusText = 'Update in progress...';
            });
          } else if (event.status == OtaStatus.PERMISSION_NOT_GRANTED_ERROR) {
            setState(() {
              _isDownloaded = true;
              _statusText = 'Permission needed to install';
            });
          } else {
            setState(() {
              _isError = true;
              _errorMessage = 'Download issue (${event.status}). You can download via browser.';
            });
          }
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _isError = true;
            _errorMessage = 'Could not download APK automatically. You can download via browser.';
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }

  void _fallbackToBrowser() async {
    Navigator.of(context).pop();
    try {
      final uri = Uri.parse(widget.updateUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch fallback update URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isError
                    ? Colors.red.shade50
                    : (_isDownloaded ? Colors.green.shade50 : AppTheme.accentForest.withValues(alpha: 0.1)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isError
                    ? Icons.error_outline
                    : (_isDownloaded ? Icons.check_circle_outline : Icons.system_update_rounded),
                color: _isError
                    ? Colors.red
                    : (_isDownloaded ? Colors.green.shade700 : AppTheme.accentForest),
                size: 44,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isError
                  ? 'UPDATE DOWNLOAD FAILED'
                  : (_isDownloaded ? 'DOWNLOAD COMPLETE' : 'DOWNLOADING UPDATE'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1,
                color: _isError
                    ? Colors.red
                    : (_isDownloaded ? Colors.green.shade800 : AppTheme.charcoalBlack),
              ),
            ),
            const SizedBox(height: 16),
            if (_isDownloaded) ...[
              const Text(
                'Update package is downloaded and ready to install.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  _triggerInstallation();
                },
                icon: const Icon(Icons.install_mobile_rounded),
                label: const Text('TAP TO INSTALL NOW', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Note: If Android prompts, enable "Allow unknown apps" permission for D&H Mobiles.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close', style: TextStyle(color: Colors.grey)),
              ),
            ] else if (!_isError) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progressVal > 0 ? _progressVal : null,
                  backgroundColor: Colors.grey.shade200,
                  color: AppTheme.accentForest,
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_statusText, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text(_progressStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentForest)),
                ],
              ),
            ] else ...[
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fallbackToBrowser,
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Download via Browser'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentForest,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
