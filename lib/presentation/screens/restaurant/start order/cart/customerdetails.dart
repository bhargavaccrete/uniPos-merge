import 'dart:convert';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/di/service_locator.dart';
import '../../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../../../domain/services/restaurant/cart_calculation_service.dart';
import '../../../../../domain/services/restaurant/day_management_service.dart';
import '../../../../widget/restaurant/opening_balance_dialog.dart';
import '../../../../../domain/services/restaurant/inventory_service.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import '../../../../../util/common/app_responsive.dart';
import '../../../../../util/common/currency_helper.dart';
import '../../../../../util/restaurant/staticswitch.dart';
import '../../../../../util/restaurant/restaurant_session.dart';
import '../../../../../stores/payment_method_store.dart';
import '../../../../../data/models/restaurant/db/customer_model_125.dart';
import '../../../../widget/componets/common/split_payment_widget.dart';
import '../../../../widget/componets/restaurant/componets/Button.dart';
import '../../../../widget/componets/restaurant/componets/filterButton.dart';
import '../../../../widget/componets/common/app_text_field.dart';
import '../startorder.dart';
import '../../util/restaurant_print_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
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

class _CustomerdetailsState extends State<Customerdetails> {
  late TextEditingController _mobileController = TextEditingController();
  late TextEditingController _nameController = TextEditingController();
  late TextEditingController _emailController = TextEditingController();

  // Customer selection
  RestaurantCustomer? selectedCustomer;
  String? _mobileError;
  bool _usePoints = false;
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

  // Split payment state
  List<PaymentEntry> _paymentEntries = [];
  double _totalPaid = 0;
  double _changeReturn = 0;
  bool _isPaymentValid = false;
  bool _isProcessing = false;
  bool discountApply = false;
  String? SelectedRemark = 'Old Customer';
  final List<String> remarkList = [
    'Old Customer',
    'Regular Customer',
    'police',
    'know (known person)',
    'other'
  ];

  // Currency symbol
  // Currency symbol is now loaded from CurrencyHelper.currentSymbol (reactive)

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
    _amountpercentageContorller.addListener(() => setState(() {}));
    _serviceChargeController.addListener(() => setState(() {}));

    _nameController = TextEditingController(
        text: widget.existingModel?.customerName ?? '');
    _emailController = TextEditingController(
        text: widget.existingModel?.customerEmail ?? '');
    _mobileController = TextEditingController(
        text: widget.existingModel?.customerNumber ?? '');

