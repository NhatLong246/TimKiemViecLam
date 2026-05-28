import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../../controller/messaging_controller.dart';

/// Gửi ảnh / ghi âm / file / vị trí cho [ChatRoomScreen].
mixin ChatRoomMediaMixin<T extends StatefulWidget> on State<T> {
  MessagingController get mediaCtrl;
  Color get mediaPrimary;

  final AudioRecorder _mediaRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  bool get isRecording => _isRecording;

  void disposeMedia() {
    _recordingTimer?.cancel();
    _mediaRecorder.dispose();
  }

  Future<bool> _requestPermission(Permission permission) async {
    var status = await permission.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await _showMediaSettingsDialog(permission);
      return false;
    }
    status = await permission.request();
    if (!status.isGranted && status.isPermanentlyDenied) {
      await _showMediaSettingsDialog(permission);
    }
    return status.isGranted;
  }

  String _permissionLabel(Permission p) {
    if (p == Permission.camera) return 'Camera';
    if (p == Permission.microphone) return 'Microphone';
    if (p == Permission.location) return 'Vị trí';
    return 'thư viện ảnh';
  }

  Future<void> _showMediaSettingsDialog(Permission p) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cần cấp quyền'),
        content: Text(
          'Ứng dụng cần quyền ${_permissionLabel(p)}.\nVui lòng cấp trong Cài đặt.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Mở Cài đặt'),
          ),
        ],
      ),
    );
  }

  void _showMediaError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg.replaceFirst('Exception: ', ''))),
    );
  }

  Future<void> takePhotoAndSend() async {
    if (!await _requestPermission(Permission.camera)) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 60,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    if (picked == null) return;
    await _sendImageFile(File(picked.path));
  }

  Future<void> pickGalleryAndSend() async {
    if (Platform.isAndroid) {
      var status = await Permission.photos.request();
      if (!status.isGranted && !status.isLimited) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          if (status.isPermanentlyDenied) {
            await _showMediaSettingsDialog(Permission.photos);
          }
          return;
        }
      }
    } else {
      if (!await _requestPermission(Permission.photos)) return;
    }

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    if (picked == null) return;
    await _sendImageFile(File(picked.path));
  }

  Future<void> _sendImageFile(File file) async {
    final bytes = await file.length();
    if (bytes > 700 * 1024) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ảnh quá lớn'),
          content: Text(
            'Ảnh ${(bytes / 1024).round()}KB — tối đa 700KB.\nChọn ảnh nhỏ hơn hoặc chụp lại.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
      return;
    }
    try {
      await mediaCtrl.sendImage(file);
    } catch (e) {
      _showMediaError(e.toString());
    }
  }

  Future<void> pickFileAndSend() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final pf = result.files.single;
      if (pf.path == null) {
        _showMediaError('Không đọc được file.');
        return;
      }
      if (pf.size > 500 * 1024) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('File quá lớn'),
            content: Text(
              '"${pf.name}" — ${(pf.size / 1024).round()}KB.\nTối đa 500KB.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đã hiểu'),
              ),
            ],
          ),
        );
        return;
      }
      await mediaCtrl.sendFile(File(pf.path!), pf.name);
    } catch (e) {
      _showMediaError(e.toString());
    }
  }

  Future<void> sendLocationMessage() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('GPS chưa bật'),
          content: const Text('Bật GPS trong Cài đặt rồi thử lại.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Geolocator.openLocationSettings();
              },
              child: const Text('Mở Cài đặt'),
            ),
          ],
        ),
      );
      return;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _showMediaError('Cần quyền vị trí.');
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang xác định vị trí...'),
        duration: Duration(seconds: 15),
      ),
    );

    try {
      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
          ),
        ).timeout(const Duration(seconds: 25));
      } on TimeoutException {
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) {
          throw Exception('Không lấy được vị trí.');
        }
        pos = last;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Gửi vị trí hiện tại'),
          content: Text(
            'Tọa độ: ${pos.latitude.toStringAsFixed(5)}, '
            '${pos.longitude.toStringAsFixed(5)}\n'
            'Độ chính xác: ±${pos.accuracy.round()}m',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: mediaPrimary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Gửi'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await mediaCtrl.sendLocation(
          lat: pos.latitude,
          lng: pos.longitude,
          accuracy: pos.accuracy,
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showMediaError(e.toString());
    }
  }

  Future<void> startRecording() async {
    if (!await _requestPermission(Permission.microphone)) return;

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/job_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _mediaRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _recordingDuration += const Duration(seconds: 1);
      });
      if (_recordingDuration.inSeconds >= 30) {
        stopRecordingAndSend();
      }
    });
  }

  Future<void> stopRecordingAndSend() async {
    _recordingTimer?.cancel();
    final path = await _mediaRecorder.stop();
    final duration = _recordingDuration;
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });
    if (path != null) {
      try {
        await mediaCtrl.sendAudio(File(path), duration);
      } catch (e) {
        _showMediaError(e.toString());
      }
    }
  }

  Future<void> cancelRecording() async {
    _recordingTimer?.cancel();
    await _mediaRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });
  }

  Widget buildRecordingBar() {
    const maxSec = 30;
    final elapsed = _recordingDuration.inSeconds.clamp(0, maxSec);
    final progress = elapsed / maxSec;
    final mm = (elapsed ~/ 60).toString().padLeft(2, '0');
    final ss = (elapsed % 60).toString().padLeft(2, '0');

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.grey.shade200,
              color: mediaPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.mic_rounded, color: Colors.red.shade400),
              const SizedBox(width: 8),
              Text('$mm:$ss', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(onPressed: cancelRecording, child: const Text('Hủy')),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: mediaPrimary),
                onPressed: stopRecordingAndSend,
                child: const Text('Gửi'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildUploadOverlay() {
    return Obx(() {
      if (!mediaCtrl.isUploading.value) return const SizedBox.shrink();
      return Container(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: mediaPrimary),
                const SizedBox(height: 14),
                const Text(
                  'Đang gửi...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
