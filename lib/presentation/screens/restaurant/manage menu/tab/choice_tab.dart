import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/restaurant/restaurant_session.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/data/models/restaurant/db/choicemodel_306.dart';
import 'package:unipos/data/models/restaurant/db/choiceoptionmodel_307.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/util/images.dart';
import 'package:uuid/uuid.dart';

class ChoiceTab extends StatefulWidget {
  const ChoiceTab({super.key});

  @override
  State<ChoiceTab> createState() => _ChoiceTabState();
}

class _ChoiceTabState extends State<ChoiceTab> {
  TextEditingController choiceController = TextEditingController();
  TextEditingController optionController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  String query = '';
  List<ChoiceOption> tempOptions = [];
  ChoicesModel? editingChoice;
  bool allowMultipleSelection = false; // Track if choice allows multiple selections

  @override
  void initState() {
    super.initState();
    searchController.addListener(() {
      setState(() {
        query = searchController.text;
      });
    });
  }

  @override
  void dispose() {
    choiceController.dispose();
    optionController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void openBottomSheet({ChoicesModel? choicemodel}) {
    setState(() {
      if (choicemodel != null) {
        choiceController.text = choicemodel.name;
        tempOptions = List<ChoiceOption>.from(choicemodel.choiceOption);
        editingChoice = choicemodel;
        allowMultipleSelection = choicemodel.allowMultipleSelection ?? false;
      } else {
        choiceController.clear();
        optionController.clear();
        tempOptions = [];
        editingChoice = null;
        allowMultipleSelection = false;
      }
    });

    final isWide = MediaQuery.of(context).size.width >= 850;
    if (isWide) {
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            child: _buildBottomSheet(isDialog: true),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _buildBottomSheet(isDialog: false),
        ),
      );
    }
  }

  Widget _buildBottomSheet({bool isDialog = false}) {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        final isEditing = editingChoice != null;

        void _addOption() {
          final val = optionController.text.trim();
          if (val.isEmpty) return;
          setModalState(() {
            tempOptions.add(ChoiceOption(id: const Uuid().v4(), name: val));
            optionController.clear();
          });
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: isDialog
                ? BorderRadius.circular(20)
                : const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle (sheet only) ───────────────────────────────
              if (!isDialog)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),

              // ── Header ─────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(20, isDialog ? 20 : 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit_rounded : Icons.checklist_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Choice' : 'Add Choice',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            isEditing
                                ? 'Update this choice group'
                                : 'Create a new customer choice group',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey.shade500),
                      splashRadius: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade100),

              // ── Scrollable form body ───────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Choice Name ──────────────────────────────────
                      AppTextField(
                        controller: choiceController,
                        label: 'Choice Name',
                        hint: 'e.g. Spice Level, Add-ons',
                        icon: Icons.checklist_rounded,
                        required: true,
                      ),
                      const SizedBox(height: 16),

                      // ── Selection Type ───────────────────────────────
                      Text('Selection Type',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600)),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _selectionChip(
                                label: 'Single',
                                subtitle: 'Pick one',
                                icon: Icons.radio_button_checked_rounded,
                                isSelected: !allowMultipleSelection,
                                onTap: () => setModalState(
                                    () => allowMultipleSelection = false),
                                isLeft: true,
                              ),
                            ),
                            Container(
                                width: 1,
                                height: 56,
                                color: AppColors.divider),
                            Expanded(
                              child: _selectionChip(
                                label: 'Multiple',
                                subtitle: 'Pick many',
                                icon: Icons.check_box_rounded,
                                isSelected: allowMultipleSelection,
                                onTap: () => setModalState(
                                    () => allowMultipleSelection = true),
                                isLeft: false,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Options ──────────────────────────────────────
                      Row(
                        children: [
                          Text('Options',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600)),
                          const Spacer(),
                          if (tempOptions.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${tempOptions.length} added',
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Add-option input row
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: optionController,
                              hint: 'e.g. Mild, Medium, Hot…',
                              icon: Icons.add_circle_outline_rounded,
                              onFieldSubmitted: (_) => _addOption(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _addOption,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.add_rounded,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Options list
                      if (tempOptions.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.divider,
                                style: BorderStyle.solid),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.playlist_add_rounded,
                                  size: 32, color: Colors.grey.shade300),
                              const SizedBox(height: 6),
                              Text('No options added yet',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.grey.shade400)),
                            ],
                          ),
                        )
                      else
                        ...tempOptions.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final opt = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${idx + 1}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(opt.name,
                                      style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.black87)),
                                ),
                                InkWell(
                                  onTap: () => setModalState(
                                      () => tempOptions.removeAt(idx)),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                        Icons.close_rounded,
                                        size: 15,
                                        color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                      const SizedBox(height: 20),

                      // ── Action buttons ───────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                side: BorderSide(
                                    color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text('Cancel',
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _addOrEditChoice(tempOptions),
                              icon: Icon(
                                isEditing
                                    ? Icons.check_rounded
                                    : Icons.add_circle_outline_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: Text(
                                isEditing ? 'Update Choice' : 'Add Choice',
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _selectionChip({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isLeft,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.horizontal(
        left: isLeft ? const Radius.circular(12) : Radius.zero,
        right: isLeft ? Radius.zero : const Radius.circular(12),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isLeft ? const Radius.circular(11) : Radius.zero,
            right: isLeft ? Radius.zero : const Radius.circular(11),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: isSelected ? AppColors.primary : Colors.grey.shade400),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade600)),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addOrEditChoice(List<ChoiceOption> option) async {
    final trimmedName = choiceController.text.trim();
    if (trimmedName.isEmpty) {
      NotificationService.instance.showError('Choice name cannot be empty');
      return;
    }

    // Duplicate name check (excluding current item when editing)
    final exists = choiceStore.choices.any((c) =>
        c.name.toLowerCase() == trimmedName.toLowerCase() &&
        c.id != (editingChoice?.id ?? ''));
    if (exists) {
      NotificationService.instance.showError('A choice with this name already exists');
      return;
    }

    final isEditing = editingChoice != null;
    final editId = editingChoice?.id;
    // Capture before clearing state, otherwise these read null below
    final existingCreatedTime = editingChoice?.createdTime;
    final existingEditCount = editingChoice?.editCount ?? 0;

    choiceController.clear();
    optionController.clear();
    editingChoice = null;
    Navigator.pop(context);

    if (isEditing && editId != null) {
      final updateChoice = ChoicesModel(
        id: editId,
        name: trimmedName,
        choiceOption: option,
        createdTime: existingCreatedTime,
        lastEditedTime: DateTime.now(),
        editedBy: RestaurantSession.staffName ?? RestaurantSession.effectiveRole,
        editCount: existingEditCount + 1,
        allowMultipleSelection: allowMultipleSelection,
      );
      await choiceStore.updateChoice(updateChoice);
    } else {
      final newchoice = ChoicesModel(
        id: Uuid().v4(),
        name: trimmedName,
        choiceOption: option,
        createdTime: DateTime.now(),
        allowMultipleSelection: allowMultipleSelection,
      );
      await choiceStore.addChoice(newchoice);
    }
  }

  Future<void> _delete(ChoicesModel choice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete "${choice.name}"?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        content: Text('This choice and its ${choice.choiceOption.length} options will be removed.',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w500))),
        ],
      ),
    );

    if (confirmed == true) {
      await choiceStore.deleteChoice(choice.id);
    }
  }

  int _getGridColumns(double width) {
    if (width > 1200) return 3;
    else if (width > 800) return 2;
    else return 2;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Modern Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppTextField(
              controller: searchController,
              hint: 'Search choices…',
              icon: Icons.search_rounded,
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                      onPressed: () {
                        searchController.clear();
                      },
                    )
                  : null,
            ),
          ),

          // Choices List
          Expanded(
            child: isTablet ? _buildTabletLayout(size) : _buildMobileLayout(size),
          ),

          // Add Choice Button
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(Size size) {
    return Observer(
      builder: (_) {
        final filteredChoices = _getFilteredChoices();

        if (filteredChoices.isEmpty) {
          return _buildEmptyState(size.height);
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: filteredChoices.length,
          itemBuilder: (context, index) {
            final choice = filteredChoices[index];
            return _buildMobileChoiceCard(choice);
          },
        );
      },
    );
  }

  Widget _buildTabletLayout(Size size) {
    return Observer(
      builder: (_) {
        final filteredChoices = _getFilteredChoices();

        if (filteredChoices.isEmpty) {
          return _buildEmptyState(size.height);
        }

        return GridView.builder(
          padding: EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _getGridColumns(size.width),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.8,
          ),
          itemCount: filteredChoices.length,
          itemBuilder: (context, index) {
            final choice = filteredChoices[index];
            return _buildGridChoiceCard(choice);
          },
        );
      },
    );
  }

  List<ChoicesModel> _getFilteredChoices() {
    final allchoice = choiceStore.choices.toList();
    return query.isEmpty
        ? allchoice
        : allchoice.where((choice) {
            final name = choice.name.toLowerCase();
            final queryLower = query.toLowerCase();
            return name.contains(queryLower);
          }).toList();
  }

  Widget _buildEmptyState(double height) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(AppImages.notfoundanimation, height: height * 0.25),
          SizedBox(height: 16),
          Text(
            query.isEmpty ? 'No Choices Found' : 'No matching choices',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          if (query.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Add choices to customize your items',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileChoiceCard(ChoicesModel choice) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: EdgeInsets.only(bottom: 8),
          leading: Icon(Icons.checklist, color: AppColors.primary, size: 20),
          title: Text(choice.name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text('${choice.choiceOption.length} options', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(onTap: () => openBottomSheet(choicemodel: choice), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: 18, color: Colors.blue))),
              InkWell(onTap: () => _delete(choice), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline, size: 18, color: Colors.red))),
            ],
          ),
          children: choice.choiceOption.isEmpty
              ? [Padding(padding: EdgeInsets.all(16), child: Text("No options", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400)))]
              : choice.choiceOption.map((option) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                    child: Row(
                      children: [
                        Container(width: 5, height: 5, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                        SizedBox(width: 10),
                        Text(option.name, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700)),
                      ],
                    ),
                  );
                }).toList(),
        ),
      ),
    );
  }

  Widget _buildGridChoiceCard(ChoicesModel choice) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(choice.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${choice.choiceOption.length} options', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              InkWell(onTap: () => openBottomSheet(choicemodel: choice), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: 16, color: Colors.blue))),
              InkWell(onTap: () => _delete(choice), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline, size: 16, color: Colors.red))),
            ],
          ),
          if (choice.choiceOption.isNotEmpty) ...[
            SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  ...choice.choiceOption.take(2).map((option) => Padding(
                    padding: EdgeInsets.only(bottom: 3),
                    child: Row(children: [
                      Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                      SizedBox(width: 8),
                      Expanded(child: Text(option.name, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  )),
                  if (choice.choiceOption.length > 2)
                    Text('+${choice.choiceOption.length - 2} more', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => openBottomSheet(),
          icon: Icon(Icons.add, size: 20),
          label: Text('Add Choice', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}