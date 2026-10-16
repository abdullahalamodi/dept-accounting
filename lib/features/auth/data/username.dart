abstract final class Username {
  static const hint = 'أحرف إنجليزية وأرقام، ويمكن استخدام . أو _ أو -';

  static String? validate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'أدخل اسم المستخدم.';
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(text)) {
      return 'استخدم أحرفًا إنجليزية وأرقامًا والرموز . أو _ أو - فقط.';
    }
    return null;
  }
}
