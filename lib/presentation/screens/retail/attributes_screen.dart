import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'package:unipos/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:unipos/data/models/retail/hive_model/attribute_value_model_220.dart';

import '../../../core/di/service_locator.dart';
import '../../../domain/store/retail/attribute_store.dart';


/// Screen for managing global product attributes (WooCommerce-style)
/// Allows creating, editing, and deleting attributes and their values
class AttributesScreen extends StatefulWidget {
  const AttributesScreen({super.key});

  @override
  State<AttributesScreen> createState() => _AttributesScreenState();
}

class _AttributesScreenState extends State<AttributesScreen> {
  final AttributeStore _attributeStore = attributeStore;

  @override
  void initState() {
    super.initState();
    _attributeStore.loadAttributes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Attributes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Attribute',
            onPressed: () => _showAddAttributeDialog(),
          ),
        ],
      ),
      body: Observer(
        builder: (_) {
          if (_attributeStore.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_attributeStore.attributes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No attributes yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create attributes like Color, Size, Material\nto use with variable products',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Attribute'),
                    onPressed: () => _showAddAttributeDialog(),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _attributeStore.attributes.length,
            itemBuilder: (context, index) {
              final attribute = _attributeStore.attributes[index];
              return _AttributeCard(
                attribute: attribute,
                values: _attributeStore.getValues(attribute.attributeId),
                onEdit: () => _showEditAttributeDialog(attribute),
                onDelete: () => _confirmDeleteAttribute(attribute),
                onAddValue: () => _showAddValueDialog(attribute),
                onEditValue: (value) => _showEditValueDialog(attribute, value),
                onDeleteValue: (value) => _confirmDeleteValue(value),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Attribute'),
        onPressed: () => _showAddAttributeDialog(),
      ),
    );
  }

  void _showAddAttributeDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Attribute'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Attribute Name',
                hintText: 'e.g., Color, Size, Material',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            Text(
              'This will be reusable across all products',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }

              final success = await _attributeStore.addAttribute(name);
              if (context.mounted) {
                Navigator.pop(context);
              }
              if (success) {
                // Reload attributes to ensure UI updates
                await _attributeStore.loadAttributes();
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Attribute "$name" created')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(_attributeStore.errorMessage ?? 'Failed to create attribute'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditAttributeDialog(AttributeModel attribute) {
    final nameController = TextEditingController(text: attribute.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Attribute'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Attribute Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }

              final success = await _attributeStore.updateAttribute(
                attribute.attributeId,
                name: name,
              );
              if (context.mounted) {
                Navigator.pop(context);
              }
              if (success) {
                await _attributeStore.loadAttributes();
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Attribute "$name" updated')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(_attributeStore.errorMessage ?? 'Failed to update'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAttribute(AttributeModel attribute) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Attribute?'),
        content: Text(
          'Are you sure you want to delete "${attribute.name}"?\n\n'
          'This will also delete all its values.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final success = await _attributeStore.deleteAttribute(attribute.attributeId);
              if (context.mounted) {
                Navigator.pop(context);
              }
              if (success) {
                await _attributeStore.loadAttributes();
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Attribute "${attribute.name}" deleted')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(_attributeStore.errorMessage ?? 'Cannot delete'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddValueDialog(AttributeModel attribute) {
    final valueController = TextEditingController();
    final colorController = TextEditingController();
    final isColor = attribute.name.toLowerCase().contains('color') ||
        attribute.name.toLowerCase().contains('colour');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${attribute.name} Value'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valueController,
              decoration: InputDecoration(
                labelText: 'Value',
                hintText: _getValueHint(attribute.name),
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            if (isColor) ...[
              const SizedBox(height: 16),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(
                  labelText: 'Color Code (optional)',
                  hintText: '#FF0000',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Tip: You can add multiple values separated by commas',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final input = valueController.text.trim();
              if (input.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a value')),
                );
                return;
              }

              // Check if multiple values (comma separated)
              final values = input.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList();

              bool success;
              if (values.length > 1) {
                success = await _attributeStore.addMultipleValues(
                  attribute.attributeId,
                  values,
                );
              } else {
                success = await _attributeStore.addValue(
                  attribute.attributeId,
                  values.first,
                  colorCode: colorController.text.trim().isNotEmpty
                      ? colorController.text.trim()
                      : null,
                );
              }

              if (context.mounted) {
                Navigator.pop(context);
              }
              if (success) {
                await _attributeStore.loadAttributes();
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Added ${values.length} value(s)')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(_attributeStore.errorMessage ?? 'Failed to add'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditValueDialog(AttributeModel attribute, AttributeValueModel value) {
    final valueController = TextEditingController(text: value.value);
    final colorController = TextEditingController(text: value.colorCode ?? '');
    final isColor = attribute.name.toLowerCase().contains('color') ||
        attribute.name.toLowerCase().contains('colour');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${attribute.name} Value'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valueController,
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            if (isColor) ...[
              const SizedBox(height: 16),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(
                  labelText: 'Color Code (optional)',
                  hintText: '#FF0000',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newValue = valueController.text.trim();
              if (newValue.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a value')),
                );
                return;
              }

              final success = await _attributeStore.updateValue(
                value.valueId,
                value: newValue,
                colorCode: colorController.text.trim().isNotEmpty
                    ? colorController.text.trim()
                    : null,
              );
              if (context.mounted) {
                Navigator.pop(context);
              }
              if (success) {
                await _attributeStore.loadAttributes();
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Value "$newValue" updated')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(_attributeStore.errorMessage ?? 'Failed to update'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteValue(AttributeValueModel value) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Value?'),
        content: Text('Are you sure you want to delete "${value.value}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final success = await _attributeStore.deleteValue(value.valueId);
              if (context.mounted) {
                Navigator.pop(context);
              }
              if (success) {
                await _attributeStore.loadAttributes();
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Value "${value.value}" deleted')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _getValueHint(String attributeName) {
    final name = attributeName.toLowerCase();
    if (name.contains('color') || name.contains('colour')) {
      return 'e.g., Red, Blue, Green';
    } else if (name.contains('size')) {
      return 'e.g., S, M, L, XL';
    } else if (name.contains('material')) {
      return 'e.g., Cotton, Polyester, Silk';
    } else if (name.contains('weight')) {
      return 'e.g., 100g, 250g, 500g';
    }
    return 'e.g., Value 1, Value 2';
  }
}

class _AttributeCard extends StatelessWidget {
  final AttributeModel attribute;
  final List<AttributeValueModel> values;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddValue;
  final Function(AttributeValueModel) onEditValue;
  final Function(AttributeValueModel) onDeleteValue;

  const _AttributeCard({
    required this.attribute,
    required this.values,
    required this.onEdit,
    required this.onDelete,
    required this.onAddValue,
    required this.onEditValue,
    required this.onDeleteValue,
  });

  @override
  Widget build(BuildContext context) {
    final isColor = attribute.name.toLowerCase().contains('color') ||
        attribute.name.toLowerCase().contains('colour');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attribute.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'slug: ${attribute.slug}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Attribute',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete Attribute',
                  onPressed: onDelete,
                ),
              ],
            ),

            const Divider(),

            // Values
            Text(
              'Values (${values.length})',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),

            if (values.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No values added yet',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: values.map((value) {
                  return _ValueChip(
                    value: value,
                    isColor: isColor,
                    onEdit: () => onEditValue(value),
                    onDelete: () => onDeleteValue(value),
                  );
                }).toList(),
              ),

            const SizedBox(height: 12),

            // Add Value Button
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Value'),
              onPressed: onAddValue,
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  final AttributeValueModel value;
  final bool isColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ValueChip({
    required this.value,
    required this.isColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Color? chipColor;
    if (isColor && value.colorCode != null) {
      try {
        final hex = value.colorCode!.replaceAll('#', '');
        chipColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    return Material(
      color: chipColor?.withOpacity(0.2) ?? Colors.grey[200],
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chipColor != null) ...[
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: chipColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(value.value),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}