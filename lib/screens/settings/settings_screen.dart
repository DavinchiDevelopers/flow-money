import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../models/user_profile.dart';
import '../../models/currency_rate.dart';
import '../../services/csv_service.dart';
import '../../services/database_interface.dart';
import '../../services/database_service.dart';
import '../../services/mock_database_service.dart';
import '../../services/currency_service.dart';
import '../recurring/recurring_list_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final DatabaseInterface _db;
  final _nameCtrl = TextEditingController();

  UserProfile? _profile;
  List<CurrencyRate> _rates = [];
  bool _loading = false;
  bool _loadingRates = false;
  bool _exporting = false;
  bool _importing = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _db = kIsWeb ? MockDatabaseService() : DatabaseService();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final p = await _db.getUserProfile();
    if (p != null) {
      setState(() {
        _profile = p;
        if (p.name.isNotEmpty) _nameCtrl.text = p.name;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final p = UserProfile(
        id: _profile?.id,
        name: _nameCtrl.text.trim(),
        createdAt: _profile?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _db.saveUserProfile(p);
      setState(() {
        _profile = p;
        _editing = false;
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
      }
    } catch (_) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving profile')),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final results = await Future.wait([
        _db.getTransactions(),
        _db.getCategories(),
      ]);
      final transactions = results[0] as List<Transaction>;
      final categories = results[1] as List<Category>;
      final csv = CsvService.exportTransactions(transactions, categories);

      await Share.share(csv, subject: 'FlowMoney Export');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV exported')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importCsv() async {
    setState(() => _importing = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;

      final file = picked.files.first;
      if (file.bytes == null) {
        throw Exception('Unable to read file');
      }
      final content = utf8.decode(file.bytes!);

      final categories = await _db.getCategories();
      final parsed = CsvService.parseTransactions(content, categories);

      if (parsed.transactions.isEmpty) {
        if (mounted) {
          final message = parsed.errors.isNotEmpty
              ? parsed.errors.first
              : 'No valid transactions found';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import CSV'),
          content: Text(
            'Import ${parsed.imported} transaction(s)?'
            '${parsed.skipped > 0 ? '\n${parsed.skipped} row(s) will be skipped.' : ''}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
          ],
        ),
      );
      if (confirmed != true) return;

      await _db.importTransactions(parsed.transactions);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${parsed.imported} transaction(s)')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _fetchRates() async {
    setState(() => _loadingRates = true);
    try {
      final rates = await CurrencyService.fetchAllRates();
      setState(() {
        _rates = rates;
        _loadingRates = false;
      });
    } catch (_) {
      setState(() => _loadingRates = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load rates')),
        );
      }
    }
  }

  Future<void> _resetData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Data'),
        content: const Text(
          'This will delete all transactions and profile data. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _loading = true);
    await _db.resetAllData();
    setState(() {
      _profile = null;
      _nameCtrl.clear();
      _editing = false;
      _loading = false;
    });
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _ProfileSection(
                  profile: _profile,
                  editing: _editing,
                  nameCtrl: _nameCtrl,
                  onEdit: () => setState(() => _editing = true),
                  onCancel: () => setState(() {
                    _editing = false;
                    _nameCtrl.text = _profile?.name ?? '';
                  }),
                  onSave: _saveProfile,
                ),
                const SizedBox(height: 20),
                _Card(
                  child: ListTile(
                    leading: const Icon(Icons.repeat_rounded),
                    title: const Text('Recurring Transactions'),
                    subtitle: const Text('Manage subscriptions and bills'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RecurringListScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _DataSection(
                  exporting: _exporting,
                  importing: _importing,
                  onExport: _exportCsv,
                  onImport: _importCsv,
                ),
                const SizedBox(height: 20),
                const _CurrencySection(),
                const SizedBox(height: 20),
                _RatesSection(rates: _rates, loading: _loadingRates, onRefresh: _fetchRates),
                const SizedBox(height: 20),
                _DangerZone(onReset: _resetData),
              ],
            ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final UserProfile? profile;
  final bool editing;
  final TextEditingController nameCtrl;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _ProfileSection({
    required this.profile,
    required this.editing,
    required this.nameCtrl,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              if (!editing) IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: onEdit),
            ],
          ),
          const SizedBox(height: 12),
          if (editing) ...[
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(onPressed: onSave, child: const Text('Save')),
              ],
            ),
          ] else if (profile != null) ...[
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Name',
              value: profile!.name.isNotEmpty ? profile!.name : 'Not set',
            ),
          ] else ...[
            Center(
              child: Column(
                children: [
                  Icon(Icons.person_outline, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No profile yet', style: TextStyle(color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: onEdit, child: const Text('Create Profile')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DataSection extends StatelessWidget {
  final bool exporting;
  final bool importing;
  final VoidCallback onExport;
  final VoidCallback onImport;

  const _DataSection({
    required this.exporting,
    required this.importing,
    required this.onExport,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Data', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Export or import transactions as CSV. Data stays on your device.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: exporting ? null : onExport,
              icon: exporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_outlined, size: 18),
              label: const Text('Export CSV'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: importing ? null : onImport,
              icon: importing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_outlined, size: 18),
              label: const Text('Import CSV'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}

class _CurrencySection extends StatelessWidget {
  const _CurrencySection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Default Currency', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primary.withAlpha((cs.primary.a * 0.06 * 255.0).round().clamp(0, 255)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withAlpha((cs.primary.a * 0.15 * 255.0).round().clamp(0, 255))),
            ),
            child: Row(
              children: [
                Icon(Icons.monetization_on_outlined, color: cs.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kazakhstani Tenge', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      Text('KZT (\u{20B8})', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
                Icon(Icons.check_circle, color: cs.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatesSection extends StatelessWidget {
  final List<CurrencyRate> rates;
  final bool loading;
  final VoidCallback onRefresh;

  const _RatesSection({required this.rates, required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Exchange Rates', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              if (loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          if (rates.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Updated ${DateFormat('MMM d, HH:mm').format(rates.first.updatedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 14),
            ...rates.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(r.flag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.code, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        Text(r.name, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Text(
                    '${r.formattedRate} \u{20B8}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            )),
          ] else ...[
            const SizedBox(height: 20),
            Center(child: Icon(Icons.currency_exchange, size: 40, color: Colors.grey.shade300)),
            const SizedBox(height: 8),
            Center(child: Text('Rates not loaded', style: TextStyle(color: Colors.grey.shade500))),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh Rates'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  final VoidCallback onReset;

  const _DangerZone({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Danger Zone',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.red.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Delete all transactions, profile, and settings. This cannot be undone.',
            style: TextStyle(fontSize: 13, color: Colors.red.shade400),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text('Delete All Data'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade500),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}
