import 'package:flutter/material.dart';
import 'package:unipos/util/color.dart';

import '../../../../../constants/restaurant/color.dart';

class Dropdown extends StatefulWidget {
  final List<String> items;
  final String selectedItem;
  final Function(String) onChanged;
  final String? hintText;

  Dropdown({
    required this.items,
    required this.selectedItem,
    required this.onChanged,
    this.hintText,
  });

  @override
  State<Dropdown> createState() => _DropdownState();
}

class _DropdownState extends State<Dropdown> {
  late String _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.selectedItem;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 1;
    final height = MediaQuery.of(context).size.height * 1;
    return Container(
      width: width * 0.66,
      height: height*0.09,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedValue,
          items: widget.items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: TextStyle(color: AppColors.primary),
              ),
            );
          }).toList(),
          onChanged: (String? value) {
            if (value != null) {
              setState(() {
                _selectedValue = value;
              });
              widget.onChanged(
                  value); // Calls the callback to update parent widget
            }
          },
        ),
      ),
    );
  }
}
