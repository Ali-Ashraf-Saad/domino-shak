import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'bridge.dart';
import 'web_shell.dart';

const Color _woodDark = Color(0xFF36210F);
const Color _brass = Color(0xFFD9A93C);

/// Fixed port so localStorage (name, settings, reconnect tokens) always keeps
/// the same origin across launches.
final InAppLocalhostServer _localhostServer = InAppLocalhostServer(
  documentRoot: 'assets/web',
  port: 8080,
  directoryIndex: 'index.html',
);

String? _serverError;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: _woodDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  if (kDebugMode) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  try {
    await _localhostServer.start();
  } catch (error) {
    _serverError = error.toString();
    debugPrint('Local web server failed to start: $error');
  }

  runApp(const DominoShakApp());
}

class DominoShakApp extends StatefulWidget {
  const DominoShakApp({super.key});

  @override
  State<DominoShakApp> createState() => _DominoShakAppState();
}

class _DominoShakAppState extends State<DominoShakApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onDetach: () => unawaited(_stopLocalServer()),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    unawaited(_stopLocalServer());
    super.dispose();
  }

  Future<void> _stopLocalServer() async {
    try {
      await _localhostServer.close();
    } catch (_) {
      // Nothing useful to do while the process is going away.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'دومينو شك',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brass,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: _woodDark,
      ),
      home: _serverError == null
          ? const WebShell()
          : _ServerErrorScreen(details: _serverError!),
    );
  }
}

class _ServerErrorScreen extends StatelessWidget {
  const _ServerErrorScreen({required this.details});

  final String details;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _woodDark,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: _brass, size: 52),
                const SizedBox(height: 16),
                const Text(
                  'مش قادر أجهّز اللعبة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'اقفل التطبيق من الخلفية وافتحه تاني.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 16),
                Text(
                  details,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
