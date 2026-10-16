import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/app_identity.dart';

class RecoveryKeyExport {
  String? savedLocation;

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
    const filename = '$appName-مفاتيح الاسترداد.txt';
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw const FileSystemException('Downloads folder unavailable');
      }
      await directory.create(recursive: true);
      var file = File(p.join(directory.path, filename));
      var copy = 1;
      while (await file.exists()) {
        file = File(
          p.join(
            directory.path,
            '${p.withoutExtension(filename)} (${copy++}).txt',
          ),
        );
      }
      await file.writeAsString(content, encoding: utf8, flush: true);
      savedLocation = file.path;
      return true;
    }
    final saved = await FilePicker.saveFile(
      fileName: filename,
      dialogTitle: 'حفظ مفاتيح الاسترداد',
      mimeType: 'text/plain',
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
    if (saved != null) savedLocation = saved.toString();
    return saved != null;
  }
}
