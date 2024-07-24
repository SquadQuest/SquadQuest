import 'package:flutter/material.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';

import 'package:squadquest/common.dart';

class PhoneNumberFormField extends StatefulWidget {
  const PhoneNumberFormField({
    super.key,
    this.enabled = true,
    this.autofocus = false,
    this.onSubmitted,
    this.initialPhoneNumber,
    this.phoneNumberController,
    this.onPhoneNumberChanged,
    this.decoration,
    this.countryFieldDecoration,
  });

  final String? initialPhoneNumber;
  final TextEditingController? phoneNumberController;
  final ValueChanged<String>? onPhoneNumberChanged;
  final void Function(String)? onSubmitted;

  final bool autofocus;
  final bool enabled;

  final InputDecoration? decoration;
  final InputDecoration? countryFieldDecoration;

  @override
  State<PhoneNumberFormField> createState() => _PhoneNumberFormFieldState();
}

class _PhoneNumberFormFieldState extends State<PhoneNumberFormField> {
  late final TextEditingController _internalController;
  late PhoneCountryData _selectedPhoneCountry;

  String suggestion = "";

  String get completePhoneNumber =>
      '+${_selectedPhoneCountry.internalPhoneCode} ${_internalController.text}';

  static final defaultCountryData =
      PhoneCodes.getPhoneCountryDataByCountryCode("US")!;

  @override
  void initState() {
    super.initState();

    _internalController = TextEditingController(
      text:
          widget.phoneNumberController?.text ?? widget.initialPhoneNumber ?? '',
    );

    if (_internalController.text.isNotEmpty) {
      _selectedPhoneCountry =
          PhoneCodes.getCountryDataByPhone(_internalController.text) ??
              defaultCountryData;
    } else {
      _selectedPhoneCountry = defaultCountryData;
    }

    _internalController.text = formatPhone(_internalController.text);

    _setupControllerListener();
  }

  void _setupControllerListener() {
    _internalController.addListener(_notify);
  }

  void _notify() {
    final newText = completePhoneNumber;
    if (widget.onPhoneNumberChanged != null) {
      widget.onPhoneNumberChanged!(newText);
    }

    if (widget.phoneNumberController != null &&
        widget.phoneNumberController != _internalController) {
      /// This can be bad if you want to manage other properties of the controller
      /// such as selection and composition, but it's fine for our purposes
      /// See [TextEditingController.text] setter for more details
      widget.phoneNumberController?.text = newText;
    }
  }

  @override
  void dispose() {
    _internalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var decoration = widget.decoration ??
        const InputDecoration(
          prefixIcon: Icon(Icons.phone),
          labelText: "Phone Number",
        );

    final countryDecoration = widget.countryFieldDecoration ??
        const InputDecoration(labelText: 'Country Code');

    final clipboardButton = _PhoneClipboardButton(
      onNumberPasted: (v) => _detectCountryFromPhone(v),
      onNumberFound: (text) => setState(() {
        suggestion = formatPhone(text);
      }),
    );

    decoration = decoration.copyWith(
      hintText: decoration.hintText != null ? decoration.hintText! : suggestion,
      suffix: decoration.suffix == null
          ? clipboardButton
          : Row(
              children: [
                if (decoration.suffix != null) decoration.suffix!,
                clipboardButton,
              ],
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: CountryDropdown(
            key: Key('country_dropdown_${_selectedPhoneCountry.countryCode}'),
            printCountryName: true,
            iconSize: 28, // match phone input field height
            decoration: countryDecoration,
            initialCountryData: _selectedPhoneCountry,
            onCountrySelected: (value) {
              setState(() {
                _selectedPhoneCountry = value;
                _notify();
              });
            },
          ),
        ),
        const SizedBox.square(dimension: 8),
        TextFormField(
          autofocus: widget.autofocus,
          readOnly: !widget.enabled,
          controller: _internalController,
          onChanged: widget.onPhoneNumberChanged != null
              ? (value) => widget.onPhoneNumberChanged!(completePhoneNumber)
              : null,
          inputFormatters: [
            phoneInputFilter,
            PhoneInputFormatter(
              defaultCountryCode: _selectedPhoneCountry.countryCode,
              allowEndlessPhone: true,
            )
          ],
          // 98212841
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumber],
          onFieldSubmitted: widget.enabled && widget.onSubmitted != null
              ? (value) => widget.onSubmitted!(value)
              : null,
          decoration: decoration,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a phone number';
            }

            if (!isPhoneValid(
              value,
              defaultCountryCode: _selectedPhoneCountry.countryCode,
            )) {
              return "Please enter a valid phone number";
            }

            return null;
          },
        ),
      ],
    );
  }

  void _detectCountryFromPhone(String value) {
    final newCountry = PhoneCodes.getCountryDataByPhone(value);

    if (newCountry != null) {
      setState(() {
        _internalController.text = formatPhone(value);
        _selectedPhoneCountry = newCountry;
      });
    }
  }
  }

class _PhoneClipboard extends StatefulWidget {
  const _PhoneClipboard(
      {super.key, required this.onNumberPasted, this.onNumberFound});

  final void Function(String) onNumberPasted;
  final void Function(String)? onNumberFound;

  @override
  State<_PhoneClipboard> createState() => _PhoneClipboardState();
}

class _PhoneClipboardState extends State<_PhoneClipboard> {
  bool _hasClipboardData = false;
  late final ClipboardStatusNotifier _clipboardStatus;

  @override
  void initState() {
    super.initState();

    Stream.periodic(const Duration(seconds: 3))
        // .takeWhile((element) => _clipboardData == null)
        .listen((event) {
      _checkClipboard();
    });
  }

  void _checkClipboard() async {
    final foo = await Clipboard.getData(Clipboard.kTextPlain);

    if (foo?.text != null) {
      final phone = foo!.text!.replaceAll(RegExp(r"[^0-9\+]"), "");

      if (phone.isNotEmpty) {
        log('Found phone number in clipboard: $phone');
        setState(() {
          _hasClipboardData = true;
          _clipboardData = phone;
        });

        if (widget.onNumberFound != null) {
          widget.onNumberFound!(phone);
        }
      }
    }
  void _pasteButtonPressed() {
    widget.onNumberPasted(_phoneFound!);
    setState(() {
      pasted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _clipboardStatus,
      builder: (context, value, child) {
        switch (value) {
          case ClipboardStatus.unknown:
          case ClipboardStatus.notPasteable:
            return const SizedBox.shrink();
          case ClipboardStatus.pasteable:
            if (_phoneFound != null) {
      return TextButton.icon(
          icon: const Icon(Icons.paste),
                label:
                    pasted ? const Text('Pasted') : const Text('Paste phone'),
                onPressed: pasted ? null : _pasteButtonPressed,
              );
    } else {
      return const SizedBox.shrink();
    }
        }
      },
    );
  }

  @override
  void dispose() {
    _clipboardStatus.dispose();
    super.dispose();
  }
}
