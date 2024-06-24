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
  final bool showLocationSharingSheet;
  final List<Widget>? actions;
  final FloatingActionButton? floatingActionButton;
  final Widget? bottomNavigationBar;

  AppScaffold(
      {super.key,
      required this.title,
      required this.body,
      this.bodyPadding,
      this.showDrawer = true,
      this.showLocationSharingSheet = true,
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
            // update bottom padding after each rebuild...
            SchedulerBinding.instance
                .addPostFrameCallback((_) => _updateBottomPadding(ref));

            // calculate body padding with bodyPadding + measured bottom sheet height
            final padding = EdgeInsets.only(
                bottom: showLocationSharingSheet
                    ? ref.watch(_bottomPaddingProvider) ?? 0
                    : 0);
            return Stack(children: [
              Padding(
                  padding:
                      bodyPadding == null ? padding : padding.add(bodyPadding!),
                  child: child!),
              ...[
                if (showLocationSharingSheet)
                  Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child:
                          NotificationListener<SizeChangedLayoutNotification>(
                              onNotification:
                                  (SizeChangedLayoutNotification notification) {
                                // ... and after each resize
                                SchedulerBinding.instance.addPostFrameCallback(
                                    (_) => _updateBottomPadding(ref));
                                return true;
                              },
                              child: SizeChangedLayoutNotifier(
                                  child: LocationSharingSheet(
                                      key: _bottomSheetKey))))
              ]
            ]);
          }),
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      drawer: showDrawer ? const AppDrawer() : null,
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

  void _updateBottomPadding(WidgetRef ref) {
    final bottomSheetBox =
        _bottomSheetKey.currentContext?.findRenderObject() as RenderBox?;

    ref.read(_bottomPaddingProvider.notifier).state =
        bottomSheetBox != null && bottomSheetBox.hasSize
            ? bottomSheetBox.size.height
            : null;
  }
}
