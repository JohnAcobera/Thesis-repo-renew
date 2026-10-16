import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/user_model.dart';

void main() {
  test('reads the account join date from created_at', () {
    final user = UserModel.fromJson({
      'id': 42,
      'full_name': 'Student Example',
      'email': 'student@example.com',
      'role': 'student',
      'created_at': '2024-03-12T08:30:00Z',
    });

    expect(user.createdAt, DateTime.utc(2024, 3, 12, 8, 30));
  });
}
