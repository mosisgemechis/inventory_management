import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/services/theme_service.dart';

/// Font family used across the auth screens. Sourced from the theme so widgets
/// that build their own [TextStyle] match the rest of the app.
String? authFontFamily(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium?.fontFamily ??
    Theme.of(context).textTheme.titleLarge?.fontFamily;

/// Colour tokens shared by the login and sign-up pages so both stay visually
/// identical in light and dark mode.
class AuthPalette {
  const AuthPalette({
    required this.isDark,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.glow,
    required this.card,
    required this.cardBorder,
    required this.field,
    required this.fieldBorder,
    required this.title,
    required this.body,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.buttonStart,
    required this.buttonEnd,
    required this.buttonText,
    required this.buttonShadow,
    required this.socialBackground,
    required this.socialBorder,
    required this.socialText,
    required this.divider,
    required this.link,
    required this.cardShadow,
    required this.danger,
    required this.success,
    required this.warning,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.secondary,
  });

  final bool isDark;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color glow;
  final Color card;
  final Color cardBorder;
  final Color field;
  final Color fieldBorder;
  final Color title;
  final Color body;
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color buttonStart;
  final Color buttonEnd;
  final Color buttonText;
  final Color buttonShadow;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color secondary;
  final Color socialBackground;
  final Color socialBorder;
  final Color socialText;
  final Color divider;
  final Color link;
  final Color cardShadow;
  final Color danger;
  final Color success;
  final Color warning;

  static const AuthPalette dark = AuthPalette(
    isDark: true,
    backgroundTop: Color(0xFF050A15),
    backgroundBottom: Color(0xFF091426),
    glow: Color(0xFF2563EB),
    card: Color(0xFF0A1424),
    cardBorder: Color(0xFF1B2E4B),
    field: Color(0xFF0D1A2D),
    fieldBorder: Color(0xFF1E3352),
    title: Color(0xFFF8FAFC),
    body: Color(0xFF9FB0C7),
    muted: Color(0xFF6B7C95),
    accent: Color(0xFF3B82F6),
    accentSoft: Color(0x2E3B82F6),
    buttonStart: Color(0xFF2563EB),
    buttonEnd: Color(0xFF3B82F6),
    buttonText: Color(0xFFFFFFFF),
    buttonShadow: Color(0x663B82F6),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF9FB0C7),
    textMuted: Color(0xFF6B7C95),
    border: Color(0xFF1B2E4B),
    socialBackground: Color(0xFF0D1A2D),
    socialBorder: Color(0xFF1E3352),
    socialText: Color(0xFFE2E8F0),
    divider: Color(0xFF1B2E4B),
    link: Color(0xFF60A5FA),
    cardShadow: Color(0x59000000),
    danger: Color(0xFFF87171),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    secondary: Color(0xFF3B82F6),
  );

  static const AuthPalette light = AuthPalette(
    isDark: false,
    backgroundTop: Color(0xFFF6F9FE),
    backgroundBottom: Color(0xFFE9F1FB),
    glow: Color(0xFF93C5FD),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE3EBF7),
    field: Color(0xFFF8FAFE),
    fieldBorder: Color(0xFFE2E8F0),
    title: Color(0xFF0B1B34),
    body: Color(0xFF64748B),
    muted: Color(0xFF94A3B8),
    accent: Color(0xFF2563EB),
    accentSoft: Color(0x142563EB),
    buttonStart: Color(0xFF0B1B34),
    buttonEnd: Color(0xFF17304F),
    buttonText: Color(0xFFFFFFFF),
    buttonShadow: Color(0x33122A4A),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    border: Color(0xFFE2E8F0),
    socialBackground: Color(0xFFFFFFFF),
    socialBorder: Color(0xFFDFE7F3),
    socialText: Color(0xFF0F172A),
    divider: Color(0xFFE2E8F0),
    link: Color(0xFF2563EB),
    cardShadow: Color(0x141E3A66),
    danger: Color(0xFFDC2626),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    secondary: Color(0xFF2563EB),
  );

  static AuthPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Full-screen shell: themed gradient, decorative dot/arc backdrop and a
