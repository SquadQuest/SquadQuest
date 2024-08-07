import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/drawer.dart';
import 'package:squadquest/components/sheets/location_sharing.dart';
import 'package:squadquest/models/instance.dart';

final _bottomPaddingProvider = StateProvider<double?>((ref) => null);

class AppScaffold extends StatelessWidget {
  final String title;
  final TextStyle? titleStyle;
  final String? loadMask;
  final Widget body;
  final EdgeInsetsGeometry? bodyPadding;
  final bool showDrawer;
  final bool showLocationSharingSheet;
  final InstanceID? locationSharingAvailableEvent;
  final List<Widget>? actions;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  AppScaffold(
      {super.key,
      required this.title,
      this.titleStyle,
      this.loadMask,
      required this.body,
      this.bodyPadding,
      this.showDrawer = true,
      this.showLocationSharingSheet = true,
      this.locationSharingAvailableEvent,
      this.actions,
      this.floatingActionButtonLocation,
      this.floatingActionButton,
      this.bottomNavigationBar});

  final GlobalKey _bottomSheetKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              if (loadMask != null) ...[
                const Opacity(
                  opacity: 0.7,
                  child: ModalBarrier(dismissible: false, color: Colors.black),
                ),
                Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          loadMask!,
                          style: const TextStyle(fontSize: 30),
                        ),
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(),
                        const SizedBox(height: 32),
                      ]),
                ),
              ],
              if (showLocationSharingSheet)
                Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: NotificationListener<SizeChangedLayoutNotification>(
                        onNotification:
                            (SizeChangedLayoutNotification notification) {
                          // ... and after each resize
                          SchedulerBinding.instance.addPostFrameCallback(
                              (_) => _updateBottomPadding(ref));
                          return true;
                        },
                        child: SizeChangedLayoutNotifier(
                            child: LocationSharingSheet(
                                key: _bottomSheetKey,
                                locationSharingAvailableEvent:
                                    locationSharingAvailableEvent))))
            ]);
          }),
      appBar: AppBar(
        title: Text(title, style: titleStyle),
        actions: actions,
      ),
      drawer: showDrawer ? const AppDrawer() : null,
      floatingActionButtonLocation: floatingActionButtonLocation,
      floatingActionButton: floatingActionButton == null
          ? null
          : Consumer(
              child: floatingActionButton,
              builder: (_, ref, child) {
                final bottomPadding = ref.watch(_bottomPaddingProvider);

                return Padding(
                    padding: EdgeInsets.only(bottom: bottomPadding ?? 0),
                    child: child);
              }),
      bottomNavigationBar: bottomNavigationBar,
    );
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
