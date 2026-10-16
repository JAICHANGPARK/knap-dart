import 'dart:math' as math;
import '../runtime/context.dart';
import 'filter.dart';

/// Standard math and numeric calculation filters.
final Map<String, KnapFilter> mathFilters = {
  'sum': (val, args) {
    if (val is! Iterable) return 0;
    final property = args.isNotEmpty && args[0] != null && args[0].toString().isNotEmpty
        ? args[0].toString()
        : null;
    num total = 0;
    for (final item in val) {
      Object? resolved = item;
      if (property != null) {
        if (item is Map) {
          resolved = item[property];
        } else {
          resolved = null;
        }
      }
      if (resolved is num) {
        total += resolved;
      } else if (resolved != null) {
        final parsed = num.tryParse(resolved.toString());
        if (parsed != null) total += parsed;
      }
    }
    if (total == total.toInt()) {
      return total.toInt();
    }
    return total;
  },
  'round': (val, args) {
    if (val == null) return 0;
    final number = val is num ? val.toDouble() : double.tryParse(val.toString());
    if (number == null) {
      reportFilterWarning(
        'Non-numeric input for round: $val',
        'round',
      );
      return val;
    }
    var decimals = 0;
    if (args.isNotEmpty) {
      final d = args[0];
      if (d is num) {
        decimals = d.toInt();
      } else if (d != null) {
        decimals = int.tryParse(d.toString()) ?? 0;
      }
    }
    if (decimals <= 0) {
      return number.round();
    }
    return double.parse(number.toStringAsFixed(decimals));
  },
  'number_format': (val, args) {
    if (val == null) return '';
    int? decimals;
    var decPoint = '.';
    var thousandsSep = ',';

    if (args.isNotEmpty) {
      final d = args[0];
      if (d is num) {
        decimals = d.toInt();
      } else if (d != null) {
        decimals = int.tryParse(d.toString());
      }
    }
    if (args.length > 1 && args[1] != null) {
      decPoint = args[1].toString();
    }
    if (args.length > 2 && args[2] != null) {
      thousandsSep = args[2].toString();
    }

    String formatSingle(num numVal) {
      final str = decimals != null
          ? numVal.toStringAsFixed(decimals)
          : numVal.toString();
      final parts = str.split('.');
      final intPart = parts[0].replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => thousandsSep,
      );
      if (parts.length > 1) {
        return '$intPart$decPoint${parts[1]}';
      }
      return intPart;
    }

    Object? formatRec(Object? item) {
      if (item is num) return formatSingle(item);
      if (item is String) {
        final parsed = num.tryParse(item);
        if (parsed != null) return formatSingle(parsed);
        return item;
      }
      if (item is List) return item.map(formatRec).toList();
      if (item is Map) return item.map((k, v) => MapEntry(k, formatRec(v)));
      return item;
    }

    final formatted = formatRec(val);
    return formatted ?? '';
  },
  'calc': (val, args) {
    if (val == null || args.isEmpty) return val;
    final numVal =
        val is num ? val.toDouble() : double.tryParse(val.toString());
    if (numVal == null) {
      reportFilterWarning(
        'Non-numeric input for calc: $val',
        'calc',
      );
      return val;
    }

    final operation = args[0]?.toString().trim() ?? '';
    if (operation.isEmpty) return numVal;

    final operator =
        operation.startsWith('**') ? '**' : operation.substring(0, 1);
    final valueStr = operation.substring(operator.length).trim();
    final operand = double.tryParse(valueStr);
    if (operand == null) return numVal;

    double result;
    switch (operator) {
      case '+':
        result = numVal + operand;
        break;
      case '-':
        result = numVal - operand;
        break;
      case '*':
        result = numVal * operand;
        break;
      case '/':
        result = operand != 0 ? numVal / operand : 0;
        break;
      case '**':
      case '^':
        result = math.pow(numVal, operand).toDouble();
        break;
      default:
        return numVal;
    }

    if (result == result.toInt()) {
      return result.toInt();
    }
    return double.parse(result.toStringAsFixed(10));
  },
};
