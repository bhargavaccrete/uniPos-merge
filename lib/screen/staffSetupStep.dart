import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/stores/setup_wizard_store.dart';
import 'package:unipos/core/config/app_config.dart';
import 'package:unipos/data/models/retail/hive_model/staff_model_222.dart';
import 'package:unipos/data/models/restaurant/db/staffModel_310.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../util/color.dart';

/// Staff Setup Step - Business Mode Aware
/// Shows retail-specific fields for retail POS
/// Shows restaurant-specific fields for restaurant POS
class StaffSetupStep extends StatefulWidget {
  final SetupWizardStore store;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const StaffSetupStep({
    Key? key,
    required this.store,
    required this.onNext,
    required this.onPrevious,
  }) : super(key: key);

  @override
  State<StaffSetupStep> createState() => _StaffSetupStepState();
}

class _StaffSetupStepState extends State<StaffSetupStep> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  final _uuid = const Uuid();

  String _selectedRole = 'Cashier';
  final List<String> _retailRoles = ['Manager', 'Cashier', 'Sales', 'Inventory'];
  final List<String> _restaurantRoles = ['Manager', 'Waiter', 'Cashier', 'Chef'];

  // Retail-specific permissions
  bool _canGiveDiscounts = false;
  bool _canAccessReports = false;
  bool _canManageInventory = false;

  List<dynamic> _staffMembers = []; // Can hold both retail and restaurant staff

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _addStaff() {
    if (_firstNameController.text.isEmpty || _pinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('First name and PIN are required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      if (AppConfig.isRetail) {
        // Create retail staff member
        final retailStaff = RetailStaffModel(
          id: _uuid.v4(),
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          email: _emailController.text.isEmpty ? null : _emailController.text,
          phone: _phoneController.text.isEmpty ? null : _phoneController.text,
          username: _usernameController.text.isEmpty
              ? _firstNameController.text.toLowerCase()
              : _usernameController.text,
          pin: _pinController.text,
          role: _selectedRole,
          canProcessSales: true,
          canProcessReturns: _selectedRole == 'Manager',
          canGiveDiscounts: _canGiveDiscounts,
          maxDiscountPercent: _canGiveDiscounts ? 20.0 : 0.0,
          canAccessReports: _canAccessReports,
          canManageInventory: _canManageInventory,
          canManageStaff: _selectedRole == 'Manager',
          canVoidTransactions: _selectedRole == 'Manager',
          canOpenCashDrawer: true,
          createdAt: DateTime.now(),
        );
        _staffMembers.add(retailStaff);
      } else {
        // Create restaurant staff member
        // Set isCashier based on role (Cashier and Manager can handle cash)
        final isCashier = _selectedRole == 'Cashier' || _selectedRole == 'Manager';

        final restaurantStaff = StaffModel(
          id: _uuid.v4(),
          userName: _usernameController.text.isEmpty
              ? _firstNameController.text.toLowerCase()
              : _usernameController.text,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          isCashier: isCashier ? 'true' : 'false',
          mobileNo: _phoneController.text,
          emailId: _emailController.text,
          pinNo: _pinController.text,
          createdAt: DateTime.now(),
        );
        _staffMembers.add(restaurantStaff);
      }

      // Clear form
      _firstNameController.clear();
      _lastNameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _usernameController.clear();
      _pinController.clear();
      _selectedRole = 'Cashier';
      _canGiveDiscounts = false;
      _canAccessReports = false;
      _canManageInventory = false;
    });
  }

  void _deleteStaff(int index) {
    setState(() {
      _staffMembers.removeAt(index);
    });
  }

  Future<void> _saveStaffToDatabase() async {
    try {
      if (AppConfig.isRetail) {
        // Box is already opened during app startup in HiveInit
        final box = Hive.box<RetailStaffModel>('retail_staff');
        for (var staff in _staffMembers) {
          if (staff is RetailStaffModel) {
            await box.add(staff);
            print('✅ Saved retail staff: ${staff.fullName}');
          }
        }
      } else {
        // Box is already opened during app startup in HiveInit
        final box = Hive.box<StaffModel>('staffBox');
        for (var staff in _staffMembers) {
          if (staff is StaffModel) {
            await box.add(staff);
            print('✅ Saved restaurant staff: ${staff.firstName} ${staff.lastName}');
          }
        }
      }
    } catch (e) {
      print('❌ Error saving staff: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save staff: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRetail = AppConfig.isRetail;
    final roles = isRetail ? _retailRoles : _restaurantRoles;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Staff Setup',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.darkNeutral,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Add staff members who will use the ${isRetail ? "POS" : "restaurant"} system',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 30),

          // Add Staff Form
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_add, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Add Staff Member',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkNeutral,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Basic Info Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'First Name *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Contact Info Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email (Optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone (Optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Login Info Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username (Optional)',
                          hintText: 'Auto-generated if empty',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: 'PIN Code * (4-6 digits)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          counterText: '',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Role Selection
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                        ),
                        items: roles.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(role),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                            // Auto-set permissions for Manager role in retail
                            if (value == 'Manager' && isRetail) {
                              _canGiveDiscounts = true;
                              _canAccessReports = true;
                              _canManageInventory = true;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(), // Spacer
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Business-specific fields
                if (isRetail) ...[
                  // Retail Permissions
                  Text(
                    'POS Permissions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Can Give Discounts'),
                    value: _canGiveDiscounts,
                    onChanged: (value) {
                      setState(() => _canGiveDiscounts = value!);
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Can Access Reports'),
                    value: _canAccessReports,
                    onChanged: (value) {
                      setState(() => _canAccessReports = value!);
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Can Manage Inventory'),
                    value: _canManageInventory,
                    onChanged: (value) {
                      setState(() => _canManageInventory = value!);
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],

                const SizedBox(height: 12),

                // Add Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addStaff,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Staff Member'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Staff List
          if (_staffMembers.isNotEmpty) ...[
            Text(
              'Added Staff (${_staffMembers.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.darkNeutral,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_staffMembers.length, (index) {
              final staff = _staffMembers[index];
              String name, role, details;

              if (staff is RetailStaffModel) {
                name = staff.fullName;
                role = staff.role;
                details = 'PIN: ${staff.pin}';
              } else if (staff is StaffModel) {
                name = '${staff.firstName} ${staff.lastName}';
                role = staff.isCashier == 'true' ? 'Cashier' : 'Staff';
                details = 'PIN: ${staff.pinNo}';
              } else {
                name = 'Unknown';
                role = '';
                details = '';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Icon(Icons.person, color: AppColors.primary),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          role,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        details,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: AppColors.danger),
                    onPressed: () => _deleteStaff(index),
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 40),

          // Navigation Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onPrevious,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                flex: 2,
                child: Observer(
                  builder: (_) => ElevatedButton(
                    onPressed: widget.store.isLoading
                        ? null
                        : () async {
                            // Save to database
                            await _saveStaffToDatabase();
                            // Continue to next step
                            widget.onNext();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: widget.store.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _staffMembers.isEmpty ? 'Skip (Add Later)' : 'Save & Continue',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}