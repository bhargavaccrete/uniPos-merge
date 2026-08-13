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
import 'customer_detail_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The shared CustomerStore has no self-hydrating constructor (restaurant's
    // screens load it themselves), so retail must load it here — without this
    // the list renders empty even when the box is full.
    customerStore.setSearchQuery('');
    customerStore.loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    customerStore.setSearchQuery(''); // Leave a clean filter for the next visit
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Filter through the store's computed list rather than the repository's
    // async search — no out-of-order results, and adds/edits show up live.
    customerStore.setSearchQuery(query);
    setState(() {});
  }

  Future<void> _showAddCustomerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();
    final gstController = TextEditingController();
    final creditLimitController = TextEditingController();
    final openingBalanceController = TextEditingController();

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
          openingBalanceController,
        ],
        child: MoneyScope(
          child: AppDialogShell(
            title: 'Add Customer',
            accent: AppColors.primary,
            icon: Icons.person_add_alt_1_rounded,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogSectionLabel('Basic Information'),
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

                _dialogSectionLabel('Business Information'),
                AppTextField(
                  controller: gstController,
                  label: 'GST Number',
                  hint: 'e.g. 22AAAAA0000A1Z5',
                  icon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.characters,
                ),

                _dialogSectionLabel('Credit Settings'),
                AppTextField(
                  controller: creditLimitController,
                  label: 'Credit Limit',
                  hint: '0 = Unlimited',
                  icon: Icons.credit_card_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: openingBalanceController,
                  label: 'Opening Balance',
                  hint: 'Due carried forward from previous records',
                  icon: Icons.account_balance_wallet_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                ),

                _dialogSectionLabel('Additional Notes'),
                AppTextField(
                  controller: notesController,
                  label: 'Notes',
                  hint: 'Any additional information…',
                  icon: Icons.sticky_note_2_outlined,
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              appDialogCancelButton(dialogContext),
              const SizedBox(width: 12),
              appDialogPrimaryButton(
                label: 'Add Customer',
                onPressed: () => _saveNewCustomer(
                  dialogContext,
                  name: nameController.text,
                  phone: phoneController.text,
                  email: emailController.text,
                  address: addressController.text,
                  notes: notesController.text,
                  gst: gstController.text,
                  creditLimit: creditLimitController.text,
                  openingBalance: openingBalanceController.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveNewCustomer(
    BuildContext dialogContext, {
    required String name,
    required String phone,
    required String email,
    required String address,
    required String notes,
    required String gst,
    required String creditLimit,
    required String openingBalance,
  }) async {
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();

    if (trimmedName.isEmpty) {
      NotificationService.instance.showError('Name is required');
      return;
    }

    // These dialogs have no Form, so the field's inline validator only *shows*
    // the error — the save path has to enforce it too.
    final phoneError = PhoneRule.validate(trimmedPhone);
    if (phoneError != null) {
      NotificationService.instance.showError(phoneError);
      return;
    }

    // Same guard restaurant already applies — a duplicate phone makes
    // getCustomerByPhone (used by POS lookup) return an arbitrary record.
    final existing = await customerStore.getCustomerByPhone(trimmedPhone);
    if (existing != null) {
      NotificationService.instance
          .showError('A customer with this phone number already exists');
      return;
    }

    final openingDue = double.tryParse(openingBalance.trim()) ?? 0.0;

    final added = await customerStore.addCustomer(
      Customer.create(
        customerId: await customerIdGeneratorService.generate(),
        name: trimmedName,
        phone: trimmedPhone,
        email: email.trim().isEmpty ? null : email.trim(),
        address: address.trim().isEmpty ? null : address.trim(),
        notes: notes.trim().isEmpty ? null : notes.trim(),
        gstNumber: gst.trim().isEmpty ? null : gst.trim().toUpperCase(),
        creditLimit: double.tryParse(creditLimit.trim()) ?? 0.0,
        openingBalance: openingDue,
      ),
    );

    if (!dialogContext.mounted) return;

    // addCustomer reports failure through its return value — don't claim
    // success when the plan gate or Hive rejected the write.
    if (!added) {
      NotificationService.instance
          .showError(customerStore.errorMessage ?? 'Failed to add customer');
      return;
    }

    Navigator.pop(dialogContext);
    NotificationService.instance.showSuccess(
      openingDue > 0
          ? 'Customer added with ${formatMoney(openingDue)} opening balance'
          : 'Customer added successfully',
    );
  }

  Widget _dialogSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  void _openCustomerDetails(Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailScreen(customer: customer),
      ),
    ).then((_) => customerStore.loadCustomers());
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Customers',
        actions: [
          // Once the book has customers, adding lives here. While it's still
          // empty the centred empty-state button is the only prompt, so this
          // stays hidden rather than offering the same action twice.
          Observer(
            builder: (context) => customerStore.customers.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    tooltip: 'Add customer',
                    onPressed: _showAddCustomerDialog,
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
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              child: AppTextField(
                controller: _searchController,
                hint: 'Search by name or phone...',
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

            _buildStatsRow(isTablet),

            Expanded(
              child: Observer(
                builder: (context) {
                  if (customerStore.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    );
                  }

                  final customers = customerStore.filteredCustomers;

                  if (customers.isEmpty) {
                    return _searchController.text.isEmpty
                        ? AppEmptyState(
                            icon: Icons.people_outline_rounded,
                            title: 'No customers yet',
                            message:
                                'Add your first customer to start tracking purchases, points and dues.',
                            action: appEmptyStateAction(
                              label: 'Add Customer',
                              onPressed: _showAddCustomerDialog,
                            ),
                          )
                        : AppEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No customers found',
                            message:
                                'No results for "${_searchController.text}".',
                          );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    itemCount: customers.length,
                    itemBuilder: (context, index) =>
                        _buildCustomerCard(customers[index], isTablet),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Headline numbers across the whole customer base (unfiltered — these
  /// describe the book, not the current search).
  Widget _buildStatsRow(bool isTablet) {
    return Observer(
      builder: (context) {
        final customers = customerStore.customers;
        if (customers.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16, vertical: 8),
          child: Row(
            children: [
              _buildStatChip('${customers.length} customers',
                  Icons.people_rounded, AppColors.primary),
              const SizedBox(width: 8),
              _buildStatChip(
                '${formatMoney(customerStore.totalOutstandingCredit)} due',
                Icons.account_balance_wallet_rounded,
                AppColors.danger,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                '${customers.fold(0, (sum, c) => sum + c.loyaltyPoints)} pts',
                Icons.stars_rounded,
                AppColors.warning,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatChip(String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer, bool isTablet) {
    final hasDue = customer.creditBalance > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasDue
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.divider,
        ),
      ),
      child: InkWell(
        onTap: () => _openCustomerDetails(customer),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: isTablet ? 20 : 18,
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
                        if (customer.totalVisites > 0)
                          '${customer.totalVisites} visits',
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
