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
    final decoration = widget.decoration ??
        const InputDecoration(
            prefixIcon: Icon(Icons.phone), labelText: "Phone Number");
    final countryDecoration = widget.countryFieldDecoration ??
        const InputDecoration(labelText: 'Country Code');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: CountryDropdown(
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
        Expanded(
          child: TextFormField(
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
        ),
      ],
    );
  }
}
