import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/shop_helper.dart';
import 'package:uuid/uuid.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedShop = 'Shop 1';
  String? _editingUid;

  void _clearForm() {
    setState(() {
      _editingUid = null;
      _emailController.clear();
      _passwordController.clear();
      _nameController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Employees')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(_editingUid == null ? 'Add New Employee' : 'Edit Employee', 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedShop,
                      decoration: const InputDecoration(labelText: 'Assign to Shop', border: OutlineInputBorder()),
                      items: [
                        DropdownMenuItem(value: 'Shop 1', child: Text(ShopHelper.getDisplayName('Shop 1'), style: const TextStyle(color: AppTheme.charcoalBlack))),
                        DropdownMenuItem(value: 'Shop 2', child: Text(ShopHelper.getDisplayName('Shop 2'), style: const TextStyle(color: AppTheme.charcoalBlack))),
                      ],
                      onChanged: (val) => setState(() => _selectedShop = val!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_editingUid != null)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: OutlinedButton(
                                onPressed: _clearForm,
                                child: const Text('Cancel'),
                              ),
                            ),
                          ),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _addEmployee,
                            child: Text(_editingUid == null ? 'Add Employee' : 'Update Employee'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Current Staff', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            StreamBuilder<List<UserModel>>(
              stream: DatabaseService().getEmployees(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final employees = snapshot.data ?? [];
                
                if (employees.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No employees found')));

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final emp = employees[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.accentForest,
                          child: Text(emp.name[0], style: const TextStyle(color: AppTheme.primaryIvory)),
                        ),
                        title: Text(emp.name),
                        subtitle: Text('${emp.email} | ${ShopHelper.getDisplayName(emp.shopId ?? "")}', style: const TextStyle(color: AppTheme.graphiteGray)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                setState(() {
                                  _editingUid = emp.uid;
                                  _nameController.text = emp.name;
                                  _emailController.text = emp.email;
                                  // Password cannot be pre-filled safely
                                  _selectedShop = emp.shopId ?? 'Shop 1';
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(emp),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(UserModel emp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to remove ${emp.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              // Delete operation would go here. For now we just implement the UI
              await DatabaseService().deleteUser(emp.uid);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addEmployee() async {
    final userModel = UserModel(
      uid: _editingUid ?? const Uuid().v4(),
      email: _emailController.text.trim(),
      name: _nameController.text.trim(),
      role: 'employee',
      shopId: _selectedShop,
    );

    await DatabaseService().updateUser(userModel);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editingUid == null ? 'Employee added' : 'Employee updated')),
      );
      _clearForm();
    }
  }
}
