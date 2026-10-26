import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thesis_repo_renew/services/tutorial_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('first-login tutorial is consumed once per normalized email', () async {
    const service = TutorialService();

    await service.markFirstLoginPending(' New.Student@Example.com ');

    expect(
      await service.consumeFirstLoginPending('new.student@example.com'),
      isTrue,
    );
    expect(
      await service.consumeFirstLoginPending('new.student@example.com'),
      isFalse,
    );
  });
}
