import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/coordinates.dart';
import 'package:open_location_code/open_location_code.dart';

import 'package:squadquest/components/event_rally_map.dart';

export 'package:geobase/coordinates.dart' show Geographic;

class FormLocationPicker extends ConsumerStatefulWidget {
  final String labelText;
  final Geographic? initialValue;
  final StateProvider<Geographic?>? valueProvider;
  final ValueChanged<Geographic?>? onChanged;
  final Function(String)? onPlaceSelect;

  const FormLocationPicker({
    super.key,
    this.labelText = 'Map location',
    this.initialValue,
    this.valueProvider,
    this.onChanged,
    this.onPlaceSelect,
  }) : assert(initialValue == null || valueProvider == null,
            'Cannot provide both initialValue and valueProvider.');

  @override
  ConsumerState<FormLocationPicker> createState() => _FormLocationPickerState();
}

class _FormLocationPickerState extends ConsumerState<FormLocationPicker> {
  StateProvider<Geographic?>? _valueProvider;

  Geographic? value;

  void _onValueChanged(Geographic? value) {
    if (widget.onChanged != null && value != ref.read(_valueProvider!)) {
      widget.onChanged!(value);
    }

    ref.read(_valueProvider!.notifier).state = value;
  }

  @override
  void initState() {
    super.initState();

    _valueProvider = widget.valueProvider ??
        StateProvider<Geographic?>((ref) => widget.initialValue);
  }

  @override
  Widget build(BuildContext context) {
    final Geographic? value = ref.watch(_valueProvider!);

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
                  ? PlusCode.encode(
                      LatLng(value.lat, value.lon),
                    ).toString()
                  : 'Tap edit to set (optional)',
              style: value != null
                  ? Theme.of(context).textTheme.bodyLarge
                  : Theme.of(context).inputDecorationTheme.hintStyle,
            ),
          ],
        ),
        TextButton(
          child: const Text('Edit'),
          onPressed: () async {
            Geographic? newValue = await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                enableDrag: false,
                isDismissible: false,
                builder: (BuildContext context) => EventRallyMap(
                    initialRallyPoint: value,
                    onPlaceSelect: widget.onPlaceSelect));

            _onValueChanged(newValue);
          },
        )
      ],
    );
  }
}
