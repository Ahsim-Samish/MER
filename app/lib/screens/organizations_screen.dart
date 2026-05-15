import 'package:flutter/material.dart';

import '../main.dart';
import '../models/domain.dart';
import 'login_screen.dart';
import 'reports_screen.dart';

class OrganizationsScreen extends StatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  State<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends State<OrganizationsScreen> {
  final _searchController = TextEditingController();
  List<Organization> _orgs = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _search(''));
  }

  Future<void> _search(String q) async {
    final orgs =
        await AppStateScope.of(context).repository.searchOrganizations(q);
    if (!mounted) return;
    setState(() => _orgs = orgs);
  }

  void _logout() {
    AppStateScope.of(context).logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Организации'),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
            ),
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Выход'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск по ОКПО или названию...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                        },
                      ),
              ),
              onChanged: (v) {
                setState(() {});
                _search(v);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: _orgs.isEmpty
                    ? const Center(child: Text('Ничего не найдено'))
                    : _OrganizationsTable(orgs: _orgs),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizationsTable extends StatelessWidget {
  final List<Organization> orgs;
  const _OrganizationsTable({required this.orgs});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 32),
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          ),
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Код региона')),
            DataColumn(label: Text('ОКПО')),
            DataColumn(label: Text('Название')),
            DataColumn(label: Text('КОНХ')),
            DataColumn(label: Text('Правовая форма')),
            DataColumn(label: Text('')),
          ],
          rows: orgs
              .map(
                (o) => DataRow(cells: [
                  DataCell(Text('${o.id}')),
                  DataCell(Text(o.regionCode)),
                  DataCell(Text(o.okpo)),
                  DataCell(ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Text(o.name, overflow: TextOverflow.ellipsis),
                  )),
                  DataCell(Text(o.konh ?? '')),
                  DataCell(Text(o.legalForm ?? '')),
                  DataCell(FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReportsScreen(organization: o),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Отчёты'),
                  )),
                ]),
              )
              .toList(),
        ),
      ),
    );
  }
}
