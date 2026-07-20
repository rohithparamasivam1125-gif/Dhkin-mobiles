import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../../services/security_service.dart';
import '../../services/biometric_service.dart';
import '../../widgets/pattern_lock_widget.dart';
import '../../main.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final SecurityService _securityService = SecurityService();
  final BiometricService _biometricService = BiometricService();
  String _currentType = 'pin';
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  int _dbMinVersionCode = 1;
  String _dbMinVersionName = '1.0.0';
  String _dbUpdateUrl = 'https://example.com/update';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final settings = await _securityService.getSettings();
    final isAvailable = await _biometricService.isBiometricsAvailable();
    final isEnabled = await _biometricService.isBiometricLoginEnabled();
    
    // Fetch version data from Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_config')
          .doc('app_status')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _dbMinVersionCode = data['minVersionCode'] ?? 1;
          _dbMinVersionName = data['minVersionName'] ?? '1.0.0';
          _dbUpdateUrl = data['updateUrl'] ?? 'https://example.com/update';
        });
      }
    } catch (e) {
      debugPrint('Error loading version settings: $e');
    }

    setState(() {
      _currentType = settings['type']!;
      _biometricAvailable = isAvailable;
      _biometricEnabled = isEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildTypeToggle(),
            const SizedBox(height: 16),
            _buildBiometricCard(),
            const SizedBox(height: 16),
            _buildVersionControlCard(),
            const SizedBox(height: 16),
            _buildUpdateAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricCard() {
    return Card(
      child: SwitchListTile(
        title: const Text('Biometric / Fingerprint Login', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          !_biometricAvailable 
              ? 'Biometrics not supported on this device' 
              : 'Unlock Owner mode with fingerprint/Face ID on this device only',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        secondary: const Icon(Icons.fingerprint, color: AppTheme.accentForest),
        value: _biometricEnabled,
        onChanged: !_biometricAvailable 
            ? null 
            : (bool value) async {
                if (value) {
                  // Authenticate before enabling
                  final authenticated = await _biometricService.authenticate();
                  if (authenticated) {
                    await _biometricService.setBiometricLoginEnabled(true);
                    setState(() {
                      _biometricEnabled = true;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Biometric Owner Login enabled successfully on this device')),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to authenticate. Biometric login remains disabled.')),
                      );
                    }
                  }
                } else {
                  // Disable biometric login
                  await _biometricService.setBiometricLoginEnabled(false);
                  setState(() {
                    _biometricEnabled = false;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Biometric Owner Login disabled')),
                    );
                  }
                }
              },
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.security, color: AppTheme.accentForest, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dashboard Protection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Currently using $_currentType lock', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Card(
      child: Column(
        children: [
          RadioListTile<String>(
            title: const Text('PIN Lock'),
            subtitle: const Text('4-digit numeric code'),
            secondary: const Icon(Icons.pin_outlined),
            value: 'pin',
            groupValue: _currentType,
            onChanged: (val) => _changeType(val!),
          ),
          const Divider(height: 1),
          RadioListTile<String>(
            title: const Text('Pattern Lock'),
            subtitle: const Text('3x3 dot grid gesture'),
            secondary: const Icon(Icons.gesture),
            value: 'pattern',
            groupValue: _currentType,
            onChanged: (val) => _changeType(val!),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateAction() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.lock_reset),
        onPressed: _currentType == 'pin' ? _showUpdatePinDialog : _showUpdatePatternDialog,
        label: Text('Update $_currentType'.toUpperCase()),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  void _changeType(String type) async {
    // Before switching, must define a secret for the new type if it doesn't match
    if (type == 'pin') {
       _showUpdatePinDialog();
    } else {
       _showUpdatePatternDialog();
    }
  }

  void _showUpdatePinDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set New PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a 4-digit code for your dashboard access.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New PIN', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.length == 4) {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                await _securityService.saveSettings('pin', controller.text);
                _loadSettings();
                navigator.pop();
                messenger.showSnackBar(const SnackBar(content: Text('PIN updated successfully')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showUpdatePatternDialog() {
    String step = "DRAW"; // DRAW -> CONFIRM
    String? firstPattern;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppTheme.accentForest, borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gesture, color: Colors.white, size: 40),
                const SizedBox(height: 16),
                Text(
                  step == "DRAW" ? 'DRAW NEW PATTERN' : 'CONFIRM PATTERN',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 24),
                PatternLockWidget(
                  onCompleted: (pattern) {
                    if (step == "DRAW") {
                      setDialogState(() {
                        firstPattern = pattern;
                        step = "CONFIRM";
                      });
                    } else {
                      if (pattern == firstPattern) {
                        _securityService.saveSettings('pattern', pattern);
                        _loadSettings();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pattern updated successfully')));
                      } else {
                        setDialogState(() => step = "DRAW");
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patterns did not match. Try again.'), backgroundColor: Colors.red));
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.white70))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVersionControlCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.system_update_alt, color: AppTheme.accentForest),
                const SizedBox(width: 12),
                const Text(
                  'App Version Control',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 24),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Installed Local Version:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Text('1.0.0 (Build 1)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Required Min Version:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Text('$_dbMinVersionName (Build $_dbMinVersionCode)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Update Link:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _dbUpdateUrl,
                    style: const TextStyle(color: Colors.blue, fontSize: 12, decoration: TextDecoration.underline),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _showConfigureVersionDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentForest,
                  side: const BorderSide(color: AppTheme.accentForest),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('CONFIGURE REQUIRED VERSION'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfigureVersionDialog() {
    final codeController = TextEditingController(text: _dbMinVersionCode.toString());
    final nameController = TextEditingController(text: _dbMinVersionName);
    final urlController = TextEditingController(text: _dbUpdateUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configure App Version'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Require devices to run a specific minimum version. Older versions will be blocked.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum Build Version Code',
                  hintText: 'e.g. 1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Minimum Version Name',
                  hintText: 'e.g. 1.0.0',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Update Download URL',
                  hintText: 'e.g. https://link.to.apk',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCode = int.tryParse(codeController.text) ?? 1;
              final newName = nameController.text.trim();
              final newUrl = urlController.text.trim();

              if (newName.isEmpty || newUrl.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              // Owner Lockout protection
              if (newCode > kCurrentVersionCode) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Warning: Lockout Threat'),
                    content: Text(
                      'Setting the required version higher than your current version (Build $kCurrentVersionCode) will lock you out of this device as well.\n\nAre you sure you want to proceed?',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No, Cancel')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Yes, Lock Device'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
              }

              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              // Update Firestore
              try {
                await FirebaseFirestore.instance
                    .collection('system_config')
                    .doc('app_status')
                    .update({
                  'minVersionCode': newCode,
                  'minVersionName': newName,
                  'updateUrl': newUrl,
                });

                setState(() {
                  _dbMinVersionCode = newCode;
                  _dbMinVersionName = newName;
                  _dbUpdateUrl = newUrl;
                });

                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('App version configuration updated successfully')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error updating version config: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
