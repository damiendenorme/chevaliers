import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/rows.dart';
import 'supabase_config.dart';
import 'widgets/row_list.dart';
import 'widgets/side_buttons.dart';
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
    this.loadRows = fetchRows,
  });

  final Future<int> Function() loadPlayerCount;
  final Future<int> Function() loadEventCount;
  final Future<int> Function() loadGameCount;
  final Future<int> Function() loadBoardGameCount;
  final Future<RowTable> Function(String table) loadRows;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final Future<int> _playerCount = widget.loadPlayerCount();
  late final Future<int> _eventCount = widget.loadEventCount();
  late final Future<int> _gameCount = widget.loadGameCount();
  late final Future<int> _boardGameCount = widget.loadBoardGameCount();

  /// Boutons latéraux : icône, libellé et table affichée au clic.
  static const _sections = [
    (Icons.person, 'Joueurs', 'joueur'),
    (Icons.confirmation_number, 'Événements', 'evenement'),
    (Icons.flag, 'Parties', 'partie'),
    (Icons.casino, 'Jeux', 'jeu'),
  ];

  /// Lignes de la table choisie, ou null tant qu'aucun bouton n'a été cliqué.
  Future<RowTable>? _rows;

  void _showTable(int index) {
    final rows = widget.loadRows(_sections[index].$3);
    setState(() {
      _rows = rows;
    });
  }

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
              title: 'Les Chevaliers',
              trailing: 'Discord',
              items: [
                _counter(_playerCount, Icons.person, 'Joueurs'),
                _counter(_eventCount, Icons.confirmation_number, 'Événements'),
                _counter(_gameCount, Icons.flag, 'Parties'),
                _counter(_boardGameCount, Icons.casino, 'Jeux'),
              ],
            ),
            Expanded(
              child: Stack(
                children: [
                  // Tableau centré sur toute la largeur de l'écran ; les
                  // boutons (et leur étirement au survol) passent par-dessus.
                  if (_rows != null)
                    Positioned.fill(
                      child: RowList(key: ObjectKey(_rows), rows: _rows!),
                    ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: SideButtons(
                      buttons: [
                        for (final (icon, label, _) in _sections) (icon, label),
                      ],
                      onPressed: _showTable,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
