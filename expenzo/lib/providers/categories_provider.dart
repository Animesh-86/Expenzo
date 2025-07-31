import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/category.dart';

class CategoriesProvider extends ChangeNotifier {
  final Box<Category> _categoryBox = Hive.box<Category>('categories');

  List<Category> get categories {
    try {
      return _categoryBox.values.toList();
    } catch (e) {
      print('Error reading categories from Hive: $e');
      return [];
    }
  }

  void addCategory(Category category) async {
    await _categoryBox.put(category.id, category);
    notifyListeners();
  }

  void updateCategory(Category category) async {
    await _categoryBox.put(category.id, category);
    notifyListeners();
  }

  void deleteCategory(String id) async {
    await _categoryBox.delete(id);
    notifyListeners();
  }

  Category? getCategory(String id) {
    try {
      return _categoryBox.get(id);
    } catch (e) {
      print('Error reading category $id from Hive: $e');
      return null;
    }
  }

  /// Resets all categories to the default set (deletes all and re-initializes)
  Future<void> resetToDefaults() async {
    await _categoryBox.clear();
    await initializeDefaults();
    notifyListeners();
  }

  // Optionally, initialize with default categories
  Future<void> initializeDefaults() async {
    final defaults = [
      Category(
        id: 'food',
        name: 'Food',
        icon: 0xe57a, // Icons.fastfood
        isCustom: false,
        color: 0xFF1976D2,
      ),
      Category(
        id: 'travel',
        name: 'Travel',
        icon: 0xe53d, // Icons.directions_car
        isCustom: false,
        color: 0xFFD32F2F,
      ),
      Category(
        id: 'shopping',
        name: 'Shopping',
        icon: 0xe59c, // Icons.shopping_cart
        isCustom: false,
        color: 0xFFFBC02D,
      ),
      Category(
        id: 'bills',
        name: 'Bills',
        icon: 0xe227, // Icons.receipt
        isCustom: false,
        color: 0xFF388E3C,
      ),
      Category(
        id: 'entertainment',
        name: 'Entertainment',
        icon: 0xe030, // Icons.movie
        isCustom: false,
        color: 0xFF7B1FA2,
      ),
      Category(
        id: 'health',
        name: 'Health',
        icon: 0xe3b0, // Icons.local_hospital
        isCustom: false,
        color: 0xFFF57C00,
      ),
      Category(
        id: 'education',
        name: 'Education',
        icon: 0xe80c, // Icons.school
        isCustom: false,
        color: 0xFF0097A7,
      ),
      Category(
        id: 'groceries',
        name: 'Groceries',
        icon: 0xe8cc, // Icons.local_grocery_store
        isCustom: false,
        color: 0xFF455A64,
      ),
      Category(
        id: 'utilities',
        name: 'Utilities',
        icon: 0xe1a0, // Icons.lightbulb
        isCustom: false,
        color: 0xFFAFB42B,
      ),
      Category(
        id: 'rent',
        name: 'Rent',
        icon: 0xe88a, // Icons.home
        isCustom: false,
        color: 0xFF5D4037,
      ),
      Category(
        id: 'salary',
        name: 'Salary',
        icon: 0xe263, // Icons.account_balance_wallet
        isCustom: false,
        color: 0xFF1976D2,
      ),
      Category(
        id: 'gifts',
        name: 'Gifts',
        icon: 0xe112, // Icons.card_giftcard
        isCustom: false,
        color: 0xFFD32F2F,
      ),
      Category(
        id: 'investments',
        name: 'Investments',
        icon: 0xe227, // Icons.trending_up (use receipt as fallback)
        isCustom: false,
        color: 0xFFFBC02D,
      ),
      Category(
        id: 'misc',
        name: 'Miscellaneous',
        icon: 0xe14c, // Icons.category
        isCustom: false,
        color: 0xFF607D8B,
      ),
    ];
    bool added = false;
    for (final cat in defaults) {
      if (_categoryBox.get(cat.id) == null) {
        await _categoryBox.put(cat.id, cat);
        added = true;
      }
    }
    if (added) notifyListeners();
  }
}
