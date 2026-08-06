import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/privacy_dialog.dart';
import '../../core/services/firestore_service.dart';
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
  bool _agreedToTerms = false;
  String _selectedCurrency = 'USD';
  String _selectedCountry = 'United States';

  static const List<Map<String, String>> _currencies = [
    {'code': 'USD', 'name': 'US Dollar'},
    {'code': 'EUR', 'name': 'Euro'},
    {'code': 'GBP', 'name': 'British Pound'},
    {'code': 'CAD', 'name': 'Canadian Dollar'},
    {'code': 'AUD', 'name': 'Australian Dollar'},
    {'code': 'NZD', 'name': 'New Zealand Dollar'},
    {'code': 'JPY', 'name': 'Japanese Yen'},
    {'code': 'CNY', 'name': 'Chinese Yuan'},
    {'code': 'INR', 'name': 'Indian Rupee'},
    {'code': 'SGD', 'name': 'Singapore Dollar'},
    {'code': 'HKD', 'name': 'Hong Kong Dollar'},
    {'code': 'AED', 'name': 'UAE Dirham'},
    {'code': 'SAR', 'name': 'Saudi Riyal'},
    {'code': 'ZAR', 'name': 'South African Rand'},
    {'code': 'ETB', 'name': 'Ethiopian Birr'},
    {'code': 'NGN', 'name': 'Nigerian Naira'},
    {'code': 'KES', 'name': 'Kenyan Shilling'},
    {'code': 'CHF', 'name': 'Swiss Franc'},
    {'code': 'BRL', 'name': 'Brazilian Real'},
    {'code': 'MXN', 'name': 'Mexican Peso'},
  ];
  final List<String> _countries = ['United States', 'Ethiopia', 'Kenya', 'Nigeria', 'South Africa', 'United Kingdom', 'Germany', 'France', 'Japan', 'Canada', 'Australia'];


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
      final email = _emailController.text.trim();
      final auth = Provider.of<AuthService>(context, listen: false);
      
      if (!auth.isValidEmail(email)) {
        setState(() { _loading = false; _error = "Please enter a valid email address."; });
        return;
      }
      
      if (!_agreedToTerms) {
        setState(() { _loading = false; _error = "Please agree to the Privacy Policy and Terms of Service."; });
        return;
      }

      await auth.signUp(
        email,
        _passwordController.text,
        _usernameController.text,
        _fullNameController.text,
        _shopNameController.text,
        currency: _selectedCurrency,
        country: _selectedCountry,
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
                    const Text('Join Core Inventory Enterprise', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _shopNameController,
                      decoration: const InputDecoration(labelText: 'Shop Name', prefixIcon: Icon(Icons.business_rounded)),
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
                    DropdownButtonFormField<String>(
                      value: _selectedCountry,
                      decoration: const InputDecoration(labelText: 'Country', prefixIcon: Icon(Icons.public)),
                      items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedCountry = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCurrency,
                      decoration: const InputDecoration(labelText: 'Primary Currency', prefixIcon: Icon(Icons.payments_outlined)),
                      items: _currencies.map((c) => DropdownMenuItem(
                        value: c['code'],
                        child: Text('${c['code']} – ${c['name']}'),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedCurrency = v!),
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
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _agreedToTerms,
                      onChanged: (v) => setState(() => _agreedToTerms = v!),
                      title: Wrap(
                        children: [
                          const Text('I agree to the ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          InkWell(
                            onTap: () => showDialog(context: context, builder: (_) => const PrivacyPolicyDialog()),
                            child: const Text('Privacy Policy & Terms', style: TextStyle(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                          ),
                        ],
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
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
