import 'package:intl/intl.dart';

class DateUtils {
  static String formatDate(DateTime dt) {
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  static String formatDateTime(DateTime dt) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  static String formatTime(DateTime dt) {
    return DateFormat('HH:mm:ss').format(dt);
  }

  static String formatReceiptDate(DateTime dt) {
    return DateFormat('dd MMM yyyy HH:mm').format(dt);
  }
}
