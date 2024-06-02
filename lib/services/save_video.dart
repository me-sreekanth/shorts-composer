import 'package:gallery_saver/gallery_saver.dart';

class SaveVideo {
  Future<bool> saveVideo(String path) async {
    return await GallerySaver.saveVideo(path) ?? false;
  }
}