/// centred, scrollable card slot.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.child,
    this.maxWidth = 470,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    return Scaffold(
      backgroundColor: palette.backgroundTop,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.backgroundTop, palette.backgroundBottom],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _AuthBackdropPainter(palette)),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(0, constraints.maxHeight - 56),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackdropPainter extends CustomPainter {
  _AuthBackdropPainter(this.palette);

  final AuthPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = palette.isDark;

    final topGlow = Rect.fromCircle(
      center: Offset(size.width * 0.82, size.height * 0.04),
      radius: size.shortestSide * 0.62,
    );
    canvas.drawCircle(
      topGlow.center,
      topGlow.width / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.glow.withValues(alpha: isDark ? 0.16 : 0.45),
            palette.glow.withValues(alpha: 0),
          ],
        ).createShader(topGlow),
    );

    final bottomGlow = Rect.fromCircle(
      center: Offset(size.width * 0.08, size.height * 0.96),
      radius: size.shortestSide * 0.55,
    );
    canvas.drawCircle(
      bottomGlow.center,
      bottomGlow.width / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.accent.withValues(alpha: isDark ? 0.13 : 0.10),
            palette.accent.withValues(alpha: 0),
          ],
        ).createShader(bottomGlow),
    );

    // Thin concentric waves anchored off the bottom-left corner.
    final arcCenter = Offset(-size.width * 0.15, size.height * 1.05);
    for (var i = 0; i < 10; i++) {
      final radius = size.width * (0.55 + i * 0.075);
      final alpha = (isDark ? 0.085 : 0.06) * (1 - i / 12);
      canvas.drawArc(
        Rect.fromCircle(center: arcCenter, radius: radius),
        -math.pi * 0.62,
        math.pi * 0.42,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = palette.accent.withValues(alpha: alpha),
      );
    }

    // Dot fields, top-left and bottom-right.
    final dotColor = isDark
        ? palette.accent.withValues(alpha: 0.30)
        : const Color(0xFF7DA9F0).withValues(alpha: 0.55);
    _dotGrid(
      canvas,
      Rect.fromLTWH(0, 0, size.width * 0.30, size.height * 0.34),
      dotColor,
      20,
    );
    _dotGrid(
      canvas,
      Rect.fromLTWH(size.width * 0.74, size.height * 0.60, size.width * 0.26, size.height * 0.40),
      dotColor,
      20,
    );
  }

  void _dotGrid(Canvas canvas, Rect rect, Color color, double step) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
        stops: const [0.12, 1],
      ).createShader(rect.inflate(step));

    for (var y = rect.top; y < rect.bottom; y += step) {
      for (var x = rect.left; x < rect.right; x += step) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AuthBackdropPainter oldDelegate) =>
      oldDelegate.palette != palette;
}

/// Rounded surface that holds the whole form.
class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(26, 16, 26, 26),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow,
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key, this.size = 84});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final radius = size * 0.24;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.45 : 0.10),
            blurRadius: size * 0.30,
            offset: Offset(0, size * 0.12),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/brand/logo_mark.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => Container(
            color: palette.isDark ? const Color(0xFFF2F7FF) : const Color(0xFFEFF5FF),
            alignment: Alignment.center,
            child: Icon(
              Icons.inventory_2_rounded,
              size: size * 0.42,
              color: palette.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    this.logoSize = 84,
    this.showTagline = true,
  });

  final double logoSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final family = authFontFamily(context);
    final wordSize = logoSize * 0.31;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AuthLogo(size: logoSize),
        SizedBox(height: logoSize * 0.20 + 4),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'GM',
                style: TextStyle(
                  fontFamily: family,
                  fontSize: wordSize,
                  fontWeight: FontWeight.w800,
                  color: palette.title,
                  letterSpacing: 0.4,
                ),
              ),
              TextSpan(
                text: ' INVENTORY',
                style: TextStyle(
                  fontFamily: family,
                  fontSize: wordSize,
                  fontWeight: FontWeight.w800,
                  color: palette.accent,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: logoSize * 0.02 + 2),
        Text(
          'EVERYWHERE',
          style: TextStyle(
            fontFamily: family,
            fontSize: math.max(9, wordSize * 0.42),
            fontWeight: FontWeight.w700,
            letterSpacing: 3.2,
            color: palette.accent,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 6),
          Text(
            'Manage  •  Track  •  Optimize',
            style: TextStyle(
              fontSize: math.max(10, wordSize * 0.50),
              fontWeight: FontWeight.w500,
              color: palette.body,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ],
    );
  }
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final service = Provider.of<ThemeService>(context);
    final isDark = service.themeMode == ThemeMode.dark;

    return Semantics(
      button: true,
      label: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      child: _HoverScale(
        child: Tooltip(
          message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: () => service.toggleTheme(!isDark),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: palette.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isDark ? 'Light Mode' : 'Dark Mode',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.body,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      transitionBuilder: (child, animation) => RotationTransition(
                        turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        key: ValueKey<bool>(isDark),
                        size: 15,
                        color: palette.accent,
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
}

class _HoverScale extends StatefulWidget {
  const _HoverScale({required this.child});

  final Widget child;

  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.03 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late final FocusNode _focusNode;
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocus);
  }

  void _handleFocus() {
    if (!mounted) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final borderColor = _focused
        ? palette.accent
        : (_hovered ? palette.accent.withValues(alpha: 0.45) : palette.fieldBorder);

    return MouseRegion(
      cursor: SystemMouseCursors.text,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: palette.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: _focused ? 1.5 : 1),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: palette.accent.withValues(alpha: palette.isDark ? 0.22 : 0.14),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                widget.icon,
                size: 19,
                color: _focused ? palette.accent : palette.muted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                obscureText: widget.obscure,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                onSubmitted: widget.onSubmitted,
                autofillHints: widget.autofillHints,
                cursorColor: palette.accent,
                cursorWidth: 1.6,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: palette.title,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                    color: palette.muted,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (widget.onToggleObscure != null)
              IconButton(
                onPressed: widget.onToggleObscure,
                padding: EdgeInsets.zero,
                splashRadius: 18,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: widget.obscure ? 'Show password' : 'Hide password',
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    widget.obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    key: ValueKey<bool>(widget.obscure),
                    size: 19,
                    color: palette.muted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AuthDropdown<T> extends StatelessWidget {
  const AuthDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
    this.hint,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final family = authFontFamily(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: palette.field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.fieldBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: palette.muted),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isDense: true,
                isExpanded: true,
                borderRadius: BorderRadius.circular(16),
                dropdownColor: palette.card,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: palette.muted,
                ),
                style: TextStyle(
                  fontFamily: family,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: palette.title,
                ),
                hint: hint == null
                    ? null
                    : Text(
                        hint!,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w400,
                          color: palette.muted,
                        ),
                      ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthPrimaryButton extends StatefulWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final enabled = widget.onPressed != null && !widget.loading;
    final active = enabled && (_hovered || _pressed);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: enabled ? widget.onPressed : null,
          child: AnimatedScale(
            scale: _pressed ? 0.995 : (_hovered && enabled ? 1.012 : 1),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: widget.loading
                      ? [
                          palette.buttonStart.withValues(alpha: 0.75),
                          palette.buttonEnd.withValues(alpha: 0.75),
                        ]
                      : [palette.buttonStart, palette.buttonEnd],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: palette.buttonShadow,
                    blurRadius: active ? 28 : 18,
                    offset: Offset(0, active ? 10 : 8),
                  ),
                ],
              ),
              child: widget.loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: palette.buttonText,
                      ),
                    )
                  : Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: palette.buttonText,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthSecondaryButton extends StatefulWidget {
  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  State<AuthSecondaryButton> createState() => _AuthSecondaryButtonState();
}

class _AuthSecondaryButtonState extends State<AuthSecondaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovered ? palette.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? palette.accent.withValues(alpha: 0.5) : palette.fieldBorder,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _hovered ? palette.accent : palette.body,
            ),
          ),
        ),
      ),
    );
  }
}

