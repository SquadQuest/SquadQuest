import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FormTimePicker extends ConsumerStatefulWidget {
  final String labelText;
  final TimeOfDay? initialValue;
  final StateProvider<TimeOfDay?>? valueProvider;
  final ValueChanged<TimeOfDay>? onChanged;

  const FormTimePicker({
    super.key,
    this.labelText = 'Time',
    this.initialValue,
    this.valueProvider,
    this.onChanged,
  }) : assert(initialValue == null || valueProvider == null,
            'Cannot provide both initialValue and valueProvider.');

  @override
  ConsumerState<FormTimePicker> createState() => _FormTimePickerState();
}

class _FormTimePickerState extends ConsumerState<FormTimePicker> {
  StateProvider<TimeOfDay?>? _valueProvider;

  void _onValueChanged(TimeOfDay value) {
    if (widget.onChanged != null && value != ref.read(_valueProvider!)) {
      widget.onChanged!(value);
    }

    ref.read(_valueProvider!.notifier).state = value;
  }

  @override
  void initState() {
    super.initState();

    _valueProvider = widget.valueProvider ??
        StateProvider<TimeOfDay?>((ref) => widget.initialValue);
  }

  @override
  Widget build(BuildContext context) {
    final TimeOfDay? value = ref.watch(_valueProvider!);

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
              value != null
                  ? MaterialLocalizations.of(context).formatTimeOfDay(value)
                  : 'hh:mm a',
              style: value != null
                  ? Theme.of(context).textTheme.bodyLarge
                  : Theme.of(context).inputDecorationTheme.hintStyle,
            ),
          ],
        ),
        TextButton(
          child: const Text('Edit'),
          onPressed: () async {
            TimeOfDay? newTime = await showTimePicker(
              context: context,
              initialTime: value ?? TimeOfDay.now(),
            );

            // Don't change the date if the date picker returns null.
            if (newTime == null) {
              return;
            }

            _onValueChanged(newTime);
          },
        )
      ],
    );
  }
}
