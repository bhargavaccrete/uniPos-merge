import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/choicemodel_306.dart';
import 'package:unipos/data/models/restaurant/db/choiceoptionmodel_307.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
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
      } else {
        choiceController.clear();
        optionController.clear();
        tempOptions = [];
        editingChoice = null;
      }
    });

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _buildBottomSheet(),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        return Container(
          padding: EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.checklist, color: AppColors.primary),
                    ),
                    SizedBox(width: 12),
                    Text(
                      editingChoice == null ? 'Add Choice' : 'Edit Choice',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Divider(height: 30),

                // Choice Name Field
                TextField(
                  controller: choiceController,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: "Choice Name",
                    labelStyle: GoogleFonts.poppins(color: Colors.grey),
                    prefixIcon: Icon(Icons.edit, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Options Section
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.list_alt, size: 20, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Options',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${tempOptions.length}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      // Add Option Field
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: optionController,
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: "Add option...",
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(Icons.add_circle_outline,
                                    color: Colors.grey.shade600, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              onSubmitted: (value) {
                                if (value.trim().isNotEmpty) {
                                  setModalState(() {
                                    tempOptions.add(ChoiceOption(
                                      id: Uuid().v4(),
                                      name: value.trim(),
                                    ));
                                    optionController.clear();
                                  });
                                }
                              },
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.add, color: Colors.white),
                              onPressed: () {
                                if (optionController.text.trim().isNotEmpty) {
                                  setModalState(() {
                                    tempOptions.add(ChoiceOption(
                                      id: Uuid().v4(),
                                      name: optionController.text.trim(),
                                    ));
                                    optionController.clear();
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      // Options List
                      if (tempOptions.isNotEmpty)
                        ...tempOptions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final option = entry.value;
                          return Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    option.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      tempOptions.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),

                      if (tempOptions.isEmpty)
                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'No options added yet',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _addOrEditChoice(tempOptions),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          editingChoice == null
                              ? Icons.add_circle_outline
                              : Icons.check_circle_outline,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Text(
                          editingChoice == null ? 'Add Choice' : 'Update Choice',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addOrEditChoice(List<ChoiceOption> option) async {
    final trimmedName = choiceController.text.trim();
    if (trimmedName.isEmpty) return;

    final isEditing = editingChoice != null;
    final editId = editingChoice?.id;

    choiceController.clear();
    optionController.clear();
    editingChoice = null;
    Navigator.pop(context);

    if (isEditing && editId != null) {
      final updateChoice = ChoicesModel(
        id: editId,
        name: trimmedName,
        choiceOption: option,
      );
      await choiceStore.updateChoice(updateChoice);
    } else {
      final newchoice = ChoicesModel(
        id: Uuid().v4(),
        name: trimmedName,
        choiceOption: option,
      );
      await choiceStore.addChoice(newchoice);
    }
  }

  Future<void> _delete(ChoicesModel choice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Choice', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this choice?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: searchController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintText: 'Search choices...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 22),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey, size: 20),
                          onPressed: () {
                            searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                ),
              ),
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
            childAspectRatio: 2,
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
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: EdgeInsets.only(bottom: 12),
          leading: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.checklist,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          title: Text(
            choice.name,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 4),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.list_alt, size: 12, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    '${choice.choiceOption.length} options',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => openBottomSheet(choicemodel: choice),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: Colors.blue,
                  ),
                ),
              ),
              SizedBox(width: 8),
              InkWell(
                onTap: () => _delete(choice),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          children: choice.choiceOption.isEmpty
              ? [
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "No options available",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
              : choice.choiceOption.map((option) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option.name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
        ),
      ),
    );
  }

  Widget _buildGridChoiceCard(ChoicesModel choice) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.checklist,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        choice.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${choice.choiceOption.length} options',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (choice.choiceOption.isNotEmpty)
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView(
                    children: [
                      ...choice.choiceOption.take(3).map((option) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  option.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (choice.choiceOption.length > 3)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            '+${choice.choiceOption.length - 3} more',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => openBottomSheet(choicemodel: choice),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _delete(choice),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => openBottomSheet(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.add, color: AppColors.primary, size: 20),
              ),
              SizedBox(width: 10),
              Text(
                'Add Choice',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}