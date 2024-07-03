import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:squadquest/logger.dart';

class FormPhotoPicker extends ConsumerStatefulWidget {
  final String labelText;
  final Uri? initialValue;
  final StateProvider<Uri?>? valueProvider;
  final ValueChanged<Uri?>? onChanged;

  const FormPhotoPicker({
    super.key,
    this.labelText = 'Photo',
    this.initialValue,
    this.valueProvider,
    this.onChanged,
  }) : assert(initialValue == null || valueProvider == null,
            'Cannot provide both initialValue and valueProvider.');

  @override
  ConsumerState<FormPhotoPicker> createState() => _FormPhotoPickerState();
}

class _FormPhotoPickerState extends ConsumerState<FormPhotoPicker> {
  StateProvider<Uri?>? _valueProvider;

  Uri? value;

  void _onValueChanged(Uri? value) {
    if (widget.onChanged != null && value != ref.read(_valueProvider!)) {
      widget.onChanged!(value);
    }

    ref.read(_valueProvider!.notifier).state = value;
  }

  @override
  void initState() {
    super.initState();

    _valueProvider = widget.valueProvider ??
        StateProvider<Uri?>((ref) => widget.initialValue);
  }

  @override
  Widget build(BuildContext context) {
    final Uri? value = ref.watch(_valueProvider!);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              widget.labelText,
              style: Theme.of(context).inputDecorationTheme.floatingLabelStyle,
            ),
            value == null
                ? const Text('Tap edit to select (optional)')
                : ConstrainedBox(
                    constraints: const BoxConstraints.tightFor(height: 100),
                    child: kIsWeb || !value.isScheme('file')
                        ? Image.network(value.toString())
                        : Image.file(
                            File(value.path),
                            errorBuilder: (BuildContext context, Object error,
                                StackTrace? stackTrace) {
                              return const Center(
                                  child:
                                      Text('This image type is not supported'));
                            },
                          )),
          ],
        )),
        Column(children: [
          ElevatedButton(
            child: const Text('Select'),
            onPressed: () async {
              final pickedFile =
                  await ImagePicker().pickImage(source: ImageSource.gallery);

              // Don't change the value if the picker returns null.
              if (pickedFile == null) {
                return;
              }

              _onValueChanged(kIsWeb
                  ? Uri.parse(pickedFile.path)
                  : File(pickedFile.path).uri);
            },
          ),
          if (value != null)
            ElevatedButton(
              child: const Text('Clear'),
              onPressed: () {
                _onValueChanged(null);
              },
            )
        ])
      ],
    );
  }
}
