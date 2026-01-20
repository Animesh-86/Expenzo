import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/category.dart';

class ExportService {
  Future<void> exportExpensesToCsv(
    List<Expense> expenses,
    List<Category> categories,
  ) async {
    List<List<dynamic>> rows = [];

    // Header
    rows.add(['Date', 'Description', 'Category', 'Amount']);

    // Map categories for easy lookup
    final catMap = {for (var c in categories) c.id: c.name};

    // Rows
    for (var expense in expenses) {
      rows.add([
        DateFormat('yyyy-MM-dd HH:mm').format(expense.date),
        expense.description,
        catMap[expense.category] ?? 'Unknown',
        expense.amount,
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/expenzo_export_${DateTime.now().millisecondsSinceEpoch}.csv';

    final File file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles([
      XFile(path),
    ], text: 'Here is my expense data from Expenzo!');
  }
}
