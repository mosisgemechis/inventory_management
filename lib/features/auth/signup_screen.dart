import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/constants/colors.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _shopNameController = TextEditingController();
  
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  bool _hasUppercase = false;
  bool _hasDigits = false;
  bool _hasSpecialCharacters = false;
  bool _hasMinLength = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    final p = _passwordController.text;
    setState(() {
      _hasUppercase = p.contains(RegExp(r'[A-Z]'));
      _hasDigits = p.contains(RegExp(r'[0-9]'));
      _hasSpecialCharacters = p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      _hasMinLength = p.length >= 8;
    });
  }

  Future<void> _handleSignup() async {
    if (_usernameController.text.isEmpty || _fullNameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty || _shopNameController.text.isEmpty) {
      setState(() => _error = "Please fill in all fields");
      return;
    }

    if (_usernameController.text.length < 3) {
      setState(() => _error = "Username must be at least 3 characters long");
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = "Passwords do not match");
      return;
    }

    if (!_hasUppercase || !_hasDigits || !_hasSpecialCharacters || !_hasMinLength) {
      setState(() => _error = "Password does not meet requirements");
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await Provider.of<AuthService>(context, listen: false).signUp(
        _emailController.text,
        _passwordController.text,
        _usernameController.text,
        _shopNameController.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Create Account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const Text('Join SmartInventory Enterprise', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _shopNameController,
                      decoration: const InputDecoration(labelText: 'Pharmacy / Shop Name', prefixIcon: Icon(Icons.business_rounded)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.badge_outlined)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username', 
                        prefixIcon: Icon(Icons.person_outline),
                        hintText: 'Enter a unique username',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPasswordRequirements(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscure,
                      decoration: const InputDecoration(labelText: 'Confirm Password', prefixIcon: Icon(Icons.lock_reset_rounded)),
                    ),
                    const SizedBox(height: 32),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.bold)),
                      ).animate().shake(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleSignup,
                        child: _loading 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                          : const Text('Register & Setup Shop'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRequirements() {
    return Column(
      children: [
        _reqItem("Minimum 8 characters", _hasMinLength),
        _reqItem("At least one uppercase letter", _hasUppercase),
        _reqItem("At least one digit", _hasDigits),
        _reqItem("At least one special character", _hasSpecialCharacters),
      ],
    );
  }

  Widget _reqItem(String text, bool met) {
    return Row(
      children: [
        Icon(met ? Icons.check_circle_rounded : Icons.circle_outlined, size: 14, color: met ? AppColors.success : AppColors.textMuted),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 11, color: met ? AppColors.textPrimary : AppColors.textMuted)),
      ],
    );
  }
}
