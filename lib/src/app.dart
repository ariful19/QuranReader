import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'home_page.dart';
import 'screen_awake_manager.dart';

class QuranReaderBootstrap extends StatefulWidget {
  const QuranReaderBootstrap({super.key});

  @override
  State<QuranReaderBootstrap> createState() => _QuranReaderBootstrapState();
}

class _QuranReaderBootstrapState extends State<QuranReaderBootstrap> {
  late final Future<QuranAppController> _controllerFuture;

  @override
  void initState() {
    super.initState();
    _controllerFuture = QuranAppController.create();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QuranReader',
      theme: _buildTheme(),
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }
        return ScreenAwakeIdleGate(child: child);
      },
      home: FutureBuilder<QuranAppController>(
        future: _controllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingView();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorView(error: snapshot.error);
          }
          return QuranHomePage(controller: snapshot.data!);
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    const seed = Color(0xFF0F766E);
    const background = Color(0xFFF7F3E9);
    const surface = Color(0xFFFFFCF5);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
        surface: surface,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF17362F),
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF17362F),
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading QuranReader...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'QuranReader could not start.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
