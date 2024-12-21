import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FormDatePicker extends ConsumerStatefulWidget {
  final String labelText;
  final DateTime? initialValue;
  final StateProvider<DateTime?>? valueProvider;
  final ValueChanged<DateTime>? onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const FormDatePicker({
    super.key,
    this.labelText = 'Date',
    this.initialValue,
    this.valueProvider,
    this.onChanged,
    this.firstDate,
    this.lastDate,
  }) : assert(initialValue == null || valueProvider == null,
            'Cannot provide both initialValue and valueProvider.');

  @override
  ConsumerState<FormDatePicker> createState() => _FormDatePickerState();
}

class _FormDatePickerState extends ConsumerState<FormDatePicker> {
  StateProvider<DateTime?>? _valueProvider;
  late DateTime _firstDate;
  late DateTime _lastDate;

  DateTime? value;

  void _onValueChanged(DateTime value) {
    if (widget.onChanged != null && value != ref.read(_valueProvider!)) {
      widget.onChanged!(value);
    }

    ref.read(_valueProvider!.notifier).state = value;
  }

  @override
  void initState() {
    super.initState();

    _valueProvider = widget.valueProvider ??
        StateProvider<DateTime?>((ref) => widget.initialValue);

    _firstDate = widget.firstDate ?? DateTime.now();
    _lastDate =
        widget.lastDate ?? DateTime.now().add(const Duration(days: 365));
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? value = ref.watch(_valueProvider!);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              widget.labelText,
              style: Theme.of(context).inputDecorationTheme.floatingLabelStyle,
            ),
            Text(
              value != null ? DateFormat.yMd().format(value) : 'mm/dd/yyyy',
              style: value != null
                  ? Theme.of(context).textTheme.bodyLarge
                  : Theme.of(context).inputDecorationTheme.hintStyle,
            ),
          ],
        ),
        TextButton(
          child: const Text('Edit'),
          onPressed: () async {
            DateTime? newDate = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: _firstDate,
              lastDate: _lastDate,
            );

            // Don't change the date if the date picker returns null.
            if (newDate == null) {
              return;
            }

            _onValueChanged(newDate);
          },
        )
      ],
    );
  }
}
