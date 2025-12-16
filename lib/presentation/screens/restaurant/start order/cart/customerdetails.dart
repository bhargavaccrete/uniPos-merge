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

class _CustomerdetailsState extends State<Customerdetails> {
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
    );

    // ✅ Step 3: Build the UI using the final, calculated values.
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: Text('Customer Details'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              CommonTextForm(
                controller: _nameController,
                borderc: 5,
                obsecureText: false,
                BorderColor: primarycolor,
                labelText: 'Name',
                LabelColor: primarycolor,
                focusNode: namenode,
                onfieldsumbitted: (v) {
                  FocusScope.of(context).requestFocus(emailnode);
                },
              ),
              SizedBox(height: 10),
              CommonTextForm(
                  focusNode: emailnode,
                  controller: _emailController,
                  borderc: 5,
                  BorderColor: primarycolor,
                  labelText: 'Email Id (optional)',
                  LabelColor: primarycolor,
                  obsecureText: false),
              SizedBox(height: 10),
              CommonTextForm(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                borderc: 5,
                BorderColor: primarycolor,
                labelText: 'Mobile No',
                LabelColor: primarycolor,
                obsecureText: false,
                icon: CountryCodePicker(
                  padding: EdgeInsets.all(10),
                  initialSelection: 'IN',
                  favorite: ['+91', 'IN'],
                  showCountryOnly: false,
                  showFlag: false,
                ),
                focusNode: mobilenode,
                onfieldsumbitted: (v) {
                  FocusScope.of(context).requestFocus(namenode);
                },
              ),
              SizedBox(height: 10),

              widget.orderType == 'Delivery'
                  ? Column(
                      children: [
                        Divider(),
                        Text(
                          'Address',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(
                          height: 5,
                        ),
                        CommonTextForm(
                          obsecureText: false,
                          controller: _houseController,
                          borderc: 10,
                          BorderColor: primarycolor,
                          // HintColor: primarycolor,
                          // hintText: 'Name',
                          labelText: 'House NO',
                          LabelColor: primarycolor,
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        CommonTextForm(
                          obsecureText: false,
                          controller: _stateController,
                          borderc: 10,
                          BorderColor: primarycolor,
                          // HintColor: primarycolor,
                          // hintText: 'Name',
                          labelText: 'State',
                          LabelColor: primarycolor,
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        CommonTextForm(
                          obsecureText: false,
                          borderc: 10,
                          BorderColor: primarycolor,
                          // HintColor: primarycolor,
                          // hintText: 'Name',
                          controller: _cityController,
                          labelText: 'City',
                          LabelColor: primarycolor,
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        CommonTextForm(
                          obsecureText: false,
                          borderc: 10,
                          BorderColor: primarycolor,
                          // HintColor: primarycolor,
                          // hintText: 'Name',
                          controller: _areaController,
                          labelText: 'Area',
                          LabelColor: primarycolor,
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        CommonTextForm(
                          obsecureText: false,
                          borderc: 10,
                          BorderColor: primarycolor,
                          // HintColor: primarycolor,
                          // hintText: 'Name',
                          controller: _postCodeController,
                          labelText: 'Post Code',
                          LabelColor: primarycolor,
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Divider(),
                      ],
                    )
                  : SizedBox(),

              Row(
                children: [
                  Expanded(
                      flex: 2,
                      child: CommonTextForm(
                          controller: _serviceChargeController,
                          borderc: 5,
                          BorderColor: Colors.grey,
                          labelText: widget.orderType == 'Delivery'
                              ? 'Delivery Charge'
                              : 'Service Charges(%)',
                          LabelColor: Colors.grey,
                          obsecureText: false)),
                  SizedBox(width: 5),
                  Expanded(
                    child: CommonButton(
                        bordercircular: 5,
                        height: height * 0.05,
                        bgcolor: servicechargeapply
                            ? Colors.red.shade300
                            : primarycolor,
                        bordercolor: servicechargeapply
                            ? Colors.red.shade300
                            : primarycolor,
                        onTap: () {
                          servicechargeapply == false
                              ? setState(() {
                                  servicechargeapply = true;
                                })
                              : setState(() {
                                  servicechargeapply = false;
                                  _serviceChargeController.clear();
                                });
                        },
                        child: Text(servicechargeapply ? 'Cancel' : 'Apply',
                            style: TextStyle(
                                color: servicechargeapply
                                    ? Colors.black
                                    : Colors.white)))
                  )
                ],
              ),
              SizedBox(height: 10),

              ExpansionTile(
                title: Text('Discount'),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: Text('Amount',
                              style: GoogleFonts.poppins(fontSize: 12)),
                          leading: Radio<DiscountType>(
                              value: DiscountType.amount,
                              groupValue: _selectedDiscountType,
                              onChanged: (value) => setState(() {
                                    _selectedDiscountType = value!;
                                  })),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: Text('Percentage',
                              style: GoogleFonts.poppins(fontSize: 12)),
                          leading: Radio<DiscountType>(
                              value: DiscountType.percentage,
                              groupValue: _selectedDiscountType,
                              onChanged: (value) => setState(() {
                                    _selectedDiscountType = value!;
                                  })),
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
                              child: CommonTextForm(
                                  controller:
                                      _selectedDiscountType == DiscountType.amount
                                          ? _amountController
                                          : _amountpercentageContorller,
                                  borderc: 10,
                                  BorderColor: Colors.grey,
                                  labelText:
                                      _selectedDiscountType == DiscountType.amount
                                          ? 'Enter Amount'
                                          : "Enter Percentage",
                                  LabelColor: Colors.grey,
                                  obsecureText: false)),
                          SizedBox(width: 5),
                          Expanded(
                            child: CommonButton(
                              bordercircular: 5,
                              height: height * 0.05,
                              bgcolor: discountApply
                                  ? Colors.red.shade300
                                  : primarycolor,
                              bordercolor: discountApply
                                  ? Colors.red.shade300
                                  : primarycolor,
                              onTap: () {
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
                                style: TextStyle(
                                  color: discountApply
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 5),

                      if (discountApply && calculations.discountAmount > 0)
                        Container(
                          width: width,
                          height: height * 0.07,
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey)),
                          child: DropdownButtonHideUnderline(
                              child: DropdownButton(
                                  value: SelectedRemark,
                                  items: remarkList.map((String dropdownValue) {
                                    return DropdownMenuItem(
                                      child: Text(dropdownValue),
                                      value: dropdownValue,
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      SelectedRemark = newValue!;
                                    });
                                  })),
                        ),
                      SizedBox(height: 5),

                      if (calculations.discountAmount != null &&
                          calculations.discountAmount! > 0 &&
                          SelectedRemark == 'other')
                        CommonTextForm(
                          controller: _remarkController,
                          borderc: 5,
                          obsecureText: false,
                          labelText: 'Remark',
                        ),
                      SizedBox(height: 5),

                      // Bill Summary
                      _buildBillSummary(calculations)
                    ],
                  )
                ],
              ),
              ExpansionTile(
                title: Text('Payment Method'),
                children: [
                  // ✅ Dynamic payment methods - only shows enabled methods from setup wizard
                  Observer(
                    builder: (_) {
                      final paymentStore = locator<PaymentMethodStore>();

                      // Get only enabled payment methods
                      final enabledMethods = paymentStore.paymentMethods
                          .where((method) => method.isEnabled)
                          .toList();

                      // If no payment methods enabled, show fallback
                      if (enabledMethods.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'No payment methods enabled. Please enable payment methods in Settings.',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceAround,
                        children: enabledMethods.map((method) {
                          return Filterbutton(
                            title: method.name,
                            selectedFilter: SelectedFilter,
                            onpressed: () {
                              setState(() {
                                SelectedFilter = method.name!;
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: 15),
              CommonButton(
                child: Text('Procced ',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                height: height * 0.06,
                onTap: () => _submitOrder(calculations),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPercentageButton(String text, double percentage) {
    return InkWell(
      onTap: () {
        setState(() {
          _amountpercentageContorller.text = percentage.toString();
          discountApply = false;
          // DiscountPercentage = percentage;
        });
      },
      child: Container(
        child: Text(text, style: GoogleFonts.poppins(fontSize: 16)),
        padding: EdgeInsets.all(5),
        decoration: BoxDecoration(
            border: Border.all(width: 1, color: Colors.grey),
            shape: BoxShape.rectangle),
      ),
    );
  }

// ✅ This widget is now simple and only displays data.
  Widget _buildBillSummary(CartCalculationService calcs) {
    double subtotal = AppSettings.isTaxInclusive
        ? calcs.subtotal - calcs.totalGST
        : calcs.subtotal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          _buildSummaryRow('Sub Total:', '₹${subtotal.toStringAsFixed(2)}'),
          if (calcs.discountAmount > 0.009)
            _buildSummaryRow('Total Discount:',
                '-₹${calcs.discountAmount.toStringAsFixed(2)}'),
          if (calcs.totalGST > 0.009)
            (AppSettings.isTaxInclusive
                ? _buildSummaryRow('Total GST(Inclusive):',
                    '₹${calcs.totalGST.toStringAsFixed(2)}')
                : _buildSummaryRow(
                    'Total GST:', '₹${calcs.totalGST.toStringAsFixed(2)}')),

          if (calcs.serviceChargeAmount > 0.009)
            _buildSummaryRow(
                widget.orderType == 'Delivery'
                    ? 'Delivery Charge:'
                    : 'Service Charge:',
                '₹${calcs.serviceChargeAmount.toStringAsFixed(2)}'),

          Divider(thickness: 2, height: 20),
          _buildSummaryRow(
              'Grand Total:', '₹${calcs.grandTotal.toStringAsFixed(2)}',
              isBold: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
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

  Future<void> proceed(CartCalculationService calculations) async {
    print('============THis is PRocced Function=============');
    if (widget.existingModel == null || widget.tableid == null) {
      // _showSnackBar('Error: No active order or table found.', isError: true);
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
      // serviceCharge: widget.orderType == 'Delivery'?calculations.deliveryCharge: calculations.serviceChargeAmount,
      serviceCharge: calculations.serviceChargeAmount,
      totalPrice: calculations.grandTotal,
      paymentMethod: SelectedFilter,
      completedAt: DateTime.now(),
      status: 'Cooking',
      tableNo: widget.tableid,
    );
    try {
      await completeOrder(completedOrder, calculations);
      await HiveTables.updateTableStatus(widget.tableid!, 'Available');
      // _showSnackBar('Order Completed Successfully!');

      NotificationService.instance.showSuccess(
        'Order Completed Successfully!',
      );

      // Show success dialog with print option
      await _showOrderSuccessDialog(completedOrder, calculations);
    } catch (e) {
      // _showSnackBar('Failed to proceed with the order: $e', isError: true);
      NotificationService.instance.showError(
        'Failed to proceed with the order: $e',
      );
    }
  }

  Future<void> completeOrder(
      OrderModel activeModel, CartCalculationService calculations) async {
    print('============this is complete order function=============');

    double preTaxSubtotal = AppSettings.isTaxInclusive
        ? calculations.subtotal - calculations.totalGST
        : calculations.subtotal;

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
      subTotal: preTaxSubtotal,
      gstRate: 0,
      gstAmount: calculations.totalGST,
      kotNumbers: activeModel.kotNumbers, // Always present in new orders
      kotBoundaries:
          activeModel.kotBoundaries, // KOT boundaries for grouping items
    );
    await HivePastOrder.addOrder(pastOrder);
    await HiveOrders.deleteOrder(activeModel.id);
  }

  Future<void> _placeOrder(CartCalculationService calculations) async {
    print('============this is place order function=============');
    print(widget.orderType);

    double preTaxSubtotal = AppSettings.isTaxInclusive
        ? calculations.subtotal - calculations.totalGST
        : calculations.subtotal;

    final int newKotNumber = await HiveOrders.getNextKotNumber();
    final String newId = Uuid().v4();
    final List<CartItem> orderItems = widget.cartitems ?? [];
    final newOrder = OrderModel(
      id: newId,
      // kotNumber removed - using kotNumbers only
      customerName: _nameController.text.trim(),
      customerNumber: _mobileController.text.trim(),
      customerEmail: _emailController.text.trim(),
      items: orderItems,
      status: 'Cooking',
      timeStamp: DateTime.now(),
      orderType: widget.orderType ?? 'Take Away',
      tableNo: widget.tableid ?? '',
      subTotal: preTaxSubtotal,
      discount: calculations.discountAmount,
      serviceCharge: calculations.serviceChargeAmount,
      gstRate: 0,
      gstAmount: calculations.totalGST
      ,
      totalPrice: calculations.grandTotal,
      paymentMethod: SelectedFilter,
      completedAt: null,
      paymentStatus: "Paid",
      isPaid: true,
      remark:
          calculations.discountAmount > 0.009 ? SelectedRemark : 'no Remark',
      // Initialize KOT tracking fields - single source of truth
      kotNumbers: [newKotNumber],
      itemCountAtLastKot: orderItems.length,
      kotBoundaries: [orderItems.length], // First KOT boundary at item count
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
      // _showSnackBar('New order placed successfully!');
      NotificationService.instance.showSuccess(
        'New Order Placed Successfully',
      );

      await HiveCart.clearCart();

      // Show success dialog with print option
      await _showOrderSuccessDialog(newOrder, calculations);
    } catch (e) {
      // _showSnackBar('Failed to create new order: $e', isError: true);
      NotificationService.instance.showError(
        'Failed to create new order: $e',
      );
    }
  }

  // Success dialog with print option
  Future<void> _showOrderSuccessDialog(
      OrderModel order, CartCalculationService calculations) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 50),
            const SizedBox(height: 10),
            Text(
              'Order Successful',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Order has been placed successfully.\nDo you want to print the receipt?',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _navigateToHome(); // Go to home
            },
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await RestaurantPrintHelper.printOrderReceipt(
                context: context,
                order: order,
                calculations: calculations,
              );
              // We don't close the dialog automatically after print,
              // allowing user to print again or close manually
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print Receipt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primarycolor,
              foregroundColor: Colors.white,
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
      MaterialPageRoute(builder: (context) => const Startorder()),
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
