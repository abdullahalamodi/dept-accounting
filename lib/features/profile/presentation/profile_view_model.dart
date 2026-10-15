import '../../../core/data/app_store.dart';
import '../../../core/ui/form_widgets.dart';

class ProfileViewModel extends ActionViewModel {
  ProfileViewModel(this.store);
  final AppStore store;
  bool saveUsername(String username) {
    if (busy) return false;
    return perform(
      () => store.updateProfile(name: store.user!.name, username: username),
    );
  }

  void logout() => store.logout();
}
