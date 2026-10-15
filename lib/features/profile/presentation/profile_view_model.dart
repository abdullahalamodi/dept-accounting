import '../../../core/data/app_store.dart';
import '../../../core/ui/form_widgets.dart';

class ProfileViewModel extends ActionViewModel {
  ProfileViewModel(this.store);
  final AppStore store;
  bool editingPassword = false;

  bool saveDetails(String name, String username) {
    if (busy) return false;
    editingPassword = false;
    return perform(() => store.updateProfile(name: name, username: username));
  }

  Future<bool> changePassword(String current, String next) {
    editingPassword = true;
    return run(() => store.changePassword(current, next));
  }

  void logout() => store.logout();
}
