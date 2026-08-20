import 'package:flutter/material.dart';
import 'package:billberrylite/util/common/short_ref.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/config/phone_rule.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/screens/retail/sale_detail_screen.dart';
import 'package:billberrylite/presentation/screens/retail/receive_payment_screen.dart';
import 'package:billberrylite/presentation/screens/retail/customer_ledger_screen.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SaleModel> _customerSales = [];
  bool _isLoading = true;
  late Customer _customer;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _tabController = TabController(length: 2, vsync: this);
    _loadCustomerSales();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerSales() async {
    setState(() => _isLoading = true);
    try {
      final sales = await saleStore.getSalesByCustomerId(_customer.customerId);
      setState(() {
        _customerSales = sales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshCustomer() async {
    final updated = await customerStore.getCustomerById(_customer.customerId);
    if (updated != null && mounted) {
      setState(() => _customer = updated);
    }
    await _loadCustomerSales();
  }

  /// Net of the customer's bills — a return is money going back out, so it
  /// subtracts. (The cards already render returns as negative.)
  /// A plain sum is already the net: `ReturnService` stores a return's
  /// subtotal/discount/tax/totalAmount as NEGATIVE values, so returns subtract
  /// themselves. Do not add a conditional minus here — it double-negates and
  /// makes a return increase the total.
  double get _netBilledAmount =>
      _customerSales.fold<double>(0, (sum, s) => sum + s.totalAmount);

  String _formatDate(String dateStr) {
    try {
      return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(dateStr));
    } catch (e) {
      return dateStr;
    }
  }

  String _formatShortDate(String dateStr) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr));
    } catch (e) {
      return dateStr;
    }
  }

  // ==================== EDIT ====================

  Future<void> _showEditCustomerDialog() async {
    final nameController = TextEditingController(text: _customer.name);
    final phoneController = TextEditingController(text: _customer.phone);
    final emailController = TextEditingController(text: _customer.email ?? '');
    final addressController = TextEditingController(
      text: _customer.address ?? '',
    );
    final notesController = TextEditingController(text: _customer.notes ?? '');
    final gstController = TextEditingController(
      text: _customer.gstNumber ?? '',
    );
    final creditLimitController = TextEditingController(
      text: _customer.creditLimit > 0
          ? _customer.creditLimit.toStringAsFixed(2)
          : '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => DialogDisposeScope(
        disposables: [
          nameController,
          phoneController,
          emailController,
          addressController,
          notesController,
          gstController,
          creditLimitController,
        ],
        child: AppDialogShell(
          title: 'Edit Customer',
          accent: AppColors.primary,
          icon: Icons.edit_outlined,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: nameController,
                label: 'Name',
                required: true,
                icon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: phoneController,
                label: 'Phone',
                hint: PhoneRule.hint,
                required: true,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                maxLength: PhoneRule.maxLength,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: PhoneRule.validate,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: emailController,
                label: 'Email',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: addressController,
                label: 'Address',
                icon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: gstController,
                label: 'GST Number',
                icon: Icons.badge_outlined,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: creditLimitController,
                label: 'Credit Limit',
                hint: '0 = Unlimited',
                icon: Icons.credit_card_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: notesController,
                label: 'Notes',
                icon: Icons.sticky_note_2_outlined,
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            appDialogCancelButton(dialogContext),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Save',
              onPressed: () => _saveEditedCustomer(
                dialogContext,
                name: nameController.text,
                phone: phoneController.text,
                email: emailController.text,
                address: addressController.text,
                notes: notesController.text,
                gst: gstController.text,
                creditLimit: creditLimitController.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEditedCustomer(
    BuildContext dialogContext, {
    required String name,
    required String phone,
    required String email,
    required String address,
    required String notes,
    required String gst,
    required String creditLimit,
  }) async {
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();

    if (trimmedName.isEmpty) {
      NotificationService.instance.showError('Name is required');
      return;
    }

    // No Form wrapper here, so the field's inline validator only *shows* the
    // error — the save path has to enforce it too.
    final phoneError = PhoneRule.validate(trimmedPhone);
    if (phoneError != null) {
      NotificationService.instance.showError(phoneError);
      return;
    }

    // Only re-check when the phone actually changed, so saving an unmodified
    // record never trips over the customer's own number.
    if (trimmedPhone != (_customer.phone ?? '')) {
      final existing = await customerStore.getCustomerByPhone(trimmedPhone);
      if (existing != null && existing.customerId != _customer.customerId) {
        NotificationService.instance.showError(
          'A customer with this phone number already exists',
        );
        return;
      }
    }

    final trimmedEmail = email.trim();
    final trimmedAddress = address.trim();
    final trimmedNotes = notes.trim();
    final trimmedGst = gst.trim();

    // Emptying an optional field must actually clear it — the clear* flags
    // exist because `x ?? this.x` alone would silently keep the old value.
    final updated = _customer.copyWith(
      name: trimmedName,
      phone: trimmedPhone,
      email: trimmedEmail.isEmpty ? null : trimmedEmail,
      clearEmail: trimmedEmail.isEmpty,
      address: trimmedAddress.isEmpty ? null : trimmedAddress,
      clearAddress: trimmedAddress.isEmpty,
      notes: trimmedNotes.isEmpty ? null : trimmedNotes,
      clearNotes: trimmedNotes.isEmpty,
      gstNumber: trimmedGst.isEmpty ? null : trimmedGst.toUpperCase(),
      clearGstNumber: trimmedGst.isEmpty,
      creditLimit: double.tryParse(creditLimit.trim()) ?? 0.0,
      updatedAt: DateTime.now().toIso8601String(),
    );

    final saved = await customerStore.updateCustomer(updated);
    if (!mounted || !dialogContext.mounted) return;

    if (!saved) {
      NotificationService.instance.showError(
        customerStore.errorMessage ?? 'Failed to update customer',
      );
      return;
    }

    setState(() => _customer = updated);
    Navigator.pop(dialogContext);
    NotificationService.instance.showSuccess('Customer updated successfully');
  }

  // ==================== REDEEM ====================

  Future<void> _showRedeemPointsDialog() async {
    final pointsController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => DialogDisposeScope(
        disposables: [pointsController],
        child: AppDialogShell(
          title: 'Redeem Points',
          subtitle: 'Available: ${_customer.loyaltyPoints} pts',
          accent: AppColors.warning,
          icon: Icons.stars_rounded,
          body: AppTextField(
            controller: pointsController,
            label: 'Points to Redeem',
            icon: Icons.star_outline_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
          ),
          actions: [
            appDialogCancelButton(dialogContext),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Redeem',
              color: AppColors.warning,
              onPressed: () async {
                final points = int.tryParse(pointsController.text.trim()) ?? 0;
                if (points <= 0) {
                  NotificationService.instance.showError(
                    'Please enter valid points',
                  );
                  return;
                }
                if (points > _customer.loyaltyPoints) {
                  NotificationService.instance.showError('Insufficient points');
                  return;
                }

                await customerStore.redeemCustomerPoints(
                  _customer.customerId,
                  points,
                );
                await _refreshCustomer();

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                NotificationService.instance.showSuccess(
                  '$points points redeemed successfully',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: _customer.name ?? 'Customer',
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit customer',
            onPressed: _showEditCustomerDialog,
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.7),
          indicatorColor: AppColors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Bills'),
          ],
        ),
      ),
      body: MoneyScope(
        child: TabBarView(
          controller: _tabController,
          children: [_buildDetailsTab(), _buildBillsTab()],
        ),
      ),
    );
  }

  /// Caps content width on large screens so the detail cards don't stretch
  /// across a laptop.
  Widget _capped(BuildContext context, Widget child) {
    final maxWidth = AppResponsive.maxCardWidth(context);
    if (maxWidth == double.infinity) return child;
    return Align(
      // topCenter, not Center: Center aligns on BOTH axes, so a
      // shrink-wrapping child floats in the vertical middle.
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  Widget _buildDetailsTab() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refreshCustomer,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppResponsive.padding(context).left,
          AppResponsive.mediumSpacing(context),
          AppResponsive.padding(context).left,
          AppResponsive.largeSpacing(context),
        ),
        child: _capped(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 16),

              _buildSectionCard(
                title: 'Contact Information',
                icon: Icons.contact_phone_outlined,
                children: [
                  _buildInfoRow('Phone', _customer.phone ?? '—'),
                  if (_customer.email?.isNotEmpty ?? false)
                    _buildInfoRow('Email', _customer.email!),
                  if (_customer.address?.isNotEmpty ?? false)
                    _buildInfoRow('Address', _customer.address!),
                  if (_customer.gstNumber?.isNotEmpty ?? false)
                    _buildInfoRow('GST Number', _customer.gstNumber!),
                ],
              ),
              const SizedBox(height: 16),

              _buildSectionCard(
                title: 'Purchase Summary',
                icon: Icons.shopping_cart_outlined,
                children: [
                  _buildInfoRow(
                    'Total Purchase',
                    formatMoney(_customer.totalPurchaseAmount),
                  ),
                  _buildInfoRow(
                    'Visit Count',
                    _customer.totalVisites.toString(),
                  ),
                  _buildInfoRow(
                    'Last Visited',
                    _customer.lastVisitAt != null
                        ? _formatShortDate(_customer.lastVisitAt!)
                        : 'Never',
                  ),
                  _buildInfoRow(
                    'Total Bills',
                    _customerSales.length.toString(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildSectionCard(
                title: 'Loyalty Points',
                icon: Icons.stars_rounded,
                iconColor: AppColors.warning,
                trailing: _customer.loyaltyPoints > 0
                    ? TextButton(
                        onPressed: _showRedeemPointsDialog,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.warning,
                        ),
                        child: Text(
                          'Redeem',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : null,
                children: [
                  _buildInfoRow(
                    'Points Balance',
                    _customer.loyaltyPoints.toString(),
                    valueColor: AppColors.warning,
                  ),
                  _buildInfoRow(
                    'Total Earned',
                    _customer.totalPointEarned.toString(),
                  ),
                  _buildInfoRow(
                    'Total Redeemed',
                    _customer.totalPointRedeemed.toString(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildCreditCard(),

              if (_customer.notes?.isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Notes',
                  icon: Icons.sticky_note_2_outlined,
                  children: [
                    Text(
                      _customer.notes!,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Account Info',
                icon: Icons.info_outline_rounded,
                children: [
                  _buildInfoRow(
                    'Customer Since',
                    _formatShortDate(_customer.createdAt),
                  ),
                  if (_customer.updatedAt != null)
                    _buildInfoRow(
                      'Last Updated',
                      _formatShortDate(_customer.updatedAt!),
                    ),
                  _buildInfoRow(
                    'Customer ID',
                    shortRef(
                      _customer.customerId,
                      minLength: 16,
                      ellipsis: true,
                    ),
                    valueStyle: GoogleFonts.robotoMono(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.textSecondary,
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

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.white.withValues(alpha: 0.18),
            child: Text(
              (_customer.name?.isNotEmpty ?? false)
                  ? _customer.name![0].toUpperCase()
                  : '?',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.getValue(
                  context,
                  mobile: 26.0,
                  tablet: 30.0,
                  desktop: 34.0,
                ),
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _customer.name ?? 'Unknown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.headingFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _customer.phone ?? '—',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildHeaderBadge(
                      Icons.shopping_bag_outlined,
                      formatMoney(_customer.totalPurchaseAmount),
                    ),
                    const SizedBox(width: 10),
                    _buildHeaderBadge(
                      Icons.stars_rounded,
                      '${_customer.loyaltyPoints} pts',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    Color? iconColor,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (trailing != null) ...[const Spacer(), trailing],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Capped label column: wide enough for the longest label, but it stops
          // growing on a laptop so every extra pixel goes to the value.
          SizedBox(
            width: AppResponsive.getValue(
              context,
              mobile: 110.0,
              tablet: 130.0,
              desktop: 150.0,
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  valueStyle ??
                  GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard() {
    final hasCredit = _customer.creditBalance > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasCredit
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(
                  Icons.credit_card_outlined,
                  size: 20,
                  color: hasCredit ? AppColors.danger : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Credit Information',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Outstanding balance — the headline number
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (hasCredit ? AppColors.danger : AppColors.success)
                        .withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Expanded + scaleDown: spaceBetween only shares out
                      // SURPLUS space, so a large balance at 30px would have
                      // pushed the DUE badge off the card.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Outstanding Balance',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.smallFontSize(context),
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formatMoney(_customer.creditBalance),
                                maxLines: 1,
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.getValue(
                                    context,
                                    mobile: 23.0,
                                    tablet: 26.0,
                                    desktop: 30.0,
                                  ),
                                  fontWeight: FontWeight.w700,
                                  color: hasCredit
                                      ? AppColors.danger
                                      : AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (hasCredit)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'DUE',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildInfoRow(
                  'Credit Limit',
                  _customer.creditLimit > 0
                      ? formatMoney(_customer.creditLimit)
                      : 'Unlimited',
                ),
                if (_customer.creditLimit > 0)
                  _buildInfoRow(
                    'Available Credit',
                    formatMoney(
                      (_customer.creditLimit - _customer.creditBalance)
                          .clamp(0, double.infinity)
                          .toDouble(),
                    ),
                    valueColor: AppColors.success,
                  ),

                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasCredit
                            ? () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReceivePaymentScreen(
                                      customer: _customer,
                                    ),
                                  ),
                                );
                                await _refreshCustomer();
                              }
                            : null,
                        icon: const Icon(Icons.payments_outlined, size: 18),
                        label: Text(
                          'Receive Payment',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          disabledBackgroundColor: AppColors.divider.withValues(
                            alpha: 0.6,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CustomerLedgerScreen(customer: _customer),
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: Text(
                          'View Ledger',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
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
    );
  }

  // ==================== BILLS ====================

  Widget _buildBillsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_customerSales.isEmpty) {
      return const AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No bills yet',
        message: 'Customer purchases will appear here.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadCustomerSales,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            color: AppColors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Total Bills',
                  _customerSales.length.toString(),
                  Icons.receipt_outlined,
                ),
                _buildSummaryItem(
                  'Net Amount',
                  formatMoney(_netBilledAmount),
                  Icons.payments_outlined,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _customerSales.length,
              itemBuilder: (context, index) =>
                  _buildBillCard(_customerSales[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.subheadingFontSize(context),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBillCard(SaleModel sale) {
    final isReturn = sale.isReturn ?? false;
    final accent = isReturn ? AppColors.danger : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isReturn
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.divider,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SaleDetailScreen(saleId: sale.saleId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isReturn
                            ? Icons.assignment_return_outlined
                            : Icons.receipt_outlined,
                        size: 18,
                        color: accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isReturn ? 'Return' : 'Sale',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getPaymentColor(
                        sale.paymentType,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sale.paymentType.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: _getPaymentColor(sale.paymentType),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill #${shortRef(sale.saleId)}',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(sale.date),
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        // abs() because the stored amount is already negative
                        // for returns — the sign is added once, here.
                        '${isReturn ? '-' : ''}${formatMoney(sale.totalAmount.abs())}',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.subheadingFontSize(context),
                          fontWeight: FontWeight.w700,
                          color: isReturn
                              ? AppColors.danger
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${sale.totalItems} items',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPaymentColor(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'cash':
        return AppColors.success;
      case 'card':
        return AppColors.info;
      case 'upi':
        return AppColors.secondary;
      case 'split':
        return AppColors.accent;
      case 'credit':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }
}
