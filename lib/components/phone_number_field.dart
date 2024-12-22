import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field2/countries.dart';
import 'package:intl_phone_field2/intl_phone_field.dart';
import 'package:dlibphonenumber/dlibphonenumber.dart';

final _nonDigitsRegExp = RegExp(r'[^\d]');

class PhoneNumberFormField extends StatefulWidget {
  const PhoneNumberFormField({
    super.key,
    this.enabled = true,
    this.autofocus = false,
    this.onSubmitted,
    this.initialCountryCode = 'US',
    this.initialPhoneNumber,
    this.phoneNumberController,
    this.onPhoneNumberChanged,
    this.decoration,
    this.countryFieldDecoration,
  });

  final String initialCountryCode;
  final String? initialPhoneNumber;
  final TextEditingController? phoneNumberController;
  final ValueChanged<PhoneNumber>? onPhoneNumberChanged;
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
  final PhoneNumberUtil _phoneUtil = PhoneNumberUtil.instance;
  late String _previousDigits;
  late Country _selectedCountry;
  Key _phoneFieldKey = UniqueKey();

  @override
  void initState() {
    super.initState();

    _selectedCountry =
        countries.firstWhere((item) => item.code == widget.initialCountryCode);

    final initialText =
        widget.phoneNumberController?.text ?? widget.initialPhoneNumber ?? '';

    _internalController = TextEditingController(
      text: initialText,
    );

    _previousDigits = initialText.replaceAll(_nonDigitsRegExp, '');

    _internalController.addListener(_onTextChange);
  }

  void _onTextChange() {
    String digits = _internalController.text.replaceAll(_nonDigitsRegExp, '');

    if (digits == _previousDigits) {
      // skip doing any processing if no digits changed (i.e. only formatting changed)
      return;
    }

    // update _previousDigits before processing
    final previousDigitsLength = _previousDigits.length;
    _previousDigits = digits;

    // if more than one digital changed, process as paste
    if ((digits.length - previousDigitsLength).abs() > 1) {
      _handlePaste(_internalController.text);
    } else {
      // otherwise, apply format-as-you-type
      final asYouTypeFormatter =
          _phoneUtil.getAsYouTypeFormatter(_selectedCountry.code);

      String result = '';
      for (int i = 0; i < digits.length; i++) {
        result = asYouTypeFormatter.inputDigit(digits[i]);
      }

      _internalController.text = result;
    }

    // update state
    try {
      PhoneNumber number =
          _phoneUtil.parse(_internalController.text, _selectedCountry.code);
      widget.phoneNumberController?.text =
          _phoneUtil.format(number, PhoneNumberFormat.e164);

      if (widget.onPhoneNumberChanged != null) {
        widget.onPhoneNumberChanged!(number);
      }
    } catch (error) {
      widget.phoneNumberController?.text = '';
    }
  }

  void _handlePaste(text) {
    print('handling pasted phone number: $text');

    Iterable<PhoneNumberMatch> foundNumbers =
        _phoneUtil.findNumbers(text, _selectedCountry.code);

    if (foundNumbers.isEmpty) {
      return;
    }

    final number = foundNumbers.elementAt(0).number;

    final regionCode = _phoneUtil.getRegionCodeForNumber(number);
    final formattedNumber =
        _phoneUtil.format(number, PhoneNumberFormat.national);

    print('found phone number: $regionCode/$formattedNumber');

    setState(() {
      _previousDigits = formattedNumber.replaceAll(_nonDigitsRegExp, '');

      _selectedCountry =
          countries.firstWhere((item) => item.code == regionCode);

      _internalController.text = formattedNumber;

      // generate new key to clear field state and force initialCountryCode to apply
      _phoneFieldKey = UniqueKey();
    });
  }

  @override
  void dispose() {
    _internalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntlPhoneField(
          key: _phoneFieldKey,
          controller: _internalController,
          disableLengthCheck: true,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'[^+\(\) 0-9\-]')),
          ],
          initialCountryCode: _selectedCountry.code,
          onCountryChanged: (country) {
            _selectedCountry = country;
          },
          validator: (fieldValue) {
            try {
              PhoneNumber number =
                  _phoneUtil.parse(fieldValue!.number, _selectedCountry.code);

              if (!_phoneUtil.isValidNumberForRegion(
                  number, _selectedCountry.code)) {
                return 'Invalid ${_selectedCountry.code} number';
              }
            } catch (error) {
              return 'Invalid ${_selectedCountry.code} number';
            }
          },
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: 'Phone number'),
        ),
      ],
    );
  }
}
