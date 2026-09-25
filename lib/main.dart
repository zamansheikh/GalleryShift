import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/decision_store.dart';
import 'data/gallery_repository.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Thumbnails are the working set; give the image cache room for a deck.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20;

  final controller = AppController(
    repo: GalleryRepository(),
    store: await DecisionStore.open(),
  );
  runApp(GalleryShiftApp(controller: controller));
}
