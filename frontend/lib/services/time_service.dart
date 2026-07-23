import '../models/study_session.dart';

class TimeService {
  static final TimeService instance = TimeService._();
  TimeService._();

  String formatTime(DateTime dt) {
    int hour = dt.hour;
    final int minute = dt.minute;
    final String period = hour >= 12 ? "PM" : "AM";
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    final String minuteStr = minute < 10 ? "0$minute" : "$minute";
    return "$hour:$minuteStr $period";
  }

  bool isSessionActive(StudySession session, DateTime now) {
    return now.isAfter(session.startTime) && now.isBefore(session.endTime);
  }

  bool isSessionUpcoming(StudySession session, DateTime now) {
    return now.isBefore(session.startTime);
  }

  bool isSessionCompleted(StudySession session, DateTime now) {
    return session.isCompleted || now.isAfter(session.endTime);
  }
}
