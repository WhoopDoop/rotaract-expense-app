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

  /// Uploads an image to Drive, makes it link-viewable (needed so the Docs
  /// API can embed it later), and returns its file ID.
  Future<String> uploadImage(File imageFile, {required String fileName}) async {
    final api = await _getDriveApi();
    final folderId = await _getOrCreateAppFolder(api);

    final fileMetadata = drive.File()
      ..name = fileName
      ..parents = [folderId];

    final media = drive.Media(imageFile.openRead(), imageFile.lengthSync());
    final uploaded = await api.files.create(fileMetadata, uploadMedia: media);
    final fileId = uploaded.id!;

    await api.permissions.create(
      drive.Permission(type: 'anyone', role: 'reader'),
      fileId,
    );

    return fileId;
  }

  Future<void> deleteFile(String fileId) async {
    final api = await _getDriveApi();
    try {
      await api.files.delete(fileId);
    } catch (_) {
      // File may already be gone — safe to ignore.
    }
  }

  /// Publicly embeddable URL, used by the Docs API to fetch the image.
  String embeddableImageUrl(String fileId) =>
      'https://drive.google.com/uc?id=$fileId';
}