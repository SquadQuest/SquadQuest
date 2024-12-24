import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import 'package:squadquest/models/topic.dart';
import 'package:squadquest/controllers/topics.dart';

class FormTopicPicker extends ConsumerStatefulWidget {
  final String labelText;
  final Topic? initialValue;
  final StateProvider<Topic?>? valueProvider;
  final ValueChanged<Topic>? onChanged;
  final bool required;

  const FormTopicPicker({
    super.key,
    this.labelText = 'Time',
    this.initialValue,
    this.valueProvider,
    this.onChanged,
    this.required = true,
  });

  @override
  ConsumerState<FormTopicPicker> createState() => _FormTopicPickerState();
}

class _FormTopicPickerState extends ConsumerState<FormTopicPicker> {
  StateProvider<Topic?>? _valueProvider;
  final _formFieldKey = GlobalKey<FormFieldState>();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  Topic? _activeTopic;
  String? _lastSearch;

  void _onValueChanged(Topic? value) {
    _textController.text = value!.name;

    ref.read(_valueProvider!.notifier).state = value;

    if ((_activeTopic == null || value.name != _activeTopic!.name)) {
      _activeTopic = value;
      if (widget.onChanged != null) {
        widget.onChanged!(value);
      }
    }

    FocusScope.of(context).nextFocus();
  }

  void _onTextSaved(String? value) async {
    value = value!.toLowerCase();

    final topicsList = await ref.read(topicsProvider.future);
    _onValueChanged(topicsList.firstWhere((topic) => topic.name == value,
        orElse: () => Topic(id: null, name: value!)));
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

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _onTextSaved(_textController.text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<Topic>(
      controller: _textController,
      focusNode: _focusNode,
      suggestionsCallback: (search) async {
        final topicsList = await ref.read(topicsProvider.future);

        _lastSearch = search = search.toLowerCase();
        return topicsList.where((topic) {
          return topic.name.toLowerCase().contains(search);
        })
            // .take(5)
            .toList();
      },
      builder: (context, controller, focusNode) {
        return TextFormField(
          key: _formFieldKey,
          onSaved: _onTextSaved,
          controller: controller,
          focusNode: focusNode,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'[^a-z\.0-9\-]'))
          ],
          decoration: InputDecoration(
            labelText: widget.required
                ? 'Topic for event'
                : 'Topic for event (optional)',
            prefixIcon: const Icon(Icons.category),
            filled: true,
            fillColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withAlpha(80),
          ),
          validator: (value) {
            if (widget.required && (value == null || value.isEmpty)) {
              return 'Please select or enter a topic';
            }
            return null;
          },
        );
      },
      emptyBuilder: (context) => const Padding(
          padding: EdgeInsets.all(16),
          child:
              Text('No existing topics found, but you can create a new one!')),
      decorationBuilder: (context, child) {
        return Material(
          type: MaterialType.card,
          elevation: 5,
          surfaceTintColor: Colors.amber,
          child: child,
        );
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

  @override
  void didUpdateWidget(FormTopicPicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.required != oldWidget.required) {
      _formFieldKey.currentState?.validate();
    }
  }
}