class AuthSocialButton extends StatefulWidget {
  const AuthSocialButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  State<AuthSocialButton> createState() => _AuthSocialButtonState();
}

class _AuthSocialButtonState extends State<AuthSocialButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hovered ? palette.accentSoft : palette.socialBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered
                  ? palette.accent.withValues(alpha: 0.55)
                  : palette.socialBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(
                widget.icon,
                size: 16,
                color: widget.iconColor ?? palette.socialText,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.socialText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthDividerLabel extends StatelessWidget {
  const AuthDividerLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: palette.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: palette.muted,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: palette.divider)),
      ],
    );
  }
}

class AuthLink extends StatefulWidget {
  const AuthLink({
    super.key,
    required this.label,
    required this.onTap,
    this.fontSize = 12.5,
    this.fontWeight = FontWeight.w600,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;

  @override
  State<AuthLink> createState() => _AuthLinkState();
}

class _AuthLinkState extends State<AuthLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final family = authFontFamily(context);
    final color = widget.color ?? palette.link;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            fontFamily: family,
            fontSize: widget.fontSize,
            fontWeight: widget.fontWeight,
            height: 1.35,
            color: _hovered ? color.withValues(alpha: 0.78) : color,
            decoration: _hovered ? TextDecoration.underline : TextDecoration.none,
            decorationColor: color.withValues(alpha: 0.5),
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.danger.withValues(alpha: palette.isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 17, color: palette.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: palette.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthFooterNote extends StatelessWidget {
  const AuthFooterNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, size: 14, color: palette.muted),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 11.5, color: palette.muted),
          ),
        ),
      ],
    );
  }
}

class AuthIconButton extends StatefulWidget {
  const AuthIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<AuthIconButton> createState() => _AuthIconButtonState();
}

class _AuthIconButtonState extends State<AuthIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovered ? palette.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: _hovered ? palette.accent.withValues(alpha: 0.5) : palette.cardBorder,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: _hovered ? palette.accent : palette.body,
          ),
        ),
      ),
    );

    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}

class AuthStepProgress extends StatelessWidget {
  const AuthStepProgress({
    super.key,
    required this.step,
    required this.total,
    this.labels,
  });

  final int step;
  final int total;
  final List<String>? labels;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final label = labels != null && step < labels!.length ? labels![step] : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'STEP ${(step + 1).toString().padLeft(2, '0')} OF ${total.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: palette.accent,
              ),
            ),
            const Spacer(),
            if (label != null)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  label,
                  key: ValueKey<String>(label),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: palette.muted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(total, (index) {
            final reached = index <= step;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                height: 4,
                margin: EdgeInsets.only(right: index == total - 1 ? 0 : 8),
                decoration: BoxDecoration(
                  color: reached ? palette.accent : palette.divider,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: index == step
                      ? [
                          BoxShadow(
                            color: palette.accent.withValues(alpha: 0.55),
                            blurRadius: 8,
                          ),
                        ]
                      : const [],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
