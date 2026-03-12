import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/models/restaurant/db/choicemodel_306.dart';
import '../../../../data/models/restaurant/db/choiceoptionmodel_307.dart';
import '../../../../util/common/app_responsive.dart';
import '../../../widget/componets/common/app_text_field.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';


class ChoiceSelectionScreen extends StatefulWidget {
  final List<String> selectedChoiceIds;

  const ChoiceSelectionScreen({
    super.key,
    required this.selectedChoiceIds,
  });

  @override
  State<ChoiceSelectionScreen> createState() => _ChoiceSelectionScreenState();
}

class _ChoiceSelectionScreenState extends State<ChoiceSelectionScreen> {
  List<ChoicesModel> availableChoices = [];
  Set<String> selectedChoiceIds = {};

  @override
  void initState() {
    super.initState();
    _loadChoices();
    _initializeSelections();
  }

  void _loadChoices() {
    if (mounted) {
      setState(() {
        availableChoices = choiceStore.choices.toList();
      });
    }
  }

  void _initializeSelections() {
    selectedChoiceIds = Set<String>.from(widget.selectedChoiceIds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Choices',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: () => _showAddChoiceDialog(),
            tooltip: 'Add New Choice',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: availableChoices.isEmpty
                ? _buildEmptyState()
                : _buildChoiceList(),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.checklist_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            SizedBox(height: 20),
            Text(
              'No Choices Available',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Create your first choice group to get started',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            CommonButton(
              onTap: () => _showAddChoiceDialog(),
              bgcolor: AppColors.primary,
              bordercircular: 10,
              height: 50,
              width: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Add Choice',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceList() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select choice groups for this item:',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 20),

          ...availableChoices.map<Widget>((choice) {
            final isSelected = selectedChoiceIds.contains(choice.id);

            return Container(
              margin: EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
              ),
              child: CheckboxListTile(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value ?? false) {
                      selectedChoiceIds.add(choice.id);
                    } else {
                      selectedChoiceIds.remove(choice.id);
                    }
                  });
                },
                activeColor: AppColors.primary,
                title: Text(
                  choice.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.black : Colors.grey[700],
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          '${choice.choiceOption.length} option${choice.choiceOption.length != 1 ? 's' : ''} available',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (choice.allowMultipleSelection ?? false)
                                ? Colors.blue.shade100
                                : Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                (choice.allowMultipleSelection ?? false)
                                    ? Icons.check_box_outlined
                                    : Icons.radio_button_checked,
                                size: 11,
                                color: (choice.allowMultipleSelection ?? false)
                                    ? Colors.blue.shade700
                                    : Colors.purple.shade700,
                              ),
                              SizedBox(width: 3),
                              Text(
                                (choice.allowMultipleSelection ?? false) ? 'Multi-select' : 'Single',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: (choice.allowMultipleSelection ?? false)
                                      ? Colors.blue.shade700
                                      : Colors.purple.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Show first 3 options
                        ...choice.choiceOption.take(3).map((option) {
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              option.name,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                            ),
                          );
                        }),
                        // Show "+X more" if more than 3 options
                        if (choice.choiceOption.length > 3)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '+${choice.choiceOption.length - 3}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 5),
                  ],
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: CommonButton(
              onTap: () => Navigator.pop(context),
              bgcolor: Colors.white,
              bordercolor: AppColors.primary,
              bordercircular: 10,
              height: AppResponsive.height(context, 0.06),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: CommonButton(
              onTap: () {
                Navigator.pop(context, selectedChoiceIds.toList());
              },
              bordercircular: 10,
              height: AppResponsive.height(context, 0.06),
              child: Text(
                'Save',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddChoiceDialog() {
    final parentContext = context;

    final choiceNameController = TextEditingController();
    final List<TextEditingController> optionControllers = [TextEditingController()];
    bool allowMultipleSelection = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Add New Choice',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter choice name and options',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 15),

                    // Choice name
                    AppTextField(
                      controller: choiceNameController,
                      label: 'Choice Name',
                      hint: 'e.g. Spice Level',
                      icon: Icons.checklist_rounded,
                    ),
                    const SizedBox(height: 16),

                    // Single / Multiple toggle
                    Text(
                      'Selection Type',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
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
                              onTap: () => setDialogState(
                                  () => allowMultipleSelection = false),
                              isLeft: true,
                            ),
                          ),
                          Container(
                              width: 1, height: 56, color: AppColors.divider),
                          Expanded(
                            child: _selectionChip(
                              label: 'Multiple',
                              subtitle: 'Pick many',
                              icon: Icons.check_box_rounded,
                              isSelected: allowMultipleSelection,
                              onTap: () => setDialogState(
                                  () => allowMultipleSelection = true),
                              isLeft: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Options
                    Text(
                      'Options:',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(optionControllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: optionControllers[index],
                                label: 'Option ${index + 1}',
                                hint: 'Enter option',
                              ),
                            ),
                            if (optionControllers.length > 1) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.remove_circle,
                                    color: Colors.red),
                                onPressed: () {
                                  setDialogState(() {
                                    optionControllers[index].dispose();
                                    optionControllers.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          optionControllers.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline,
                          color: AppColors.primary),
                      label: Text(
                        'Add Option',
                        style: GoogleFonts.poppins(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    for (var c in optionControllers) c.dispose();
                    choiceNameController.dispose();
                    Navigator.pop(context);
                  },
                  child: Text('Cancel',
                      style: GoogleFonts.poppins(color: Colors.grey[600])),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (choiceNameController.text.trim().isEmpty) {
                      NotificationService.instance
                          .showError('Please enter a choice name');
                      return;
                    }

                    final options = optionControllers
                        .where((c) => c.text.trim().isNotEmpty)
                        .map((c) => ChoiceOption(
                              id: const Uuid().v4(),
                              name: c.text.trim(),
                            ))
                        .toList();

                    if (options.isEmpty) {
                      NotificationService.instance
                          .showError('Please add at least one option');
                      return;
                    }

                    final newChoice = ChoicesModel(
                      id: const Uuid().v4(),
                      name: choiceNameController.text.trim(),
                      choiceOption: options,
                      allowMultipleSelection: allowMultipleSelection,
                    );

                    await choiceStore.addChoice(newChoice);

                    FocusScope.of(parentContext).unfocus();
                    Navigator.of(context).pop();

                    await Future.delayed(const Duration(milliseconds: 100));
                    for (var c in optionControllers) c.dispose();
                    choiceNameController.dispose();

                    if (mounted) _loadChoices();

                    NotificationService.instance.showSuccess(
                        'Choice "${newChoice.name}" added with ${options.length} options');
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: Text('Add',
                      style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ],
            );
          },
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
                color:
                    isSelected ? AppColors.primary : Colors.grey.shade400),
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
}