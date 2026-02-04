import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/drawermanage.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/models/restaurant/db/staffModel_310.dart';

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
  TextEditingController roleController = TextEditingController();
  TextEditingController mobileController = TextEditingController();
  TextEditingController mailController = TextEditingController();
  TextEditingController pinNoController = TextEditingController();
  TextEditingController searchController = TextEditingController();

  String selectedrole = 'Select Role';
  String searchQuery = '';
  final _formKey = GlobalKey<FormState>();

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

  Future<void> _addStaff() async {
    final newstaff = StaffModel(
      id: Uuid().v4().toString(),
      userName: userNameController.text.trim(),
      firstName: firstNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      isCashier: selectedrole,
      mobileNo: mobileController.text.trim(),
      emailId: mailController.text.trim(),
      pinNo: pinNoController.text.trim(),
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
    roleController.clear();
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
                TextField(
                  controller: searchController,
                  onChanged: _searchStaff,
                  decoration: InputDecoration(
                    hintText: 'Search staff...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: isTablet ? 15 : 14,
                      color: Colors.grey.shade500,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.primary,
                      size: isTablet ? 24 : 22,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isTablet ? 16 : 12,
                    ),
                  ),
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: EdgeInsets.all(isTablet ? 24 : 16),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Container(
                    padding: EdgeInsets.all(isTablet ? 24 : 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.person_add_rounded,
                                size: isTablet ? 28 : 24,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Add New Staff",
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 20 : 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 32, color: Colors.grey.shade200),
                        CommonTextForm(
                          obsecureText: false,
                          labelText: 'Username',
                          LabelColor: AppColors.primary,
                          controller: userNameController,
                          BorderColor: AppColors.primary,
                          borderc: 12,
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CommonTextForm(
                                obsecureText: false,
                                labelText: 'First Name',
                                LabelColor: AppColors.primary,
                                controller: firstNameController,
                                BorderColor: AppColors.primary,
                                borderc: 12,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: CommonTextForm(
                                obsecureText: false,
                                labelText: 'Last Name',
                                LabelColor: AppColors.primary,
                                controller: lastNameController,
                                BorderColor: AppColors.primary,
                                borderc: 12,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: AppColors.primary),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: selectedrole,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              hintText: 'Select Role',
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 15 : 14,
                              color: Colors.black87,
                            ),
                            items: [
                              'Select Role',
                              'Cashier',
                              'Waiter',
                              'Manager',
                              'Kitchen Staff'
                            ].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedrole = newValue ?? 'Select Role';
                              });
                            },
                            validator: (value) {
                              if (value == 'Select Role') {
                                return 'Please select a role';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(height: 16),
                        CommonTextForm(
                          obsecureText: false,
                          labelText: 'Mobile Number',
                          LabelColor: AppColors.primary,
                          controller: mobileController,
                          BorderColor: AppColors.primary,
                          borderc: 12,
                        ),
                        SizedBox(height: 16),
                        CommonTextForm(
                          obsecureText: false,
                          labelText: 'Email Address',
                          LabelColor: AppColors.primary,
                          controller: mailController,
                          BorderColor: AppColors.primary,
                          borderc: 12,
                        ),
                        SizedBox(height: 16),
                        CommonTextForm(
                          obsecureText: true,
                          labelText: 'PIN Number',
                          LabelColor: AppColors.primary,
                          controller: pinNoController,
                          BorderColor: AppColors.primary,
                          borderc: 12,
                        ),
                        SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTablet ? 24 : 20,
                                  vertical: isTablet ? 14 : 12,
                                ),
                              ),
                              child: Text(
                                "Cancel",
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 15 : 14,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  if (selectedrole != 'Select Role') {
                                    _addStaff();
                                    Navigator.pop(context);
                                    NotificationService.instance.showSuccess(
                                      'Staff added successfully',
                                    );
                                  } else {
                                    NotificationService.instance.showInfo(
                                      'Please select a role',
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTablet ? 28 : 24,
                                  vertical: isTablet ? 14 : 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                "Add Staff",
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 15 : 14,
                                  fontWeight: FontWeight.w600,
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
    TextEditingController editPinController =
        TextEditingController(text: staff.pinNo);
    String editSelectedRole = staff.isCashier;
    bool isActive = staff.isActive ?? true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: EdgeInsets.all(isTablet ? 24 : 16),
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.all(isTablet ? 24 : 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.edit_rounded,
                              size: isTablet ? 28 : 24,
                              color: Colors.orange,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Edit Staff',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 20 : 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 32, color: Colors.grey.shade200),
                      CommonTextForm(
                        obsecureText: false,
                        labelText: 'Username',
                        LabelColor: Colors.orange,
                        controller: editUserNameController,
                        BorderColor: Colors.orange,
                        borderc: 12,
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: CommonTextForm(
                              obsecureText: false,
                              labelText: 'First Name',
                              LabelColor: Colors.orange,
                              controller: editFirstNameController,
                              BorderColor: Colors.orange,
                              borderc: 12,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: CommonTextForm(
                              obsecureText: false,
                              labelText: 'Last Name',
                              LabelColor: Colors.orange,
                              controller: editLastNameController,
                              BorderColor: Colors.orange,
                              borderc: 12,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.orange),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: ['Cashier', 'Waiter', 'Manager', 'Kitchen Staff']
                                  .contains(editSelectedRole)
                              ? editSelectedRole
                              : 'Cashier',
                          isExpanded: true,
                          underline: SizedBox(),
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 15 : 14,
                            color: Colors.black87,
                          ),
                          items: ['Cashier', 'Waiter', 'Manager', 'Kitchen Staff']
                              .map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              editSelectedRole = newValue ?? 'Cashier';
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      CommonTextForm(
                        obsecureText: false,
                        labelText: 'Mobile Number',
                        LabelColor: Colors.orange,
                        controller: editMobileController,
                        BorderColor: Colors.orange,
                        borderc: 12,
                      ),
                      SizedBox(height: 16),
                      CommonTextForm(
                        obsecureText: false,
                        labelText: 'Email Address',
                        LabelColor: Colors.orange,
                        controller: editEmailController,
                        BorderColor: Colors.orange,
                        borderc: 12,
                      ),
                      SizedBox(height: 16),
                      CommonTextForm(
                        obsecureText: true,
                        labelText: 'PIN Number',
                        LabelColor: Colors.orange,
                        controller: editPinController,
                        BorderColor: Colors.orange,
                        borderc: 12,
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Account Status:',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 15 : 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  isActive ? 'Active' : 'Disabled',
                                  style: GoogleFonts.poppins(
                                    color: isActive ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isTablet ? 14 : 13,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Switch(
                                  value: isActive,
                                  activeColor: AppColors.primary,
                                  onChanged: (value) {
                                    setState(() {
                                      isActive = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 24 : 20,
                                vertical: isTablet ? 14 : 12,
                              ),
                            ),
                            child: Text(
                              "Cancel",
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 15 : 14,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              final updatedStaff = staff.copyWith(
                                userName: editUserNameController.text.trim(),
                                firstName: editFirstNameController.text.trim(),
                                lastName: editLastNameController.text.trim(),
                                isCashier: editSelectedRole,
                                mobileNo: editMobileController.text.trim(),
                                emailId: editEmailController.text.trim(),
                                pinNo: editPinController.text.trim(),
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 28 : 24,
                                vertical: isTablet ? 14 : 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              "Update",
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 15 : 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
