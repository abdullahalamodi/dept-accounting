import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../../core/app_identity.dart';

class RecoveryKeyExport {
  Future<bool> save({
    required String recoveryCode,
    required String backupKey,
  }) async {
    final content = [
      '$appName — مفاتيح الاسترداد',
      '',
      'رمز استرداد دخول المالك',
      recoveryCode,
      '',
      'مفتاح استعادة النسخ الاحتياطية',
      backupKey,
      '',
      'رمز الدخول يعيد تعيين كلمة مرور المالك.',
      'مفتاح النسخ ضروري لاستعادة ملفات النسخ الاحتياطية المشفرة.',
      'هذا الملف يحتوي المفاتيح فقط، ولا يحتوي بيانات المحل. لاستعادة بياناتك تحتاج إلى هذا المفتاح وملف نسخة احتياطية بامتداد .dept_accounting.',
      'بعد إنشاء المحل، افتح «الإعدادات والنسخ»، واختر مجلد النسخة الخارجية على USB أو قرص خارجي، ثم اضغط «إنشاء نسخة احتياطية الآن».',
      '',
      'احفظ هذا الملف في مكان آمن خارج جهاز المحل، ولا تشاركه مع الآخرين.',
      'فقدان رمز الدخول يمنع استرداد كلمة المرور، وفقدان مفتاح النسخ يمنع استعادة النسخ المشفرة.',
      '',
    ].join('\n');
    final saved = await FilePicker.saveFile(
      fileName: '$appName-مفاتيح الاسترداد.txt',
      dialogTitle: 'حفظ مفاتيح الاسترداد',
      mimeType: 'text/plain',
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
    return saved != null;
  }
}
