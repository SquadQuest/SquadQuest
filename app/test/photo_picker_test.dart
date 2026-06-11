import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadquest/providers/providers.dart';
import 'package:squadquest/repositories/upload_repository.dart';
import 'package:squadquest/widgets/photo_picker.dart';

class FakeUploadRepository implements UploadRepository {
  String? lastKind;
  @override
  Future<Upload> uploadImage({
    required String kind,
    required Uint8List bytes,
    required String contentType,
  }) async {
    lastKind = kind;
    return const Upload(key: 'profile/x.jpg', url: 'https://cdn/x.jpg');
  }
}

void main() {
  testWidgets('renders a tappable picker with the fallback icon when empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uploadRepositoryProvider.overrideWithValue(FakeUploadRepository()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PhotoPicker(kind: 'profile', onUploaded: (_) {}),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('photoPicker')), findsOneWidget);
    expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
  });

  testWidgets('uses the given fallback icon for non-profile kinds', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uploadRepositoryProvider.overrideWithValue(FakeUploadRepository()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PhotoPicker(
              kind: 'community',
              fallbackIcon: Icons.image_outlined,
              onUploaded: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('photoPicker')), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });
}

// Note: the populated-image path uses NetworkImage, which Flutter's test harness
// can't load (HTTP 400) without an image mock — covered by MCP/manual instead.
