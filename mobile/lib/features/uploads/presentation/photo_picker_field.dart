import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../data/upload_repository.dart';

/// A photo already uploaded (or in the process of uploading) as part of a
/// task/issue/progress-report form.
class PhotoAttachment {
  const PhotoAttachment({required this.photoUrl, this.caption});
  final String photoUrl;
  final String? caption;
}

/// Shared "attach photos" control for task/issue/progress-report forms:
/// shows thumbnails of already-uploaded photos plus a button to capture or
/// pick one. Each pick runs presign+PUT+attach as one atomic call via
/// [UploadRepository.captureUploadAndAttach] against [attachPath] — the
/// parent entity (task/issue/report) must already exist (i.e. have an id)
/// before this widget is shown, since [targetId] identifies it.
///
/// On success, the raw attach-response JSON is handed to [onAttached] so the
/// parent can parse it into its own typed model (`TaskPhoto.fromJson`, etc.)
/// and append it to its own list — this widget only owns the visual grid.
/// On a network failure the photo is queued for retry (see
/// `PhotoUploadRetryService`) and an inline "will sync later" notice is shown
/// instead of a hard error.
class PhotoPickerField extends StatefulWidget {
  const PhotoPickerField({
    super.key,
    required this.entityType,
    required this.uploadRepository,
    required this.attachPath,
    required this.targetKind,
    required this.targetId,
    this.onAttached,
    this.onChanged,
    this.initialAttachments = const [],
  });

  final UploadEntityType entityType;
  final UploadRepository uploadRepository;

  /// REST path to POST `{photo_url, caption}` to once the file is uploaded,
  /// e.g. `/tasks/$taskId/photos`.
  final String attachPath;

  /// Matches `queued_photo_uploads.target_kind` (`'task'`, `'issue'`, or
  /// `'progress_report'`) — used to rebuild [attachPath] on a queued retry.
  final String targetKind;
  final String targetId;

  /// Raw JSON body of the attach endpoint's response, fired once per photo
  /// that uploads and attaches successfully (not fired for a queued photo,
  /// since there is no server response yet).
  final ValueChanged<Map<String, dynamic>>? onAttached;

  /// Fired with the widget's own running list of thumbnails whenever it
  /// changes — optional, since most callers now get everything they need
  /// from [onAttached].
  final ValueChanged<List<PhotoAttachment>>? onChanged;
  final List<PhotoAttachment> initialAttachments;

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  late final List<PhotoAttachment> _attachments = List.of(
    widget.initialAttachments,
  );
  bool _isUploading = false;
  String? _error;

  Future<void> _addPhoto(ImageSource source) async {
    setState(() {
      _isUploading = true;
      _error = null;
    });
    try {
      final json = await widget.uploadRepository
          .captureUploadAndAttach<Map<String, dynamic>>(
            entityType: widget.entityType,
            source: source,
            attachPath: widget.attachPath,
            targetKind: widget.targetKind,
            targetId: widget.targetId,
            fromJson: (json) => json,
          );
      if (json == null) return; // user cancelled
      final photoUrl = json['photo_url'] as String?;
      if (photoUrl != null) {
        setState(
          () => _attachments.add(
            PhotoAttachment(photoUrl: photoUrl, caption: json['caption'] as String?),
          ),
        );
        widget.onChanged?.call(List.unmodifiable(_attachments));
      }
      widget.onAttached?.call(json);
    } on PhotoUploadQueuedException {
      setState(
        () => _error =
            'No connection — this photo will upload automatically once you\'re back online.',
      );
    } on ApiException catch (e) {
      setState(() => _error = 'Could not upload photo: ${e.message}');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removeAt(int index) {
    setState(() => _attachments.removeAt(index));
    widget.onChanged?.call(List.unmodifiable(_attachments));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photos', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _attachments.length; i++)
              _PhotoThumbnail(
                url: _attachments[i].photoUrl,
                onRemove: () => _removeAt(i),
              ),
            _AddPhotoButton(
              isBusy: _isUploading,
              onCamera: () => _addPhoto(ImageSource.camera),
              onGallery: () => _addPhoto(ImageSource.gallery),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.url, required this.onRemove});
  final String url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            width: 88,
            height: 88,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 88,
              height: 88,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: IconButton(
            icon: const Icon(Icons.cancel, size: 20),
            onPressed: onRemove,
            tooltip: 'Remove photo',
          ),
        ),
      ],
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({
    required this.isBusy,
    required this.onCamera,
    required this.onGallery,
  });

  final bool isBusy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return const SizedBox(
        width: 88,
        height: 88,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showSourcePicker(context),
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.add_a_photo_outlined),
      ),
    );
  }

  void _showSourcePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onGallery();
              },
            ),
          ],
        ),
      ),
    );
  }
}
