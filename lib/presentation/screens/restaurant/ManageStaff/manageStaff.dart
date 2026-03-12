import
'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/drawermanage.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/models/restaurant/db/staffModel_310.dart';
import '../../../../util/restaurant/restaurant_auth_helper.dart';

class manageStaff extends StatefulWidget {
  const manageStaff({super.key});

  @override
  State<manageStaff> createState() => _manageStaffState();
}

class _manageStaffState extends State<manageStaff> {
  @override
  void initState() {
    super.initState();
    staffStore.loadStaff();
  }

  TextEditingController userNameController = TextEditingController();
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController mobileController = TextEditingController();
  TextEditingController mailController = TextEditingController();
  TextEditingController pinNoController = TextEditingController();
  TextEditingController searchController = TextEditingController();

  String selectedrole = 'Select Role';
  String searchQuery = '';
  final _formKey = GlobalKey<FormState>();
  final _editFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    userNameController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    mobileController.dispose();
    mailController.dispose();
    pinNoController.dispose();
    searchController.dispose();
    super.dispose();
  }

  // ── Role chip metadata ───────────────────────────────────────────────────
  static const _roleLabels = ['Manager', 'Cashier', 'Waiter'];
  static const _roleIcons = {
    'Manager': Icons.manage_accounts_rounded,
    'Cashier': Icons.point_of_sale_rounded,
    'Waiter': Icons.restaurant_rounded,
  };
  static const _roleColors = {
    'Manager': Color(0xFF7C3AED),
    'Cashier': Color(0xFF059669),
    'Waiter': Color(0xFFDB2777),
  };

  Widget _buildRoleSelector(String current, void Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Role *'),
        Row(
          children: _roleLabels.map((role) {
            final isSelected = current == role;
            final color = _roleColors[role]!;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: role != _roleLabels.last ? 8 : 0),
                child: GestureDetector(
                  onTap: () => onSelect(role),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.1) : AppColors.surfaceLight,
                      border: Border.all(
                        color: isSelected ? color : AppColors.divider,
                        width: isSelected ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_roleIcons[role]!, size: 20,
                            color: isSelected ? color : AppColors.textSecondary),
                        const SizedBox(height: 4),
                        Text(role,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? color : AppColors.textSecondary,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _addStaff() async {
    final newstaff = StaffModel(
      id: Uuid().v4().toString(),
      userName: userNameController.text.trim(),
      firstName: firstNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      isCashier: selectedrole,
      mobileNo: mobileController.text.trim(),
      emailId: mailController.text.trim(),
      pinNo: RestaurantAuthHelper.hashPassword(pinNoController.text.trim()),
      isActive: true,
      createdAt: DateTime.now(),
    );
    await staffStore.addStaff(newstaff);
    _clear();
  }

  void _searchStaff(String query) {
    setState(() {
      searchQuery = query;
    });
  }

  List<StaffModel> _getFilteredStaff() {
    final allStaff = staffStore.staff.toList();
    if (searchQuery.isEmpty) {
      return allStaff;
    }
    final searchLower = searchQuery.toLowerCase();
    return allStaff.where((staff) {
      return staff.userName.toLowerCase().contains(searchLower) ||
          staff.firstName.toLowerCase().contains(searchLower) ||
          staff.lastName.toLowerCase().contains(searchLower) ||
          staff.emailId.toLowerCase().contains(searchLower) ||
          staff.mobileNo.contains(searchLower);
    }).toList();
  }

  void _clear() {
    userNameController.clear();
    firstNameController.clear();
    lastNameController.clear();
    mobileController.clear();
    mailController.clear();
    pinNoController.clear();
    selectedrole = 'Select Role';
  }

  Future<void> _updateStaff(StaffModel staff) async {
    await staffStore.updateStaff(staff);
  }

  void _deleteStaff(String id) async {
    await staffStore.deleteStaff(id);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          'Staff Management',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: 8,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    size: isTablet ? 22 : 20,
                    color: AppColors.primary,
                  ),
                ),
                if (isTablet) ...[
                  SizedBox(width: 10),
                  Text(
                    'Admin',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      drawer: DrawerManage(
        isDelete: true,
        issync: true,
        islogout: true,
      ),
      body: Column(
        children: [
          // Search & Add Button Section
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Column(
              children: [
                // Search Bar
                AppTextField(
                  controller: searchController,
                  hint: 'Search staff…',
                  icon: Icons.search_rounded,
                  onChanged: _searchStaff,
                ),
                SizedBox(height: isTablet ? 16 : 12),
                // Add Staff Button
                SizedBox(
                  width: double.infinity,
                  height: isTablet ? 50 : 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      selectedrole = 'Select Role';
                      _clear();
                      _showAddStaffDialog(context, isTablet);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(Icons.person_add_rounded, size: isTablet ? 22 : 20),
                    label: Text(
                      'Add New Staff',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Staff List
          Expanded(
            child: Observer(
              builder: (_) {
                final filteredStaff = _getFilteredStaff();

                if (staffStore.isLoading) {
                  return Center(child: CircularProgressIndicator());
                }

                if (filteredStaff.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: isTablet ? 80 : 64,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          searchQuery.isEmpty
                              ? 'No staff members yet'
                              : 'No staff found',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 18 : 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (searchQuery.isEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            'Add your first staff member',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 14 : 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(isTablet ? 20 : 16),
                  itemCount: filteredStaff.length,
                  itemBuilder: (context, index) {
                    final staff = filteredStaff[index];
                    return _buildStaffCard(context, staff, isTablet);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(BuildContext context, StaffModel staff, bool isTablet) {
    return Padding(
      padding: EdgeInsets.only(bottom: isTablet ? 12 : 10),
      child: Slidable(
        key: ValueKey(staff.id),
        endActionPane: ActionPane(
          motion: ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (context) async {
                final updatedStaff = staff.copyWith(
                  isActive: !(staff.isActive ?? true),
                );
                await _updateStaff(updatedStaff);
                if (context.mounted) {
                  NotificationService.instance.showInfo(
                    (updatedStaff.isActive ?? true)
                        ? 'Staff Enabled'
                        : 'Staff Disabled',
                  );
                }
              },
              backgroundColor: (staff.isActive ?? true) ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
              icon: (staff.isActive ?? true) ? Icons.block : Icons.check_circle,
              label: (staff.isActive ?? true) ? 'Disable' : 'Enable',
              borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
            ),
            SlidableAction(
              onPressed: (context) {
                _showDeleteConfirmation(context, staff.id);
              },
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete_rounded,
              label: 'Delete',
              borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: (staff.isActive ?? true) == false
                ? Colors.grey.shade100
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(isTablet ? 16 : 14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: isTablet ? 56 : 50,
                height: isTablet ? 56 : 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  size: isTablet ? 28 : 24,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              // Staff Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.userName,
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "${staff.firstName} ${staff.lastName}",
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 14 : 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            staff.isCashier,
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 12 : 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if ((staff.isActive ?? true) == false) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'DISABLED',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 11 : 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Action Buttons
              Row(
                children: [
                  IconButton(
                    onPressed: () => _showStaffDetails(context, staff, isTablet),
                    icon: Icon(Icons.visibility_rounded),
                    color: Colors.blue,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showEditStaffDialog(context, staff, isTablet),
                    icon: Icon(Icons.edit_rounded),
                    color: Colors.orange,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context, bool isTablet) {
    bool pinVisible = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 40 : 16, vertical: 24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_add_rounded,
                            size: 22, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Add New Staff',
                            style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 20),
                        color: Colors.grey.shade500,
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.shade100),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    Divider(color: Colors.grey.shade100),
                    const SizedBox(height: 16),

                    // ── First + Last Name ────────────────────────────
                    Row(children: [
                      Expanded(child: AppTextField(
                        controller: firstNameController,
                        label: 'First Name',
                        hint: 'John',
                        icon: Icons.person_outline,
                        required: true,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: AppTextField(
                        controller: lastNameController,
                        label: 'Last Name',
                        hint: 'Doe',
                        icon: Icons.person_outline,
                        required: true,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      )),
                    ]),
                    const SizedBox(height: 14),

                    // ── Username ─────────────────────────────────────
                    AppTextField(
                      controller: userNameController,
                      label: 'Username',
                      hint: 'e.g. john_cashier',
                      icon: Icons.alternate_email_rounded,
                      required: true,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Username is required' : null,
                    ),
                    const SizedBox(height: 14),

                    // ── Role ─────────────────────────────────────────
                    _buildRoleSelector(selectedrole,
                        (role) => setS(() => selectedrole = role)),
                    const SizedBox(height: 14),

                    // ── Mobile + Email ───────────────────────────────
                    Row(children: [
                      Expanded(child: AppTextField(
                        controller: mobileController,
                        label: 'Mobile',
                        hint: '9876543210',
                        icon: Icons.phone_outlined,
                        required: true,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (v.trim().length != 10) return 'Must be 10 digits';
                          return null;
                        },
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: AppTextField(
                        controller: mailController,
                        label: 'Email',
                        hint: 'john@email.com',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(v.trim()))
                              return 'Invalid email';
                          }
                          return null;
                        },
                      )),
                    ]),
                    const SizedBox(height: 14),

                    // ── PIN ──────────────────────────────────────────
                    AppTextField(
                      controller: pinNoController,
                      label: 'PIN (4–6 digits)',
                      hint: '••••',
                      icon: Icons.lock_outline_rounded,
                      required: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: !pinVisible,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      suffixIcon: IconButton(
                        icon: Icon(
                          pinVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18, color: Colors.grey.shade500),
                        onPressed: () => setS(() => pinVisible = !pinVisible),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'PIN is required';
                        if (!RegExp(r'^\d{4,6}$').hasMatch(v.trim())) return '4–6 digits only';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Buttons ──────────────────────────────────────
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text('Cancel',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.person_add_rounded, size: 18),
                          label: Text('Add Staff',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              if (selectedrole == 'Select Role') {
                                NotificationService.instance.showInfo('Please select a role');
                                return;
                              }
                              final username = userNameController.text.trim().toLowerCase();
                              if (staffStore.staff.any((s) => s.userName.toLowerCase() == username)) {
                                NotificationService.instance.showError('Username already exists.');
                                return;
                              }
                              _addStaff();
                              Navigator.pop(ctx);
                              NotificationService.instance.showSuccess('Staff added successfully');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditStaffDialog(BuildContext context, StaffModel staff, bool isTablet) {
    TextEditingController editUserNameController =
        TextEditingController(text: staff.userName);
    TextEditingController editFirstNameController =
        TextEditingController(text: staff.firstName);
    TextEditingController editLastNameController =
        TextEditingController(text: staff.lastName);
    TextEditingController editMobileController =
        TextEditingController(text: staff.mobileNo);
    TextEditingController editEmailController =
        TextEditingController(text: staff.emailId);
    // FIX: Never pre-fill with the stored hash — re-hash only if user types a new PIN.
    TextEditingController editPinController = TextEditingController();
    String editSelectedRole = staff.isCashier;
    bool isActive = staff.isActive ?? true;
    bool editPinVisible = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 40 : 20,
                vertical: 24,
              ),
              child: Form(
                key: _editFormKey,
                child: SingleChildScrollView(
                child: Container(
                  width: isTablet ? 520 : double.infinity,
                  padding: EdgeInsets.all(isTablet ? 28 : 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──────────────────────────────────────────
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.edit_rounded,
                              size: isTablet ? 26 : 22,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Staff',
                                  style: GoogleFonts.poppins(
                                    fontSize: isTablet ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Update staff member details',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close, color: Colors.grey.shade500),
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      Divider(height: 28, color: Colors.grey.shade200),

                      // ── First / Last Name ────────────────────────────────
                      Row(
                        children: [
                          Expanded(child: AppTextField(
                            controller: editFirstNameController,
                            label: 'First Name',
                            hint: 'John',
                            icon: Icons.person_outline,
                            required: true,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: AppTextField(
                            controller: editLastNameController,
                            label: 'Last Name',
                            hint: 'Doe',
                            icon: Icons.person_outline,
                            required: true,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          )),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Username ─────────────────────────────────────────
                      AppTextField(
                        controller: editUserNameController,
                        label: 'Username',
                        hint: 'e.g. john_cashier',
                        icon: Icons.alternate_email_rounded,
                        required: true,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Username is required' : null,
                      ),
                      const SizedBox(height: 14),

                      // ── Role ─────────────────────────────────────────────
                      _buildRoleSelector(
                        ['Manager', 'Cashier', 'Waiter'].contains(editSelectedRole)
                            ? editSelectedRole
                            : 'Cashier',
                        (role) => setState(() => editSelectedRole = role),
                      ),
                      const SizedBox(height: 14),

                      // ── Mobile / Email ───────────────────────────────────
                      Row(
                        children: [
                          Expanded(child: AppTextField(
                            controller: editMobileController,
                            label: 'Mobile',
                            hint: '9876543210',
                            icon: Icons.phone_outlined,
                            required: true,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (v.trim().length != 10) return 'Must be 10 digits';
                              return null;
                            },
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: AppTextField(
                            controller: editEmailController,
                            label: 'Email',
                            hint: 'john@email.com',
                            icon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v != null && v.trim().isNotEmpty) {
                                if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(v.trim()))
                                  return 'Invalid email';
                              }
                              return null;
                            },
                          )),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── New PIN ──────────────────────────────────────────
                      AppTextField(
                        controller: editPinController,
                        label: 'New PIN (leave blank to keep current)',
                        hint: '4–6 digits',
                        icon: Icons.lock_outline_rounded,
                        obscureText: !editPinVisible,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        suffixIcon: IconButton(
                          icon: Icon(
                            editPinVisible ? Icons.visibility_off : Icons.visibility,
                            size: 20, color: Colors.grey.shade500,
                          ),
                          onPressed: () => setState(() => editPinVisible = !editPinVisible),
                        ),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            if (!RegExp(r'^\d{4,6}$').hasMatch(v.trim())) return 'PIN must be 4–6 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── Account Status toggle ────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Account Status',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  isActive ? 'Active' : 'Disabled',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isActive ? Colors.green.shade700 : Colors.red.shade400,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch(
                                  value: isActive,
                                  activeColor: AppColors.primary,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (v) => setState(() => isActive = v),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Action buttons ───────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (!_editFormKey.currentState!.validate()) return;
                                // FIX: Duplicate username check (exclude this staff's own record).
                                final newUsername = editUserNameController.text.trim().toLowerCase();
                                final isDuplicate = staffStore.staff.any(
                                  (s) => s.id != staff.id && s.userName.toLowerCase() == newUsername,
                                );
                                if (isDuplicate) {
                                  NotificationService.instance.showError('Username already exists.');
                                  return;
                                }
                                final newPin = editPinController.text.trim();
                                final updatedStaff = staff.copyWith(
                                  userName: editUserNameController.text.trim(),
                                  firstName: editFirstNameController.text.trim(),
                                  lastName: editLastNameController.text.trim(),
                                  isCashier: editSelectedRole,
                                  mobileNo: editMobileController.text.trim(),
                                  emailId: editEmailController.text.trim(),
                                  // Only re-hash if user typed a new PIN; keep existing hash otherwise.
                                  pinNo: newPin.isNotEmpty
                                      ? RestaurantAuthHelper.hashPassword(newPin)
                                      : staff.pinNo,
                                  isActive: isActive,
                                );
                                await _updateStaff(updatedStaff);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  NotificationService.instance.showSuccess(
                                    'Staff updated successfully',
                                  );
                                }
                              },
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: Text(
                                'Update Staff',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            );
          },
        );
      },
    );
  }

  void _showStaffDetails(BuildContext context, StaffModel staff, bool isTablet) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, color: AppColors.primary, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Staff Details",
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Name', "${staff.firstName} ${staff.lastName}", isTablet),
              _buildDetailRow('Username', staff.userName, isTablet),
              _buildDetailRow('Role', staff.isCashier, isTablet),
              _buildDetailRow('Mobile', staff.mobileNo, isTablet),
              _buildDetailRow('Email', staff.emailId, isTablet),
              _buildDetailRow('Status', (staff.isActive ?? true) ? 'Active' : 'Disabled', isTablet),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Close',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 15 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, bool isTablet) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 14 : 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 14 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared field helpers ─────────────────────────────────────────────────

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
      );

  void _showDeleteConfirmation(BuildContext context, String staffId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_rounded, color: Colors.red, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Staff?',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this staff member? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteStaff(staffId);
              Navigator.pop(dialogContext);
              NotificationService.instance.showSuccess('Staff deleted successfully');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
