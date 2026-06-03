import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/messaging_models.dart';

/// Bubble ảnh / âm thanh / file / vị trí cho chat việc làm.
class JobMediaMessageBubble extends StatelessWidget {
  const JobMediaMessageBubble({
    super.key,
    required this.msg,
    required this.isMine,
    required this.primary,
    required this.senderName,
    this.avatar,
    this.showSenderName = false,
    this.messageWrapper,
  });

  final JobChatMessage msg;
  final bool isMine;
  final Color primary;
  final String senderName;
  final Widget? avatar;
  final bool showSenderName;
  /// Bọc nội dung tin (để gắn vuốt trả lời).
  final Widget Function(Widget child)? messageWrapper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine && avatar != null) ...[avatar!, const SizedBox(width: 8)],
          Expanded(
            child: _wrapMessageBody(
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMine && showSenderName)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ),
                  _content(context),
                ],
              ),
            ),
          ),
          if (isMine && avatar != null) ...[const SizedBox(width: 8), avatar!],
        ],
      ),
    );
  }

  Widget _wrapMessageBody(Widget body) {
    final wrap = messageWrapper;
    if (wrap != null) return wrap(body);
    return body;
  }

  Widget _content(BuildContext context) {
    if (msg.isImage) return _JobImageContent(msg: msg, isMine: isMine, primary: primary);
    if (msg.isAudio) {
      return _JobAudioContent(msg: msg, isMine: isMine, primary: primary);
    }
    if (msg.isFile) return _JobFileContent(msg: msg, isMine: isMine, primary: primary);
    if (msg.isLocation) {
      return _JobLocationContent(msg: msg, isMine: isMine, primary: primary);
    }
    return const SizedBox.shrink();
  }
}

class _JobImageContent extends StatelessWidget {
  const _JobImageContent({
    required this.msg,
    required this.isMine,
    required this.primary,
  });

  final JobChatMessage msg;
  final bool isMine;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _decodeImage(msg.attachmentUrl),
          if (msg.createdAt != null)
            Container(
              color: isMine ? primary : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                DateFormat('HH:mm').format(msg.createdAt!),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10,
                  color: isMine ? Colors.white70 : Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _decodeImage(String? raw) {
    if (raw == null || !raw.startsWith('data:')) {
      return _broken();
    }
    try {
      final base64Str = raw.contains(',') ? raw.split(',').last : raw;
      return Image.memory(
        base64Decode(base64Str),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _broken(),
      );
    } catch (_) {
      return _broken();
    }
  }

  static Widget _broken() => Container(
        height: 120,
        color: const Color(0xFFEEF0F7),
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      );
}

class _JobAudioContent extends StatefulWidget {
  const _JobAudioContent({
    required this.msg,
    required this.isMine,
    required this.primary,
  });

  final JobChatMessage msg;
  final bool isMine;
  final Color primary;

  @override
  State<_JobAudioContent> createState() => _JobAudioContentState();
}

class _JobAudioContentState extends State<_JobAudioContent> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Duration get _fallbackDuration {
    final parts = widget.msg.content.split(':');
    if (parts.length == 2) {
      return Duration(
        minutes: int.tryParse(parts[0]) ?? 0,
        seconds: int.tryParse(parts[1]) ?? 0,
      );
    }
    return Duration.zero;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final raw = widget.msg.attachmentUrl ?? '';
    if (raw.isEmpty) return;

    if (_playing) {
      await _player.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }

    try {
      final base64Str = raw.contains(',') ? raw.split(',').last : raw;
      final bytes = base64Decode(base64Str);
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/job_audio_${widget.msg.msgId}.m4a');
      await f.writeAsBytes(bytes, flush: true);
      await _player.play(DeviceFileSource(f.path));
      if (mounted) setState(() => _playing = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không phát được: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.isMine;
    final p = widget.primary;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
        minWidth: 160,
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFF0084FF) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 4),
          bottomRight: Radius.circular(mine ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: mine
                    ? Colors.white.withValues(alpha: 0.2)
                    : p.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: mine ? Colors.white : p,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.mic_rounded, color: mine ? Colors.white70 : Colors.grey),
          const SizedBox(width: 8),
          Text(
            (() {
              final totalDur = _duration > Duration.zero ? _duration : _fallbackDuration;
              if (totalDur > Duration.zero && (_playing || _position > Duration.zero)) {
                final remaining = totalDur - _position;
                return _formatDuration(remaining.isNegative ? Duration.zero : remaining);
              }
              return widget.msg.content;
            })(),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: mine ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobFileContent extends StatelessWidget {
  const _JobFileContent({
    required this.msg,
    required this.isMine,
    required this.primary,
  });

  final JobChatMessage msg;
  final bool isMine;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final ext = (msg.metadata?['ext'] ?? '').toString();
    final size = msg.metadata?['size'] as int?;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMine ? const Color(0xFF0084FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file_rounded,
            color: isMine ? Colors.white : primary,
            size: 32,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isMine ? Colors.white : Colors.black87,
                  ),
                ),
                if (size != null)
                  Text(
                    '${(size / 1024).round()} KB · ${ext.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isMine ? Colors.white70 : Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JobLocationContent extends StatelessWidget {
  const _JobLocationContent({
    required this.msg,
    required this.isMine,
    required this.primary,
  });

  final JobChatMessage msg;
  final bool isMine;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final lat = (msg.metadata?['lat'] as num?)?.toDouble();
    final lng = (msg.metadata?['lng'] as num?)?.toDouble();

    return GestureDetector(
      onTap: lat != null && lng != null
          ? () => launchUrl(
                Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                ),
                mode: LaunchMode.externalApplication,
              )
          : null,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary.withValues(alpha: 0.15),
                    primary.withValues(alpha: 0.08),
                  ],
                ),
              ),
              child: Center(
                child: Icon(Icons.location_on_rounded, size: 48, color: primary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vị trí đã chia sẻ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (lat != null && lng != null)
                    Text(
                      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  Text(
                    'Chạm để mở Google Maps',
                    style: TextStyle(fontSize: 11, color: primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
