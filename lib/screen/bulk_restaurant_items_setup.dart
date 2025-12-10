// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:uuid/uuid.dart';
// import 'package:hive/hive.dart';
// import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
// import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
// import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';
// import 'package:unipos/data/models/restaurant/db/extramodel_303.dart';
// import 'package:unipos/data/models/restaurant/db/toppingmodel_304.dart';
// import 'package:unipos/util/color.dart';
// import 'package:unipos/util/responsive.dart';
//
// /// Bulk restaurant menu items setup screen for setup wizard
// class BulkRestaurantItemsSetup extends StatefulWidget {
//   final VoidCallback? onNext;
//   final VoidCallback? onPrevious;
//
//   const BulkRestaurantItemsSetup({
//     Key? key,
//     this.onNext,
//     this.onPrevious,
//   }) : super(key: key);
//
//   @override
//   State<BulkRestaurantItemsSetup> createState() => _BulkRestaurantItemsSetupState();
// }
//
// class _BulkRestaurantItemsSetupState extends State<BulkRestaurantItemsSetup> {
//   final List<BulkItemRow> _itemRows = [];
//   final _scrollController = ScrollController();
//   bool _isLoading = false;
//   List<Category> _categories = [];
//   List<VariantModel> _variants = [];
//   List<Extramodel> _extras = [];
//   List<Topping> _toppings = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//     _addEmptyRow();
//   }
//
//   @override
//   void dispose() {
//     _scrollController.dispose();
//     for (var row in _itemRows) {
//       row.dispose();
//     }
//     super.dispose();
//   }
//
//   Future<void> _loadData() async {
//     try {
//       final categoryBox = await Hive.openBox<Category>('categories');
//       final variantBox = await Hive.openBox<VariantModel>('variants');
//       final extraBox = await Hive.openBox<Extramodel>('extras');
//       final toppingBox = await Hive.openBox<Topping>('toppings');
//
//       setState(() {
//         _categories = categoryBox.values.toList();
//         _variants = variantBox.values.toList();
//         _extras = extraBox.values.toList();
//         _toppings = toppingBox.values.toList();
//       });
//     } catch (e) {
//       print('Error loading data: $e');
//     }
//   }
//
//   void _addEmptyRow() {
//     setState(() {
//       _itemRows.add(BulkItemRow());
//     });
//   }
//
//   void _removeRow(int index) {
//     if (_itemRows.length > 1) {
//       setState(() {
//         _itemRows[index].dispose();
//         _itemRows.removeAt(index);
//       });
//     }
//   }
//
//   void _duplicateRow(int index) {
//     setState(() {
//       final original = _itemRows[index];
//       final duplicate = BulkItemRow(
//         nameController: TextEditingController(text: original.nameController.text),
//         priceController: TextEditingController(text: original.priceController.text),
//         descriptionController: TextEditingController(text: original.descriptionController.text),
//         selectedCategoryId: original.selectedCategoryId,
//         isVeg: original.isVeg,
//         selectedVariants: List.from(original.selectedVariants),
//         selectedExtras: List.from(original.selectedExtras),
//         selectedToppings: List.from(original.selectedToppings),
//       );
//       _itemRows.insert(index + 1, duplicate);
//     });
//   }
//
//   Future<void> _saveAllItems() async {
//     // Validate all rows
//     final validRows = <BulkItemRow>[];
//     for (var i = 0; i < _itemRows.length; i++) {
//       final row = _itemRows[i];
//       if (row.nameController.text.trim().isEmpty) {
//         continue; // Skip empty rows
//       }
//
//       if (row.priceController.text.trim().isEmpty) {
//         _showError('Row ${i + 1}: Please enter price');
//         return;
//       }
//
//       validRows.add(row);
//     }
//
//     if (validRows.isEmpty) {
//       _showError('Please add at least one item');
//       return;
//     }
//
//     setState(() => _isLoading = true);
//
//     try {
//       final itemBox = await Hive.openBox<Items>('itemBoxs');
//       const uuid = Uuid();
//
//       int successCount = 0;
//       for (var row in validRows) {
//         try {
//           final itemId = uuid.v4();
//           final item = Items(
//             id: itemId,
//             name: row.nameController.text.trim(),
//             price: double.tryParse(row.priceController.text) ?? 0.0,
//             description: row.descriptionController.text.trim().isNotEmpty
//                 ? row.descriptionController.text.trim()
//                 : null,
//             imagePath: null,
//             categoryOfItem: row.selectedCategoryId,
//             isVeg: row.isVeg,
//             unit: null,
//             variant: null,
//             choiceIds: null,
//             extraId: row.selectedExtras.isNotEmpty ? row.selectedExtras : null,
//             taxRate: null,
//             isEnabled: true,
//             trackInventory: false,
//             stockQuantity: 0.0,
//             allowOrderWhenOutOfStock: false,
//             isSoldByWeight: false,
//             createdTime: DateTime.now(),
//             lastEditedTime: null,
//             editedBy: null,
//             editCount: 0,
//             extraConstraints: null,
//           );
//
//           await itemBox.add(item);
//           successCount++;
//         } catch (e) {
//           print('Error saving item: $e');
//         }
//       }
//
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Successfully added $successCount items!'),
//             backgroundColor: AppColors.success,
//           ),
//         );
//
//         // Clear the form
//         setState(() {
//           for (var row in _itemRows) {
//             row.dispose();
//           }
//           _itemRows.clear();
//           _addEmptyRow();
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         _showError('Failed to save items: $e');
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }
//
//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: AppColors.danger,
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final isMobile = Responsive.isMobile(context);
//
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8F9FA),
//       body: Column(
//         children: [
//           _buildHeader(isMobile),
//           _buildInstructions(isMobile),
//           Expanded(
//             child: _buildItemsTable(isMobile),
//           ),
//           _buildBottomBar(isMobile),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildHeader(bool isMobile) {
//     return Container(
//       padding: EdgeInsets.all(isMobile ? 16 : 24),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Bulk Menu Items Setup',
//             style: TextStyle(
//               fontSize: isMobile ? 20 : 24,
//               fontWeight: FontWeight.bold,
//               color: AppColors.darkNeutral,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Quickly add multiple menu items at once',
//             style: TextStyle(
//               fontSize: isMobile ? 14 : 16,
//               color: Colors.grey[600],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildInstructions(bool isMobile) {
//     return Container(
//       margin: EdgeInsets.all(isMobile ? 16 : 20),
//       padding: EdgeInsets.all(isMobile ? 12 : 16),
//       decoration: BoxDecoration(
//         color: AppColors.info.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: AppColors.info.withOpacity(0.3),
//         ),
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.info_outline, color: AppColors.info, size: isMobile ? 20 : 24),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Text(
//               'Add items one by one, or duplicate similar items. You can skip this step and add items later.',
//               style: TextStyle(
//                 fontSize: isMobile ? 13 : 14,
//                 color: Colors.grey[700],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildItemsTable(bool isMobile) {
//     if (isMobile) {
//       return _buildMobileList();
//     } else {
//       return _buildDesktopTable();
//     }
//   }
//
//   Widget _buildMobileList() {
//     return ListView.builder(
//       controller: _scrollController,
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       itemCount: _itemRows.length,
//       itemBuilder: (context, index) {
//         return _buildMobileItemCard(index);
//       },
//     );
//   }
//
//   Widget _buildMobileItemCard(int index) {
//     final row = _itemRows[index];
//
//     return Card(
//       margin: const EdgeInsets.only(bottom: 16),
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   'Item ${index + 1}',
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: AppColors.primary,
//                   ),
//                 ),
//                 Row(
//                   children: [
//                     IconButton(
//                       icon: const Icon(Icons.content_copy, size: 20),
//                       onPressed: () => _duplicateRow(index),
//                       tooltip: 'Duplicate',
//                     ),
//                     if (_itemRows.length > 1)
//                       IconButton(
//                         icon: const Icon(Icons.delete, size: 20, color: Colors.red),
//                         onPressed: () => _removeRow(index),
//                         tooltip: 'Remove',
//                       ),
//                   ],
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             _buildTextField(
//               controller: row.nameController,
//               label: 'Item Name *',
//               hint: 'e.g., Margherita Pizza',
//             ),
//             const SizedBox(height: 12),
//             _buildTextField(
//               controller: row.priceController,
//               label: 'Price *',
//               hint: '0.00',
//               keyboardType: TextInputType.number,
//             ),
//             const SizedBox(height: 12),
//             _buildCategoryDropdown(row),
//             const SizedBox(height: 12),
//             _buildVegNonVegSelector(row),
//             const SizedBox(height: 12),
//             _buildTextField(
//               controller: row.descriptionController,
//               label: 'Description (Optional)',
//               hint: 'Brief description',
//               maxLines: 2,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDesktopTable() {
//     return SingleChildScrollView(
//       controller: _scrollController,
//       padding: const EdgeInsets.all(20),
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.05),
//               blurRadius: 10,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Column(
//           children: [
//             _buildTableHeader(),
//             ..._itemRows.asMap().entries.map((entry) {
//               return _buildTableRow(entry.key);
//             }).toList(),
//             _buildAddRowButton(),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTableHeader() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.primary.withOpacity(0.1),
//         borderRadius: const BorderRadius.only(
//           topLeft: Radius.circular(12),
//           topRight: Radius.circular(12),
//         ),
//       ),
//       child: Row(
//         children: [
//           const SizedBox(width: 40), // For row number
//           Expanded(flex: 3, child: _buildHeaderCell('Item Name *')),
//           Expanded(flex: 2, child: _buildHeaderCell('Price *')),
//           Expanded(flex: 2, child: _buildHeaderCell('Category')),
//           Expanded(flex: 2, child: _buildHeaderCell('Type')),
//           Expanded(flex: 3, child: _buildHeaderCell('Description')),
//           const SizedBox(width: 100), // For actions
//         ],
//       ),
//     );
//   }
//
//   Widget _buildHeaderCell(String text) {
//     return Text(
//       text,
//       style: const TextStyle(
//         fontSize: 13,
//         fontWeight: FontWeight.w600,
//         color: AppColors.darkNeutral,
//       ),
//     );
//   }
//
//   Widget _buildTableRow(int index) {
//     final row = _itemRows[index];
//
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         border: Border(
//           bottom: BorderSide(
//             color: Colors.grey[200]!,
//             width: 1,
//           ),
//         ),
//       ),
//       child: Row(
//         children: [
//           // Row number
//           SizedBox(
//             width: 40,
//             child: Text(
//               '${index + 1}',
//               style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.grey[600],
//               ),
//             ),
//           ),
//           // Name
//           Expanded(
//             flex: 3,
//             child: Padding(
//               padding: const EdgeInsets.only(right: 8),
//               child: _buildTableTextField(
//                 controller: row.nameController,
//                 hint: 'e.g., Margherita Pizza',
//               ),
//             ),
//           ),
//           // Price
//           Expanded(
//             flex: 2,
//             child: Padding(
//               padding: const EdgeInsets.only(right: 8),
//               child: _buildTableTextField(
//                 controller: row.priceController,
//                 hint: '0.00',
//                 keyboardType: TextInputType.number,
//               ),
//             ),
//           ),
//           // Category
//           Expanded(
//             flex: 2,
//             child: Padding(
//               padding: const EdgeInsets.only(right: 8),
//               child: _buildTableCategoryDropdown(row),
//             ),
//           ),
//           // Veg/Non-Veg
//           Expanded(
//             flex: 2,
//             child: Padding(
//               padding: const EdgeInsets.only(right: 8),
//               child: _buildTableVegNonVegSelector(row),
//             ),
//           ),
//           // Description
//           Expanded(
//             flex: 3,
//             child: Padding(
//               padding: const EdgeInsets.only(right: 8),
//               child: _buildTableTextField(
//                 controller: row.descriptionController,
//                 hint: 'Optional',
//               ),
//             ),
//           ),
//           // Actions
//           SizedBox(
//             width: 100,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.content_copy, size: 18),
//                   onPressed: () => _duplicateRow(index),
//                   tooltip: 'Duplicate',
//                   padding: EdgeInsets.zero,
//                   constraints: const BoxConstraints(),
//                 ),
//                 const SizedBox(width: 8),
//                 if (_itemRows.length > 1)
//                   IconButton(
//                     icon: const Icon(Icons.delete, size: 18, color: Colors.red),
//                     onPressed: () => _removeRow(index),
//                     tooltip: 'Remove',
//                     padding: EdgeInsets.zero,
//                     constraints: const BoxConstraints(),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildAddRowButton() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       child: OutlinedButton.icon(
//         onPressed: _addEmptyRow,
//         icon: const Icon(Icons.add, size: 18),
//         label: const Text('Add Another Item'),
//         style: OutlinedButton.styleFrom(
//           foregroundColor: AppColors.primary,
//           side: BorderSide(color: AppColors.primary),
//           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(8),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String label,
//     required String hint,
//     TextInputType? keyboardType,
//     int maxLines = 1,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//             color: AppColors.darkNeutral,
//           ),
//         ),
//         const SizedBox(height: 6),
//         TextField(
//           controller: controller,
//           keyboardType: keyboardType,
//           maxLines: maxLines,
//           decoration: InputDecoration(
//             hintText: hint,
//             hintStyle: TextStyle(color: Colors.grey[400]),
//             filled: true,
//             fillColor: const Color(0xFFF5F5F5),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8),
//               borderSide: BorderSide.none,
//             ),
//             contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildTableTextField({
//     required TextEditingController controller,
//     required String hint,
//     TextInputType? keyboardType,
//   }) {
//     return TextField(
//       controller: controller,
//       keyboardType: keyboardType,
//       decoration: InputDecoration(
//         hintText: hint,
//         hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
//         filled: true,
//         fillColor: const Color(0xFFF5F5F5),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(6),
//           borderSide: BorderSide.none,
//         ),
//         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//         isDense: true,
//       ),
//       style: const TextStyle(fontSize: 13),
//     );
//   }
//
//   Widget _buildCategoryDropdown(BulkItemRow row) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Category',
//           style: TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//             color: AppColors.darkNeutral,
//           ),
//         ),
//         const SizedBox(height: 6),
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12),
//           decoration: BoxDecoration(
//             color: const Color(0xFFF5F5F5),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: DropdownButtonHideUnderline(
//             child: DropdownButton<String>(
//               value: row.selectedCategoryId,
//               isExpanded: true,
//               hint: const Text('Select category'),
//               items: [
//                 const DropdownMenuItem<String>(
//                   value: null,
//                   child: Text('No category'),
//                 ),
//                 ..._categories.map((category) {
//                   return DropdownMenuItem<String>(
//                     value: category.id,
//                     child: Text(category.name ?? 'Unnamed'),
//                   );
//                 }).toList(),
//               ],
//               onChanged: (value) {
//                 setState(() {
//                   row.selectedCategoryId = value;
//                 });
//               },
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildTableCategoryDropdown(BulkItemRow row) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF5F5F5),
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: DropdownButtonHideUnderline(
//         child: DropdownButton<String>(
//           value: row.selectedCategoryId,
//           isExpanded: true,
//           isDense: true,
//           hint: const Text('Select', style: TextStyle(fontSize: 13)),
//           items: [
//             const DropdownMenuItem<String>(
//               value: null,
//               child: Text('None', style: TextStyle(fontSize: 13)),
//             ),
//             ..._categories.map((category) {
//               return DropdownMenuItem<String>(
//                 value: category.id,
//                 child: Text(
//                   category.name ?? 'Unnamed',
//                   style: const TextStyle(fontSize: 13),
//                 ),
//               );
//             }).toList(),
//           ],
//           onChanged: (value) {
//             setState(() {
//               row.selectedCategoryId = value;
//             });
//           },
//         ),
//       ),
//     );
//   }
//
//   Widget _buildVegNonVegSelector(BulkItemRow row) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Type',
//           style: TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//             color: AppColors.darkNeutral,
//           ),
//         ),
//         const SizedBox(height: 6),
//         Row(
//           children: [
//             Expanded(
//               child: _buildVegChip(row, 'veg', 'Veg', Colors.green),
//             ),
//             const SizedBox(width: 8),
//             Expanded(
//               child: _buildVegChip(row, 'nonveg', 'Non-Veg', Colors.red),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
//
//   Widget _buildTableVegNonVegSelector(BulkItemRow row) {
//     return Row(
//       children: [
//         Expanded(
//           child: InkWell(
//             onTap: () => setState(() => row.isVeg = 'veg'),
//             child: Container(
//               padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
//               decoration: BoxDecoration(
//                 color: row.isVeg == 'veg'
//                     ? Colors.green.withOpacity(0.1)
//                     : const Color(0xFFF5F5F5),
//                 borderRadius: const BorderRadius.only(
//                   topLeft: Radius.circular(6),
//                   bottomLeft: Radius.circular(6),
//                 ),
//                 border: Border.all(
//                   color: row.isVeg == 'veg' ? Colors.green : Colors.grey[300]!,
//                   width: 1.5,
//                 ),
//               ),
//               child: Text(
//                 'Veg',
//                 style: TextStyle(
//                   fontSize: 12,
//                   fontWeight: row.isVeg == 'veg' ? FontWeight.w600 : FontWeight.normal,
//                   color: row.isVeg == 'veg' ? Colors.green : Colors.grey[700],
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           ),
//         ),
//         Expanded(
//           child: InkWell(
//             onTap: () => setState(() => row.isVeg = 'nonveg'),
//             child: Container(
//               padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
//               decoration: BoxDecoration(
//                 color: row.isVeg == 'nonveg'
//                     ? Colors.red.withOpacity(0.1)
//                     : const Color(0xFFF5F5F5),
//                 borderRadius: const BorderRadius.only(
//                   topRight: Radius.circular(6),
//                   bottomRight: Radius.circular(6),
//                 ),
//                 border: Border.all(
//                   color: row.isVeg == 'nonveg' ? Colors.red : Colors.grey[300]!,
//                   width: 1.5,
//                 ),
//               ),
//               child: Text(
//                 'Non-Veg',
//                 style: TextStyle(
//                   fontSize: 12,
//                   fontWeight: row.isVeg == 'nonveg' ? FontWeight.w600 : FontWeight.normal,
//                   color: row.isVeg == 'nonveg' ? Colors.red : Colors.grey[700],
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildVegChip(BulkItemRow row, String value, String label, Color color) {
//     final isSelected = row.isVeg == value;
//
//     return InkWell(
//       onTap: () => setState(() => row.isVeg = value),
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 12),
//         decoration: BoxDecoration(
//           color: isSelected ? color.withOpacity(0.1) : const Color(0xFFF5F5F5),
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(
//             color: isSelected ? color : Colors.grey[300]!,
//             width: 1.5,
//           ),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               isSelected ? Icons.check_circle : Icons.circle_outlined,
//               color: isSelected ? color : Colors.grey[400],
//               size: 18,
//             ),
//             const SizedBox(width: 6),
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
//                 color: isSelected ? color : Colors.grey[700],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildBottomBar(bool isMobile) {
//     return Container(
//       padding: EdgeInsets.all(isMobile ? 16 : 20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: const Offset(0, -2),
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           OutlinedButton(
//             onPressed: widget.onPrevious,
//             style: OutlinedButton.styleFrom(
//               padding: EdgeInsets.symmetric(
//                 horizontal: isMobile ? 24 : 32,
//                 vertical: isMobile ? 12 : 16,
//               ),
//               side: BorderSide(color: AppColors.primary),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             child: const Text('Back'),
//           ),
//           Row(
//             children: [
//               if (!isMobile) ...[
//                 TextButton(
//                   onPressed: widget.onNext,
//                   child: const Text('Skip for Now'),
//                 ),
//                 const SizedBox(width: 12),
//               ],
//               ElevatedButton(
//                 onPressed: _isLoading ? null : _saveAllItems,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: AppColors.success,
//                   padding: EdgeInsets.symmetric(
//                     horizontal: isMobile ? 24 : 32,
//                     vertical: isMobile ? 12 : 16,
//                   ),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//                 child: _isLoading
//                     ? const SizedBox(
//                         width: 20,
//                         height: 20,
//                         child: CircularProgressIndicator(
//                           strokeWidth: 2,
//                           valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                         ),
//                       )
//                     : const Text('Save All Items'),
//               ),
//               const SizedBox(width: 12),
//               ElevatedButton(
//                 onPressed: widget.onNext,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: AppColors.primary,
//                   padding: EdgeInsets.symmetric(
//                     horizontal: isMobile ? 24 : 32,
//                     vertical: isMobile ? 12 : 16,
//                   ),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//                 child: const Text('Continue'),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// /// Data class for a single bulk item row
// class BulkItemRow {
//   final TextEditingController nameController;
//   final TextEditingController priceController;
//   final TextEditingController descriptionController;
//   String? selectedCategoryId;
//   String isVeg;
//   List<String> selectedVariants;
//   List<String> selectedExtras;
//   List<String> selectedToppings;
//
//   BulkItemRow({
//     TextEditingController? nameController,
//     TextEditingController? priceController,
//     TextEditingController? descriptionController,
//     this.selectedCategoryId,
//     this.isVeg = 'veg',
//     List<String>? selectedVariants,
//     List<String>? selectedExtras,
//     List<String>? selectedToppings,
//   })  : nameController = nameController ?? TextEditingController(),
//         priceController = priceController ?? TextEditingController(),
//         descriptionController = descriptionController ?? TextEditingController(),
//         selectedVariants = selectedVariants ?? [],
//         selectedExtras = selectedExtras ?? [],
//         selectedToppings = selectedToppings ?? [];
//
//   void dispose() {
//     nameController.dispose();
//     priceController.dispose();
//     descriptionController.dispose();
//   }
// }