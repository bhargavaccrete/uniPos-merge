import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/restaurant/responsive_helper.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/models/restaurant/db/choicemodel_306.dart';
import '../../../../data/models/restaurant/db/choiceoptionmodel_307.dart';
import '../../../widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/core/di/service_locator.dart';


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
                    Text(
                      '${choice.choiceOption.length} option${choice.choiceOption.length != 1 ? 's' : ''} available',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
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
              height: ResponsiveHelper.responsiveHeight(context, 0.06),
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
              height: ResponsiveHelper.responsiveHeight(context, 0.06),
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

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Add New Choice',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter choice name and options',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 15),
                    CommonTextForm(
                      controller: choiceNameController,
                      labelText: 'Choice Name (e.g., Spice Level)',
                      obsecureText: false,
                      borderc: 8,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Options:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 10),
                    ...List.generate(optionControllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: CommonTextForm(
                                controller: optionControllers[index],
                                labelText: 'Option ${index + 1}',
                                obsecureText: false,
                                borderc: 8,
                              ),
                            ),
                            if (optionControllers.length > 1) ...[
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.remove_circle, color: Colors.red),
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
                    SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          optionControllers.add(TextEditingController());
                        });
                      },
                      icon: Icon(Icons.add_circle_outline, color: AppColors.primary),
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
                    for (var controller in optionControllers) {
                      controller.dispose();
                    }
                    choiceNameController.dispose();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (choiceNameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          content: Text('Please enter a choice name'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Collect all non-empty options
                    final options = optionControllers
                        .where((controller) => controller.text.trim().isNotEmpty)
                        .map((controller) => ChoiceOption(
                      id: Uuid().v4(),
                      name: controller.text.trim(),
                    ))
                        .toList();

                    if (options.isEmpty) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          content: Text('Please add at least one option'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Create the new choice object
                    final newChoice = ChoicesModel(
                      id: Uuid().v4(),
                      name: choiceNameController.text.trim(),
                      choiceOption: options,
                    );

                    // Save using store
                    await choiceStore.addChoice(newChoice);

                    // Unfocus keyboard first
                    FocusScope.of(parentContext).unfocus();

                    // Close the dialog
                    Navigator.of(context).pop();

                    // After dialog is closed, dispose controllers
                    await Future.delayed(Duration(milliseconds: 100));
                    for (var controller in optionControllers) {
                      controller.dispose();
                    }
                    choiceNameController.dispose();

                    // Reload choices in parent widget
                    if (mounted) {
                      _loadChoices();
                    }

                    // Show success message
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Choice "${newChoice.name}" added with ${options.length} options',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: Text(
                    'Add',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}