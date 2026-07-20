import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/auth/permission.dart';
import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/shared/widgets/loading_view.dart';
import 'package:mobile/shared/widgets/responsive_scaffold.dart';

import '../bloc/user_form_bloc.dart';
import '../bloc/user_form_event.dart';
import '../bloc/user_form_state.dart';
import '../data/team_models.dart';

const double _kMaxFormWidth = 560;

/// Create/edit form for a single user. `userId == null` creates a new user
/// (password required); otherwise the existing user is loaded and updated
/// (password field hidden — password changes go through the dedicated
/// reset-password action instead).
class UserFormPage extends StatelessWidget {
  const UserFormPage({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = getIt<UserFormBloc>();
        final id = userId;
        if (id != null) bloc.add(UserFormUserLoaded(id));
        return bloc;
      },
      child: _UserFormView(userId: userId),
    );
  }
}

class _UserFormView extends StatefulWidget {
  const _UserFormView({this.userId});

  final String? userId;

  @override
  State<_UserFormView> createState() => _UserFormViewState();
}

class _UserFormViewState extends State<_UserFormView> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _jobTitleController = TextEditingController();
  Role _role = Role.employee;

  bool get _isEdit => widget.userId != null;
  bool _prefilled = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _jobTitleController.dispose();
    super.dispose();
  }

  void _prefill(TeamUser user) {
    if (_prefilled) return;
    _prefilled = true;
    _fullNameController.text = user.fullName;
    _emailController.text = user.email ?? '';
    _phoneController.text = user.phone ?? '';
    _jobTitleController.text = user.jobTitle ?? '';
    _role = user.role;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<UserFormBloc>().add(
      UserFormSubmitted(
        userId: widget.userId,
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        password: _isEdit ? null : _passwordController.text,
        role: _role,
        jobTitle: _jobTitleController.text.trim().isEmpty
            ? null
            : _jobTitleController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit user' : 'Add user')),
      body: SafeArea(
        child: BlocConsumer<UserFormBloc, UserFormState>(
          listenWhen: (previous, current) =>
              current.status == UserFormStatus.success ||
              (current.status == UserFormStatus.failure &&
                  current.errorMessage != previous.errorMessage),
          listener: (context, state) {
            if (state.status == UserFormStatus.success) {
              Navigator.of(context).pop();
            } else if (state.status == UserFormStatus.failure) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
            }
          },
          builder: (context, state) {
            if (state.loadedUser != null) _prefill(state.loadedUser!);
            final isBusy =
                state.status == UserFormStatus.loading ||
                state.status == UserFormStatus.submitting;
            if (_isEdit && state.loadedUser == null && isBusy) {
              return const LoadingView();
            }
            final form = Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Enter a full name'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    validator: (_) {
                      if (_emailController.text.trim().isEmpty &&
                          _phoneController.text.trim().isEmpty) {
                        return 'Provide at least one of email or phone';
                      }
                      return null;
                    },
                  ),
                  if (!_isEdit) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) {
                        if (_isEdit) return null;
                        if (value == null || value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<Role>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: Role.values
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.value),
                          ),
                        )
                        .toList(),
                    onChanged: (role) {
                      if (role != null) setState(() => _role = role);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _jobTitleController,
                    decoration: const InputDecoration(labelText: 'Job title'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: isBusy ? null : _submit,
                    child: isBusy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEdit ? 'Save changes' : 'Create user'),
                  ),
                ],
              ),
            );
            return ResponsiveScaffold(
              compact: (context) => SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: form,
              ),
              expanded: (context) => SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _kMaxFormWidth),
                    child: form,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
