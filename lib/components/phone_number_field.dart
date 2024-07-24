import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';

import '../common.dart';

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
          onChanged: (value) {
            _onPhoneNumberChanged(value);
            widget.onPhoneNumberChanged != null
                ? (v) => widget.onPhoneNumberChanged!(completePhoneNumber)
                : null;
          },
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

  String _lastText = "";

  void _onPhoneNumberChanged(String value) {
    value =
        value.replaceAll(RegExp(r'\D'), ''); // remove all non-digit characters
    final similarity = StringSimilarity.compareTwoStrings(value, _lastText);

    switch (similarity) {
      // Assuming value parameter is a complete number (with country code), this means
      // the new content has country code too and we won't to display it to the user.
      // Then we trigger the detection that will format everything for us.
      //
      // TL;DR: Solves a problem where the country code is displayed if the same number
      // is pasted again.
      case 1:
        _detectCountryFromPhone(value);
        break;
      // Sufficient similarity to not trigger the detection. This is like removing
      // less than half the number in one edit.
      case >= 0.6:
        break;
      default:
        _detectCountryFromPhone(value);
    }

    _lastText = value;
  }

  void _detectCountryFromPhone(String value) {
    final newCountry = PhoneCodes.getCountryDataByPhone(value);

    if (newCountry != null) {
      log("Found country: ${newCountry.country}");
      if (isPhoneValid(value, defaultCountryCode: newCountry.countryCode)) {
        log("Phone valid for ${newCountry.country}");
        setState(() {
          _internalController.text = formatPhone(value);
          _selectedPhoneCountry = newCountry;
        });
      } else {
        log("Phone invalid for ${newCountry.country}");
      }
    }
  }
}

class _PhoneClipboardButton extends StatefulWidget {
  const _PhoneClipboardButton({
    required this.onNumberPasted,
    this.onNumberFound,
  });

  final void Function(String text) onNumberPasted;
  final void Function(String text)? onNumberFound;

  @override
  State<_PhoneClipboardButton> createState() => _PhoneClipboardButtonState();
}

class _PhoneClipboardButtonState extends State<_PhoneClipboardButton> {
  String? _phoneFound;
  bool pasted = false;

  late final ClipboardStatusNotifier _clipboardStatus;

  // Ths many async components ensures that the data from streams and
  // subscriptions is not missed (lost in memory) when the widget is
  // disposed
  late final Timer _periodicTimer;
  final StreamController<String?> _clipboardStreamController =
      StreamController.broadcast();
  late final StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();

    _clipboardStatus = ClipboardStatusNotifier();

    _periodicTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) async {
        final content = await _getClipboardData();
        _clipboardStreamController.add(content);
      },
    );

    _subscription = _clipboardStreamController.stream
        .where(_shouldPickData)
        .cast<String>()
        .listen(_checkValue);

    // HACK: Timer will wait 5 seconds to do the first check.
    // Replicate stream behavior but in a imperative way
    _getClipboardData().then(
      (value) {
        if (_shouldPickData(value)) {
          _checkValue(value!);
        }
      },
    );
  }

  void _checkValue(String text) async {
    if (isPhoneValid(text)) {
      setState(() {
        _phoneFound = text;
        pasted = false;
      });

      if (widget.onNumberFound != null) {
        widget.onNumberFound!(text);
      }
    }
  }

  bool _shouldPickData(String? data) {
    return data != null && data != _phoneFound;
  }

  static Future<String?> _getClipboardData() async {
    if (await Clipboard.hasStrings()) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } else {
      return null;
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
    _periodicTimer.cancel();
    _subscription.cancel();
    _clipboardStreamController.close();
    _clipboardStatus.dispose();
    super.dispose();
  }
}

// Copyed from https://github.com/jeremylandon/string-similarity/blob/master/lib/src/string_similarity_base.dart
/// Finds degree of similarity between two strings, based on Dice's Coefficient, which is mostly better than Levenshtein distance.
class StringSimilarity {
  /// Returns a fraction between 0 and 1, which indicates the degree of similarity between the two strings. 0 indicates completely different strings, 1 indicates identical strings. The comparison is case-sensitive.
  ///
  /// _(same as 'string'.similarityTo extension method)_
  ///
  /// ##### Arguments
  /// - first (String?): The first string
  /// - second (String?): The second string
  ///
  /// (Order does not make a difference)
  ///
  /// ##### Returns
  /// (number): A fraction from 0 to 1, both inclusive. Higher number indicates more similarity.
  static double compareTwoStrings(String? first, String? second) {
    // if both are null
    if (first == null && second == null) {
      return 1;
    }
    // as both are not null if one of them is null then return 0
    if (first == null || second == null) {
      return 0;
    }

    first =
        first.replaceAll(RegExp(r'\s+\b|\b\s'), ''); // remove all whitespace
    second =
        second.replaceAll(RegExp(r'\s+\b|\b\s'), ''); // remove all whitespace

    // if both are empty strings
    if (first.isEmpty && second.isEmpty) {
      return 1;
    }
    // if only one is empty string
    if (first.isEmpty || second.isEmpty) {
      return 0;
    }
    // identical
    if (first == second) {
      return 1;
    }
    // both are 1-letter strings
    if (first.length == 1 && second.length == 1) {
      return 0;
    }
    // if either is a 1-letter string
    if (first.length < 2 || second.length < 2) {
      return 0;
    }

    final firstBigrams = <String, int>{};
    for (var i = 0; i < first.length - 1; i++) {
      final bigram = first.substring(i, i + 2);
      final count =
          firstBigrams.containsKey(bigram) ? firstBigrams[bigram]! + 1 : 1;
      firstBigrams[bigram] = count;
    }

    var intersectionSize = 0;
    for (var i = 0; i < second.length - 1; i++) {
      final bigram = second.substring(i, i + 2);
      final count =
          firstBigrams.containsKey(bigram) ? firstBigrams[bigram]! : 0;

      if (count > 0) {
        firstBigrams[bigram] = count - 1;
        intersectionSize++;
      }
    }

    return (2.0 * intersectionSize) / (first.length + second.length - 2);
  }
}