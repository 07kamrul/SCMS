import 'package:flutter/material.dart';
import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/shared/widgets/responsive_scaffold.dart';

import '../data/auth_repository.dart';

const double _kMaxFormWidth = 480;

/// Public self-service form to create a new company plus its owner user.
/// Calls [AuthRepository.registerCompany] directly — this doesn't need to
/// go through the auth bloc since there is no session involved yet.
class RegisterCompanyPage extends StatefulWidget {
  const RegisterCompanyPage({super.key});

  @override
  State<RegisterCompanyPage> createState() => _RegisterCompanyPageState();
}

class _RegisterCompanyPageState extends State<RegisterCompanyPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _ownerFullNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _ownerPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _companyNameController.dispose();
    _ownerFullNameController.dispose();
    _ownerEmailController.dispose();
    _ownerPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await getIt<AuthRepository>().registerCompany(
        companyName: _companyNameController.text.trim(),
        ownerFullName: _ownerFullNameController.text.trim(),
        ownerEmail: _ownerEmailController.text.trim(),
        ownerPassword: _ownerPasswordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company registered. You can now sign in.'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _companyNameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Company name'),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Enter a company name'
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _ownerFullNameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Your full name'),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Enter your full name'
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _ownerEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Your email'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter your email';
              }
              if (!value.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _ownerPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Password'),
            validator: (value) {
              if (value == null || value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            validator: (value) {
              if (value != _ownerPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create company'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = _buildForm(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Register company')),
      body: ResponsiveScaffold(
        compact: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: form,
          ),
        ),
        expanded: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxFormWidth),
                child: form,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
