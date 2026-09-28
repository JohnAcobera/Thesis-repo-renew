import 'package:flutter/material.dart';

import '../widgets/student_nav_bar.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({required this.username, required this.email, super.key});

  final String username;
  final String email;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: StudentNavBar(
      title: 'Generate a Study Material',
      username: username,
      email: email,
    ),
  );
}
