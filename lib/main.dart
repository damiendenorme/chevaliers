import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';
import 'widgets/top_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const MyApp());
}

/// Nombre de lignes dans la table `joueur`.
Future<int> fetchPlayerCount() =>
    Supabase.instance.client.from('joueur').count(CountOption.exact);

/// Nombre de lignes dans la table `evenement`.
Future<int> fetchEventCount() =>
    Supabase.instance.client.from('evenement').count(CountOption.exact);

/// Nombre de lignes dans la table `partie`.
Future<int> fetchGameCount() =>
    Supabase.instance.client.from('partie').count(CountOption.exact);

/// Nombre de lignes dans la table `jeu`.
Future<int> fetchBoardGameCount() =>
    Supabase.instance.client.from('jeu').count(CountOption.exact);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Les Chevaliers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: .fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        // Fond uni gris foncé ; le thème sombre garde le texte clair et lisible.
        scaffoldBackgroundColor: const Color(0xFF2B2B2B),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    this.loadPlayerCount = fetchPlayerCount,
    this.loadEventCount = fetchEventCount,
    this.loadGameCount = fetchGameCount,
    this.loadBoardGameCount = fetchBoardGameCount,
  });

  final Future<int> Function() loadPlayerCount;
  final Future<int> Function() loadEventCount;
  final Future<int> Function() loadGameCount;
  final Future<int> Function() loadBoardGameCount;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final Future<int> _playerCount = widget.loadPlayerCount();
  late final Future<int> _eventCount = widget.loadEventCount();
  late final Future<int> _gameCount = widget.loadGameCount();
  late final Future<int> _boardGameCount = widget.loadBoardGameCount();

  Widget _counter(Future<int> future, IconData icon, String tooltip) {
    return FutureBuilder<int>(
      future: future,
      builder: (context, snapshot) =>
          TopBarInfo(icon: icon, value: snapshot.data, tooltip: tooltip),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              items: [
                _counter(_playerCount, Icons.person, 'Joueurs'),
                _counter(_eventCount, Icons.confirmation_number, 'Événements'),
                _counter(_gameCount, Icons.flag, 'Parties'),
                _counter(_boardGameCount, Icons.casino, 'Jeux'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
