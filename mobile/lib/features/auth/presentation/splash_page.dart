import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:mobile/shared/widgets/loading_view.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Shown while the app checks for an existing session on startup.
///
/// Dispatches [AuthSessionRequested] once and shows a spinner while the
/// bloc is in [AuthInitial]/[AuthLoading]. Navigation away from this page
/// (to the authenticated home or to login) is handled by the app's router
/// redirect logic reacting to [AuthBloc]'s state, wired in a later
/// integration pass.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const AuthSessionRequested());
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: LoadingView());
  }
}
