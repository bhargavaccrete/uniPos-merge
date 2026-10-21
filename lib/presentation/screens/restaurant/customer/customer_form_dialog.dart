import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/entitlement_keys.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Add or edit a customer, as a dialog rather than a pushed page — the same
/// shape Manage Staff uses for its add/edit forms.
///
/// Returns `'added'` / `'updated'` on success and null when dismissed, which is
/// exactly what the old full-page screen popped with, so callers only swap the
/// `Navigator.push` for this call and keep their result handling.
Future<String?> showCustomerFormDialog(
  BuildContext context, {
  Customer? customer,
}) async {
  final isEdit = customer != null;

  // Gate the ENTRANCE: check entitlement before showing a form the user would
  // not be allowed to submit, rather than letting them fill it in and fail.
  if (!isEdit) {
    if (!PlanGuard.allowedOr(
      context,
      EntKeys.customers,
      featureName: 'Customers',
    )) {
      return null;
    }
    if (!PlanGuard.withinLimitOr(
      context,
      EntKeys.customersMax,
      customerStore.customers.length,
      unit: 'customers',
    )) {
      return null;
    }
  }

  final nameController = TextEditingController(text: customer?.name ?? '');
  final phoneController = TextEditingController(text: customer?.phone ?? '');
  final foodPreferenceController = TextEditingController(
    text: customer?.foodPrefrence ?? '',
  );
  final notesController = TextEditingController(text: customer?.notes ?? '');

  final nameFocus = FocusNode();
  final phoneFocus = FocusNode();
  final foodPreferenceFocus = FocusNode();
  final notesFocus = FocusNode();

  // Local key per dialog open — a shared member GlobalKey inside a showDialog
  // builder trips a _dependents assertion on back-dismiss.
  final formKey = GlobalKey<FormState>();

  bool isSaving = false;

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => DialogDisposeScope(
      disposables: [
        nameController,
        phoneController,
        foodPreferenceController,
        notesController,
        nameFocus,
        phoneFocus,
        foodPreferenceFocus,
        notesFocus,
      ],
      child: StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            if (isSaving) return;
            if (!formKey.currentState!.validate()) return;

            setDialogState(() => isSaving = true);

            try {
              final phone = phoneController.text.trim();
              final foodPreference = foodPreferenceController.text.trim();
              final notes = notesController.text.trim();

              if (isEdit) {
                // Phone is the identity key, so a changed one must not collide
                // with another customer's.
                if (phone != (customer.phone ?? '')) {
                  final existing = await customerStore.getCustomerByPhone(
                    phone,
                  );
                  if (existing != null &&
                      existing.customerId != customer.customerId) {
                    NotificationService.instance.showError(
                      'A customer with this phone number already exists',
                    );
                    setDialogState(() => isSaving = false);
                    return;
                  }
                }

                // Emptying an optional field must actually clear it — the
                // clear* flags exist because `x ?? this.x` alone would
                // silently keep the old value.
                final updated = customer.copyWith(
                  name: nameController.text.trim(),
                  phone: phone,
                  foodPrefrence: foodPreference.isEmpty ? null : foodPreference,
                  clearFoodPrefrence: foodPreference.isEmpty,
                  notes: notes.isEmpty ? null : notes,
                  clearNotes: notes.isEmpty,
                  updatedAt: DateTime.now().toIso8601String(),
                );

                final ok = await customerStore.updateCustomer(updated);
                if (ctx.mounted) Navigator.pop(ctx, ok ? 'updated' : null);
              } else {
                final existing = await customerStore.getCustomerByPhone(phone);
                if (existing != null) {
                  NotificationService.instance.showError(
                    'A customer with this phone number already exists',
                  );
                  setDialogState(() => isSaving = false);
                  return;
                }

                final created = Customer.create(
                  customerId: const Uuid().v4(),
                  name: nameController.text.trim(),
                  phone: phone,
                  foodPrefrence: foodPreference.isEmpty ? null : foodPreference,
                  notes: notes.isEmpty ? null : notes,
                );

                final ok = await customerStore.addCustomer(created);
                if (ctx.mounted) Navigator.pop(ctx, ok ? 'added' : null);
              }
            } catch (e) {
              NotificationService.instance.showError('Error: $e');
              if (ctx.mounted) setDialogState(() => isSaving = false);
            }
          }

          return AppDialogShell(
            title: isEdit ? 'Edit Customer' : 'Add Customer',
            subtitle: isEdit
                ? 'Update customer details'
                : 'Add a new customer to your database',
            accent: AppColors.primary,
            icon: isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
            body: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Basic Information',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(ctx),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: AppResponsive.mediumSpacing(ctx)),

                  AppTextField(
                    controller: nameController,
                    focusNode: nameFocus,
                    label: 'Customer Name',
                    hint: 'Enter customer name',
                    icon: Icons.person_outline_rounded,
                    required: true,
                    autofocus: !isEdit,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => phoneFocus.requestFocus(),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Please enter customer name'
                        : null,
                  ),
                  SizedBox(height: AppResponsive.mediumSpacing(ctx)),

                  AppTextField(
                    controller: phoneController,
                    focusNode: phoneFocus,
                    label: 'Phone Number',
                    hint: 'Enter 10-digit phone number',
                    icon: Icons.phone_rounded,
                    required: true,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => foodPreferenceFocus.requestFocus(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter phone number';
                      }
                      if (value.trim().length != 10) {
                        return 'Phone number must be exactly 10 digits';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: AppResponsive.largeSpacing(ctx)),

                  Text(
                    'Preferences',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(ctx),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: AppResponsive.mediumSpacing(ctx)),

                  AppTextField(
                    controller: foodPreferenceController,
                    focusNode: foodPreferenceFocus,
                    label: 'Food Preference',
                    hint: 'E.g., Vegetarian, Non-Veg, Vegan',
                    icon: Icons.restaurant_menu_rounded,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => notesFocus.requestFocus(),
                  ),
                  SizedBox(height: AppResponsive.mediumSpacing(ctx)),

                  AppTextField(
                    controller: notesController,
                    focusNode: notesFocus,
                    label: 'Notes',
                    hint: 'Any special notes about this customer',
                    icon: Icons.notes_rounded,
                    // Multiline in a dialog: 3 lines, so the body scrolls
                    // rather than pushing the action row off a short window.
                    maxLines: 3,
                    onFieldSubmitted: (_) => FocusScope.of(ctx).unfocus(),
                  ),

                  if (isEdit) ...[
                    SizedBox(height: AppResponsive.largeSpacing(ctx)),
                    Container(
                      padding: EdgeInsets.all(AppResponsive.mediumSpacing(ctx)),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.blue,
                            size: AppResponsive.iconSize(ctx),
                          ),
                          SizedBox(width: AppResponsive.smallSpacing(ctx)),
                          Expanded(
                            child: Text(
                              'Total Visits: ${customer.totalVisites}  |  '
                              'Loyalty Points: ${customer.loyaltyPoints}',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.smallFontSize(ctx),
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              appDialogCancelButton(ctx),
              const SizedBox(width: 12),
              appDialogPrimaryButton(
                label: isSaving
                    ? 'Saving…'
                    : (isEdit ? 'Update Customer' : 'Add Customer'),
                onPressed: isSaving ? () {} : submit,
              ),
            ],
          );
        },
      ),
    ),
  );
}
