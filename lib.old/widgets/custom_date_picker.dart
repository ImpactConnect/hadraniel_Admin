import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDatePicker extends StatelessWidget {
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;
  final String labelText;
  final String hintText;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final InputDecoration? decoration;

  const CustomDatePicker({
    Key? key,
    required this.selectedDate,
    required this.onDateSelected,
    this.labelText = 'Select Date',
    this.hintText = 'Select a date',
    this.firstDate,
    this.lastDate,
    this.decoration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _selectDate(context),
      child: InputDecorator(
        decoration:
            decoration ??
            InputDecoration(
              labelText: labelText,
              hintText: hintText,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
        child: Text(
          selectedDate != null
              ? DateFormat('MMM dd, yyyy').format(selectedDate!)
              : '',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2100),
    );

    if (picked != null && picked != selectedDate) {
      onDateSelected(picked);
    }
  }
}

class CustomDateRangePicker extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime, DateTime) onDateRangeSelected;
  final String labelText;
  final String hintText;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final InputDecoration? decoration;

  const CustomDateRangePicker({
    Key? key,
    this.startDate,
    this.endDate,
    required this.onDateRangeSelected,
    this.labelText = 'Select Date Range',
    this.hintText = 'Select a date range',
    this.firstDate,
    this.lastDate,
    this.decoration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _selectDateRange(context),
      child: InputDecorator(
        decoration:
            decoration ??
            InputDecoration(
              labelText: labelText,
              hintText: hintText,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.date_range),
            ),
        child: Text(
          startDate != null && endDate != null
              ? '${DateFormat('MMM dd, yyyy').format(startDate!)} - ${DateFormat('MMM dd, yyyy').format(endDate!)}'
              : '',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2100),
    );

    if (picked != null) {
      onDateRangeSelected(picked.start, picked.end);
    }
  }
}
