import '../../../core/data/app_store.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../data/auth_models.dart';
import '../data/passwords.dart';
import '../data/recovery_key_export.dart';

class AuthViewModel extends ActionViewModel {
  AuthViewModel(this.store, {RecoveryKeyExport? recoveryKeyExport})
    : _recoveryKeyExport = recoveryKeyExport ?? RecoveryKeyExport();
  final AppStore store;
  final RecoveryKeyExport _recoveryKeyExport;
  final recovery = Passwords.token(24);
  final backupKey = Passwords.token(32);
  bool recoveryFileDownloaded = false;
  bool recoveryStorageConfirmed = false;
  bool downloadingRecoveryKeys = false;
  String? recoveryDownloadError;
  String? get recoveryFileLocation => _recoveryKeyExport.savedLocation;

  bool get canSetup =>
      recoveryFileDownloaded &&
      recoveryStorageConfirmed &&
      !downloadingRecoveryKeys;

  void confirmRecoveryStorage(bool confirmed) {
    recoveryStorageConfirmed = recoveryFileDownloaded && confirmed;
    changed();
  }

  Future<void> downloadRecoveryKeys() async {
    if (busy || downloadingRecoveryKeys) return;
    downloadingRecoveryKeys = true;
    recoveryDownloadError = null;
    notifyListeners();
    try {
      if (await _recoveryKeyExport.save(
        recoveryCode: recovery,
        backupKey: backupKey,
      )) {
        recoveryFileDownloaded = true;
      }
    } catch (_) {
      recoveryDownloadError = 'تعذر حفظ ملف المفاتيح في مجلد التنزيلات (Downloads). تحقق من صلاحية الوصول والمساحة المتاحة ثم حاول مجددًا.';
    } finally {
      downloadingRecoveryKeys = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) =>
      run(() => store.login(username, password));
  Future<bool> setup(
    Shop shop,
    String name,
    String username,
    String password,
  ) => run(() async {
    if (!canSetup) {
      throw const BusinessException(
        'حمّل مفاتيح الاسترداد وأكد حفظها في مكان آمن للمتابعة.',
      );
    }
    await store.setup(
      shop: shop,
      ownerName: name,
      username: username,
      password: password,
      recovery: recovery,
      backupKey: backupKey,
    );
  });
  Future<bool> recover(String code, String password) =>
      run(() => store.recoverOwner(code, password));
}
