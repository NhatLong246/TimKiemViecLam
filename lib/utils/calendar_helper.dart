import 'package:add_2_calendar/add_2_calendar.dart';

class CalendarHelper {
  static Future<bool> addShiftToDeviceCalendar({
    required String title,
    required String description,
    required String dateYmd,
    required String startTimeHm,
    required String endTimeHm,
    String? location,
  }) async {
    final start = _parseDateTime(dateYmd, startTimeHm);
    final end = _parseDateTime(dateYmd, endTimeHm);
    if (start == null || end == null) return false;

    final event = Event(
      title: title,
      description: description,
      location: location ?? '',
      startDate: start,
      endDate: end.isAfter(start) ? end : start.add(const Duration(hours: 4)),
      allDay: false,
    );

    return Add2Calendar.addEvent2Cal(event);
  }

  static DateTime? _parseDateTime(String ymd, String hm) {
    try {
      final dateParts = ymd.split('-');
      final timeParts = hm.split(':');
      if (dateParts.length != 3) return null;
      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        timeParts.length > 1 ? int.parse(timeParts[1]) : 0,
      );
    } catch (_) {
      return null;
    }
  }
}
