import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../core/services/auth_service.dart';
import '../../core/constants/colors.dart';
import 'signup_screen.dart';

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
              painter: WavePainter(color: AppColors.secondary.withOpacity(0.05)),
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
                      child: const Icon(Icons.inventory_2_rounded, size: 64, color: AppColors.secondary),
                    ).animate().fadeIn(duration: 1.seconds).scale(),
                    
                    const SizedBox(height: 24),
                    const Text('SmartInventory', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: -1.5)),
                    const Text('Control your shop from anywhere.', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
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
                              const Text('Welcome Back', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              const Text('Sign in to continue', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              const SizedBox(height: 40),
                              
                              TextField(
                                controller: _identifierController,
                                decoration: const InputDecoration(
                                  labelText: 'Username / Email',
                                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscure,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                onSubmitted: (_) => _handleLogin(),
                              ),
                              const SizedBox(height: 12),
                              
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(onPressed: () {}, child: const Text('Forgot password?', style: TextStyle(fontSize: 12))),
                              ),
                              const SizedBox(height: 32),
                              
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
                                    : const Text('Login'),
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
                        const Text("New user?", style: TextStyle(color: AppColors.textSecondary)),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())), 
                          child: const Text('Create an account', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    Text('© 2026 SmartInventory. All rights reserved.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
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

class WavePainter extends CustomPainter {
  final Color color;
  WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    var path = Path();
    for (var i = 0; i < size.height; i += 40) {
      path.moveTo(0, i.toDouble());
      path.quadraticBezierTo(
        size.width / 4, i - 20,
        size.width / 2, i.toDouble(),
      );
      path.quadraticBezierTo(
        3 * size.width / 4, i + 20,
        size.width, i.toDouble(),
      );
    }
    canvas.drawPath(path, paint);

    var path2 = Path();
    for (var i = 0; i < size.width; i += 40) {
      path2.moveTo(i.toDouble(), 0);
      path2.quadraticBezierTo(
        i - 20, size.height / 4,
        i.toDouble(), size.height / 2,
      );
      path2.quadraticBezierTo(
        i + 20, 3 * size.height / 4,
        i.toDouble(), size.height,
      );
    }
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