    // Auto-load existing customer so points toggle shows on settle screen
    final hasPhone = widget.existingModel?.customerNumber?.trim().isNotEmpty == true;
    final hasName = widget.existingModel?.customerName?.trim().isNotEmpty == true;
    if (hasPhone || hasName) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingCustomer());
    }

    // Currency is loaded in main.dart via CurrencyHelper.load()
  }

  Future<void> _loadExistingCustomer() async {
    final phone = widget.existingModel?.customerNumber?.trim() ?? '';
    final name = widget.existingModel?.customerName?.trim() ?? '';
    try {
      if (phone.isNotEmpty) {
        final results = await restaurantCustomerStore.searchCustomers(phone);
        final match = results.where((c) => c.phone == phone).firstOrNull;
        if (match != null && mounted) {
          setState(() => selectedCustomer = match);
          return;
        }
      }
      if (name.isNotEmpty) {
        final results = await restaurantCustomerStore.searchCustomers(name);
        final match = results
            .where((c) => c.name?.toLowerCase() == name.toLowerCase())
            .firstOrNull;
        if (match != null && mounted) {
          setState(() => selectedCustomer = match);
        }
      }
    } catch (e) {
    }
  }

  // Handle customer selection from autocomplete
  void _onCustomerSelected(RestaurantCustomer customer) {
    setState(() {
      selectedCustomer = customer;
      _nameController.text = customer.name ?? '';
      _emailController.text = ''; // Email not stored in customer model
      _mobileController.text = customer.phone ?? '';
    });
  }

  @override
  void dispose() {
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
    // This build method is now much cleaner.

    // ✅ Step 1: Gather all inputs from the UI.
    final double discountInputValue = discountApply
        ? (_selectedDiscountType == DiscountType.amount
            ? _toDouble(_amountController)
            : _toDouble(_amountpercentageContorller))
        : 0.0;

    final double serviceChargeValue =
        servicechargeapply ? _toDouble(_serviceChargeController) : 0.0;
    final bool isDelivery = widget.orderType == 'Delivery';

    // ✅ Step 2: Create the service to do all the math.
    final calculations = CartCalculationService(
      items: widget.cartitems ?? widget.existingModel?.items ?? [],
      discountType: _selectedDiscountType,
      discountValue: discountInputValue,
      serviceChargePercentage: isDelivery ? 0.0 : serviceChargeValue,
      deliveryCharge: isDelivery ? serviceChargeValue : 0.0,
      isDeliveryOrder: isDelivery,
      // Use stored tax mode from existing order; fall back to app setting for new orders
      isTaxInclusive: widget.existingModel?.isTaxInclusive ?? AppSettings.isTaxInclusive,
    );

    // ✅ Step 3: Loyalty points discount
    final int availablePoints = selectedCustomer?.loyaltyPoints ?? 0;
    final int pointsDiscount = (_usePoints && availablePoints > 0)
        ? availablePoints.clamp(0, calculations.grandTotal.floor())
        : 0;
    final double netPayable = calculations.grandTotal - pointsDiscount;

    // ✅ Step 4: Build the UI using the final, calculated values.
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Customer Details',
        titleFontSize: isTablet ? 22 : 20,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // Show selected customer info
              if (selectedCustomer != null)
                Container(
                  width: width,
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.green.shade200,
                        child: Text(
                          selectedCustomer!.name?.isNotEmpty == true
                              ? selectedCustomer!.name![0].toUpperCase()
                              : '?',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedCustomer!.name ?? 'Unknown',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (selectedCustomer!.phone != null)
                              Text(
                                selectedCustomer!.phone!,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            Row(
                              children: [
                                _buildInfoChip(
                                  Icons.restaurant,
                                  '${selectedCustomer!.totalVisites} visits',
                                  Colors.blue,
                                ),
                                SizedBox(width: 8),
                                _buildInfoChip(
                                  Icons.stars,
                                  '${selectedCustomer!.loyaltyPoints} pts',
                                  Colors.orange,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.clear, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            selectedCustomer = null;
                            _nameController.clear();
                            _emailController.clear();
                            _mobileController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),

              // Loyalty Points Toggle
              if (selectedCustomer != null && availablePoints > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.stars_rounded, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$availablePoints pts = ${CurrencyHelper.currentSymbol}$availablePoints discount',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                      Switch(
                        value: _usePoints,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _usePoints = val),
                      ),
                    ],
                  ),
                ),

              // Customer Information section header
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Text('Customer Information',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    const Spacer(),
                    Text('Optional', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),

              // Autocomplete Name Field
              Autocomplete<RestaurantCustomer>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<RestaurantCustomer>.empty();
                  }
                  return await restaurantCustomerStore.searchCustomers(textEditingValue.text);
                },
                displayStringForOption: (RestaurantCustomer customer) => customer.name ?? '',
                onSelected: (RestaurantCustomer customer) {
                  _onCustomerSelected(customer);
                },
                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                  // Sync with _nameController
                  if (_nameController.text != controller.text) {
                    controller.text = _nameController.text;
                    controller.selection = TextSelection.collapsed(offset: controller.text.length);
                  }
                  _nameController = controller;

                  return AppTextField(
                    controller: controller,
                    focusNode: focusNode,
                    label: 'Customer Name',
                    hint: 'Search by name…',
                    icon: Icons.person_outline,
                    onFieldSubmitted: (v) => FocusScope.of(context).requestFocus(emailnode),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 0,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: width * 0.9,
                        constraints: const BoxConstraints(maxHeight: 200),
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider),
                          itemBuilder: (context, index) {
                            final customer = options.elementAt(index);
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => onSelected(customer),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.primary.withOpacity(0.12),
                                      child: Text(
                                        customer.name?.isNotEmpty == true ? customer.name![0].toUpperCase() : '?',
                                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(customer.name ?? 'Unknown',
                                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                          Text('${customer.phone ?? ''} • ${customer.totalVisites} visits',
                                              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.north_west, size: 14, color: AppColors.textSecondary),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              AppTextField(
                focusNode: emailnode,
                controller: _emailController,
                label: 'Email',
                hint: 'Email ID (optional)',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),

              // Autocomplete Mobile Field
              Autocomplete<RestaurantCustomer>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<RestaurantCustomer>.empty();
                  }
                  return await restaurantCustomerStore.searchCustomers(textEditingValue.text);
                },
                displayStringForOption: (RestaurantCustomer customer) => customer.phone ?? '',
                onSelected: (RestaurantCustomer customer) {
                  _onCustomerSelected(customer);
                },
                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                  // Sync with _mobileController
                  if (_mobileController.text != controller.text) {
                    controller.text = _mobileController.text;
                    controller.selection = TextSelection.collapsed(offset: controller.text.length);
                  }
                  _mobileController = controller;

                  return AppTextField(
                    controller: controller,
                    focusNode: focusNode,
                    label: 'Mobile Number',
                    hint: 'Mobile number',
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    prefixWidget: CountryCodePicker(
                      padding: EdgeInsets.zero,
                      initialSelection: 'IN',
                      favorite: ['+91', 'IN'],
                      showCountryOnly: false,
                      showFlag: false,
                    ),
                    onFieldSubmitted: (v) => FocusScope.of(context).requestFocus(namenode),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 0,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: width * 0.9,
                        constraints: const BoxConstraints(maxHeight: 200),
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider),
                          itemBuilder: (context, index) {
                            final customer = options.elementAt(index);
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => onSelected(customer),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.primary.withOpacity(0.12),
                                      child: Text(
                                        customer.name?.isNotEmpty == true ? customer.name![0].toUpperCase() : '?',
                                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(customer.name ?? 'Unknown',
                                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                          Text('${customer.phone ?? ''} • ${customer.totalVisites} visits',
                                              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.north_west, size: 14, color: AppColors.textSecondary),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_mobileError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12, bottom: 4),
                  child: Text(
                    _mobileError!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.red.shade600,
                    ),
                  ),
                ),

              SizedBox(height: 10),

              if (widget.orderType == 'Delivery')
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          border: Border(bottom: BorderSide(color: AppColors.divider)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Text('Delivery Address', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppTextField(controller: _houseController, label: 'House / Flat No', hint: 'e.g. B-101', icon: Icons.home_outlined),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(child: AppTextField(controller: _cityController, label: 'City', hint: 'City', icon: Icons.location_city_outlined)),
                                const SizedBox(width: 12),
                                Expanded(child: AppTextField(controller: _areaController, label: 'Area', hint: 'Area / Locality', icon: Icons.map_outlined)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(child: AppTextField(controller: _stateController, label: 'State', hint: 'State', icon: Icons.flag_outlined)),
                                const SizedBox(width: 12),
                                Expanded(child: AppTextField(controller: _postCodeController, label: 'Post Code', hint: 'PIN code', icon: Icons.pin_drop_outlined, keyboardType: TextInputType.number)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Service/Delivery Charge Card
              Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        controller: _serviceChargeController,
                        label: widget.orderType == 'Delivery' ? 'Delivery Charge' : 'Service Charge',
                        hint: widget.orderType == 'Delivery' ? 'Delivery charge amount' : 'Service charge %',
                        icon: widget.orderType == 'Delivery' ? Icons.delivery_dining : Icons.percent,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: servicechargeapply
                                ? Colors.red.shade400
                                : AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: isTablet ? 18 : 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            servicechargeapply == false
                                ? setState(() {
                                    servicechargeapply = true;
                                  })
                                : setState(() {
                                    servicechargeapply = false;
                                    _serviceChargeController.clear();
                                  });
                          },
                          child: Text(
                            servicechargeapply ? 'Cancel' : 'Apply',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          )),
                    )
                  ],
                ),
              ),

              // Discount Card
              Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ExpansionTile(
                  backgroundColor: Colors.white,
                  collapsedBackgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Row(
                    children: [
                      Icon(Icons.discount_outlined, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Discount',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedDiscountType = DiscountType.amount),
                          child: Row(
                            children: [
                              Radio<DiscountType>(
                                value: DiscountType.amount,
                                groupValue: _selectedDiscountType,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (value) => setState(() => _selectedDiscountType = value!),
                              ),
                              Text('Amount', style: GoogleFonts.poppins(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedDiscountType = DiscountType.percentage),
                          child: Row(
                            children: [
                              Radio<DiscountType>(
                                value: DiscountType.percentage,
                                groupValue: _selectedDiscountType,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (value) => setState(() => _selectedDiscountType = value!),
                              ),
                              Text('Percentage', style: GoogleFonts.poppins(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_selectedDiscountType == DiscountType.percentage)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPercentageButton('05%', 5),
                        SizedBox(width: 5),
                        _buildPercentageButton('10%', 10),
                        SizedBox(width: 5),
                        _buildPercentageButton('15%', 15),
                        SizedBox(width: 5),
                        _buildPercentageButton('20%', 20),
                        SizedBox(width: 5),
                        _buildPercentageButton('25%', 25),
                        SizedBox(width: 5),
                      ],
                    ),

                  SizedBox(height: 10),
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _selectedDiscountType == DiscountType.amount
                                  ? _amountController
                                  : _amountpercentageContorller,
                              label: _selectedDiscountType == DiscountType.amount ? 'Amount' : 'Percentage',
                              hint: _selectedDiscountType == DiscountType.amount ? 'Enter amount' : 'Enter percentage',
                              icon: _selectedDiscountType == DiscountType.amount ? Icons.currency_rupee : Icons.percent,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: discountApply
                                    ? Colors.red.shade400
                                    : AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(vertical: isTablet ? 18 : 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  if (discountApply) {
                                    // Cancel
                                    discountApply = false;
                                    _amountController.clear();
                                    _amountpercentageContorller.clear();
                                    DiscountPercentage = 0;
                                  } else {
                                    // Apply
                                    discountApply = true;
                                  }
                                });
                              },
                              child: Text(
                                discountApply ? 'Cancel' : 'Apply',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 5),

                      if (discountApply && calculations.discountAmount > 0) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Discount Reason',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: remarkList.map((reason) {
                            final isSelected = SelectedRemark == reason;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => SelectedRemark = reason),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.divider,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  reason,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      SizedBox(height: 5),

                      if (calculations.discountAmount != null &&
                          calculations.discountAmount! > 0 &&
                          SelectedRemark == 'other')
                        AppTextField(
                          controller: _remarkController,
                          label: 'Remark',
                          hint: 'Enter remark',
                          icon: Icons.note_alt_outlined,
                        ),
                      SizedBox(height: 5),

                      // Bill Summary
                      _buildBillSummary(calculations, pointsDiscount: pointsDiscount)
                        ],
                      ),
                    ]),
                    )],
                ),
              ),

              // Payment Method Card
              Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ExpansionTile(
                  backgroundColor: Colors.white,
                  collapsedBackgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  initiallyExpanded: true,
                  title: Row(
                    children: [
                      Icon(Icons.payment, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Payment Method',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SplitPaymentWidget(
                        billTotal: netPayable,
                        onPaymentChanged: _onPaymentChanged,
                        onValidationChanged: _onValidationChanged,
                      ),
                    ),
                  ],
                ),
              ),

                  ],
                ),
              ),
            ),
          ),
          // Proceed Button — pinned at bottom
          Container(
            color: AppColors.surfaceLight,
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: isTablet ? 54 : 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPaymentValid ? AppColors.primary : AppColors.textSecondary,
                  foregroundColor: Colors.white,
                  elevation: _isPaymentValid ? 2 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: (_isPaymentValid && !_isProcessing) ? () => _submitOrder(calculations) : null,
                child: _isProcessing
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(
                        'Proceed to Checkout',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 17 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPercentageButton(String text, double percentage) {
    final isSelected = _amountpercentageContorller.text == percentage.toString();

    return InkWell(
      onTap: () {
        setState(() {
          _amountpercentageContorller.text = percentage.toString();
          discountApply = true;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          border: Border.all(
            width: 1.5,
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

// ✅ Mode-aware labels matching PetPooja/Billberry standard
  Widget _buildBillSummary(CartCalculationService calcs, {int pointsDiscount = 0}) {
    final isInclusive = AppSettings.isTaxInclusive;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          // Item Total (with mode-aware label)
          _buildSummaryRow(
            isInclusive ? 'Item Total (Incl GST):' : 'Item Total:',
            '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(calcs.itemTotal)}'
          ),

          // Discount
          if (calcs.discountAmount > 0.009)
            _buildSummaryRow(
              'Discount:',
              '-${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(calcs.discountAmount)}'
            ),

          // Divider after discount
          if (calcs.discountAmount > 0.009 || calcs.totalGST > 0.009)
            Divider(thickness: 1, height: 16),

          // Taxable Amount / Sub Total (mode-aware label)
          _buildSummaryRow(
            isInclusive ? 'Taxable Amount:' : 'Sub Total (Before Tax):',
            '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(calcs.subtotal)}'
          ),

          // GST (mode-aware label)
          if (calcs.totalGST > 0.009)
            _buildSummaryRow(
              isInclusive ? 'GST (Included):' : 'GST:',
              '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(calcs.totalGST)}'
            ),

          // Service/Delivery Charge
          if (calcs.serviceChargeAmount > 0.009)
            _buildSummaryRow(
                widget.orderType == 'Delivery'
                    ? 'Delivery Charge:'
                    : 'Service Charge:',
                '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(calcs.serviceChargeAmount)}'),

          // Round Off
          if (AppSettings.roundOff && calcs.roundOffAmount.abs() > 0.009)
            _buildSummaryRow(
                'Round Off:',
                '${calcs.roundOffAmount >= 0 ? '+' : ''}${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(calcs.roundOffAmount)}'),

          // Points Redeemed
          if (pointsDiscount > 0)
            _buildSummaryRow(
              'Points Redeemed:',
              '-${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(pointsDiscount.toDouble())}',
              color: Colors.amber.shade700,
            ),

          // Final divider before grand total
          Divider(thickness: 2, height: 20),

          // Net Payable
          _buildSummaryRow(
              pointsDiscount > 0 ? 'Net Payable:' : 'Grand Total:',
              '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(calcs.grandTotal - pointsDiscount)}',
              isBold: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
          Text(value,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  double _toDouble(TextEditingController c, {double fallback = 0}) {
    final s = c.text.trim();
    if (s.isEmpty) return fallback;
    final v = double.tryParse(s);
    return v ?? fallback;
  }

  // Split payment callbacks
  void _onPaymentChanged(List<PaymentEntry> payments, double totalPaid, double change) {
    setState(() {
      _paymentEntries = payments;
      _totalPaid = totalPaid;
      _changeReturn = change;
    });
  }

  void _onValidationChanged(bool isValid) {
    setState(() {
      _isPaymentValid = isValid;
    });
  }

  void _clear() {
    setState(() {
      if (discountApply) {
        discountApply = false;
        _amountpercentageContorller.clear();
        _amountController.clear();
        DiscountPercentage = 0;
      } else {
        discountApply = true;
      }
      // calculations.discountAmount = 0;
    });
  }

  Future<void> proceed(CartCalculationService calculations, {int pointsUsed = 0}) async {
    if (widget.existingModel == null || widget.tableid == null) {
      // _showSnackBar('Error: No active order or table found.', isError: true);
      NotificationService.instance.showError(
        'Error: No active order or table found.',
      );

      return;
    }
    // Prepare split payment data
    final paymentList = _paymentEntries.map((e) => e.toMap()).toList();
    final isSplit = _paymentEntries.length > 1;

    // Check if new items were added (settle without update)
    final List<CartItem> itemsToSettle = widget.cartitems ?? widget.existingModel!.items;
    final int previousItemCount = widget.existingModel!.itemCountAtLastKot ?? widget.existingModel!.items.length;
    final int currentItemCount = itemsToSettle.length;
    final bool hasNewItems = currentItemCount > previousItemCount;

    // Generate new KOT if items were added without updating order first
    List<int> finalKotNumbers = List<int>.from(widget.existingModel!.kotNumbers);
    List<int> finalKotBoundaries = List<int>.from(widget.existingModel!.kotBoundaries);

    if (hasNewItems) {
      // Generate a new KOT for the newly added items before settling
      final int newKotNumber = await orderStore.getNextKotNumber();
      finalKotNumbers.add(newKotNumber);
      finalKotBoundaries.add(currentItemCount);


      // Deduct stock for newly added items
      final newlyAddedItems = itemsToSettle.skip(previousItemCount).toList();
      await InventoryService.deductStockForOrder(newlyAddedItems);

      // Print KOT for the new items — kitchen needs to know what was added.
      // Build a temporary OrderModel containing only the new items for this KOT.
      if (mounted && AppSettings.generateKOT) {
        try {
          final kotOrder = widget.existingModel!.copyWith(
            items: newlyAddedItems, // Only the new items for this KOT
            kotNumbers: [newKotNumber],
            kotBoundaries: [newlyAddedItems.length],
            itemCountAtLastKot: newlyAddedItems.length,
          );
          await RestaurantPrintHelper.printKOT(
            context: context,
            order: kotOrder,
            kotNumber: newKotNumber,
            autoPrint: true,
          );
        } catch (e) {
        }
      }
    }

    // Get current session ID
    final currentSessionId = await DayManagementService.getCurrentSessionId();

    final OrderModel completedOrder = widget.existingModel!.copyWith(
      items: itemsToSettle, // Use updated items if provided
      kotNumbers: finalKotNumbers, // Include new KOT if generated
      kotBoundaries: finalKotBoundaries, // Update boundaries
      itemCountAtLastKot: currentItemCount, // Update item count
      customerName: _nameController.text.trim(),
      customerNumber: _mobileController.text.trim(),
      customerEmail: _emailController.text.trim(),
      discount: calculations.discountAmount,
      // serviceCharge: widget.orderType == 'Delivery'?calculations.deliveryCharge: calculations.serviceChargeAmount,
      serviceCharge: calculations.serviceChargeAmount,
      totalPrice: calculations.grandTotal - pointsUsed, // net payable after points
      paymentMethod: isSplit ? 'Split Payment' : _paymentEntries.first.method,
      completedAt: DateTime.now(),
      status: 'Cooking',
      tableNo: widget.tableid,
      isPaid: true,
      paymentStatus: 'Paid',
      customerId: selectedCustomer?.customerId, // Link to customer
      // Split payment fields
      paymentListJson: jsonEncode(paymentList),
      isSplitPayment: isSplit,
      totalPaid: _totalPaid,
      changeReturn: _changeReturn,
      sessionId: currentSessionId ?? widget.existingModel!.sessionId, // Ensure sessionId is preserved/attached
    );
    try {
      // For Dine In orders that haven't been served yet: just record the payment
      // and keep the order active so kitchen/staff can still serve it.
      // The order will move to past automatically when staff marks it as Served.
      final bool isDineIn = (widget.existingModel!.orderType == 'Dine In');
      final bool alreadyServed = (widget.existingModel!.status == 'Served');

      if (isDineIn && !alreadyServed) {
        // Generate a bill number now so the receipt can show "Bill No" immediately
        final int billNumber = await orderStore.getNextBillNumber();

        // Store the bill number on the order so later prints use the same number
        final orderWithBill = completedOrder.copyWith(billNumber: billNumber);
        await orderStore.updateOrder(orderWithBill);
        await restaurantCartStore.clearCart();
        if (selectedCustomer != null) {
          if (pointsUsed > 0) {
            await restaurantCustomerStore.updateCustomerVisit(
              customerId: selectedCustomer!.customerId, orderType: '', pointsToAdd: -pointsUsed);
          }
          final int earned = ((calculations.grandTotal - pointsUsed) / 100).floor();
          await _updateCustomerStats(selectedCustomer!, 'Dine In', pointsToEarn: earned);
        }

        // Show success + print dialog (same as completed orders)
        await _showOrderSuccessDialog(orderWithBill, calculations, billNumber: billNumber, pointsUsed: pointsUsed);
        return;
      }

      // Take Away / Delivery / already Served → complete immediately
      final int billNumber = await completeOrder(completedOrder, calculations, pointsUsed: pointsUsed);

      // Update customer stats if customer is linked
      if (selectedCustomer != null) {
        if (pointsUsed > 0) {
          await restaurantCustomerStore.updateCustomerVisit(
            customerId: selectedCustomer!.customerId, orderType: '', pointsToAdd: -pointsUsed);
        }
        final int earned = ((calculations.grandTotal - pointsUsed) / 100).floor();
        await _updateCustomerStats(selectedCustomer!, widget.orderType ?? 'Take Away', pointsToEarn: earned);
      }

      // Clear the cart after successful settlement
      await restaurantCartStore.clearCart();

      await tableStore.updateTableStatus(widget.tableid!, 'Available');

      NotificationService.instance.showSuccess(
        'Order Completed Successfully!',
      );

      // Show success dialog with print option
      await _showOrderSuccessDialog(completedOrder, calculations, billNumber: billNumber, pointsUsed: pointsUsed);
    } catch (e) {
      NotificationService.instance.showError(
        'Failed to proceed with the order: $e',
      );
    }
  }

  Future<int> completeOrder(
      OrderModel activeModel, CartCalculationService calculations, {int pointsUsed = 0}) async {

    // Note: calculations.subtotal is already the base price (without tax)
    // CartCalculationService handles tax extraction for tax-inclusive mode

    // Generate daily bill number for completed order
    final int billNumber = await orderStore.getNextBillNumber();

    // Get current session ID or fallback to order's session
    final currentSessionId = await DayManagementService.getCurrentSessionId();

    final pastOrder = PastOrderModel(
      id: activeModel.id,
      customerName: activeModel.customerName,
      totalPrice: activeModel.totalPrice, // already net payable (set in proceed)
      items: activeModel.items,
      orderAt: activeModel.timeStamp,
      orderType: activeModel.orderType,
      paymentmode: _paymentEntries.isNotEmpty
          ? (_paymentEntries.length > 1 ? 'Split Payment' : _paymentEntries.first.method)
          : 'Cash',
      remark:
          SelectedRemark == 'other' ? _remarkController.text : SelectedRemark,
      Discount: activeModel.discount, // regular discount only
      loyaltyPointsUsed: pointsUsed > 0 ? pointsUsed : null,
      subTotal: calculations.subtotal,
      gstRate: 0,
      gstAmount: calculations.totalGST,
      kotNumbers: activeModel.kotNumbers, // Always present in new orders
      kotBoundaries:
          activeModel.kotBoundaries, // KOT boundaries for grouping items
      billNumber: billNumber, // Daily bill number (resets every day)
      isTaxInclusive: AppSettings.isTaxInclusive, // Store tax mode at order creation
      tableNo: activeModel.tableNo,
      shiftId: RestaurantSession.currentShiftId,
      sessionId: currentSessionId ?? activeModel.sessionId, // Assign to current session to reflect payment
      discountAppliedBy: (activeModel.discount != null && activeModel.discount! > 0)
          ? (RestaurantSession.isAdmin ? 'Admin' : '${RestaurantSession.staffName ?? RestaurantSession.effectiveRole} (${RestaurantSession.effectiveRole})')
          : null,
      customerId: activeModel.customerId,
      serviceCharge: activeModel.serviceCharge,
      paymentListJson: activeModel.paymentListJson,
      isSplitPayment: activeModel.isSplitPayment,
      totalPaid: activeModel.totalPaid,
      changeReturn: activeModel.changeReturn,
    );
    // Idempotency guard: if this order is already in pastOrderBox (crash on previous
    // attempt between addOrder and deleteOrder), skip the write and just clean up.
    final alreadySettled = await pastOrderStore.getOrderById(activeModel.id);
    if (alreadySettled == null) {
      await pastOrderStore.addOrder(pastOrder);
    }
    // Always attempt delete — harmless if already deleted after a crash.
    await orderStore.deleteOrder(activeModel.id);

    return billNumber; // Return the generated bill number
  }

  Future<void> _placeOrder(CartCalculationService calculations, {int pointsUsed = 0}) async {

    // Note: calculations.subtotal is already the base price (without tax)
    // CartCalculationService handles tax extraction for tax-inclusive mode

    final int newKotNumber = await orderStore.getNextKotNumber();
    final String newId = Uuid().v4();
    final List<CartItem> orderItems = widget.cartitems ?? [];

    // Prepare split payment data
    final paymentList = _paymentEntries.map((e) => e.toMap()).toList();
    final isSplit = _paymentEntries.length > 1;
    final paymentMethodDisplay = isSplit ? 'Split Payment' : _paymentEntries.first.method;

    // Get current session ID
    final currentSessionId = await DayManagementService.getCurrentSessionId();

    // Check if this is a "Settle & Print" operation (immediate completion)
    if (widget.isSettle == true) {
      // Generate bill number for immediate settlement
      final int billNumber = await orderStore.getNextBillNumber();

      // Create completed order directly (skip active orders)
      final pastOrder = PastOrderModel(
        id: newId,
        customerName: _nameController.text.trim(),
        totalPrice: calculations.grandTotal - pointsUsed, // net payable after points
        items: orderItems,
        orderAt: DateTime.now(),
        orderType: widget.orderType ?? 'Take Away',
        paymentmode: paymentMethodDisplay,
        remark: calculations.discountAmount > 0.009 ? SelectedRemark : 'no Remark',
        Discount: calculations.discountAmount, // regular discount only
        subTotal: calculations.subtotal,
        gstRate: 0,
        gstAmount: calculations.totalGST,
        kotNumbers: [newKotNumber],
        kotBoundaries: [orderItems.length],
        billNumber: billNumber, // Daily bill number
        // Split payment fields
        paymentListJson: jsonEncode(paymentList),
        isSplitPayment: isSplit,
        totalPaid: _totalPaid,
        changeReturn: _changeReturn,
        isTaxInclusive: AppSettings.isTaxInclusive, // Store tax mode at order creation
        tableNo: widget.orderType == 'Dine In' ? widget.tableid : null,
        loyaltyPointsUsed: pointsUsed > 0 ? pointsUsed : null,
        shiftId: RestaurantSession.currentShiftId,
        sessionId: currentSessionId, // Link to POS session
        discountAppliedBy: calculations.discountAmount > 0.009
            ? (RestaurantSession.isAdmin ? 'Admin' : '${RestaurantSession.staffName ?? RestaurantSession.effectiveRole} (${RestaurantSession.effectiveRole})')
            : null,
        customerId: selectedCustomer?.customerId,
        serviceCharge: calculations.serviceChargeAmount,
      );

      try {
        await pastOrderStore.addOrder(pastOrder);

        // Deduct stock for direct settlement (order not placed first)
        await InventoryService.deductStockForOrder(orderItems);

        // Update customer stats if customer is linked
        if (selectedCustomer != null) {
          if (pointsUsed > 0) {
            await restaurantCustomerStore.updateCustomerVisit(
              customerId: selectedCustomer!.customerId, orderType: '', pointsToAdd: -pointsUsed);
          }
          final int earned = ((calculations.grandTotal - pointsUsed) / 100).floor();
          await _updateCustomerStats(selectedCustomer!, widget.orderType ?? 'Take Away', pointsToEarn: earned);
        }

        await restaurantCartStore.clearCart();

        // Auto-print KOT to kitchen — the kitchen needs to know what to
        // make even for direct-settle orders (e.g., takeaway paid upfront).
        // Uses the same thermal path as regular orders.
        if (mounted && AppSettings.generateKOT) {
          try {
            // Build a temporary OrderModel for KOT printing (printKOT needs OrderModel)
            final kotOrder = OrderModel(
              id: newId,
              customerName: _nameController.text.trim(),
              customerNumber: _mobileController.text.trim(),
              customerEmail: _emailController.text.trim(),
              items: orderItems,
              status: 'Processing',
              timeStamp: DateTime.now(),
              orderType: widget.orderType ?? 'Take Away',
              tableNo: widget.tableid ?? '',
              totalPrice: calculations.grandTotal,
              kotNumbers: [newKotNumber],
              itemCountAtLastKot: orderItems.length,
              kotBoundaries: [orderItems.length],
              orderNumber: null,
            );
            await RestaurantPrintHelper.printKOT(
              context: context,
              order: kotOrder,
              kotNumber: newKotNumber,
              autoPrint: true,
            );
          } catch (e) {
          }
        }

        NotificationService.instance.showSuccess(
          'Order Settled Successfully',
        );

        // Show success dialog with bill number for printing
        await _showOrderSuccessDialogWithBillNumber(pastOrder, calculations, billNumber, pointsUsed: pointsUsed);
      } catch (e) {
        NotificationService.instance.showError(
          'Failed to settle order: $e',
        );
      }
      return;
    }

    // Regular order placement (for kitchen - active order)
    final newOrder = OrderModel(
      id: newId,
      // kotNumber removed - using kotNumbers only
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
      gstAmount: calculations.totalGST
      ,
      totalPrice: calculations.grandTotal,
      paymentMethod: paymentMethodDisplay,
      completedAt: null,
      paymentStatus: "Unpaid",
      isPaid: false,
      remark:
          calculations.discountAmount > 0.009 ? SelectedRemark : 'no Remark',
      // Initialize KOT tracking fields - single source of truth
      kotNumbers: [newKotNumber],
      itemCountAtLastKot: orderItems.length,
      kotBoundaries: [orderItems.length], // First KOT boundary at item count
      customerId: selectedCustomer?.customerId, // Link to customer
      sessionId: currentSessionId, // Stamp session at placement so settlement always has a reference
      // Split payment fields
      paymentListJson: jsonEncode(paymentList),
      isSplitPayment: isSplit,
      totalPaid: _totalPaid,
      changeReturn: _changeReturn,
      isTaxInclusive: AppSettings.isTaxInclusive, // Store tax mode at order creation
    );
    try {
      await orderStore.addOrder(newOrder);

      // NOTE: Customer stats (visits + points) are updated at settlement, NOT here.
      // Updating here would cause double-counting when the order is later settled.

      if (widget.tableid != null && widget.tableid!.isNotEmpty) {
        await tableStore.updateTableStatus(
          widget.tableid!,
          'Running',
          total: newOrder.totalPrice,
          orderTime: newOrder.timeStamp,
        );
      }
      // _showSnackBar('New order placed successfully!');
      NotificationService.instance.showSuccess(
        'New Order Placed Successfully',
      );

      await restaurantCartStore.clearCart();

      // Show success dialog with print option
      await _showOrderSuccessDialog(newOrder, calculations);
    } catch (e) {
      // _showSnackBar('Failed to create new order: $e', isError: true);
      NotificationService.instance.showError(
        'Failed to create new order: $e',
      );
    }
  }

  // Success dialog with print option (newly placed order)
  Future<void> _showOrderSuccessDialog(
      OrderModel order, CartCalculationService calculations, {int? billNumber, int pointsUsed = 0}) async {
    await _showSuccessDialog(
      order: order,
      calculations: calculations,
      billNumber: billNumber,
      pointsUsed: pointsUsed,
      title: 'Order Placed!',
      printLabel: 'Print Receipt',
    );
  }

  // Success dialog for settled orders (with bill number)
  Future<void> _showOrderSuccessDialogWithBillNumber(
      PastOrderModel pastOrder, CartCalculationService calculations, int billNumber, {int pointsUsed = 0}) async {
    if (!mounted) return;

    // Convert pastOrderModel to OrderModel for printing
    final orderForPrint = OrderModel(
      id: pastOrder.id,
      customerName: pastOrder.customerName,
      customerNumber: '',
      customerEmail: '',
      items: pastOrder.items,
      status: 'Completed',
      timeStamp: pastOrder.orderAt ?? DateTime.now(),
      orderType: pastOrder.orderType ?? 'Take Away',
      tableNo: pastOrder.tableNo,
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
      isTaxInclusive: pastOrder.isTaxInclusive, // Use stored tax mode from past order
      // Carry split-payment data so the bill can print the per-method breakdown.
      isSplitPayment: pastOrder.isSplitPayment,
      paymentListJson: pastOrder.paymentListJson,
      totalPaid: pastOrder.totalPaid,
      changeReturn: pastOrder.changeReturn,
    );

    await _showSuccessDialog(
      order: orderForPrint,
      calculations: calculations,
      billNumber: billNumber,
      pointsUsed: pointsUsed,
      title: 'Order Settled!',
      printLabel: 'Print Bill',
    );
  }

  /// Shared success dialog for both newly placed and settled orders.
  /// Green header band + order summary + Done / Print actions.
  Future<void> _showSuccessDialog({
    required OrderModel order,
    required CartCalculationService calculations,
    required int? billNumber,
    required int pointsUsed,
    required String title,
    required String printLabel,
  }) async {
    if (!mounted) return;

    final sym = CurrencyHelper.currentSymbol;
    final paid = order.totalPaid ?? 0;
    final change = order.changeReturn ?? 0;
    final method = (order.isSplitPayment ?? false)
        ? 'Split'
        : (order.paymentMethod ?? '').trim();
    final noun = printLabel.toLowerCase().contains('bill') ? 'bill' : 'receipt';
    String cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Green header band ────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (billNumber != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Bill #INV$billNumber',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Body ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Order summary
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          children: [
                            _summaryRow('Total',
                                '$sym${DecimalSettings.formatAmount(order.totalPrice)}',
                                emphasize: true),
                            if (paid > 0) ...[
                              const SizedBox(height: 10),
                              _summaryRow('Paid', '$sym${DecimalSettings.formatAmount(paid)}'),
                            ],
                            if (change > 0) ...[
                              const SizedBox(height: 10),
                              _summaryRow('Change', '$sym${DecimalSettings.formatAmount(change)}'),
                            ],
                            if (method.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _summaryRow('Payment', cap(method)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Would you like to print the $noun?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _navigateToHome();
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                side: BorderSide(color: AppColors.divider),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Done',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await RestaurantPrintHelper.printOrderReceipt(
                                  context: context,
                                  order: order,
                                  calculations: calculations,
                                  billNumber: billNumber,
                                  loyaltyPointsDiscount: pointsUsed,
                                );
                                // User stays on dialog — press Done to go home
                              },
                              icon: const Icon(Icons.print_rounded, size: 20),
                              label: Text(
                                printLabel,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: emphasize ? 14 : 13,
            fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
            color: emphasize ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: emphasize ? 16 : 13.5,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
            color: emphasize ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const Startorder()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> clearCart() async {
    try {
      await restaurantCartStore.clearCart();
      if (mounted) {
        NotificationService.instance.showInfo(
          'Cart cleared',
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError(
          'Error clearing cart',
        );
      }
    }
  }

  // Update customer statistics (visits, loyalty points, last visit, etc.)
  Future<void> _updateCustomerStats(RestaurantCustomer customer, String orderType, {int pointsToEarn = 0}) async {
    try {

      await restaurantCustomerStore.updateCustomerVisit(
        customerId: customer.customerId,
        orderType: orderType,
        pointsToAdd: pointsToEarn,
      );

      // Verify the update
      final updatedCustomer = await restaurantCustomerStore.getCustomerById(customer.customerId);
      if (updatedCustomer != null) {
      } else {
      }
    } catch (e) {
    }
  }

  /// If the user typed a name or phone but did not select from autocomplete,
  /// find-or-create a customer record and link them to this order.
  Future<void> _autoSaveNewCustomer() async {
    if (selectedCustomer != null) return; // already linked via autocomplete

    final name = _nameController.text.trim();
    final phone = _mobileController.text.trim();
    if (name.isEmpty && phone.isEmpty) return; // nothing entered

    try {
      // Search by phone first to avoid creating duplicates
      if (phone.isNotEmpty) {
        final results = await restaurantCustomerStore.searchCustomers(phone);
        final match = results.where((c) => c.phone == phone).firstOrNull;
        if (match != null) {
          if (mounted) setState(() => selectedCustomer = match);
          return;
        }
      }

      // Search by name if phone didn't match
      if (name.isNotEmpty) {
        final results = await restaurantCustomerStore.searchCustomers(name);
        final match = results.where((c) =>
          c.name?.toLowerCase() == name.toLowerCase() &&
          (phone.isEmpty || c.phone == phone)
        ).firstOrNull;
        if (match != null) {
          if (mounted) setState(() => selectedCustomer = match);
          return;
        }
      }

      // No existing customer found — create new
      final newCustomer = RestaurantCustomer.create(
        customerId: const Uuid().v4(),
        name: name.isNotEmpty ? name : null,
        phone: phone.isNotEmpty ? phone : null,
      );
      final saved = await restaurantCustomerStore.addCustomer(newCustomer);
      if (saved && mounted) {
        setState(() => selectedCustomer = newCustomer);
      }
    } catch (e) {
      // Non-fatal — order proceeds even if customer save fails
    }
  }

  Future<void> _submitOrder(CartCalculationService calculations) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _doSubmitOrder(calculations);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _doSubmitOrder(CartCalculationService calculations) async {
    // No active day session yet → start the day (opening balance) right here,
    // then continue. The day begins at the first order/settlement.
    final bool sessionOpen = await DayManagementService.isSessionOpen();
    if (!sessionOpen) {
      final started = await promptStartDay(context);
      if (!started) {
        if (mounted) {
          NotificationService.instance.showError('Start the day to place the order');
        }
        return;
      }
    }

    // Validate mobile number if entered
    final phone = _mobileController.text.trim();
    if (phone.isNotEmpty) {
      final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length != 10) {
        setState(() => _mobileError = 'Mobile number must be exactly 10 digits');
        return;
      }
    }
    setState(() => _mobileError = null);

    // Compute points usage
    final int availablePoints = selectedCustomer?.loyaltyPoints ?? 0;
    final int pointsUsed = (_usePoints && availablePoints > 0)
        ? availablePoints.clamp(0, calculations.grandTotal.floor())
        : 0;

    // Guard: re-check payment validity. Skip when bill is fully covered by loyalty points.
    final bool fullyCoveredByPoints = (calculations.grandTotal - pointsUsed) <= 0;
    if (!_isPaymentValid && !fullyCoveredByPoints) {
      NotificationService.instance.showError('Please complete payment details before proceeding.');
      return;
    }

    // Auto-save customer if name/phone was typed but not picked from list
    await _autoSaveNewCustomer();

    if (selectedCustomer != null) {
    } else {
    }

    if (widget.isSettle == true) {
      await _placeOrder(calculations, pointsUsed: pointsUsed);
    } else {
      await proceed(calculations, pointsUsed: pointsUsed);
    }
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

