import '../runtime/context.dart';
import 'filter.dart';

int _isoWeekNumber(DateTime date) {
  final dayOfWeek = date.weekday; // 1 = Monday, 7 = Sunday
  final thursday = date.add(Duration(days: 4 - dayOfWeek));
  final yearStart = DateTime(thursday.year, 1, 1);
  final dayOfYear = thursday.difference(yearStart).inDays + 1;
  return ((dayOfYear - 1) / 7).floor() + 1;
}

int _isoWeekYear(DateTime date) {
  final dayOfWeek = date.weekday;
  final thursday = date.add(Duration(days: 4 - dayOfWeek));
  return thursday.year;
}

const _monthsFull = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December'
];

const _monthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

const _daysFull = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];

const _daysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

DateTime? _parseDateTime(Object? val) {
  if (val == null) return null;
  if (val is DateTime) return val;
  if (val is num) {
    final intVal = val.toInt();
    if (intVal < 10000000000) {
      return DateTime.fromMillisecondsSinceEpoch(intVal * 1000);
    }
    return DateTime.fromMillisecondsSinceEpoch(intVal);
  }
  final str = val.toString().trim();
  if (str.toLowerCase() == 'now' || str.toLowerCase() == 'today') {
    return DateTime.now();
  }
  return DateTime.tryParse(str);
}

DateTime? _parseDateTimeWithFormat(String str, String inputFormat) {
  final escaped = RegExp.escape(inputFormat)
      .replaceAll('YYYY', r'(?<Y>\d{4})')
      .replaceAll('YY', r'(?<y>\d{2})')
      .replaceAll('MM', r'(?<M>\d{1,2})')
      .replaceAll('DD', r'(?<D>\d{1,2})')
      .replaceAll('HH', r'(?<H>\d{1,2})')
      .replaceAll('mm', r'(?<m>\d{1,2})')
      .replaceAll('ss', r'(?<s>\d{1,2})');
  try {
    final match = RegExp('^$escaped\$').firstMatch(str.trim());
    if (match != null) {
      final names = match.groupNames.toSet();
      final yStr = names.contains('Y')
          ? match.namedGroup('Y')
          : (names.contains('y') ? match.namedGroup('y') : null);
      var year = yStr != null ? int.parse(yStr) : DateTime.now().year;
      if (year < 100) year += 2000;
      final month =
          names.contains('M') ? int.tryParse(match.namedGroup('M') ?? '') ?? 1 : 1;
      final day =
          names.contains('D') ? int.tryParse(match.namedGroup('D') ?? '') ?? 1 : 1;
      final hour =
          names.contains('H') ? int.tryParse(match.namedGroup('H') ?? '') ?? 0 : 0;
      final minute =
          names.contains('m') ? int.tryParse(match.namedGroup('m') ?? '') ?? 0 : 0;
      final second =
          names.contains('s') ? int.tryParse(match.namedGroup('s') ?? '') ?? 0 : 0;
      return DateTime(year, month, day, hour, minute, second);
    }
  } catch (_) {}
  return _parseDateTime(str);
}

String _formatDate(DateTime dt, String format) {
  final tokenRegex = RegExp(
    r'\[([^\]]+)\]|MMMM|MMM|MM|M|YYYY|YY|GGGG|GG|WW|W|DD|D|dddd|ddd|d|HH|H|hh|h|mm|m|ss|s|A|a|.',
  );

  return tokenRegex.allMatches(format).map((match) {
    final literal = match.group(1);
    if (literal != null) return literal;
    final token = match.group(0)!;
    switch (token) {
      case 'MMMM':
        return _monthsFull[dt.month - 1];
      case 'MMM':
        return _monthsShort[dt.month - 1];
      case 'MM':
        return dt.month.toString().padLeft(2, '0');
      case 'M':
        return dt.month.toString();
      case 'YYYY':
        return dt.year.toString().padLeft(4, '0');
      case 'YY':
        return (dt.year % 100).toString().padLeft(2, '0');
      case 'GGGG':
        return _isoWeekYear(dt).toString().padLeft(4, '0');
      case 'GG':
        return (_isoWeekYear(dt) % 100).toString().padLeft(2, '0');
      case 'WW':
        return _isoWeekNumber(dt).toString().padLeft(2, '0');
      case 'W':
        return _isoWeekNumber(dt).toString();
      case 'DD':
        return dt.day.toString().padLeft(2, '0');
      case 'D':
        return dt.day.toString();
      case 'dddd':
        return _daysFull[dt.weekday - 1];
      case 'ddd':
        return _daysShort[dt.weekday - 1];
      case 'd':
        return (dt.weekday % 7).toString();
      case 'HH':
        return dt.hour.toString().padLeft(2, '0');
      case 'H':
        return dt.hour.toString();
      case 'hh':
        final h = dt.hour % 12;
        return (h == 0 ? 12 : h).toString().padLeft(2, '0');
      case 'h':
        final h = dt.hour % 12;
        return (h == 0 ? 12 : h).toString();
      case 'mm':
        return dt.minute.toString().padLeft(2, '0');
      case 'm':
        return dt.minute.toString();
      case 'ss':
        return dt.second.toString().padLeft(2, '0');
      case 's':
        return dt.second.toString();
      case 'A':
        return dt.hour >= 12 ? 'PM' : 'AM';
      case 'a':
        return dt.hour >= 12 ? 'pm' : 'am';
      default:
        return token;
    }
  }).join('');
}

