import 'package:flutter/material.dart';

import '../main.dart';
import '../models/domain.dart';
import 'organizations_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AppUser? _selectedUser;
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  List<AppUser> _users = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadUsers);
  }

  Future<void> _loadUsers() async {
    final users =
        await AppStateScope.of(context).repository.listUsers();
    if (!mounted) return;
    setState(() => _users = users);
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await AppStateScope.of(context)
        .login(_selectedUser!.id, _passwordController.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      setState(() => _error = 'Неверный пароль');
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OrganizationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFF1E88E5),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_outlined,
                          color: Colors.white, size: 160),
                      SizedBox(height: 32),
                      Text(
                        'Электронная отчётность\n2-фермер',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Авторизация пользователя',
                          style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text('Заполните поля ниже:'),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<AppUser>(
                        initialValue: _selectedUser,
                        items: _users
                            .map((u) => DropdownMenuItem<AppUser>(
                                  value: u,
                                  child: Row(children: [
                                    const Icon(Icons.person_outline, size: 18),
                                    const SizedBox(width: 8),
                                    Flexible(child: Text(u.district)),
                                  ]),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedUser = v),
                        decoration:
                            const InputDecoration(labelText: 'Пользователь'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Пароль',
                          prefixIcon: Icon(Icons.lock_outline),
                          helperText: 'Демо-пароль: 1234',
                        ),
                        onSubmitted: (_) =>
                            _selectedUser != null ? _submit() : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!,
                            style: TextStyle(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.login),
                          onPressed: _selectedUser != null && !_loading
                              ? _submit
                              : null,
                          label: const Text('Войти'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
