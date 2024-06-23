import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/drawer.dart';
import 'package:squadquest/components/sheets/location_sharing.dart';

final _bottomPaddingProvider = StateProvider<double?>((ref) => null);

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final EdgeInsetsGeometry? bodyPadding;
  final bool showDrawer;
  final List<Widget>? actions;
  final FloatingActionButton? floatingActionButton;
  final Widget? bottomNavigationBar;

  AppScaffold(
      {super.key,
      required this.title,
      required this.body,
      this.bodyPadding,
      this.showDrawer = true,
      this.actions,
      this.floatingActionButton,
      this.bottomNavigationBar});

  final GlobalKey _bottomSheetKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      body: Consumer(
          child: body,
          builder: (_, ref, child) {
            final padding =
                EdgeInsets.only(bottom: ref.watch(_bottomPaddingProvider) ?? 0);
            return Padding(
                padding:
                    bodyPadding == null ? padding : padding.add(bodyPadding!),
                child: child!);
          }),
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      drawer: showDrawer ? const AppDrawer() : null,
      bottomSheet: Consumer(builder: (_, ref, __) {
        return NotificationListener<SizeChangedLayoutNotification>(
            onNotification: (SizeChangedLayoutNotification notification) {
              SchedulerBinding.instance.addPostFrameCallback((_) {
                final bottomSheetBox = _bottomSheetKey.currentContext
                    ?.findRenderObject() as RenderBox?;

                ref.read(_bottomPaddingProvider.notifier).state =
                    bottomSheetBox != null && bottomSheetBox.hasSize
                        ? bottomSheetBox.size.height
                        : null;
              });

              return true;
            },
            child: SizeChangedLayoutNotifier(
                child: LocationSharingSheet(key: _bottomSheetKey)));
      }),
      floatingActionButton: floatingActionButton == null
          ? null
          : Consumer(
              child: floatingActionButton,
              builder: (_, ref, child) {
                final bottomPadding = ref.watch(_bottomPaddingProvider);

                return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [child!, SizedBox(height: bottomPadding)]);
              }),
      bottomNavigationBar: bottomNavigationBar,
    ));
  }
}
