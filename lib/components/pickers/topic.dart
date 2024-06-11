import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import 'package:squad_quest/models/topic.dart';
import 'package:squad_quest/controllers/topics.dart';

class FormTopicPicker extends ConsumerStatefulWidget {
  final String labelText;
  final Topic? initialValue;
  final StateProvider<Topic?>? valueProvider;
  final ValueChanged<Topic>? onChanged;

  const FormTopicPicker({
    super.key,
    this.labelText = 'Time',
    this.initialValue,
    this.valueProvider,
    this.onChanged,
  });

  @override
  ConsumerState<FormTopicPicker> createState() => _FormTopicPickerState();
}

class _FormTopicPickerState extends ConsumerState<FormTopicPicker> {
  StateProvider<Topic?>? _valueProvider;
  final _textController = TextEditingController();
  String? _lastSearch;

  void _onValueChanged(Topic value) {
    final lastValue = ref.read(_valueProvider!);

    _textController.text = value.name;

    if (widget.onChanged != null &&
        (lastValue == null || value.name != lastValue.name)) {
      widget.onChanged!(value);
    }

    ref.read(_valueProvider!.notifier).state = value;
    FocusScope.of(context).nextFocus();
  }

  @override
  void initState() {
    super.initState();

    _valueProvider = widget.valueProvider ??
        StateProvider<Topic?>((ref) => widget.initialValue);

    final initialValue = ref.read(_valueProvider!);

    if (initialValue != null) {
      _textController.text = initialValue.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Topic? value = ref.watch(_valueProvider!);

    return TypeAheadField<Topic>(
      controller: _textController,
      suggestionsCallback: (search) async {
        final topicsList = await ref.read(topicsListProvider.future);
        log("Searching for: $search");
        _lastSearch = search = search.toLowerCase();
        return topicsList
            .where((topic) {
              return topic.name.toLowerCase().contains(search);
            })
            .take(5)
            .toList();
      },
      builder: (context, controller, focusNode) {
        return TextField(
            controller: controller,
            focusNode: focusNode,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[^a-z\.0-9\-]'))
            ],
            decoration: const InputDecoration(
              labelText: 'Topic for event',
            ));
      },
      itemBuilder: (context, topic) {
        int? matchIndex;

        if (_lastSearch != null && _lastSearch!.isNotEmpty) {
          matchIndex =
              topic.name.toLowerCase().indexOf(_lastSearch!.toLowerCase());
          if (matchIndex == -1) {
            matchIndex = null;
          }
        }

        return ListTile(
          title: RichText(
              text: TextSpan(
                  style: Theme.of(context).textTheme.bodyLarge,
                  children: matchIndex == null
                      ? [TextSpan(text: topic.name)]
                      : [
                          TextSpan(text: topic.name.substring(0, matchIndex)),
                          TextSpan(
                              text: topic.name.substring(
                                  matchIndex, matchIndex + _lastSearch!.length),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(
                              text: topic.name
                                  .substring(matchIndex + _lastSearch!.length))
                        ])),
        );
      },
      onSelected: _onValueChanged,
    );
  }
}
