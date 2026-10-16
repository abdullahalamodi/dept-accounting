class BusinessException implements Exception {
  const BusinessException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract final class Numbers {
  static const maxValue = 100000000000000;

  static int parse(
    String input, {
    int decimals = 2,
    bool negative = false,
    bool emptyAsZero = false,
  }) {
    if (emptyAsZero && input.trim().isEmpty) return 0;
    var text = input
        .trim()
        .replaceAll('٬', '')
        .replaceAll(',', '')
        .replaceAll('٫', '.');
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    for (var i = 0; i < 10; i++) {
      text = text.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
    }
    if (!RegExp(negative ? r'^-?\d+(\.\d+)?$' : r'^\d+(\.\d+)?$')
        .hasMatch(text)) {
      throw const BusinessException('أدخل رقمًا صحيحًا بالقيمة المطلوبة.');
    }
    final sign = text.startsWith('-') ? -1 : 1;
    final parts = text.replaceAll('-', '').split('.');
    final fraction = parts.length > 1 ? parts[1] : '';
    if (fraction.length > decimals) {
      throw BusinessException('الحد الأقصى $decimals منازل عشرية.');
    }
    final scaled =
        BigInt.parse(parts[0] + fraction.padRight(decimals, '0')) *
        BigInt.from(sign);
    if (scaled.abs() > BigInt.from(maxValue)) {
      throw const BusinessException('القيمة أكبر من الحد المسموح.');
    }
    return scaled.toInt();
  }

  static int ratio(int a, int b, int divisor) {
    if (divisor <= 0) throw const BusinessException('معامل الحساب غير صالح.');
    final value = BigInt.from(a) * BigInt.from(b);
    final result =
        (value.abs() + BigInt.from(divisor ~/ 2)) ~/ BigInt.from(divisor);
    if (result > BigInt.from(maxValue)) {
      throw const BusinessException('ناتج الحساب أكبر من الحد المسموح.');
    }
    return result.toInt() * value.sign;
  }

  static int baseQuantity(int quantity, int factor) {
    final product = BigInt.from(quantity) * BigInt.from(factor);
    if (product % BigInt.from(1000) != BigInt.zero) {
      throw const BusinessException(
        'تحويل الوحدة يتجاوز دقة الكمية (ثلاث منازل).',
      );
    }
    return ratio(quantity, factor, 1000);
  }

  static String input(int value, {int decimals = 2, bool blankZero = false}) {
    if (blankZero && value == 0) return '';
    final sign = value < 0 ? '-' : '';
    final digits = value.abs().toString().padLeft(decimals + 1, '0');
    if (decimals == 0) return '$sign$digits';
    final fraction = digits
        .substring(digits.length - decimals)
        .replaceFirst(RegExp(r'0+$'), '');
    return '$sign${digits.substring(0, digits.length - decimals)}${fraction.isEmpty ? '' : '.$fraction'}';
  }

  static String format(int value, {int decimals = 2}) {
    final parts = input(value, decimals: decimals).split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return parts.length == 1 ? whole : '$whole.${parts.last}';
  }
}
