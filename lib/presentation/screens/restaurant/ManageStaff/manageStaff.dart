import
'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/componets/drawermanage.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/models/restaurant/db/staffModel_310.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../util/restaurant/restaurant_auth_helper.dart';
import '../../../../util/common/app_responsive.dart';

class manageStaff extends StatefulWidget {
  const manageStaff({super.key});

  @override
  State<manageStaff> createState() => _manageStaffState();
}

class _manageStaffState extends State<manageStaff> {
  TextEditingController userNameController = TextEditingController();
  TextEditingController firstNameController = TextEditingController();

  bool _usernameManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    staffStore.loadStaff();
    firstNameController.addListener(_syncUsernameFromFirstName);
  }

  void _syncUsernameFromFirstName() {
    if (_usernameManuallyEdited) return;
    final generated = firstNameController.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    if (userNameController.text != generated) {
      userNameController.value = userNameController.value.copyWith(
        text: generated,
        selection: TextSelection.collapsed(offset: generated.length),
      );
    }
  }
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

  /// PIN-only login means PINs must be globally unique — across all staff AND
  /// the admin. Returns true if [pin] is already taken. [excludeStaffId] skips
  /// the staff being edited.
  Future<bool> _isPinTaken(String pin, {String? excludeStaffId}) async {
    final staffClash = staffStore.staff.any((s) =>
        s.id != excludeStaffId &&
        RestaurantAuthHelper.verifyPassword(pin, s.pinNo));
    if (staffClash) return true;
    // Check the admin PIN too. If nothing is stored yet, the admin is still on
    // the login default ('123456') — so compare against that, otherwise a staff
    // could take the default admin PIN and shadow the admin at login.
    final prefs = await SharedPreferences.getInstance();
    final adminPass = prefs.getString('restaurant_admin_password');
    final adminCollision = adminPass != null
        ? RestaurantAuthHelper.verifyPassword(pin, adminPass)
        : pin == '123456';
    if (adminCollision) return true;
    return false;
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
    _usernameManuallyEdited = false;
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
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Staff Management',
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
                          size: 64,
                          color: AppColors.divider,
                        ),
                        SizedBox(height: 16),
                        Text(
                          searchQuery.isEmpty
                              ? 'No staff members yet'
                              : 'No staff found',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 18 : 16,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (searchQuery.isEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            'Add your first staff member',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 14 : 13,
                              color: AppColors.textSecondary,
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
                ? AppColors.surfaceMedium
                : AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(isTablet ? 14 : 12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: isTablet ? 22 : 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  staff.firstName.isNotEmpty ? staff.firstName[0].toUpperCase() : '?',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.primary),
                ),
              ),
              SizedBox(width: isTablet ? 14 : 10),
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
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "${staff.firstName} ${staff.lastName}",
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 14 : 13,
                        color: AppColors.textSecondary,
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
                                fontWeight: FontWeight.w500,
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
                    color: AppColors.info,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.info.withValues(alpha: 0.1),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showEditStaffDialog(context, staff, isTablet),
                    icon: Icon(Icons.edit_rounded),
                    color: AppColors.primary,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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
        builder: (ctx, setS) => AppDialogShell(
          title: 'Add New Staff',
          accent: AppColors.primary,
          icon: Icons.person_add_rounded,
          body: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  )),
                ]),
                const SizedBox(height: 14),

                // Username field hidden — auto-generated from first name.

                // ── Role ─────────────────────────────────────────
                _buildRoleSelector(selectedrole,
                    (role) => setS(() => selectedrole = role)),
                const SizedBox(height: 14),

                // ── Mobile + Email ───────────────────────────────
                Row(children: [
                  Expanded(child: AppTextField(
                    controller: mobileController,
                    label: 'Mobile (optional)',
                    hint: '9876543210',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty && v.trim().length != 10) {
                        return 'Must be 10 digits';
                      }
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
                  hint: '••••••',
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
                    if (!RegExp(r'^\d{4,6}$').hasMatch(v.trim())) return 'PIN must be 4–6 digits';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            appDialogCancelButton(ctx),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Add Staff',
              onPressed: () async {
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
                  if (await _isPinTaken(pinNoController.text.trim())) {
                    NotificationService.instance.showError(
                        'This PIN is already in use. Choose a different one.');
                    return;
                  }
                  _addStaff();
                  if (ctx.mounted) Navigator.pop(ctx);
                  NotificationService.instance.showSuccess('Staff added successfully');
                }
              },
            ),
          ],
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
            return AppDialogShell(
              title: 'Edit Staff',
              subtitle: 'Update staff member details',
              accent: AppColors.primary,
              icon: Icons.edit_rounded,
              body: Form(
                key: _editFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        )),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Username field hidden — kept as-is, not editable.

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
                          label: 'Mobile (optional)',
                          hint: '9876543210',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty && v.trim().length != 10) {
                              return 'Must be 10 digits';
                            }
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
                      maxLength: 6,
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
                  ],
                ),
              ),
              actions: [
                appDialogCancelButton(context),
                const SizedBox(width: 12),
                appDialogPrimaryButton(
                  label: 'Update Staff',
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
                    if (newPin.isNotEmpty &&
                        await _isPinTaken(newPin, excludeStaffId: staff.id)) {
                      NotificationService.instance.showError(
                          'This PIN is already in use. Choose a different one.');
                      return;
                    }
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
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Dispose the dialog-local controllers when it closes (created fresh
      // on every open) so they don't leak.
      editUserNameController.dispose();
      editFirstNameController.dispose();
      editLastNameController.dispose();
      editMobileController.dispose();
      editEmailController.dispose();
      editPinController.dispose();
    });
  }

  void _showStaffDetails(BuildContext context, StaffModel staff, bool isTablet) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AppDialogShell(
          title: 'Staff Details',
          accent: AppColors.primary,
          icon: Icons.person,
          body: Column(
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
            appDialogPrimaryButton(
              label: 'Close',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, bool isTablet) {
    return Padding(
      padding: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isTablet ? 110 : 80,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 15 : 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 15 : 13,
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

  Future<void> _showDeleteConfirmation(BuildContext context, String staffId) async {
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Delete Staff?',
      message:
          'Are you sure you want to delete this staff member? This action cannot be undone.',
      confirmLabel: 'Delete',
      accent: Colors.red,
      icon: Icons.delete_rounded,
    );
    if (ok) {
      _deleteStaff(staffId);
      NotificationService.instance.showSuccess('Staff deleted successfully');
    }
  }
}
