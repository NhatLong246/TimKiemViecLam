import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'widgets/incoming_call_overlay.dart';

/// Màn hình cuộc gọi dùng Agora RTC Engine
/// Hỗ trợ cả gọi thoại và gọi video.
///
/// Để lấy App ID:
///   1. Truy cập https://console.agora.io/
///   2. Tạo project mới → lấy App ID
///   3. Thay chuỗi _appId bên dưới
class CallScreen extends StatefulWidget {
  final bool isVideo;
  final String groupName;
  final String userName;
  final String userId;
  final String callId;
  final Future<void> Function()? onCallEnded;

  const CallScreen({
    super.key,
    required this.isVideo,
    required this.groupName,
    required this.userId,
    required this.callId,
    this.userName = 'Người dùng',
    this.onCallEnded,
    // ignore: unused_element
    String roomUrl = '',
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  // ── ĐỔI GIÁ TRỊ NÀY THÀNH APP ID CỦA BẠN TỪ console.agora.io ──────────────
  static const String _appId = '3059660a70af4028b3c0bc308304fa56';

  RtcEngine? _engine;
  bool _localJoined = false;
  bool _muted = false;
  bool _cameraOff = false;
  late bool _speakerOn;
  final Set<int> _remoteUids = {};
  String? _errorMsg;

  Timer? _timer;
  int _seconds = 0;

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void initState() {
    super.initState();
    _speakerOn = widget.isVideo;
    // Đóng overlay cuộc gọi đến khi đã vào màn hình gọi
    IncomingCallOverlay.markInCall();
    _initAgora();
  }

  @override
  void dispose() {
    _stopTimer();
    _engine?.leaveChannel();
    _engine?.release();
    // Cho phép hiện overlay cuộc gọi mới sau khi rời cuộc gọi
    IncomingCallOverlay.markCallEnded();
    super.dispose();
  }

  Future<void> _initAgora() async {
    // 1. Xin quyền
    final List<Permission> perms = [
      Permission.microphone,
      if (widget.isVideo) Permission.camera,
    ];
    final statuses = await perms.request();
    final micOk = statuses[Permission.microphone]?.isGranted ?? false;
    final camOk =
        !widget.isVideo || (statuses[Permission.camera]?.isGranted ?? false);

    if (!micOk || !camOk) {
      if (mounted) {
        setState(() => _errorMsg =
            widget.isVideo ? 'Cần quyền Micro và Camera.' : 'Cần quyền Micro.');
      }
      return;
    }

    // 2. Khởi tạo engine
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: _appId));

      // 3. Đăng ký event handlers
      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (mounted) {
            setState(() => _localJoined = true);
            _engine?.setEnableSpeakerphone(_speakerOn);
          }
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (mounted) {
            setState(() => _remoteUids.add(remoteUid));
            _startTimer();
          }
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (mounted) {
            setState(() => _remoteUids.remove(remoteUid));
            if (_remoteUids.isEmpty) {
              _stopTimer();
              _seconds = 0;
            }
          }
        },
        onConnectionStateChanged: (connection, state, reason) {
          if (state == ConnectionStateType.connectionStateFailed) {
            if (mounted) {
              setState(() => _errorMsg = 'Lỗi kết nối Agora: ${reason.name}');
            }
          }
        },
        onError: (err, msg) {
          if (mounted) setState(() => _errorMsg = 'Lỗi Agora: $msg');
        },
      ));

      await engine.enableAudio();

      if (widget.isVideo) {
        await engine.enableVideo();
        await engine.startPreview();
      }
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // 4. Join channel — token = '' cho dev (không cần token)
      await engine.joinChannel(
        token: '',
        channelId: widget.callId,
        uid: 0,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: widget.isVideo,
          publishMicrophoneTrack: true,
        ),
      );

      if (mounted) setState(() => _engine = engine);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Không thể khởi tạo: $e');
    }
  }

  void _toggleMute() {
    _engine?.muteLocalAudioStream(!_muted);
    setState(() => _muted = !_muted);
  }

  void _toggleCamera() {
    _engine?.muteLocalVideoStream(!_cameraOff);
    setState(() => _cameraOff = !_cameraOff);
  }

  void _toggleSpeaker() {
    _engine?.setEnableSpeakerphone(!_speakerOn);
    setState(() => _speakerOn = !_speakerOn);
  }

  void _switchCamera() => _engine?.switchCamera();

  Future<void> _endCall() async {
    try {
      await widget.onCallEnded?.call();
    } catch (_) {}
    await _engine?.leaveChannel();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_appId == 'YOUR_AGORA_APP_ID') {
      return _buildSetupGuide();
    }
    if (_errorMsg != null) return _buildError(_errorMsg!);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // Remote video (hoặc placeholder)
        _buildRemoteView(),
        // Local video (picture-in-picture góc trên phải)
        if (widget.isVideo) _buildLocalView(),
        // Tên người dùng góc dưới phải
        Positioned(
          right: 16,
          bottom: 100,
          child: Text(
            widget.groupName,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        // Control bar dưới
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildControls(),
        ),
      ]),
    );
  }

  Widget _buildRemoteView() {
    if (!widget.isVideo) {
      final String statusText;
      if (_remoteUids.isNotEmpty) {
        final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
        final ss = (_seconds % 60).toString().padLeft(2, '0');
        statusText = '$mm:$ss';
      } else {
        statusText = 'Đang chờ...';
      }

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: _remoteUids.isNotEmpty
                  ? _remoteUids
                      .map((uid) => const CircleAvatar(
                            radius: 36,
                            backgroundColor: Color(0xFF7B1FA2),
                            child: Icon(Icons.person, size: 40, color: Colors.white),
                          ))
                      .toList()
                  : [
                      const CircleAvatar(
                        radius: 56,
                        backgroundColor: Color(0xFF7B1FA2),
                        child: Icon(Icons.person, size: 64, color: Colors.white),
                      ),
                    ],
            ),
            const SizedBox(height: 24),
            Text(
              widget.groupName,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (_remoteUids.isNotEmpty) ...[
              Text(
                'Đang gọi với ${_remoteUids.length} người khác',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              statusText,
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_remoteUids.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Đang chờ người tham gia...',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    final uids = _remoteUids.toList();
    if (uids.length == 1) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: uids[0]),
          connection: RtcConnection(channelId: widget.callId),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: uids.length > 2 ? 2 : 1,
        childAspectRatio: uids.length > 2 ? 1.0 : 1.2,
      ),
      itemCount: uids.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine!,
              canvas: VideoCanvas(uid: uids[index]),
              connection: RtcConnection(channelId: widget.callId),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocalView() {
    if (!_localJoined || _cameraOff || _engine == null) return const SizedBox();
    return Positioned(
      top: 60,
      right: 16,
      child: Container(
        width: 100,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _engine!,
              canvas: const VideoCanvas(uid: 0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mic
          _ControlBtn(
            icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _muted ? 'Tắt mic' : 'Mic',
            onTap: _toggleMute,
            active: !_muted,
          ),
          // Camera (chỉ hiện khi video call)
          if (widget.isVideo)
            _ControlBtn(
              icon: _cameraOff
                  ? Icons.videocam_off_rounded
                  : Icons.videocam_rounded,
              label: _cameraOff ? 'Camera tắt' : 'Camera',
              onTap: _toggleCamera,
              active: !_cameraOff,
            ),
          // Kết thúc
          _ControlBtn(
            icon: Icons.call_end_rounded,
            label: 'Kết thúc',
            onTap: _endCall,
            isEndCall: true,
          ),
          // Loa
          _ControlBtn(
            icon: _speakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            label: _speakerOn ? 'Loa' : 'Tắt loa',
            onTap: _toggleSpeaker,
            active: _speakerOn,
          ),
          // Đổi camera
          if (widget.isVideo)
            _ControlBtn(
              icon: Icons.flip_camera_android_rounded,
              label: 'Đổi cam',
              onTap: _switchCamera,
            ),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Cuộc gọi'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 64),
              const SizedBox(height: 20),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 15, height: 1.5)),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B1FA2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () => openAppSettings(),
                child: const Text('Mở Cài đặt',
                    style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Quay lại',
                    style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Hướng dẫn cài đặt App ID nếu chưa điền
  Widget _buildSetupGuide() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Cần cấu hình Agora'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.settings_rounded,
                  color: Colors.amber, size: 56),
              const SizedBox(height: 20),
              const Text(
                'Cần App ID từ Agora',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                '1. Truy cập https://console.agora.io/\n'
                '2. Đăng ký miễn phí / đăng nhập\n'
                '3. Tạo Project mới\n'
                '4. Copy App ID\n'
                '5. Dán vào biến _appId trong\n'
                '   lib/screens/chat/call_screen.dart',
                style: TextStyle(color: Colors.white70, height: 1.8),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Quay lại',
                    style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Nút điều khiển trong call ────────────────────────────────────────────────
class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool? active;
  final bool isEndCall;

  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active,
    this.isEndCall = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = isEndCall
        ? Colors.redAccent
        : (active == false
            ? Colors.grey.shade700
            : Colors.white.withOpacity(0.15));

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
