import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/shop_helper.dart';
import 'owner/owner_home.dart';
import 'sales/employee_home.dart';
import '../../services/security_service.dart';
import '../../services/biometric_service.dart';
import '../../widgets/pattern_lock_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  bool _isStaffDevice = false;
  bool _showOwnerButton = true;
  int _shopIconTapCount = 0;

  @override
  void initState() {
    super.initState();
    _checkDeviceType();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/logo.png'), context);
  }

  Future<void> _checkDeviceType() async {
    final prefs = await SharedPreferences.getInstance();
    final isStaff = prefs.getBool('is_staff_device') ?? false;
    setState(() {
      _isStaffDevice = isStaff;
      if (isStaff) {
        _showOwnerButton = false;
      }
    });
  }

  void _showOwnerAuthDialog() async {
    final settings = await SecurityService().getSettings();
    final String lockType = settings['type']!;
    final bool isBioEnabled = await BiometricService().isBiometricLoginEnabled();

    if (isBioEnabled) {
      final authenticated = await BiometricService().authenticate();
      if (authenticated) {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OwnerHomeScreen()));
        }
        return;
      }
    }
    
    if (mounted) {
      if (lockType == 'pin') {
        _showPinDialog(isBioEnabled);
      } else {
        _showPatternDialog(isBioEnabled);
      }
    }
  }

  void _showPinDialog(bool isBioEnabled) {
    String currentPin = "";
    bool isError = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void handlePinChange(String value) async {
              if (value.length > 4) {
                _pinController.text = value.substring(0, 4);
                return;
              }
              setModalState(() {
                currentPin = value;
                isError = false;
              });

              if (value.length == 4) {
                final isValid = await SecurityService().verify(value);
                if (isValid) {
                  if (mounted) {
                    Navigator.pop(context);
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OwnerHomeScreen()));
                  }
                } else {
                  setModalState(() {
                    isError = true;
                    currentPin = "";
                    _pinController.clear();
                  });
                }
              }
            }

            return _buildAuthDialogFrame(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Icon(Icons.lock_person_outlined, color: AppTheme.primaryIvory, size: 40),
                    const SizedBox(height: 16),
                    const Text('ENTER PIN', style: TextStyle(color: AppTheme.primaryIvory, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        bool isFilled = index < currentPin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isError ? Colors.red : (isFilled ? AppTheme.primaryIvory : Colors.white10),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 0, width: 0,
                      child: TextField(
                        controller: _pinController,
                        focusNode: _pinFocusNode,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        onChanged: handlePinChange,
                        maxLength: 4,
                        decoration: const InputDecoration(counterText: ""),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
                        ),
                        if (isBioEnabled)
                          IconButton(
                            icon: const Icon(Icons.fingerprint, color: AppTheme.primaryIvory, size: 28),
                            onPressed: () async {
                              final authenticated = await BiometricService().authenticate();
                              if (authenticated && mounted) {
                                Navigator.pop(context);
                                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OwnerHomeScreen()));
                              }
                            },
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) => _pinController.clear());
  }

  void _showPatternDialog(bool isBioEnabled) {
    bool isError = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => _buildAuthDialogFrame(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gesture, color: Colors.white, size: 40),
              const SizedBox(height: 16),
              const Text('DRAW PATTERN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 24),
              PatternLockWidget(
                isError: isError,
                onCompleted: (pattern) async {
                  final isValid = await SecurityService().verify(pattern);
                  if (isValid) {
                    if (mounted) {
                      Navigator.pop(context);
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OwnerHomeScreen()));
                    }
                  } else {
                    setModalState(() => isError = true);
                    Future.delayed(const Duration(seconds: 1), () {
                      if (mounted) setModalState(() => isError = false);
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
                  ),
                  if (isBioEnabled)
                    IconButton(
                      icon: const Icon(Icons.fingerprint, color: Colors.white, size: 28),
                      onPressed: () async {
                        final authenticated = await BiometricService().authenticate();
                        if (authenticated && mounted) {
                          Navigator.pop(context);
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OwnerHomeScreen()));
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthDialogFrame({required Widget child}) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppTheme.accentForest,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 15, spreadRadius: 5)],
        ),
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.accentForest, AppTheme.charcoalBlack],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
            children: [
              const Spacer(),
              GestureDetector(
                onTap: () {
                  if (_isStaffDevice && !_showOwnerButton) {
                    _shopIconTapCount++;
                    if (_shopIconTapCount >= 7) {
                      setState(() {
                        _showOwnerButton = true;
                        _shopIconTapCount = 0;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Owner access enabled'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 100,
                    width: 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'D&H MOBILES',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryIvory,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'Premium Mobile Shop System',
                style: TextStyle(color: AppTheme.primaryIvory.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    if (_showOwnerButton) ...[
                      ElevatedButton(
                        onPressed: _showOwnerAuthDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryIvory,
                          foregroundColor: AppTheme.accentForest,
                          minimumSize: const Size(double.infinity, 56),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.admin_panel_settings),
                            SizedBox(width: 12),
                            Text('OWNER ACCESS'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    OutlinedButton(
                      onPressed: () => _showShopSelectionSheet(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryIvory,
                        side: const BorderSide(color: AppTheme.primaryIvory),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline),
                          SizedBox(width: 12),
                          Text('STAFF ENTRY'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Developed by - RR  software solution',
                style: TextStyle(
                  color: AppTheme.primaryIvory.withValues(alpha: 0.5),
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }

  void _showShopSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 500),
      builder: (context) => const _StaffLoginSheet(),
    );
  }
}

class _StaffLoginSheet extends StatefulWidget {
  const _StaffLoginSheet({super.key});

  @override
  State<_StaffLoginSheet> createState() => _StaffLoginSheetState();
}

class _StaffLoginSheetState extends State<_StaffLoginSheet> {
  int _step = 0; // 0: Select Shop, 1: Loading, 2: Select Employee
  String? _selectedShopId;
  List<dynamic> _employees = [];
  String? _errorMessage;

  void _selectShop(String shopId) async {
    setState(() {
      _selectedShopId = shopId;
      _step = 1; // Loading
      _errorMessage = null;
    });

    try {
      final list = await DatabaseService().getEmployees(shopId).first;
      if (list.isEmpty) {
        setState(() {
          _errorMessage = 'No employees found. Please add one from Owner Dashboard.';
          _step = 0;
        });
      } else {
        setState(() {
          _employees = list;
          _step = 2; // Show employees
        });
      }
    } catch (e, stackTrace) {
      debugPrint('ERROR LOADING EMPLOYEES: $e');
      debugPrint(stackTrace.toString());
      setState(() {
        _errorMessage = 'Failed to load employees: $e';
        _step = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Container(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.primaryIvory,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.15),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              ),
            );
          },
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Column(
        key: const ValueKey('error'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: AppTheme.charcoalBlack, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => setState(() => _errorMessage = null),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentForest, foregroundColor: Colors.white),
            child: const Text('OK'),
          ),
          const SizedBox(height: 10),
        ],
      );
    }

    if (_step == 0) {
      return Column(
        key: const ValueKey('select_shop'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('SELECT SHOP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentForest, letterSpacing: 1.5)),
          const SizedBox(height: 24),
          _buildShopCard('Shop 1', Icons.store_outlined),
          const SizedBox(height: 12),
          _buildShopCard('Shop 2', Icons.storefront_outlined),
          const SizedBox(height: 16),
        ],
      );
    } else if (_step == 1) {
      return const Column(
        key: const ValueKey('loading'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 32),
          CircularProgressIndicator(color: AppTheme.accentForest),
          SizedBox(height: 16),
          Text('Loading employees...', style: TextStyle(color: AppTheme.accentForest, fontWeight: FontWeight.w600)),
          SizedBox(height: 32),
        ],
      );
    } else {
      return Column(
        key: const ValueKey('select_employee'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.accentForest),
                onPressed: () => setState(() => _step = 0),
              ),
              Expanded(
                child: Text(
                  'Select Employee - ${ShopHelper.getDisplayName(_selectedShopId!)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accentForest),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48), // balance back icon space
            ],
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _employees.length,
              itemBuilder: (context, index) {
                final emp = _employees[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.accentForest,
                      foregroundColor: Colors.white,
                      child: Text(emp.name.substring(0, 1).toUpperCase()),
                    ),
                    title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.charcoalBlack)),
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('is_staff_device', true);
                      if (mounted) {
                        Navigator.pop(context); // Close bottom sheet
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => EmployeeHomeScreen(
                              shopId: _selectedShopId!,
                              employeeName: emp.name,
                            ),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.05, 0.05),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            transitionDuration: const Duration(milliseconds: 350),
                          ),
                        );
                      }
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: AppTheme.accentForest.withValues(alpha: 0.05),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      );
    }
  }

  Widget _buildShopCard(String name, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.accentForest),
      title: Text(ShopHelper.getDisplayName(name), style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.charcoalBlack)),
      onTap: () => _selectShop(name),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: AppTheme.accentForest.withValues(alpha: 0.05),
    );
  }
}
