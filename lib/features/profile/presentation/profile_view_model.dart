import '../../../core/data/store_tasks.dart';
import '../../../core/data/app_store.dart';
import '../../../core/ui/form_widgets.dart';

class ProfileViewModel extends ActionViewModel {
  ProfileViewModel(this.store);
  final AppStore store;
  Future<bool> saveUsername(String username) {
    return run(
      () async => store.run(StoreTasks.profile(store.user!.name, username)),
    );
  }

  void logout() => store.logout();
}
