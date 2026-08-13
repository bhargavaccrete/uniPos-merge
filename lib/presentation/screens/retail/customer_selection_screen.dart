import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/config/phone_rule.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';

class CustomerSelectionScreen extends StatefulWidget {
  const CustomerSelectionScreen({super.key});

  @override
  State<CustomerSelectionScreen> createState() =>
      _CustomerSelectionScreenState();
}

class _CustomerSelectionScreenState extends State<CustomerSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Clear any previous selection, then hydrate the store — the shared
    // CustomerStore doesn't self-load, so the filtered list would be empty.
    customerStore.clearSelection();
    customerStore.loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    customerStore.setSearchQuery('');
    super.dispose();
  }

  void _onSearchChanged(String query) {
    customerStore.setSearchQuery(query);
    setState(() {});
  }

  void _selectCustomer(Customer customer) {
    customerStore.selectCustomer(customer);
    Navigator.pop(context, customer);
  }

  Future<void> _showAddCustomerDialog() async {
    final nameController = TextEditingController();
    // Pre-fill the phone only when the typed query looks like a number.
    final typed = _searchController.text.trim();
    final phoneController = TextEditingController(
      text: RegExp(r'^\d+$').hasMatch(typed) ? typed : '',
    );
    final nameSeed = RegExp(r'^\d+$').hasMatch(typed) ? '' : typed;
    nameController.text = nameSeed;
    final emailController = TextEditingController();
    final addressController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => DialogDisposeScope(
        disposables: [
          nameController,
          phoneController,
          emailController,
          addressController,
        ],
        child: AppDialogShell(
          title: 'Add Customer',
          accent: AppColors.primary,
          icon: Icons.person_add_alt_1_rounded,
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
            ],
          ),
          actions: [
            appDialogCancelButton(dialogContext),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Add & Select',
              onPressed: () => _saveAndSelect(
                dialogContext,
                name: nameController.text,
                phone: phoneController.text,
                email: emailController.text,
                address: addressController.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndSelect(
    BuildContext dialogContext, {
    required String name,
    required String phone,
    required String email,
    required String address,
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

    // An existing number means the cashier should pick that customer, not
    // create a second record that splits their credit and points.
    final existing = await customerStore.getCustomerByPhone(trimmedPhone);
    if (existing != null) {
      if (!mounted || !dialogContext.mounted) return;
      Navigator.pop(dialogContext);
      NotificationService.instance
          .showError('That phone already belongs to ${existing.name ?? 'a customer'} — selected instead');
      _selectCustomer(existing);
      return;
    }

    final newCustomer = Customer.create(
      customerId: await customerIdGeneratorService.generate(),
      name: trimmedName,
      phone: trimmedPhone,
      email: email.trim().isEmpty ? null : email.trim(),
      address: address.trim().isEmpty ? null : address.trim(),
    );

    final added = await customerStore.addCustomer(newCustomer);
    if (!mounted || !dialogContext.mounted) return;

    // Never attach an unsaved customer to the bill — the sale would reference
    // a customerId that isn't in the box.
    if (!added) {
      NotificationService.instance
          .showError(customerStore.errorMessage ?? 'Failed to add customer');
      return;
    }

    Navigator.pop(dialogContext);
    _selectCustomer(newCustomer);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Select Customer',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(
              'Skip',
              style: GoogleFonts.poppins(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: MoneyScope(
        child: Column(
          children: [
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.all(16),
              child: AppTextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                hint: 'Type name or mobile number...',
                icon: Icons.search_rounded,
                onChanged: _onSearchChanged,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
            Expanded(
              child: Observer(
                builder: (context) {
                  if (_searchController.text.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.person_search_rounded,
                      title: 'Search for a customer',
                      message:
                          'Type a name or mobile number to find customers.',
                    );
                  }

                  final results = customerStore.filteredCustomers;

                  if (results.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.person_add_alt_1_outlined,
                      title: 'No customer found',
                      message: 'No results for "${_searchController.text}".',
                      action: appEmptyStateAction(
                        label: 'Add New Customer',
                        onPressed: _showAddCustomerDialog,
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: results.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildAddNewCustomerTile();
                      return _buildCustomerTile(results[index - 1]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewCustomerTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary),
      ),
      child: InkWell(
        onTap: _showAddCustomerDialog,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: AppColors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Customer',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Create customer with "${_searchController.text}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerTile(Customer customer) {
    final hasDue = customer.creditBalance > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: () => _selectCustomer(customer),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  (customer.name?.isNotEmpty ?? false)
                      ? customer.name![0].toUpperCase()
                      : '?',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (customer.phone?.isNotEmpty ?? false) customer.phone!,
                        if (customer.totalPurchaseAmount > 0)
                          formatMoney(customer.totalPurchaseAmount),
                        if (customer.loyaltyPoints > 0)
                          '${customer.loyaltyPoints} pts',
                      ].join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Dues matter at the till — the cashier needs to see them before
              // putting another credit sale on this account.
              if (hasDue) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Due ${formatMoney(customer.creditBalance)}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
