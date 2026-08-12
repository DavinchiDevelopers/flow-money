import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/category.dart';
import '../../models/recurring_transaction.dart';
import '../../services/database_interface.dart';
import '../../services/database_service.dart';
import '../../services/mock_database_service.dart';
import '../../services/recurring_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';

class AddRecurringScreen extends StatefulWidget {
  final RecurringTransaction? recurring;

  const AddRecurringScreen({super.key, this.recurring});

  @override
  State<AddRecurringScreen> createState() => _AddRecurringScreenState();
}

class _AddRecurringScreenState extends State<AddRecurringScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final DatabaseInterface _db;
  late final TabController _tabController;
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  TransactionType _type = TransactionType.expense;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  Category? _selectedCat;
  DateTime _startDate = DateTime.now();
  List<Category> _categories = [];
  bool _saving = false;

  bool get _isEditing => widget.recurring != null;

  @override
  void initState() {
    super.initState();
    _db = kIsWeb ? MockDatabaseService() : DatabaseService();

    if (_isEditing) {
      final r = widget.recurring!;
      _type = r.type;
      _frequency = r.frequency;
      _amountCtrl.text = r.amount.toInt().toString();
      _descCtrl.text = r.description;
      _startDate = r.startDate;
    }

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _type == TransactionType.expense ? 0 : 1,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _type = _tabController.index == 0 ? TransactionType.expense : TransactionType.income;
          _selectedCat = null;
        });
        _loadCategories();
      }
    });
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await _db.getCategoriesByType(_type);
    setState(() {
      _categories = cats;
      if (_isEditing && cats.isNotEmpty) {
        _selectedCat = cats.firstWhere(
          (c) => c.id == widget.recurring!.categoryId,
          orElse: () => cats.first,
        );
      } else if (cats.isNotEmpty && _selectedCat == null) {
        _selectedCat = cats.first;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedCat == null) return;
    setState(() => _saving = true);
    try {
      final amount = double.parse(_amountCtrl.text.replaceAll(' ', ''));
      final desc = _descCtrl.text.trim();

      if (_isEditing) {
        await _db.updateRecurringTransaction(widget.recurring!.copyWith(
          amount: amount,
          description: desc.isEmpty ? _selectedCat!.name : desc,
          categoryId: _selectedCat!.id!,
          type: _type,
          frequency: _frequency,
          startDate: _startDate,
        ));
      } else {
        await _db.insertRecurringTransaction(RecurringTransaction(
          amount: amount,
          description: desc.isEmpty ? _selectedCat!.name : desc,
          categoryId: _selectedCat!.id!,
          type: _type,
          frequency: _frequency,
          startDate: _startDate,
          nextDate: RecurringService.dateOnly(_startDate),
          createdAt: DateTime.now(),
        ));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving recurring transaction')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: AppConstants.minDate,
      lastDate: AppConstants.maxDate,
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _type == TransactionType.expense ? AppTheme.expenseColor : AppTheme.incomeColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Recurring' : 'New Recurring'),
        actions: [
          if (!_saving)
            TextButton(
              onPressed: _save,
              child: Text('Save', style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
            ),
        ],
        bottom: _isEditing
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: accent,
                labelColor: accent,
                unselectedLabelColor: Colors.grey,
                tabs: const [Tab(text: 'Expense'), Tab(text: 'Income')],
              ),
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _AmountField(controller: _amountCtrl),
                  const SizedBox(height: 20),
                  _FrequencySelector(
                    value: _frequency,
                    onChanged: (f) => setState(() => _frequency = f),
                  ),
                  const SizedBox(height: 20),
                  _CategoryGrid(
                    categories: _categories,
                    selected: _selectedCat,
                    onSelect: (c) => setState(() => _selectedCat = c),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    maxLength: AppConstants.maxDescriptionLength,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: _selectedCat?.name ?? 'Optional',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _DatePicker(
                    label: 'Start date',
                    date: _startDate,
                    onTap: _pickStartDate,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _isEditing ? 'Save Changes' : 'Create Recurring',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;

  const _AmountField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        labelText: 'Amount',
        suffixText: AppConstants.currency,
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Enter amount';
        final n = double.tryParse(v);
        if (n == null || n < AppConstants.minAmount) return 'Invalid amount';
        return null;
      },
    );
  }
}

class _FrequencySelector extends StatelessWidget {
  final RecurringFrequency value;
  final ValueChanged<RecurringFrequency> onChanged;

  const _FrequencySelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Frequency', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: RecurringFrequency.values.map((f) {
            final selected = value == f;
            return ChoiceChip(
              label: Text(f.displayName),
              selected: selected,
              onSelected: (_) => onChanged(f),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<Category> categories;
  final Category? selected;
  final ValueChanged<Category> onSelect;

  const _CategoryGrid({required this.categories, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 10),
        if (categories.isEmpty)
          const Center(child: CircularProgressIndicator())
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((cat) {
              final isSelected = selected?.id == cat.id;
              final color = Color(int.parse('0xFF${cat.colorHex.substring(1)}'));
              return GestureDetector(
                onTap: () => onSelect(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? color : color.withAlpha((color.a * 0.08 * 255.0).round().clamp(0, 255)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : color.withAlpha((color.a * 0.3 * 255.0).round().clamp(0, 255)),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppConstants.iconFor(cat.icon), color: isSelected ? Colors.white : color, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        cat.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : color,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DatePicker({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMMM d, yyyy').format(date),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
