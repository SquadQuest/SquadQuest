import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/models/instance.dart';

class FormVisibilityPicker extends ConsumerStatefulWidget {
  final String labelText;
  final InstanceVisibility? initialValue;
  final StateProvider<InstanceVisibility?>? valueProvider;
  final ValueChanged<InstanceVisibility>? onChanged;

  const FormVisibilityPicker({
    super.key,
    this.labelText = 'Event Visibility',
    this.initialValue,
    this.valueProvider,
    this.onChanged,
  }) : assert(initialValue == null || valueProvider == null,
            'Cannot provide both initialValue and valueProvider.');

  @override
  ConsumerState<FormVisibilityPicker> createState() =>
      _FormVisibilityPickerState();
}

class _FormVisibilityPickerState extends ConsumerState<FormVisibilityPicker> {
  StateProvider<InstanceVisibility?>? _valueProvider;

  void _onValueChanged(InstanceVisibility? value) {
    if (value != null &&
        widget.onChanged != null &&
        value != ref.read(_valueProvider!)) {
      widget.onChanged!(value);
    }

    ref.read(_valueProvider!.notifier).state = value;
  }

  @override
  void initState() {
    super.initState();

    _valueProvider = widget.valueProvider ??
        StateProvider<InstanceVisibility?>((ref) => widget.initialValue);
  }

  @override
  Widget build(BuildContext context) {
    final InstanceVisibility? value = ref.watch(_valueProvider!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        ...[
          if (widget.labelText.isNotEmpty)
            Text(
              widget.labelText,
              style: Theme.of(context).inputDecorationTheme.floatingLabelStyle,
            ),
        ],
        RadioListTile<InstanceVisibility>(
          secondary: visibilityIcons[InstanceVisibility.private],
          title: const Text('Private'),
          subtitle: const Text('Only people you invite can see this event'),
          value: InstanceVisibility.private,
          groupValue: value,
          onChanged: _onValueChanged,
          visualDensity: VisualDensity.compact,
        ),
        RadioListTile<InstanceVisibility>(
          secondary: visibilityIcons[InstanceVisibility.friends],
          title: const Text('Friends'),
          subtitle: const Text('Only your friends can see this event'),
          value: InstanceVisibility.friends,
          groupValue: value,
          onChanged: _onValueChanged,
          visualDensity: VisualDensity.compact,
        ),
        RadioListTile<InstanceVisibility>(
          secondary: visibilityIcons[InstanceVisibility.public],
          title: const Text('Public'),
          subtitle: const Text('Anyone can see this event'),
          value: InstanceVisibility.public,
          groupValue: value,
          onChanged: _onValueChanged,
          visualDensity: VisualDensity.compact,
        )
      ],
    );
  }
}