int? _parseIsoDurationToSeconds(String str) {
  final match = RegExp(
    r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$',
  ).firstMatch(str.trim());
  if (match == null) return null;
  final years = int.tryParse(match.group(1) ?? '') ?? 0;
  final months = int.tryParse(match.group(2) ?? '') ?? 0;
  final weeks = int.tryParse(match.group(3) ?? '') ?? 0;
  final days = int.tryParse(match.group(4) ?? '') ?? 0;
  final hours = int.tryParse(match.group(5) ?? '') ?? 0;
  final minutes = int.tryParse(match.group(6) ?? '') ?? 0;
  final seconds = double.tryParse(match.group(7) ?? '') ?? 0.0;
  final totalSec = years * 31536000 +
      months * 2592000 +
      weeks * 604800 +
      days * 86400 +
      hours * 3600 +
      minutes * 60 +
      seconds;
  return totalSec.round();
}

/// Date and duration filters for formatting, shifting, and parsing timestamps.
final Map<String, KnapFilter> dateFilters = {
  'date': (val, args) {
    if (val == null) return '';
    final str = val.toString().trim();
    final format =
        args.isNotEmpty ? args[0]?.toString() ?? 'YYYY-MM-DD' : 'YYYY-MM-DD';
    final inputFormat = args.length > 1 ? args[1]?.toString() : null;

    DateTime? dt;
    if (inputFormat != null && inputFormat.isNotEmpty) {
      dt = _parseDateTimeWithFormat(str, inputFormat);
    } else {
      dt = _parseDateTime(val);
    }

    if (dt == null) {
      reportFilterWarning(
        'Invalid date input: $val',
        'date',
      );
      return str;
    }
    return _formatDate(dt, format);
  },
  'date_modify': (val, args) {
    final dt = _parseDateTime(val);
    if (dt == null || args.isEmpty) return val?.toString() ?? '';

    final modifier = args[0]?.toString().trim() ?? '';
    final match = RegExp(
      r'^([+-]?\d+)\s*(year|month|week|day|hour|minute|second)s?$',
      caseSensitive: false,
    ).firstMatch(modifier);

    if (match == null) return _formatDate(dt, 'YYYY-MM-DD');

    final amount = int.tryParse(match.group(1)!) ?? 0;
    final unit = match.group(2)!.toLowerCase();

    DateTime modified;
    switch (unit) {
      case 'year':
        modified = DateTime(
          dt.year + amount,
          dt.month,
          dt.day,
          dt.hour,
          dt.minute,
          dt.second,
        );
        break;
      case 'month':
        modified = DateTime(
          dt.year,
          dt.month + amount,
          dt.day,
          dt.hour,
          dt.minute,
          dt.second,
        );
        break;
      case 'week':
        modified = dt.add(Duration(days: amount * 7));
        break;
      case 'day':
        modified = dt.add(Duration(days: amount));
        break;
      case 'hour':
        modified = dt.add(Duration(hours: amount));
        break;
      case 'minute':
        modified = dt.add(Duration(minutes: amount));
        break;
      case 'second':
        modified = dt.add(Duration(seconds: amount));
        break;
      default:
        modified = dt;
    }

    final format = args.length > 1
        ? args[1]?.toString() ?? 'YYYY-MM-DD'
        : 'YYYY-MM-DD';
    return _formatDate(modified, format);
  },
  'duration': (val, args) {
    if (val == null) return '';
    int? totalSeconds;
    if (val is num) {
      totalSeconds = val.toInt();
    } else {
      final str = val.toString().trim();
      totalSeconds = _parseIsoDurationToSeconds(str);
      if (totalSeconds == null) {
        final parsed = double.tryParse(str);
        if (parsed != null) {
          totalSeconds = parsed.toInt();
        } else {
          return val.toString();
        }
      }
    }

    final totalHours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (args.isEmpty) {
      final mm = minutes.toString().padLeft(2, '0');
      final ss = seconds.toString().padLeft(2, '0');
      if (totalHours > 0) {
        final hh = totalHours.toString().padLeft(2, '0');
        return '$hh:$mm:$ss';
      }
      return '$mm:$ss';
    }

    final format = args[0]?.toString() ?? '';
    return format
        .replaceAll('HH', totalHours.toString().padLeft(2, '0'))
        .replaceAll('H', totalHours.toString())
        .replaceAll('mm', minutes.toString().padLeft(2, '0'))
        .replaceAll('m', minutes.toString())
        .replaceAll('ss', seconds.toString().padLeft(2, '0'))
        .replaceAll('s', seconds.toString());
  },
};
