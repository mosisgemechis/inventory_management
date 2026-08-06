import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui';
import '../../core/services/auth_service.dart';
import '../../core/constants/colors.dart';
import 'signup_screen.dart';
import '../../core/l10n/l10n.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_identifierController.text.isEmpty || _passwordController.text.isEmpty) {
      if (mounted) setState(() => _error = "Please fill in all fields");
      return;
    }

    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      await Provider.of<AuthService>(context, listen: false).signIn(
        _identifierController.text,
        _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().contains(']') ? e.toString().split(']').last.trim() : e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Deep Navy Gradient Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.loginGradient,
              ),
            ),
          ),
          
          // Subtle Mesh/Wave Pattern Overlay
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(color: AppColors.secondary.withOpacity(0.08)),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    // Glassmorphic Logo Container
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                           BoxShadow(color: AppColors.secondary.withOpacity(0.2), blurRadius: 40, spreadRadius: 0)
                        ]
                      ),
                      child: const Icon(Icons.barcode_reader, size: 64, color: AppColors.secondary),
                    ).animate().fadeIn(duration: 1.seconds).scale(),
                    
                    const SizedBox(height: 24),
                    const Text('Core Inventory', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: -1.5)),
                    Text('control_anywhere'.tr(context), style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                    const SizedBox(height: 48),
                    
                    // Glassmorphic Login Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('welcome_back'.tr(context), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              Text('signin_continue'.tr(context), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              const SizedBox(height: 40),
                              
                              TextField(
                                controller: _identifierController,
                                decoration: InputDecoration(
                                  labelText: 'username'.tr(context),
                                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscure,
                                decoration: InputDecoration(
                                  labelText: 'password'.tr(context),
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                onSubmitted: (_) => _handleLogin(),
                              ),
                              const SizedBox(height: 24),
                              
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Center(
                                    child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ),
                                ).animate().shake(),
                              
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    shadowColor: AppColors.secondary.withOpacity(0.4),
                                    elevation: _loading ? 0 : 8,
                                  ),
                                  child: _loading 
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                    : Text('login'.tr(context)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fade(duration: 800.ms).moveY(begin: 40, end: 0, curve: Curves.easeOutCubic),
                    
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('new_user'.tr(context), style: const TextStyle(color: AppColors.textSecondary)),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())), 
                          child: Text('create_account'.tr(context), style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    Text('© 2026 Core Inventory. All rights reserved.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const double step = 40.0;

    for (double i = 0; i <= size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Add some "dots" at intersections for a more techy feel
    var dotPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    for (double i = 0; i <= size.width; i += step * 2) {
      for (double j = 0; j <= size.height; j += step * 2) {
         canvas.drawCircle(Offset(i, j), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
