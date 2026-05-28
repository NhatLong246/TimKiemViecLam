import 'package:flutter/material.dart';

/// Giờ · vị trí · tên ảnh — dùng trên màn NTD và nhân viên.
class AttendancePhotoInfo extends StatelessWidget {
  const AttendancePhotoInfo({
    super.key,
    this.capturedAt,
    this.time,
    this.locationLabel,
    this.fileName,
    this.textColor,
    this.dense = false,
  });

  final String? capturedAt;
  final String? time;
  final String? locationLabel;
  final String? fileName;
  final Color? textColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? Colors.grey.shade700;
    final timeLine = (capturedAt ?? '').isNotEmpty
        ? capturedAt!
        : ((time ?? '').isNotEmpty ? 'Giờ: $time' : null);
    final loc = (locationLabel ?? '').trim();
    final name = (fileName ?? '').trim();

    if (timeLine == null && loc.isEmpty && name.isEmpty) {
      return const SizedBox.shrink();
    }

    final fontSize = dense ? 9.0 : 10.0;
    final iconSize = dense ? 11.0 : 12.0;

    return Padding(
      padding: EdgeInsets.only(top: dense ? 4 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (timeLine != null)
            _line(Icons.access_time, timeLine, color, fontSize, iconSize),
          if (loc.isNotEmpty)
            _line(Icons.location_on_outlined, loc, color, fontSize, iconSize),
          if (name.isNotEmpty)
            _line(Icons.image_outlined, name, color, fontSize, iconSize),
        ],
      ),
    );
  }

  Widget _line(
    IconData icon,
    String text,
    Color color,
    double fontSize,
    double iconSize,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: fontSize, color: color, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }
}
