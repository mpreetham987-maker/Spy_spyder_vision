import 'package:flutter/material.dart';

import 'app_shell.dart';

/// Entry point pushed by the splash screen. Kept as a thin wrapper
/// around [AppShell] so navigation/router code elsewhere in the app
/// can always target `DashboardScreen` regardless of how the internal
/// tab-shell implementation evolves.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => const AppShell();
}
