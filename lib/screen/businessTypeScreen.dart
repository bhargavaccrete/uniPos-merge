import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/stores/setup_wizard_store.dart';
import '../util/color.dart';
import '../util/responsive.dart';

/// Business Type Selection Step
/// UI Only - uses Observer to listen to store changes
/// Calls store methods for actions
class BusinessTypeStep extends StatelessWidget {
  final SetupWizardStore store;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const BusinessTypeStep({
    Key? key,
    required this.store,
    required this.onNext,
    required this.onPrevious,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Your Business Type',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.darkNeutral,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This helps us customize UniPOS for your needs',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 30),

          // Business Types Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Responsive.isMobile(context) ? 2 : 3,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.6,
            ),
            itemCount: store.businessTypes.length,
            itemBuilder: (context, index) {
              final type = store.businessTypes[index];
              // Each card wrapped in Observer to react to selection change
              return Observer(
                builder: (_) {
                  final isSelected = store.selectedBusinessTypeId == type['id'];
                  return _BusinessTypeCard(
                    id: type['id']!,
                    title: type['name']!,
                    description: type['description']!,
                    iconName: type['icon']!,
                    isSelected: isSelected,
                    onTap: () async {
                      await store.selectBusinessType(type['id']!, type['name']!);
                    },
                  );
                },
              );
            },
          ),

          const SizedBox(height: 40),

          // Navigation Buttons - uses Observer for button state
          Observer(
            builder: (_) => Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPrevious,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: store.canProceedFromBusinessType
                        ? () async {
                            // Ensure business type is saved and dependencies are initialized
                            await store.saveBusinessType();
                            // Re-trigger initialization in case it wasn't done on selection
                            await store.selectBusinessType(
                              store.selectedBusinessTypeId!,
                              store.selectedBusinessTypeName!,
                            );
                            onNext();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual Business Type Card Widget
class _BusinessTypeCard extends StatelessWidget {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final bool isSelected;
  final VoidCallback onTap;

  const _BusinessTypeCard({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.isSelected,
    required this.onTap,
  });

  IconData _getIcon() {
    switch (iconName) {
      case 'store':
        return Icons.store;
      case 'restaurant':
        return Icons.restaurant;
      case 'build':
        return Icons.build;
      case 'shopping_basket':
        return Icons.shopping_basket;
      case 'medical_services':
        return Icons.medical_services;
      case 'category':
        return Icons.category;
      default:
        return Icons.business;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIcon(),
              size: 40,
              color: isSelected ? AppColors.primary : Colors.grey[600],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.darkNeutral,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}