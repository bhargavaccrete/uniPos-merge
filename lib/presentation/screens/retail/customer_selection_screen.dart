import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/config/phone_rule.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
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
    // The selection is deliberately NOT cleared here. Opening the picker to
    // check or change who is attached used to detach them silently, so backing
    // out lost the customer. Removing is an explicit action on the banner.
    // The shared CustomerStore doesn't self-load, so hydrate it or the filtered
    // list would be empty.
    customerStore.setSearchQuery('');
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

  void _removeSelected() {
    customerStore.selectCustomer(null);
    Navigator.pop(context, null);
  }

  /// Enter on the search box commits when the query has narrowed to one
  /// customer — the common case after typing a mobile number.
  void _submitSearch(String _) {
    final results = customerStore.filteredCustomers;
    if (results.length == 1) _selectCustomer(results.first);
  }

  Future<void> _showAddCustomerDialog() async {
    // Seed from whatever was typed in the search box: a number is a phone,
    // anything else is a name.
    final typed = _searchController.text.trim();
    final seededPhone = RegExp(r'^\d+$').hasMatch(typed);
    final nameController = TextEditingController(
      text: seededPhone ? '' : typed,
    );
    final phoneController = TextEditingController(
      text: seededPhone ? typed : '',
    );
    final emailController = TextEditingController();
    final addressController = TextEditingController();

    // Email and address are rarely captured at the till and pushed the buttons
    // off a phone screen. One tap away, and never cleared once shown.
    bool showMoreFields = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => DialogDisposeScope(
        disposables: [
          nameController,
          phoneController,
          emailController,
          addressController,
        ],
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() => _saveAndSelect(
              dialogContext,
              name: nameController.text,
              phone: phoneController.text,
              email: emailController.text,
              address: addressController.text,
            );

            return AppDialogShell(
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
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
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
                    // Both required fields are filled by this point, so the
                    // keyboard's own action can finish the job.
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => submit(),
                  ),
                  if (showMoreFields) ...[
                    SizedBox(height: AppResponsive.mediumSpacing(context)),
                    AppTextField(
                      controller: emailController,
                      label: 'Email',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: AppResponsive.mediumSpacing(context)),
                    AppTextField(
                      controller: addressController,
                      label: 'Address',
                      icon: Icons.location_on_outlined,
                      maxLines: 2,
                    ),
                  ] else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            setDialogState(() => showMoreFields = true),
                        icon: Icon(
                          Icons.add_rounded,
                          size: AppResponsive.smallIconSize(context),
                        ),
                        label: Text(
                          'Email & address',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                appDialogCancelButton(dialogContext),
                SizedBox(width: AppResponsive.mediumSpacing(context)),
                appDialogPrimaryButton(
                  label: 'Add & Select',
                  onPressed: submit,
                ),
              ],
            );
          },
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
      NotificationService.instance.showError(
        'That phone already belongs to ${existing.name ?? 'a customer'} — selected instead',
      );
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
      NotificationService.instance.showError(
        customerStore.errorMessage ?? 'Failed to add customer',
      );
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
          // "Skip" only reads right while nothing is attached — with a customer
          // on the bill this button closes without changing anything, and
          // detaching is the banner's Remove.
          Observer(
            builder: (context) => TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                customerStore.hasSelection ? 'Done' : 'Skip',
                style: GoogleFonts.poppins(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        maxWidth: AppResponsive.maxContentWidth(context),
        child: MoneyScope(
          child: Column(
            children: [
              Observer(
                builder: (context) {
                  final selected = customerStore.selectedCustomer;
                  if (selected == null) return const SizedBox.shrink();
                  return _buildSelectedBanner(selected);
                },
              ),
              Container(
                color: AppColors.white,
                padding: AppResponsive.cardPadding(context),
                child: AppTextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  // No autofocus: the keyboard opened over the Recent list, so
                  // the two-tap path for a repeat customer was hidden behind it.
                  hint: 'Type name or mobile number...',
                  icon: Icons.search_rounded,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  onFieldSubmitted: _submitSearch,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            size: AppResponsive.iconSize(context),
                          ),
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
                    // Nothing typed: offer the customers most likely to be at
                    // the counter. Demanding a search first made every repeat
                    // customer cost a full name or number.
                    if (_searchController.text.isEmpty) {
                      final recents = customerStore.recentCustomers;
                      if (recents.isEmpty) {
                        return AppEmptyState(
                          icon: Icons.person_add_alt_1_outlined,
                          title: 'No customers yet',
                          message:
                              'Add one to attach them to this bill and start '
                              'tracking their points and dues.',
                          action: appEmptyStateAction(
                            label: 'Add New Customer',
                            onPressed: _showAddCustomerDialog,
                          ),
                        );
                      }
                      return ListView.builder(
                        // Bottom pad clears the FAB.
                        padding: EdgeInsets.fromLTRB(
                          AppResponsive.padding(context).left,
                          AppResponsive.padding(context).left,
                          AppResponsive.padding(context).left,
                          88,
                        ),
                        itemCount: recents.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) return _buildListHeader('Recent');
                          return _buildCustomerTile(recents[index - 1]);
                        },
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
                      // Bottom pad clears the FAB. Static on purpose: it is
                      // coupled to that button's height, not to a breakpoint,
                      // so laddering it would under- or over-clear.
                      padding: EdgeInsets.fromLTRB(
                        AppResponsive.padding(context).left,
                        AppResponsive.padding(context).left,
                        AppResponsive.padding(context).left,
                        88,
                      ),
                      itemCount: results.length,
                      itemBuilder: (context, index) =>
                          _buildCustomerTile(results[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      // Same placement and shape as the Customers list screen's add action.
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        tooltip: 'Add Customer',
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
    );
  }

  /// Who is currently on the bill, with the only way to take them off.
  Widget _buildSelectedBanner(Customer customer) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppResponsive.padding(context).left,
        AppResponsive.mediumSpacing(context),
        AppResponsive.smallSpacing(context),
        AppResponsive.mediumSpacing(context),
      ),
      color: AppColors.success.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: AppResponsive.iconSize(context),
            color: AppColors.success,
          ),
          SizedBox(width: AppResponsive.smallSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name ?? 'Unknown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'On this bill${(customer.phone?.isNotEmpty ?? false) ? '  •  ${customer.phone}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _removeSelected,
            icon: Icon(
              Icons.close_rounded,
              size: AppResponsive.smallIconSize(context),
            ),
            label: Text(
              'Remove',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader(String label) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 4,
        vertical: AppResponsive.smallSpacing(context),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.captionFontSize(context),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildCustomerTile(Customer customer) {
    final hasDue = customer.creditBalance > 0;

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: () => _selectCustomer(customer),
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.mediumSpacing(context),
            vertical: AppResponsive.smallSpacing(context),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: AppResponsive.smallAvatarSize(context) / 2,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  (customer.name?.isNotEmpty ?? false)
                      ? customer.name![0].toUpperCase()
                      : '?',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: AppResponsive.mediumSpacing(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (customer.phone?.isNotEmpty ?? false)
                          customer.phone!,
                        if (customer.totalPurchaseAmount > 0)
                          formatMoney(customer.totalPurchaseAmount),
                        if (customer.loyaltyPoints > 0)
                          '${customer.loyaltyPoints} pts',
                      ].join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Dues matter at the till — the cashier needs to see them before
              // putting another credit sale on this account.
              if (hasDue) ...[
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.smallSpacing(context),
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Due ${formatMoney(customer.creditBalance)}',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: AppResponsive.iconSize(context),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
