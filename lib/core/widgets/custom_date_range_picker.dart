import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';

class CustomDateRangeDialog extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const CustomDateRangeDialog({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<CustomDateRangeDialog> createState() => _CustomDateRangeDialogState();
}

class _CustomDateRangeDialogState extends State<CustomDateRangeDialog> {
  DateTime? _start;
  DateTime? _end;

  // Track the months currently being displayed (left and right panes)
  late DateTime _leftMonth;
  late DateTime _rightMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = widget.initialStartDate;
    _end = widget.initialEndDate;
    if (_start != null) {
      _leftMonth = DateTime(_start!.year, _start!.month, 1);
    } else {
      _leftMonth = DateTime(now.year, now.month, 1);
    }
    _rightMonth = DateTime(_leftMonth.year, _leftMonth.month + 1, 1);
  }

  void _nextMonth() {
    setState(() {
      _leftMonth = DateTime(_leftMonth.year, _leftMonth.month + 1, 1);
      _rightMonth = DateTime(_leftMonth.year, _leftMonth.month + 1, 1);
    });
  }

  void _prevMonth() {
    setState(() {
      _leftMonth = DateTime(_leftMonth.year, _leftMonth.month - 1, 1);
      _rightMonth = DateTime(_leftMonth.year, _leftMonth.month + 1, 1);
    });
  }

  void _handleDayTap(DateTime date) {
    setState(() {
      if (_start == null && _end == null) {
        _start = date;
      } else if (_start != null && _end == null) {
        if (date.isBefore(_start!)) {
          _start = date;
        } else {
          _end = date;
        }
      } else {
        _start = date;
        _end = null;
      }
    });
  }

  bool _isStart(DateTime date) => _start != null && _isSameDay(_start!, date);
  bool _isEnd(DateTime date) => _end != null && _isSameDay(_end!, date);
  bool _isInRange(DateTime date) {
    if (_start == null || _end == null) return false;
    return date.isAfter(_start!) && date.isBefore(_end!);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  final DateFormat _tfFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0C1935), // Navy blue
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  const Text("Custom Date Range", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                children: [
                  // Inputs Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Start Date", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            const SizedBox(height: 8),
                            _buildInputBox(_start != null ? _tfFormat.format(_start!) : ''),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text("—", style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("End Date", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            const SizedBox(height: 8),
                            _buildInputBox(_end != null ? _tfFormat.format(_end!) : ''),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // dual calendar layout
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildMonthCalendar(_leftMonth, isLeft: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMonthCalendar(_rightMonth, isLeft: false)),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Summary and Actions Footer
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calculate_outlined, color: AppColors.secondary, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Selected Range", style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                    if (_start != null && _end != null)
                                      Text("${_tfFormat.format(_start!)} - ${_tfFormat.format(_end!)} (${_end!.difference(_start!).inDays + 1} days)",
                                          style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold))
                                    else
                                      const Text("Select start and end date", style: TextStyle(color: Colors.black87, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.grey)),
                        ),
                        child: const Text("Cancel", style: TextStyle(color: Colors.black87)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: (_start != null && _end != null) ? () => Navigator.pop(context, DateTimeRange(start: _start!, end: _end!)) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0C1935),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                             Icon(Icons.check, size: 16),
                             SizedBox(width: 8),
                             Text("Apply"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.black54),
          const SizedBox(width: 12),
          Text(text.isEmpty ? "Select date" : text, 
             style: const TextStyle(color: Colors.black87, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar(DateTime month, {required bool isLeft}) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday; // 1=Mon, 7=Sun
    final dayOffset = firstWeekday == 7 ? 0 : firstWeekday;
    final weeksCount = ((daysInMonth + dayOffset) / 7).ceil();

    return Column(
      children: [
        // Month Navigation Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            isLeft 
              ? IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth)
              : const SizedBox(width: 48),
            Text(DateFormat('MMMM yyyy').format(month), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
            !isLeft
              ? IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth)
              : const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 12),
        // Weekdays
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
            .map((w) => Text(w, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)))
            .toList(),
        ),
        const SizedBox(height: 8),
        // Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, 
            childAspectRatio: 1,
            mainAxisSpacing: 2,
            crossAxisSpacing: 0,
          ),
          itemCount: weeksCount * 7,
          itemBuilder: (ctx, i) {
            final dayIndex = i - dayOffset + 1;
            if (dayIndex <= 0 || dayIndex > daysInMonth) return const SizedBox();
            final date = DateTime(month.year, month.month, dayIndex);
            
            final isS = _isStart(date);
            final isE = _isEnd(date);
            final inR = _isInRange(date);
            final isToday = _isSameDay(date, DateTime.now());

            Color? bgColor;
            Color textColor = Colors.black87;

            if (isS || isE) {
              bgColor = const Color(0xFF0C1935);
              textColor = Colors.white;
            } else if (inR) {
              bgColor = Colors.blue.withOpacity(0.1);
            }

            BorderRadius? br;
            if (isS && isE) {
               br = BorderRadius.circular(100);
            } else if (isS) {
               br = const BorderRadius.horizontal(left: Radius.circular(100));
            } else if (isE) {
               br = const BorderRadius.horizontal(right: Radius.circular(100));
            }

            return GestureDetector(
              onTap: () => _handleDayTap(date),
              child: Container(
                decoration: BoxDecoration(
                  color: inR ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                  // If it's the exact edge, draw circle
                ),
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (isS || isE) ? const Color(0xFF0C1935) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('$dayIndex', style: TextStyle(
                        color: textColor, 
                        fontWeight: isS || isE || isToday ? FontWeight.bold : FontWeight.normal
                      )),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

Future<DateTimeRange?> showCustomDateRangePicker({
  required BuildContext context, 
  DateTime? initialStartDate, 
  DateTime? initialEndDate
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (ctx) => CustomDateRangeDialog(
      initialStartDate: initialStartDate,
      initialEndDate: initialEndDate,
    ),
  );
}
