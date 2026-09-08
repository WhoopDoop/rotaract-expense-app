import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class DriveService {
  final GoogleSignIn googleSignIn;
  DriveService(this.googleSignIn);

  static const _folderName = 'Rotaract Expense App';

  Future<drive.DriveApi> _getDriveApi() async {
    final client = await googleSignIn.authenticatedClient();
    if (client == null) {
      throw Exception('Not signed in — could not get authenticated client.');
    }
    return drive.DriveApi(client);
  }

  // Finds (or creates) a single app folder in the user's Drive to keep things tidy.
  Future<String> _getOrCreateAppFolder(drive.DriveApi api) async {
    final existing = await api.files.list(
      q: "mimeType = 'application/vnd.google-apps.folder' and name = '$_folderName' and trashed = false",
      spaces: 'drive',
    );
    if (existing.files != null && existing.files!.isNotEmpty) {
      return existing.files!.first.id!;
    }
    final folder = drive.File()
      ..name = _folderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder);
    return created.id!;
  }

  /// Uploads an image file to Drive and returns its file ID.
  Future<String> uploadImage(File imageFile, {required String fileName}) async {
    final api = await _getDriveApi();
    final folderId = await _getOrCreateAppFolder(api);

    final fileMetadata = drive.File()
      ..name = fileName
      ..parents = [folderId];

    final media = drive.Media(imageFile.openRead(), imageFile.lengthSync());

    final uploaded = await api.files.create(fileMetadata, uploadMedia: media);
    return uploaded.id!;
  }

  /// Deletes a previously uploaded file (used when a bill's photo is replaced).
  Future<void> deleteFile(String fileId) async {
    final api = await _getDriveApi();
    try {
      await api.files.delete(fileId);
    } catch (_) {
      // File may already be gone — safe to ignore.
    }
  }

  /// Direct-view link, handy if you ever want to open the photo in a browser.
  String viewLink(String fileId) =>
      'https://drive.google.com/uc?id=$fileId';
}