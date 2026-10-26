import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  const TutorialService();

  String _pendingKey(String email) =>
      'quizforge_tutorial_pending_${email.trim().toLowerCase()}';

  Future<void> markFirstLoginPending(String email) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(_pendingKey(email), true);
    if (!saved) {
      throw Exception('The new-user tutorial could not be scheduled.');
    }
  }

  Future<bool> consumeFirstLoginPending(String email) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _pendingKey(email);
    final isPending = preferences.getBool(key) ?? false;
    if (!isPending) return false;

    final removed = await preferences.remove(key);
    if (!removed) {
      throw Exception('The new-user tutorial could not be scheduled.');
    }
    return true;
  }
}
