import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_Table.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_cart.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_order.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_pastorder.dart';
import 'package:uuid/uuid.dart';

import '../../../../../constants/restaurant/color.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../../../domain/services/restaurant/cart_calculation_service.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import '../../../../../util/restaurant/staticswitch.dart';
import '../../../../../util/restaurant/decimal_settings.dart';
import '../../../../../util/restaurant/currency_helper.dart';
import '../../../../../stores/payment_method_store.dart';
import '../../../../widget/componets/restaurant/componets/Button.dart';
import '../../../../widget/componets/restaurant/componets/Textform.dart';
import '../../../../widget/componets/restaurant/componets/filterButton.dart';
import '../startorder.dart';
import '../../util/restaurant_print_helper.dart';

enum DiscountType { amount, percentage }

class Customerdetails extends StatefulWidget {
  final OrderModel? existingModel;
  final String? tableid;
  final List<CartItem>? cartitems;
  final double totalPrice;
  final String? orderType;
  final bool? isSettle;
  Customerdetails({
    super.key,
    required this.totalPrice,
    this.tableid,
    this.existingModel,
    this.cartitems,
    this.orderType,
    this.isSettle = false,
  });

  @override
  State<Customerdetails> createState() => _CustomerdetailsState();
}

class _CustomerdetailsState extends State<Customerdetails> with TickerProviderStateMixin {
  late TextEditingController _mobileController = TextEditingController();
  late TextEditingController _nameController = TextEditingController();
  late TextEditingController _emailController = TextEditingController();
  final _serviceChargeController = TextEditingController();
  final _deliveryChargeController = TextEditingController();
  final _discountController = TextEditingController();
  final _amountController = TextEditingController();
  final _amountpercentageContorller = TextEditingController();
  final _remarkController = TextEditingController();
  final _discountValueController = TextEditingController();

  final _houseController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  final _postCodeController = TextEditingController();

  FocusNode mobilenode = FocusNode();
  FocusNode namenode = FocusNode();
  FocusNode emailnode = FocusNode();

  DiscountType _selectedDiscountType = DiscountType.amount;
  int selectedOption = 1;
  double DiscountPercentage = 0;
  String SelectedFilter = 'Cash';
  bool servicechargeapply = false;
  bool discountApply = false;
  String? SelectedRemark = 'Old Customer';
  final List<String> remarkList = [
    'Old Customer',
    'Regular Customer',
    'police',
    'know (known person)',
    'other'
  ];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    _amountController.addListener(() => setState(() {}));
    _amountpercentageContorller.addListener(() => setState(() {}));
    _serviceChargeController.addListener(() => setState(() {}));

    _nameController = TextEditingController(
        text: widget.existingModel?.customerName ?? '');
    _emailController = TextEditingController(
        text: widget.existingModel?.customerEmail ?? '');
    _mobileController = TextEditingController(
        text: widget.existingModel?.customerNumber ?? '');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _mobileController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _serviceChargeController.dispose();
    _discountController.dispose();
    _remarkController.dispose();
    _houseController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _postCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double discountInputValue = discountApply
        ? (_selectedDiscountType == DiscountType.amount
        ? _toDouble(_amountController)
        : _toDouble(_amountpercentageContorller))
        : 0.0;

    final double serviceChargeValue =
    servicechargeapply ? _toDouble(_serviceChargeController) : 0.0;
    final bool isDelivery = widget.orderType == 'Delivery';

