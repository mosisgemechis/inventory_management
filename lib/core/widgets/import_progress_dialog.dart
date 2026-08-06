import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/bulk_import/import_models.dart';

class ImportProgressDialog extends StatefulWidget {
  final Future<void> Function(
    Function(ImportProgressState state) onProgress,
  ) onStart;
  final ImportCancellationToken cancellationToken;

  const ImportProgressDialog({
    super.key,
    required this.onStart,
    required this.cancellationToken,
  });

  @override
  State<ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<ImportProgressDialog> {
  ImportProgressState _state = ImportProgressState(
    current: 0,
    total: 1,
    currentProductName: "Preparing import…",
    importedCount: 0,
    updatedCount: 0,
    skippedCount: 0,
    failedCount: 0,
  );

  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onStart((s) {
        if (mounted) setState(() => _state = s);
      });
    });
  }

  void _requestCancel() {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    widget.cancellationToken.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = _state.total > 0
        ? (_state.current / _state.total).clamp(0.0, 1.0)
        : 0.0;
    final percentInt = (progressPercent * 100).toInt();
    final isCancelled = _state.isCancelled;

    Color barColor = AppColors.secondary;
    if (_cancelling && !isCancelled) barColor = Colors.orange;
    if (isCancelled) barColor = Colors.orange;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────
              Row(
                children: [
                  if (!_cancelling && !isCancelled)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.secondary),
                    )
                  else
                    const Icon(Icons.cancel_outlined,
                        color: Colors.orange, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCancelled
                              ? "Import Cancelled"
                              : _cancelling
                                  ? "Cancelling… (finishing current row)"
                                  : "Importing Products…",
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          isCancelled
                              ? "Stopped after ${_state.current} of ${_state.total} rows."
                              : "Processing row ${_state.current} of ${_state.total}",
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "$percentInt%",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: barColor),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Progress Bar ─────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progressPercent,
                  minHeight: 10,
                  backgroundColor: barColor.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              const SizedBox(height: 12),

              // ── Current Product Name ──────────────────────
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCancelled
                          ? Icons.stop_circle_outlined
                          : Icons.inventory_2_outlined,
                      size: 15,
                      color: barColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _state.currentProductName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Counter Badges ───────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _counterBadge(
                      "Imported", "${_state.importedCount}", AppColors.success),
                  _counterBadge(
                      "Updated", "${_state.updatedCount}", AppColors.info),
                  _counterBadge(
                      "Skipped", "${_state.skippedCount}", Colors.orange),
                  _counterBadge(
                      "Failed", "${_state.failedCount}", AppColors.danger),
                ],
              ),
              const SizedBox(height: 16),

              // ── Cancel Button ────────────────────────────
              if (!isCancelled)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _cancelling ? null : _requestCancel,
                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                    label: Text(
                        _cancelling ? "Cancelling…" : "Cancel Import"),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _counterBadge(String label, String count, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          count,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
