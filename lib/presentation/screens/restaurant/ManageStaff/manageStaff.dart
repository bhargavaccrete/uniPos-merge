import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_staff.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/drawermanage.dart';
import 'package:uuid/uuid.dart';

import '../../../../data/models/restaurant/db/staffModel_310.dart';

// final int itemCount = 0;
class manageStaff extends StatefulWidget {
  const manageStaff({super.key});

  @override
  State<manageStaff> createState() => _manageStaffState();
}
class _manageStaffState extends State<manageStaff> {
  @override
  void initState() {
    super.initState();
    loadHIveStaff();
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
  List<StaffModel> staffList = [];
  List<StaffModel> filteredStaffList = [];
  final _formKey = GlobalKey<FormState>();

// In _StaffFormDialogState
  @override
  void dispose() {
    userNameController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    mobileController.dispose();
    mailController.dispose();
    pinNoController.dispose();
    super.dispose();
  }
  Future<void>_addStaff()async{
    final newstaff = StaffModel(
        id: Uuid().v4().toString(),
        userName: userNameController.text.trim(),
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        isCashier: selectedrole,
        mobileNo: mobileController.text.trim(),
        emailId: mailController.text.trim(),
        pinNo: pinNoController.text.trim(),
        createdAt: DateTime.now()
    );
    await StaffBox.addStaff(newstaff);
    await loadHIveStaff();
    _clear();
  }

  Future<void>loadHIveStaff()async{
    final staffbox = await StaffBox.getStaffBox();
    final allstaff =  staffbox.values.toList();
    allstaff.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Fix null safety for existing records without isActive field
    for (var staff in allstaff) {
      if (staff.isActive == null) {
        final updatedStaff = staff.copyWith(isActive: true);
        await StaffBox.updateStaff(updatedStaff);
      }
    }

    setState(() {
      staffList = allstaff;
      filteredStaffList = allstaff;
    });
  }

  void _searchStaff(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredStaffList = staffList;
      } else {
        filteredStaffList = staffList.where((staff) {
          final searchLower = query.toLowerCase();
          return staff.userName.toLowerCase().contains(searchLower) ||
              staff.firstName.toLowerCase().contains(searchLower) ||
              staff.lastName.toLowerCase().contains(searchLower) ||
              staff.emailId.toLowerCase().contains(searchLower) ||
              staff.mobileNo.contains(searchLower);
        }).toList();
      }
    });
  }

  void _clear (){
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
    await StaffBox.updateStaff(staff);
    await loadHIveStaff();
  }

  void _deleteStaff(String id )async{
    await StaffBox.deleteStaff(id);
    await loadHIveStaff();
  }



  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 1;
    final height = MediaQuery.of(context).size.height * 1;

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        shadowColor: Colors.black,
        actions: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(Icons.person),
                Text(
                  "Admin",
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
          )
        ],
      ),
      body: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Search Bar
            Container(
              margin: EdgeInsets.only(bottom: 20),
              child: TextField(
                controller: searchController,
                onChanged: _searchStaff,
                decoration: InputDecoration(
                  hintText: 'Search staff by name, email, or phone...',
                  prefixIcon: Icon(Icons.search, color: primarycolor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primarycolor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primarycolor, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    "Staff Management",
                    textScaler: TextScaler.linear(1.2),
                    style: TextStyle(fontSize: 19.0),
                  ),
                ),
                SizedBox(
                  width: 10.0,
                ),
                //button of add staff
                Flexible(
                    child: CommonButton(
                        bordercircular: 5,
                        bordercolor: primarycolor,
                        bgcolor: Colors.white,
                        width: width * 0.3,
                        height: height * 0.06,
                        onTap: () {
                          selectedrole = 'Select Role';
                          _clear();
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return StatefulBuilder(
                                  builder: (context, setState) {
                                    return Dialog(
                                        insetPadding: EdgeInsets.all(16),
                                        child: Form(
                                          key: _formKey,
                                          child: SingleChildScrollView(
                                            child: Container(
                                              padding: EdgeInsets.only(
                                                //for keyboard Navigation
                                                bottom: MediaQuery.of(context)
                                                    .viewInsets
                                                    .bottom,
                                                top: 20,
                                                left: 20,
                                                right: 20,
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.person_add,
                                                    size: 40.0,
                                                    color: Colors.deepOrange,
                                                  ),
                                                  Text("Add New Staff"),
                                                  Divider(
                                                    thickness: 1,
                                                    color: Colors.grey,
                                                  ),
                                                  Padding(padding: EdgeInsets.all(10)),
                                                  CommonTextForm(
                                                    obsecureText: false,
                                                    labelText: 'UserName',
                                                    LabelColor: primarycolor,
                                                    controller: userNameController,
                                                    BorderColor: primarycolor,
                                                    borderc: 5,
                                                  ),
                                                  SizedBox(
                                                    height: 10,
                                                  ),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child:   CommonTextForm(
                                                          obsecureText: false,
                                                          labelText: 'First Name',
                                                          LabelColor: primarycolor,
                                                          controller: firstNameController,
                                                          BorderColor: primarycolor,
                                                          borderc: 5,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 5,
                                                      ),
                                                      Expanded(
                                                        child: Padding(
                                                          padding: const EdgeInsets.only(
                                                              right: 5, left: 5),
                                                          child:  CommonTextForm(
                                                            obsecureText: false,
                                                            labelText: 'Last Name',
                                                            LabelColor: primarycolor,
                                                            controller: lastNameController,
                                                            BorderColor: primarycolor,
                                                            borderc: 5,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(
                                                    height: 10,
                                                  ),
                                                  Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: primarycolor),
                                                      borderRadius: BorderRadius.circular(5),
                                                    ),
                                                    child: DropdownButtonFormField<String>(
                                                      value: selectedrole,
                                                      decoration: InputDecoration(
                                                        border: InputBorder.none,
                                                        contentPadding: EdgeInsets.zero,
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
                                                  SizedBox(
                                                    height: 10,
                                                  ),
                                                  Center(
                                                      child: Column(
                                                        children: [
                                                          CommonTextForm(
                                                            obsecureText: false,
                                                            labelText: 'Mobile No',
                                                            LabelColor: primarycolor,
                                                            controller: mobileController,
                                                            BorderColor: primarycolor,
                                                            borderc: 5,
                                                          ),
                                                          SizedBox(
                                                            height: 10,
                                                          ),
                                                          CommonTextForm(
                                                            obsecureText: false,
                                                            labelText: 'Email ID',
                                                            LabelColor: primarycolor,
                                                            controller: mailController,
                                                            BorderColor: primarycolor,
                                                            borderc: 5,
                                                          ),
                                                          SizedBox(
                                                            height: 10,
                                                          ),
                                                          CommonTextForm(
                                                            obsecureText: false,
                                                            labelText: 'Pin No',
                                                            LabelColor: primarycolor,
                                                            controller: pinNoController,
                                                            BorderColor: primarycolor,
                                                            borderc: 5,
                                                          ),
                                                          SizedBox(
                                                            height: 10,
                                                          ),
                                                        ],
                                                      )),
                                                  SizedBox(
                                                    height: 10,
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      CommonButton(
                                                          bordercircular: 5,
                                                          bordercolor: Colors.white,
                                                          bgcolor: Colors.white,
                                                          width: width * 0.3,
                                                          height: height * 0.05,
                                                          onTap: () {
                                                            Navigator.of(context).pop();
                                                          },
                                                          child: Text("Cancel")),
                                                      CommonButton(
                                                          bordercircular: 5,
                                                          bordercolor: primarycolor,
                                                          bgcolor: primarycolor,
                                                          width: width * 0.3,
                                                          height: height * 0.05,
                                                          onTap: () {
                                                            if (_formKey.currentState!.validate()) {
                                                              if (selectedrole != 'Select Role') {
                                                                _addStaff();
                                                                Navigator.of(context).pop();
                                                              } else {
                                                                NotificationService.instance.showInfo(
                                                                  'Please select a role',
                                                                );


                                                                // ScaffoldMessenger.of(context).showSnackBar(
                                                                //   SnackBar(content: Text('Please select a role')),
                                                                // );
                                                              }
                                                            }
                                                          },
                                                          child: Text("Add", style: TextStyle(color: Colors.white)))
                                                    ],
                                                  )
                                                ],
                                              ),
                                            ),
                                          ),
                                        ));
                                  },
                                );
                              });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Icon(
                                Icons.person_add_alt,
                                color: Colors.deepOrangeAccent,
                              ),
                              Text("Add Staff",
                                  textScaler: TextScaler.linear(1.5),
                                  style: TextStyle(fontSize: width * 0.025),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ))
                ),
              ],
            ),
            SizedBox(
              height: 30,
            ),

            // staffList.isEmpty?
            //     Icon(Icons.hourglass_empty):
            Expanded(
              child: ListView.builder(
                  itemCount: filteredStaffList.length,
                  itemBuilder: (context , index){

                    final staff = filteredStaffList[index];
                    return Slidable(
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
                                    (updatedStaff.isActive ?? true) ? 'Staff Enabled' : 'Staff Disabled',
                                  );


                                  // ScaffoldMessenger.of(context).showSnackBar(
                                  //   SnackBar(
                                  //     content: Text(
                                  //       (updatedStaff.isActive ?? true) ? 'Staff Enabled' : 'Staff Disabled',
                                  //     ),
                                  //     duration: Duration(seconds: 2),
                                  //   ),
                                  // );
                                }
                              },
                              backgroundColor: (staff.isActive ?? true) ? Colors.orange : Colors.green,
                              foregroundColor: Colors.white,
                              icon: (staff.isActive ?? true) ? Icons.block : Icons.check_circle,
                              label: (staff.isActive ?? true) ? 'Disable' : 'Enable',
                            ),
                            SlidableAction(
                              onPressed: (context) {
                                _deleteStaff(staff.id);
                              },
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              icon: Icons.delete,
                              label: 'Delete',
                            ),
                          ]),
                      child: Card(
                        elevation: 2,
                        color: (staff.isActive ?? true) == false ? Colors.grey[100] : Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        staff.userName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        "${staff.firstName} ${staff.lastName}",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            staff.isCashier,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: primarycolor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          if ((staff.isActive ?? true) == false)
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                'DISABLED',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      // view button
                                      CommonButton(
                                        bordercircular: 5,
                                        width: width * 0.2,
                                        height: height * 0.05,
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return Center(
                                                child: AlertDialog(
                                                  icon: Icon(Icons.person,
                                                      size: 30.0, color: primarycolor),
                                                  title: Text("User Details",
                                                      style: TextStyle(
                                                          fontWeight: FontWeight.bold)),
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                    children: [
                                                      Text("Name: ${staff.firstName} ${staff.lastName}",
                                                          style: TextStyle(fontSize: 16)),
                                                      SizedBox(height: 8),
                                                      Text("Mobile:${staff.mobileNo}",
                                                          style: TextStyle(fontSize: 16)),
                                                      SizedBox(height: 8),
                                                      Text("Email: ${staff.emailId}",
                                                          style: TextStyle(fontSize: 16)),
                                                    ],
                                                  ),
                                                  actions: [
                                                    CommonButton(
                                                        height: height * 0.05,
                                                        width: width * 0.2,
                                                        onTap: () {
                                                          Navigator.of(context).pop();
                                                        },
                                                        child: Text('Add')),
                                                    CommonButton(
                                                        height: height * 0.05,
                                                        width: width * 0.2,
                                                        onTap: () {
                                                          Navigator.of(context).pop();
                                                        },
                                                        child: Text('Close'))
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        },
                                        child: Text(
                                          'View',
                                          style: GoogleFonts.poppins(color: Colors.white),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 5,
                                      ),
                                      CommonButton(
                                        bordercircular: 5,
                                        bgcolor: Colors.deepOrange,
                                        bordercolor: Colors.deepOrange,
                                        width: width * 0.2,
                                        height: height * 0.05,
                                        onTap: () {
                                          // Initialize controllers with current staff data
                                          TextEditingController editUserNameController = TextEditingController(text: staff.userName);
                                          TextEditingController editFirstNameController = TextEditingController(text: staff.firstName);
                                          TextEditingController editLastNameController = TextEditingController(text: staff.lastName);
                                          TextEditingController editMobileController = TextEditingController(text: staff.mobileNo);
                                          TextEditingController editEmailController = TextEditingController(text: staff.emailId);
                                          TextEditingController editPinController = TextEditingController(text: staff.pinNo);
                                          String editSelectedRole = staff.isCashier;
                                          bool isActive = staff.isActive ?? true;

                                          showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return StatefulBuilder(
                                                  builder: (context, setState) {
                                                    return SingleChildScrollView(
                                                      child: AlertDialog(
                                                        title: Column(
                                                          children: [
                                                            Icon(
                                                              Icons.edit,
                                                              size: 40.0,
                                                              color: primarycolor,
                                                            ),
                                                            Text(
                                                              'Edit Staff',
                                                              style: TextStyle(
                                                                  fontSize: 20,
                                                                  fontWeight: FontWeight.bold),
                                                            ),
                                                            Divider(
                                                              color: Colors.grey,
                                                              thickness: 1,
                                                            )
                                                          ],
                                                        ),
                                                        content: Container(
                                                          width: double.maxFinite,
                                                          child: Column(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              CommonTextForm(
                                                                obsecureText: false,
                                                                labelText: 'Username',
                                                                LabelColor: primarycolor,
                                                                controller: editUserNameController,
                                                                BorderColor: primarycolor,
                                                                borderc: 5,
                                                              ),
                                                              SizedBox(height: 10),
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child: CommonTextForm(
                                                                      obsecureText: false,
                                                                      labelText: 'First Name',
                                                                      LabelColor: primarycolor,
                                                                      controller: editFirstNameController,
                                                                      BorderColor: primarycolor,
                                                                      borderc: 5,
                                                                    ),
                                                                  ),
                                                                  SizedBox(width: 10),
                                                                  Expanded(
                                                                    child: CommonTextForm(
                                                                      obsecureText: false,
                                                                      labelText: 'Last Name',
                                                                      LabelColor: primarycolor,
                                                                      controller: editLastNameController,
                                                                      BorderColor: primarycolor,
                                                                      borderc: 5,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              SizedBox(height: 10),
                                                              Container(
                                                                padding: EdgeInsets.symmetric(horizontal: 12),
                                                                decoration: BoxDecoration(
                                                                  border: Border.all(color: primarycolor),
                                                                  borderRadius: BorderRadius.circular(5),
                                                                ),
                                                                child: DropdownButton<String>(
                                                                  value: ['Cashier', 'Waiter', 'Manager', 'Kitchen Staff'].contains(editSelectedRole) ? editSelectedRole : 'Cashier',
                                                                  isExpanded: true,
                                                                  underline: SizedBox(),
                                                                  items: ['Cashier', 'Waiter', 'Manager', 'Kitchen Staff'].map((String value) {
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
                                                              SizedBox(height: 10),
                                                              CommonTextForm(
                                                                obsecureText: false,
                                                                labelText: 'Mobile No',
                                                                LabelColor: primarycolor,
                                                                controller: editMobileController,
                                                                BorderColor: primarycolor,
                                                                borderc: 5,
                                                              ),
                                                              SizedBox(height: 10),
                                                              CommonTextForm(
                                                                obsecureText: false,
                                                                labelText: 'Email ID',
                                                                LabelColor: primarycolor,
                                                                controller: editEmailController,
                                                                BorderColor: primarycolor,
                                                                borderc: 5,
                                                              ),
                                                              SizedBox(height: 10),
                                                              CommonTextForm(
                                                                obsecureText: false,
                                                                labelText: 'Pin No',
                                                                LabelColor: primarycolor,
                                                                controller: editPinController,
                                                                BorderColor: primarycolor,
                                                                borderc: 5,
                                                              ),
                                                              SizedBox(height: 15),
                                                              Row(
                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                children: [
                                                                  Text(
                                                                    'Account Status:',
                                                                    style: TextStyle(
                                                                      fontSize: 14,
                                                                      fontWeight: FontWeight.w500,
                                                                    ),
                                                                  ),
                                                                  Switch(
                                                                    value: isActive,
                                                                    activeColor: primarycolor,
                                                                    onChanged: (value) {
                                                                      setState(() {
                                                                        isActive = value;
                                                                      });
                                                                    },
                                                                  ),
                                                                  Text(
                                                                    isActive ? 'Active' : 'Disabled',
                                                                    style: TextStyle(
                                                                      color: isActive ? Colors.green : Colors.red,
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        actions: [
                                                          CommonButton(
                                                            bgcolor: Colors.white,
                                                            bordercolor: Colors.grey,
                                                            bordercircular: 5,
                                                            height: height * 0.05,
                                                            width: width * 0.25,
                                                            onTap: () {
                                                              Navigator.of(context).pop();
                                                            },
                                                            child: Text("Cancel",
                                                                style: TextStyle(
                                                                    color: Colors.black,
                                                                    fontWeight: FontWeight.bold)),
                                                          ),
                                                          CommonButton(
                                                            bgcolor: primarycolor,
                                                            bordercolor: primarycolor,
                                                            bordercircular: 5,
                                                            height: height * 0.05,
                                                            width: width * 0.25,
                                                            onTap: () async {
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
                                                                Navigator.of(context).pop();
                                                                // ScaffoldMessenger.of(context).showSnackBar(
                                                                //   SnackBar(content: Text('Staff updated successfully')),
                                                                // );

                                                                NotificationService.instance.showSuccess(
                                                                  'Staff updated successfully',
                                                                );


                                                              }
                                                            },
                                                            child: Text("Update",
                                                                style: TextStyle(
                                                                    color: Colors.white,
                                                                    fontWeight: FontWeight.bold)),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                );
                                              });
                                        },
                                        child: Icon(
                                          Icons.note_alt_rounded,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );}
              ),
            ),
          ],
        ),
      ),
      drawer: DrawerManage(
        isDelete: true,
        issync: true,
        islogout: true,
      ),
    );
  }
}
