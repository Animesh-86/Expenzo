import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/categories_provider.dart';
import '../theme.dart';
import 'package:uuid/uuid.dart';

// Helper function to get IconData from codePoint - uses constant Icons for tree-shaking
IconData getIconFromCodePoint(int codePoint) {
  // Map common code points to constant Icons
  switch (codePoint) {
    case 0xe57a: // Icons.fastfood
      return Icons.fastfood;
    case 0xe53d: // Icons.directions_car
      return Icons.directions_car;
    case 0xe59c: // Icons.shopping_cart
      return Icons.shopping_cart;
    case 0xe227: // Icons.receipt
      return Icons.receipt;
    case 0xe030: // Icons.movie
      return Icons.movie;
    case 0xe3b0: // Icons.local_hospital
      return Icons.local_hospital;
    case 0xe80c: // Icons.school
      return Icons.school;
    case 0xe8cc: // Icons.local_grocery_store
      return Icons.local_grocery_store;
    case 0xe1a0: // Icons.lightbulb
      return Icons.lightbulb;
    case 0xe88a: // Icons.home
      return Icons.home;
    case 0xe263: // Icons.account_balance_wallet
      return Icons.account_balance_wallet;
    case 0xe112: // Icons.card_giftcard
      return Icons.card_giftcard;
    case 0xe14c: // Icons.category
      return Icons.category;
    default:
      return Icons.category; // fallback
  }
}

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  void _showCategoryDialog(BuildContext context, {Category? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    int iconCode = category?.icon ?? Icons.category.codePoint;
    int selectedColor = category?.color ?? 0xFF1976D2;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          content: GlassmorphicCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Category Name'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Icon: '),
                    Icon(
                      getIconFromCodePoint(iconCode),
                      color: Color(selectedColor),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white70),
                      onPressed: () async {
                        final picked = await showDialog<int>(
                          context: context,
                          builder: (context) =>
                              _IconPickerDialog(selectedIcon: iconCode),
                        );
                        if (picked != null) {
                          iconCode = picked;
                          (context as Element).markNeedsBuild();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Color: '),
                    ..._CategoryColorPalette.colors.map(
                      (color) => GestureDetector(
                        onTap: () {
                          selectedColor = color.value;
                          (context as Element).markNeedsBuild();
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == color.value
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: selectedColor == color.value
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final provider = Provider.of<CategoriesProvider>(
                      context,
                      listen: false,
                    );
                    if (category == null) {
                      provider.addCategory(
                        Category(
                          id: const Uuid().v4(),
                          name: name,
                          icon: iconCode,
                          isCustom: true,
                          color: selectedColor,
                        ),
                      );
                    } else {
                      provider.updateCategory(
                        Category(
                          id: category.id,
                          name: name,
                          icon: iconCode,
                          isCustom: true,
                          color: selectedColor,
                        ),
                      );
                    }
                    Navigator.of(context).pop();
                  },
                  child: Text(category == null ? 'Add' : 'Update'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CategoriesProvider>(context);
    final categories = provider.categories;
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      body: categories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.category, size: 64, color: Colors.blueAccent),
                  SizedBox(height: 16),
                  Text(
                    'No categories yet!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create your first category to organize your expenses.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return ListTile(
                  leading: Icon(
                    getIconFromCodePoint(cat.icon),
                    color: Colors.white70,
                  ),
                  title: Text(
                    cat.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: cat.isCustom
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blueAccent,
                              ),
                              onPressed: () =>
                                  _showCategoryDialog(context, category: cat),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => provider.deleteCategory(cat.id),
                            ),
                          ],
                        )
                      : null,
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(context),
        tooltip: 'Add Category',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _IconPickerDialog extends StatelessWidget {
  final int selectedIcon;
  const _IconPickerDialog({required this.selectedIcon});

  @override
  Widget build(BuildContext context) {
    // A small set of Material icons for demo; can be expanded
    final icons = [
      Icons.fastfood,
      Icons.flight,
      Icons.shopping_cart,
      Icons.receipt_long,
      Icons.directions_car,
      Icons.coffee,
      Icons.movie,
      Icons.healing,
      Icons.pets,
      Icons.sports_soccer,
      Icons.category,
    ];
    return AlertDialog(
      backgroundColor: Colors.transparent,
      content: GlassmorphicCard(
        child: SizedBox(
          width: 300,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: icons.map((icon) {
              final code = icon.codePoint;
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(code),
                child: CircleAvatar(
                  backgroundColor: code == selectedIcon
                      ? Colors.blueAccent
                      : Colors.white12,
                  child: Icon(icon, color: Colors.white),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _CategoryColorPalette {
  static const List<Color> colors = [
    Color(0xFF1976D2), // Blue
    Color(0xFFD32F2F), // Red
    Color(0xFFFBC02D), // Yellow
    Color(0xFF388E3C), // Green
    Color(0xFF7B1FA2), // Purple
    Color(0xFFF57C00), // Orange
    Color(0xFF0097A7), // Cyan
    Color(0xFF455A64), // Blue Grey
    Color(0xFFAFB42B), // Lime
    Color(0xFF5D4037), // Brown
  ];
}
