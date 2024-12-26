import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'event_section.dart';

class EventDescription extends StatefulWidget {
  final String? description;

  const EventDescription({
    super.key,
    this.description,
  });

  @override
  State<EventDescription> createState() => _EventDescriptionState();
}

class _EventDescriptionState extends State<EventDescription> {
  bool _isExpanded = false;
  final GlobalKey _markdownKey = GlobalKey();
  double? _markdownHeight;
  static const double _maxHeight = 100.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureMarkdownHeight();
    });
  }

  @override
  void didUpdateWidget(EventDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.description != widget.description) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _measureMarkdownHeight();
      });
    }
  }

  void _measureMarkdownHeight() {
    final RenderBox? renderBox =
        _markdownKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        _markdownHeight = renderBox.size.height;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final markdown =
        widget.description!.replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), '\n\n');

    return EventSection(
      title: 'About',
      children: [
        // Hidden measurement widget
        Offstage(
          child: MarkdownBody(
            key: _markdownKey,
            data: markdown,
          ),
        ),
        Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _isExpanded
                  ? _markdownHeight
                  : min(_maxHeight, _markdownHeight ?? 0),
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: MarkdownBody(
                  data: markdown,
                  selectable: true,
                  onTapLink: (text, href, title) {
                    if (href != null) {
                      launchUrlString(href);
                    }
                  },
                ),
              ),
            ),
            if (!_isExpanded &&
                _markdownHeight != null &&
                _markdownHeight! > _maxHeight)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 32,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).scaffoldBackgroundColor.withAlpha(0),
                        Theme.of(context)
                            .scaffoldBackgroundColor
                            .withAlpha(200),
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_markdownHeight != null && _markdownHeight! > _maxHeight)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Text(
                _isExpanded ? 'Show less' : 'Show more',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
