import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../services/security_service.dart';
import '../../widgets/pattern_lock_widget.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final SecurityService _securityService = SecurityService();
  String _currentType = 'pin';
  String _currentSecret = '1111';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final settings = await _securityService.getSettings();
    setState(() {
      _currentType = settings['type']!;
      _currentSecret = settings['secret']!;
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
            _buildUpdateAction(),
          ],
        ),
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
                await _securityService.saveSettings('pin', controller.text);
                _loadSettings();
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN updated successfully')));
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
}
