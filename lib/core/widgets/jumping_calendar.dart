import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';

class JumpingDateRangePicker extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;
  const JumpingDateRangePicker({super.key, required this.initialStart, required this.initialEnd});

  @override
  State<JumpingDateRangePicker> createState() => _JumpingDateRangePickerState();
}

enum CalendarView { days, months, years }

class _JumpingDateRangePickerState extends State<JumpingDateRangePicker> {
  late DateTime _startDate;
  late DateTime _endDate;
  late DateTime _viewMonth;
  CalendarView _currentView = CalendarView.days;
  bool _selectingStart = true;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStart;
    _endDate = widget.initialEnd;
    _viewMonth = DateTime(_startDate.year, _startDate.month, 1);
  }

  void _onDateTapped(DateTime date) {
    setState(() {
      if (_selectingStart) {
        _startDate = date;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      } else {
        if (date.isBefore(_startDate)) {
          // If user taps a date before start while in "End" mode, 
          // treat it as moving the start date.
          _startDate = date;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = date;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: 400,
        height: 520,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            const Divider(height: 1),
            // Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildViewContent(),
              ),
            ),
            const Divider(height: 1),
            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Select Range",
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              _headerDatePart(DateFormat('MMM d').format(_startDate), () {
                setState(() {
                  _selectingStart = true;
                  _currentView = CalendarView.days;
                });
              }, _selectingStart),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward_rounded,
                    color: Colors.blueAccent, size: 18),
              ),
              _headerDatePart(DateFormat('MMM d').format(_endDate), () {
                setState(() {
                  _selectingStart = false;
                  _currentView = CalendarView.days;
                });
              }, !_selectingStart),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        setState(() => _currentView = CalendarView.months),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12)),
                    child: Text(DateFormat('MMMM').format(_viewMonth),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface)),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () =>
                        setState(() => _currentView = CalendarView.years),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12)),
                    child: Text(_viewMonth.year.toString(),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7))),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                      onPressed: () => _moveMonth(-1),
                      icon: const Icon(Icons.chevron_left_rounded)),
                  IconButton(
                      onPressed: () => _moveMonth(1),
                      icon: const Icon(Icons.chevron_right_rounded)),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerDatePart(String label, VoidCallback onTap, bool isActive) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? Colors.blueAccent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? Colors.blueAccent
                    : Theme.of(context).colorScheme.onSurface)),
      ),
    );
  }

  void _moveMonth(int dir) {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + dir, 1);
    });
  }

  Widget _buildViewContent() {
    switch (_currentView) {
      case CalendarView.days:
        return _buildDaysGrid();
      case CalendarView.months:
        return _buildMonthsGrid();
      case CalendarView.years:
        return _buildYearsGrid();
    }
  }

  Widget _buildDaysGrid() {
    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final lastDay = DateTime(_viewMonth.year, _viewMonth.month + 1, 0);
    final startPadding = (firstDay.weekday % 7);
    final dayNames = ["S", "M", "T", "W", "T", "F", "S"];

    return Column(
      key: const ValueKey('days'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: dayNames
                .map((d) => SizedBox(
                    width: 40,
                    child: Center(
                        child: Text(d,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.4),
                                fontSize: 12,
                                fontWeight: FontWeight.bold)))))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7),
            itemBuilder: (context, i) {
              final dayNum = i - startPadding + 1;
              if (dayNum < 1 || dayNum > lastDay.day) return const SizedBox();

              final current =
                  DateTime(_viewMonth.year, _viewMonth.month, dayNum);
              final isStart = current == _startDate;
              final isEnd = current == _endDate;
              final isSelected = isStart || isEnd;
              final isInRange =
                  current.isAfter(_startDate) && current.isBefore(_endDate);

              return GestureDetector(
                onTap: () => _onDateTapped(current),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blueAccent
                        : (isInRange
                            ? Colors.blueAccent.withOpacity(0.1)
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(dayNum.toString(),
                        style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isInRange
                                    ? Colors.blueAccent
                                    : Theme.of(context).colorScheme.onSurface),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthsGrid() {
    final months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return GridView.builder(
      key: const ValueKey('months'),
      padding: const EdgeInsets.all(24),
      itemCount: 12,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.5),
      itemBuilder: (context, i) {
        final isCurrent = _viewMonth.month == i + 1;
        return InkWell(
          onTap: () => setState(() {
            _viewMonth = DateTime(_viewMonth.year, i + 1, 1);
            _currentView = CalendarView.days;
          }),
          child: Center(
            child: Text(months[i],
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent
                        ? Colors.blueAccent
                        : Theme.of(context).colorScheme.onSurface)),
          ),
        );
      },
    );
  }

  Widget _buildYearsGrid() {
    final currentYear = DateTime.now().year;
    return GridView.builder(
      key: const ValueKey('years'),
      padding: const EdgeInsets.all(24),
      itemCount: 20,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, childAspectRatio: 1.5),
      itemBuilder: (context, i) {
        final year = currentYear - 10 + i;
        final isCurrent = _viewMonth.year == year;
        return InkWell(
          onTap: () => setState(() {
            _viewMonth = DateTime(year, _viewMonth.month, 1);
            _currentView = CalendarView.days;
          }),
          child: Center(
            child: Text(year.toString(),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent
                        ? Colors.blueAccent
                        : Theme.of(context).colorScheme.onSurface)),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel",
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5)))),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.pop(
                context, DateTimeRange(start: _startDate, end: _endDate)),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text("Apply Range"),
          )
        ],
      ),
    );
  }
}
