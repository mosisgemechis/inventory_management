import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../db/app_database.dart';
import '../services/conflict_service.dart';

/// A persistent, expanding banner that shows when there are unacknowledged
/// sync conflicts. Clicking a conflict expands its full details and provides
/// an [Acknowledge] button.
///
/// Survives app restarts — backed by [SyncConflicts] Drift table.
/// Place it near the top of the layout that contains your main content.
class ConflictBanner extends StatefulWidget {
  const ConflictBanner({super.key, required this.shopId});
  final String shopId;

  @override
  State<ConflictBanner> createState() => _ConflictBannerState();
}

class _ConflictBannerState extends State<ConflictBanner> {
  final ConflictService _conflicts = ConflictService();
  List<SyncConflict> _items = [];
  bool _expanded = false;
  StreamSubscription<List<SyncConflict>>? _sub;
  String? _expandedId;
  bool _acknowledging = false;

  @override
  void initState() {
    super.initState();
    _sub = _conflicts.watchUnacknowledged(widget.shopId).listen((rows) {
      if (mounted) setState(() => _items = rows);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Color get _bannerColor {
    if (_items.any((c) => c.severity == 'high')) return const Color(0xFFB00020);
    if (_items.any((c) => c.severity == 'medium')) return const Color(0xFFE65100);
    return const Color(0xFF1565C0);
  }

  IconData get _bannerIcon {
    if (_items.any((c) => c.severity == 'high')) return Icons.error_outline_rounded;
    if (_items.any((c) => c.severity == 'medium')) return Icons.warning_amber_rounded;
    return Icons.info_outline_rounded;
  }

  Future<void> _acknowledge(SyncConflict conflict) async {
    if (_acknowledging) return;
    setState(() => _acknowledging = true);
    try {
      await _conflicts.acknowledge(conflict.conflictId, shopId: widget.shopId);
      if (mounted) {
        setState(() {
          _expandedId = null;
          if (_items.length <= 1) _expanded = false;
        });
      }
    } finally {
      if (mounted) setState(() => _acknowledging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final count = _items.length;
    final bannerColor = _bannerColor;

    // Use LayoutBuilder so the expanded list height is capped relative to
    // available space, preventing bottom-overflow on mobile screens.
    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final screenH = MediaQuery.sizeOf(context).height;
        // Header row is ~48 px; leave the rest for the scrollable card list.
        const headerH = 48.0;
        final listMaxH = (screenH * 0.52 - headerH).clamp(80.0, screenH * 0.52);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuart,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          // clipBehavior prevents the animated resize painting outside the box.
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: bannerColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: bannerColor.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header row ──────────────────────────────────
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(_bannerIcon, color: bannerColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$count unacknowledged sync ${count == 1 ? 'conflict' : 'conflicts'} require your attention',
                          style: TextStyle(
                            color: bannerColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: bannerColor,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
              // ── Conflict list ────────────────────────────────
              if (_expanded)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: listMaxH),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _items
                          .map((c) => _ConflictCard(
                                conflict: c,
                                isExpanded: _expandedId == c.conflictId,
                                bannerColor: bannerColor,
                                acknowledging: _acknowledging,
                                onToggle: () => setState(() => _expandedId =
                                    _expandedId == c.conflictId
                                        ? null
                                        : c.conflictId),
                                onAcknowledge: () => _acknowledge(c),
                              ))
                          .toList(),
                    ),
                  ),
                ),
            ],
          ),
        ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.15, end: 0, curve: Curves.easeOutQuart);
      },
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.isExpanded,
    required this.bannerColor,
    required this.acknowledging,
    required this.onToggle,
    required this.onAcknowledge,
  });

  final SyncConflict conflict;
  final bool isExpanded;
  final Color bannerColor;
  final bool acknowledging;
  final VoidCallback onToggle;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detectedAt = DateFormat('MMM d, h:mm a').format(conflict.detectedAt.toLocal());

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bannerColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: bannerColor.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Conflict header ──
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SeverityDot(severity: conflict.severity),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conflict.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: bannerColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            conflict.body,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                            maxLines: isExpanded ? null : 2,
                            overflow: isExpanded ? null : TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: bannerColor.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),

            // ── Expanded detail ──
            if (isExpanded) ...[
              const Divider(height: 1, indent: 12, endIndent: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (conflict.whatHappened != null) ...[
                      _DetailRow(label: 'What happened', text: conflict.whatHappened!),
                      const SizedBox(height: 6),
                    ],
                    if (conflict.whatSystemDid != null) ...[
                      _DetailRow(label: 'What GM Inventory Everywhere did', text: conflict.whatSystemDid!),
                      const SizedBox(height: 6),
                    ],
                    if (conflict.requiredAction != null) ...[
                      _DetailRow(
                        label: conflict.requiresAction ? '⚠ Action required' : 'No action needed',
                        text: conflict.requiredAction!,
                        labelColor: conflict.requiresAction ? bannerColor : null,
                      ),
                      const SizedBox(height: 6),
                    ],
                    _DetailRow(label: 'Detected', text: detectedAt),
                    if (conflict.affectedEntityName != null) ...[
                      const SizedBox(height: 4),
                      _DetailRow(label: 'Affected record', text: '${conflict.affectedEntityName} (${conflict.affectedEntityType})'),
                    ],
                    const SizedBox(height: 12),
                    // ── Acknowledge button ──
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: bannerColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: acknowledging ? null : onAcknowledge,
                        icon: acknowledging
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: Text(
                          acknowledging ? 'Acknowledging…' : 'Acknowledge',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (conflict.requiresAction) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Acknowledging marks this conflict as seen. '
                        'It does not automatically fix the underlying issue — review the record above.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: bannerColor.withValues(alpha: 0.75),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeverityDot extends StatelessWidget {
  const _SeverityDot({required this.severity});
  final String severity;

  @override
  Widget build(BuildContext context) {
    final colors = {
      'high': const Color(0xFFB00020),
      'medium': const Color(0xFFE65100),
      'low': const Color(0xFF1565C0),
    };
    return Container(
      width: 10, height: 10,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: colors[severity] ?? Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.text, this.labelColor});
  final String label;
  final String text;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: labelColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          TextSpan(
            text: text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
