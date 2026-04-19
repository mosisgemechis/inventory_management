import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/constants/colors.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_identifierController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = "Please fill in all fields");
      return;
    }

    setState(() { _loading = true; _error = null; });
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
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, Color(0xFF0F172A)],
                ),
              ),
            ),
          ),
          
          // Complex CustomPainter Parallax Background
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: SubtleIconPainter(
                      progress: _bgController.value,
                      iconPacks: _generateIcons(),
                    ),
                  );
                },
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  elevation: 40,
                  shadowColor: Colors.black.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.inventory_2_rounded, size: 48, color: AppColors.primary),
                        ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 24),
                        const Text('SmartInventory', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: -1)),
                        const Text('Enterprise Resource Planning', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, letterSpacing: 0.5)),
                        const SizedBox(height: 48),
                        TextField(
                          controller: _identifierController,
                          decoration: const InputDecoration(labelText: 'Username or Email', prefixIcon: Icon(Icons.person_outline_rounded)),
                        ),
                        const SizedBox(height: 24),
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
                          onSubmitted: (_) => _handleLogin(),
                        ),
                        const SizedBox(height: 40),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.bold)),
                          ).animate().shake(),
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _loading 
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) 
                              : const Text('Log In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fade(duration: 800.ms).moveY(begin: 30, end: 0, curve: Curves.easeOut),
              ),
            ),
          ),
        ],
      ),
    );
  }
  List<FloatingIcon> _generateIcons() {
    return List.generate(20, (i) => FloatingIcon(
      offset: Offset((i * 0.17) % 1.0, (i * 0.13) % 1.0),
      icon: i % 2 == 0 ? Icons.inventory_2_outlined : Icons.medication_outlined,
      size: 40 + (i % 5) * 15.0,
      opacity: 0.02 + (i % 3) * 0.03,
      speed: 0.5 + (i % 4) * 0.5,
    ));
  }
}

class FloatingIcon {
  final Offset offset;
  final IconData icon;
  final double size;
  final double opacity;
  final double speed;
  FloatingIcon({required this.offset, required this.icon, required this.size, required this.opacity, required this.speed});
}

class SubtleIconPainter extends CustomPainter {
  final double progress;
  final List<FloatingIcon> iconPacks;
  SubtleIconPainter({required this.progress, required this.iconPacks});

  @override
  void paint(Canvas canvas, Size size) {
    for (var i in iconPacks) {
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: String.fromCharCode(i.icon.codePoint),
        style: TextStyle(
          fontSize: i.size,
          fontFamily: i.icon.fontFamily,
          package: i.icon.fontPackage,
          color: Colors.white.withOpacity(i.opacity),
        ),
      );
      textPainter.layout();
      
      double y = (1.0 - ((progress * i.speed + i.offset.dy) % 1.0)) * size.height;
      double x = i.offset.dx * size.width;
      
      canvas.save();
      canvas.translate(x, y);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(SubtleIconPainter oldDelegate) => true;
}