    final calculations = CartCalculationService(
      items: widget.cartitems ?? widget.existingModel?.items ?? [],
      discountType: _selectedDiscountType,
      discountValue: discountInputValue,
      serviceChargePercentage: isDelivery ? 0.0 : serviceChargeValue,
      deliveryCharge: isDelivery ? serviceChargeValue : 0.0,
      isDeliveryOrder: isDelivery,
    );

    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primarycolor,
        title: Text(
          'Customer Details',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header gradient section
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primarycolor, primarycolor.withOpacity(0.8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildOrderTypeChip(),
                        if (widget.tableid != null && widget.tableid!.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          _buildTableChip(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Main content
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Information Section
                    _buildSectionCard(
                      title: 'Customer Information',
                      icon: Icons.person_outline,
                      iconColor: Colors.blue,
                      child: Column(
                        children: [
                          _buildEnhancedTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.person,
                            focusNode: namenode,
                            onFieldSubmitted: (v) {
                              FocusScope.of(context).requestFocus(emailnode);
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildEnhancedTextField(
                            controller: _emailController,
                            label: 'Email Address (Optional)',
                            icon: Icons.email_outlined,
                            focusNode: emailnode,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _buildEnhancedTextField(
                            controller: _mobileController,
                            label: 'Mobile Number',
                            icon: Icons.phone_outlined,
                            focusNode: mobilenode,
                            keyboardType: TextInputType.phone,
                            prefix: CountryCodePicker(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              initialSelection: 'IN',
                              favorite: const ['+91', 'IN'],
                              showCountryOnly: false,
                              showFlag: false,
                              textStyle: GoogleFonts.poppins(
                                fontSize: 14,
                                color: primarycolor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onFieldSubmitted: (v) {
                              FocusScope.of(context).requestFocus(namenode);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Delivery Address Section
                    if (widget.orderType == 'Delivery')
                      _buildSectionCard(
                        title: 'Delivery Address',
                        icon: Icons.location_on_outlined,
                        iconColor: Colors.green,
                        child: Column(
                          children: [
                            _buildEnhancedTextField(
                              controller: _houseController,
                              label: 'House/Building No.',
                              icon: Icons.home_outlined,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildEnhancedTextField(
                                    controller: _stateController,
                                    label: 'State',
                                    icon: Icons.map_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildEnhancedTextField(
                                    controller: _cityController,
                                    label: 'City',
                                    icon: Icons.location_city_outlined,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildEnhancedTextField(
                              controller: _areaController,
                              label: 'Area/Locality',
                              icon: Icons.place_outlined,
                            ),
                            const SizedBox(height: 16),
                            _buildEnhancedTextField(
                              controller: _postCodeController,
                              label: 'Postal Code',
                              icon: Icons.pin_drop_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Service/Delivery Charge Section
                    _buildSectionCard(
                      title: widget.orderType == 'Delivery'
                          ? 'Delivery Charge'
                          : 'Service Charge',
                      icon: widget.orderType == 'Delivery'
                          ? Icons.delivery_dining
                          : Icons.room_service,
                      iconColor: Colors.orange,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildEnhancedTextField(
                              controller: _serviceChargeController,
                              label: widget.orderType == 'Delivery'
                                  ? 'Charge Amount'
                                  : 'Percentage (%)',
                              icon: Icons.attach_money,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildToggleButton(
                              isActive: servicechargeapply,
                              onTap: () {
                                setState(() {
                                  if (servicechargeapply) {
                                    servicechargeapply = false;
                                    _serviceChargeController.clear();
                                  } else {
                                    servicechargeapply = true;
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Discount Section
                    _buildDiscountSection(calculations),

                    const SizedBox(height: 16),

                    // Payment Method Section
                    _buildPaymentMethodSection(),

                    const SizedBox(height: 24),

                    // Proceed Button
                    _buildProceedButton(height, calculations),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTypeChip() {
    IconData icon;
    Color color;

    switch (widget.orderType) {
      case 'Delivery':
        icon = Icons.delivery_dining;
        color = Colors.orange;
        break;
      case 'Take Away':
        icon = Icons.shopping_bag_outlined;
        color = Colors.green;
        break;
      case 'Dine In':
        icon = Icons.restaurant;
        color = Colors.blue;
        break;
      default:
        icon = Icons.receipt;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            widget.orderType ?? 'Order',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.table_restaurant, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            'Table ${widget.tableid}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: primarycolor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    Widget? prefix,
    Function(String)? onFieldSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        onSubmitted: onFieldSubmitted,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: Colors.grey[600],
            fontSize: 14,
          ),
          prefixIcon: prefix ?? Icon(icon, color: primarycolor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
              colors: [Colors.red.shade400, Colors.red.shade300],
            )
                : LinearGradient(
              colors: [primarycolor, primarycolor.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: (isActive ? Colors.red : primarycolor).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              isActive ? 'Cancel' : 'Apply',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountSection(CartCalculationService calculations) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_offer, color: Colors.purple, size: 22),
          ),
          title: Text(
            'Discount',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: primarycolor,
            ),
          ),
          children: [
            // Discount Type Selection
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildDiscountTypeOption(
                      'Amount',
                      DiscountType.amount,
                      Icons.attach_money,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDiscountTypeOption(
                      'Percentage',
                      DiscountType.percentage,
                      Icons.percent,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Percentage Quick Buttons
            if (_selectedDiscountType == DiscountType.percentage)
              Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5, 10, 15, 20, 25].map((percent) {
                      return _buildPercentageChip(percent);
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Discount Input
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildEnhancedTextField(
                    controller: _selectedDiscountType == DiscountType.amount
                        ? _amountController
                        : _amountpercentageContorller,
                    label: _selectedDiscountType == DiscountType.amount
                        ? 'Enter Amount'
                        : 'Enter Percentage',
                    icon: _selectedDiscountType == DiscountType.amount
                        ? Icons.money_off
                        : Icons.percent,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToggleButton(
                    isActive: discountApply,
                    onTap: () {
                      setState(() {
                        if (discountApply) {
                          discountApply = false;
                          _amountController.clear();
                          _amountpercentageContorller.clear();
                          DiscountPercentage = 0;
                        } else {
                          discountApply = true;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),

            // Remark Dropdown
            if (discountApply && calculations.discountAmount > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: SelectedRemark,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down, color: primarycolor),
                    style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
                    items: remarkList.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        SelectedRemark = newValue!;
                      });
                    },
                  ),
                ),
              ),
            ],

            // Custom Remark
            if (calculations.discountAmount > 0 && SelectedRemark == 'other') ...[
              const SizedBox(height: 16),
              _buildEnhancedTextField(
                controller: _remarkController,
                label: 'Custom Remark',
                icon: Icons.edit_note,
              ),
            ],

            // Bill Summary
            if (discountApply || calculations.discountAmount > 0) ...[
              const SizedBox(height: 20),
              _buildBillSummary(calculations),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountTypeOption(String label, DiscountType type, IconData icon) {
    final isSelected = _selectedDiscountType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedDiscountType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primarycolor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? primarycolor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: primarycolor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPercentageChip(int percent) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _amountpercentageContorller.text = percent.toString();
          discountApply = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primarycolor.withOpacity(0.8), primarycolor],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primarycolor.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '$percent%',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.payment, color: Colors.green, size: 22),
          ),
          title: Text(
            'Payment Method',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: primarycolor,
            ),
          ),
          children: [
            Observer(
              builder: (_) {
                final paymentStore = locator<PaymentMethodStore>();
                final enabledMethods = paymentStore.paymentMethods
                    .where((method) => method.isEnabled)
                    .toList();

                if (enabledMethods.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No payment methods enabled. Please enable payment methods in Settings.',
                            style: GoogleFonts.poppins(
                              color: Colors.orange.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: enabledMethods.map((method) {
                    final isSelected = SelectedFilter == method.name;
                    IconData methodIcon;

                    switch (method.name?.toLowerCase()) {
                      case 'cash':
                        methodIcon = Icons.money;
                        break;
                      case 'card':
                        methodIcon = Icons.credit_card;
                        break;
                      case 'upi':
                        methodIcon = Icons.qr_code_scanner;
                        break;
                      case 'online':
                        methodIcon = Icons.phone_android;
                        break;
                      default:
                        methodIcon = Icons.payment;
                    }

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          SelectedFilter = method.name!;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? primarycolor : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? primarycolor : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                            BoxShadow(
                              color: primarycolor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              methodIcon,
                              size: 20,
                              color: isSelected ? Colors.white : primarycolor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              method.name!,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillSummary(CartCalculationService calcs) {
    final isInclusive = AppSettings.isTaxInclusive;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primarycolor.withOpacity(0.05),
            primarycolor.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primarycolor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primarycolor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.receipt_long, color: primarycolor, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Bill Summary',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: primarycolor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            isInclusive ? 'Item Total (Incl GST)' : 'Item Total',
            calcs.itemTotal,
          ),
          if (calcs.discountAmount > 0.009) ...[
            const SizedBox(height: 8),
            _buildSummaryRow('Discount', -calcs.discountAmount, isDiscount: true),
          ],
          if (calcs.discountAmount > 0.009 || calcs.totalGST > 0.009)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: primarycolor.withOpacity(0.2), height: 1),
            ),
          _buildSummaryRow(
            isInclusive ? 'Taxable Amount' : 'Sub Total (Before Tax)',
            calcs.subtotal,
          ),
          if (calcs.totalGST > 0.009) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              isInclusive ? 'GST (Included)' : 'GST',
              calcs.totalGST,
              isTax: true,
            ),
          ],
          if (calcs.serviceChargeAmount > 0.009) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              widget.orderType == 'Delivery' ? 'Delivery Charge' : 'Service Charge',
              calcs.serviceChargeAmount,
            ),
          ],
          if (AppSettings.roundOff && calcs.roundOffAmount.abs() > 0.009) ...[
            const SizedBox(height: 8),
            _buildSummaryRow('Round Off', calcs.roundOffAmount, isRoundOff: true),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: primarycolor.withOpacity(0.3), thickness: 2, height: 1),
          ),
          _buildSummaryRow('Grand Total', calcs.grandTotal, isGrandTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
      String label,
      double value, {
        bool isDiscount = false,
        bool isTax = false,
        bool isRoundOff = false,
        bool isGrandTotal = false,
      }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: isGrandTotal ? 16 : 13,
            fontWeight: isGrandTotal ? FontWeight.w700 : FontWeight.w500,
            color: isGrandTotal ? primarycolor : Colors.black87,
          ),
        ),
        Text(
          '${isDiscount ? '-' : isRoundOff && value >= 0 ? '+' : ''}${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(value.abs())}',
          style: GoogleFonts.poppins(
            fontSize: isGrandTotal ? 18 : 14,
            fontWeight: isGrandTotal ? FontWeight.w700 : FontWeight.w600,
            color: isGrandTotal
                ? primarycolor
                : isDiscount
                ? Colors.red.shade600
                : isTax
                ? Colors.orange.shade700
                : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildProceedButton(double height, CartCalculationService calculations) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primarycolor, primarycolor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primarycolor.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _submitOrder(calculations),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Proceed to ${widget.isSettle == true ? 'Settle' : 'Confirm'}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _toDouble(TextEditingController c, {double fallback = 0}) {
    final s = c.text.trim();
    if (s.isEmpty) return fallback;
    final v = double.tryParse(s);
    return v ?? fallback;
  }

  // [All remaining methods remain exactly the same - proceed, completeOrder, _placeOrder, etc.]

  Future<void> proceed(CartCalculationService calculations) async {
    print('============THis is PRocced Function=============');
    if (widget.existingModel == null || widget.tableid == null) {
      NotificationService.instance.showError(
        'Error: No active order or table found.to cart',
      );
      return;
    }
    final OrderModel completedOrder = widget.existingModel!.copyWith(
      customerName: _nameController.text.trim(),
      customerNumber: _mobileController.text.trim(),
      customerEmail: _emailController.text.trim(),
      discount: calculations.discountAmount,
      serviceCharge: calculations.serviceChargeAmount,
      totalPrice: calculations.grandTotal,
      paymentMethod: SelectedFilter,
      completedAt: DateTime.now(),
      status: 'Cooking',
      tableNo: widget.tableid,
      isPaid: true,
      paymentStatus: 'Paid',
    );
    try {
      final int billNumber = await completeOrder(completedOrder, calculations);
      await HiveTables.updateTableStatus(widget.tableid!, 'Available');
      NotificationService.instance.showSuccess(
        'Order Completed Successfully!',
      );
      await _showOrderSuccessDialog(completedOrder, calculations, billNumber: billNumber);
    } catch (e) {
      NotificationService.instance.showError(
        'Failed to proceed with the order: $e',
      );
    }
  }

  Future<int> completeOrder(
      OrderModel activeModel, CartCalculationService calculations) async {
    print('============this is complete order function=============');
    final int billNumber = await HiveOrders.getNextBillNumber();
    print('✅ Bill number generated: $billNumber');

    final pastOrder = pastOrderModel(
      id: activeModel.id,
      customerName: activeModel.customerName,
      totalPrice: calculations.grandTotal,
      items: activeModel.items,
      orderAt: activeModel.timeStamp,
      orderType: activeModel.orderType,
      paymentmode: SelectedFilter,
      remark:
      SelectedRemark == 'other' ? _remarkController.text : SelectedRemark,
      Discount: calculations.discountAmount,
      subTotal: calculations.subtotal,
      gstRate: 0,
      gstAmount: calculations.totalGST,
      kotNumbers: activeModel.kotNumbers,
      kotBoundaries: activeModel.kotBoundaries,
      billNumber: billNumber,
    );
    await HivePastOrder.addOrder(pastOrder);
    await HiveOrders.deleteOrder(activeModel.id);
    return billNumber;
  }

  Future<void> _placeOrder(CartCalculationService calculations) async {
    print('============this is place order function=============');
    print(widget.orderType);

    final int newKotNumber = await HiveOrders.getNextKotNumber();
    final String newId = Uuid().v4();
    final List<CartItem> orderItems = widget.cartitems ?? [];

    if (widget.isSettle == true) {
      final int billNumber = await HiveOrders.getNextBillNumber();
      print('✅ Bill number generated for settle & print: $billNumber');

      print('🔍 DEBUG: Creating pastOrder with payment method: $SelectedFilter');
      final pastOrder = pastOrderModel(
        id: newId,
        customerName: _nameController.text.trim(),
        totalPrice: calculations.grandTotal,
        items: orderItems,
        orderAt: DateTime.now(),
        orderType: widget.orderType ?? 'Take Away',
        paymentmode: SelectedFilter,
        remark: calculations.discountAmount > 0.009 ? SelectedRemark : 'no Remark',
        Discount: calculations.discountAmount,
        subTotal: calculations.subtotal,
        gstRate: 0,
        gstAmount: calculations.totalGST,
        kotNumbers: [newKotNumber],
        kotBoundaries: [orderItems.length],
        billNumber: billNumber,
      );
      print('🔍 DEBUG: pastOrder.paymentmode = ${pastOrder.paymentmode}');

      try {
        await HivePastOrder.addOrder(pastOrder);
        await HiveCart.clearCart();

        NotificationService.instance.showSuccess(
          'Order Settled Successfully',
        );
        await _showOrderSuccessDialogWithBillNumber(pastOrder, calculations, billNumber);
      } catch (e) {
        NotificationService.instance.showError(
          'Failed to settle order: $e',
        );
      }
      return;
    }

    final newOrder = OrderModel(
      id: newId,
      customerName: _nameController.text.trim(),
      customerNumber: _mobileController.text.trim(),
      customerEmail: _emailController.text.trim(),
      items: orderItems,
      status: 'Processing',
      timeStamp: DateTime.now(),
      orderType: widget.orderType ?? 'Take Away',
      tableNo: widget.tableid ?? '',
      subTotal: calculations.subtotal,
      discount: calculations.discountAmount,
      serviceCharge: calculations.serviceChargeAmount,
      gstRate: 0,
      gstAmount: calculations.totalGST,
      totalPrice: calculations.grandTotal,
      paymentMethod: SelectedFilter,
      completedAt: null,
      paymentStatus: "Unpaid",
      isPaid: false,
      remark:
      calculations.discountAmount > 0.009 ? SelectedRemark : 'no Remark',
      kotNumbers: [newKotNumber],
      itemCountAtLastKot: orderItems.length,
      kotBoundaries: [orderItems.length],
    );
    try {
      await HiveOrders.addOrder(newOrder);
      if (widget.tableid != null && widget.tableid!.isNotEmpty) {
        await HiveTables.updateTableStatus(
          widget.tableid!,
          'Running',
          total: newOrder.totalPrice,
          orderTime: newOrder.timeStamp,
        );
      }
      NotificationService.instance.showSuccess(
        'New Order Placed Successfully',
      );

      await HiveCart.clearCart();
      await _showOrderSuccessDialog(newOrder, calculations);
    } catch (e) {
      NotificationService.instance.showError(
        'Failed to create new order: $e',
      );
    }
  }

  Future<void> _showOrderSuccessDialog(
      OrderModel order, CartCalculationService calculations, {int? billNumber}) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 50),
            ),
            const SizedBox(height: 16),
            Text(
              'Order Successful',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: Text(
          'Order has been placed successfully.\nDo you want to print the receipt?',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToHome();
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Close', style: GoogleFonts.poppins()),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await RestaurantPrintHelper.printOrderReceipt(
                context: context,
                order: order,
                calculations: calculations,
                billNumber: billNumber,
              );
            },
            icon: const Icon(Icons.print, size: 18),
            label: Text('Print Receipt', style: GoogleFonts.poppins()),
            style: ElevatedButton.styleFrom(
              backgroundColor: primarycolor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showOrderSuccessDialogWithBillNumber(
      pastOrderModel pastOrder, CartCalculationService calculations, int billNumber) async {
    if (!mounted) return;

    print('🔍 DEBUG: Converting pastOrder to OrderModel');
    print('🔍 DEBUG: pastOrder.paymentmode = ${pastOrder.paymentmode}');
    final orderForPrint = OrderModel(
      id: pastOrder.id,
      customerName: pastOrder.customerName,
      customerNumber: '',
      customerEmail: '',
      items: pastOrder.items,
      status: 'Completed',
      timeStamp: pastOrder.orderAt ?? DateTime.now(),
      orderType: pastOrder.orderType ?? 'Take Away',
      tableNo: '',
      totalPrice: pastOrder.totalPrice,
      kotNumbers: pastOrder.kotNumbers,
      itemCountAtLastKot: pastOrder.items.length,
      kotBoundaries: pastOrder.kotBoundaries,
      subTotal: pastOrder.subTotal,
      gstAmount: pastOrder.gstAmount,
      gstRate: pastOrder.gstRate,
      discount: pastOrder.Discount,
      paymentMethod: pastOrder.paymentmode,
      isPaid: true,
      paymentStatus: 'Paid',
      completedAt: DateTime.now(),
    );
    print('🔍 DEBUG: orderForPrint.paymentMethod = ${orderForPrint.paymentMethod}');
    print('🔍 DEBUG: orderForPrint.isPaid = ${orderForPrint.isPaid}');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 50),
            ),
            const SizedBox(height: 16),
            Text(
              'Order Settled',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: Text(
          'Bill #${billNumber.toString().padLeft(3, '0')} generated successfully.\nDo you want to print the bill?',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToHome();
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Close', style: GoogleFonts.poppins()),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await RestaurantPrintHelper.printOrderReceipt(
                context: context,
                order: orderForPrint,
                calculations: calculations,
                billNumber: billNumber,
              );
            },
            icon: const Icon(Icons.print, size: 18),
            label: Text('Print Bill', style: GoogleFonts.poppins()),
            style: ElevatedButton.styleFrom(
              backgroundColor: primarycolor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const POSMainScreen()),
          (Route<dynamic> route) => false,
    );
  }

  Future<void> clearCart() async {
    try {
      await HiveCart.clearCart();
      if (mounted) {
        NotificationService.instance.showInfo(
          'Cart cleared',
        );
      }
    } catch (e) {
      print('Error clearing cart: $e');
      if (mounted) {
        NotificationService.instance.showInfo(
          '$Error clearing cart',
        );
      }
    }
  }

  Future<void> _submitOrder(CartCalculationService calculations) async {
    if (widget.isSettle == true) {
      await _placeOrder(calculations);
    } else {
      await proceed(calculations);
    }
  }
}