import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/rows.dart';
import 'supabase_config.dart';
import 'widgets/row_list.dart';
import 'widgets/section_buttons.dart';
import 'widgets/top_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const MyApp());
}

/// Nombre de joueurs, d'événements, de parties et de jeux en base.
typedef Counts = ({int players, int events, int games, int boardGames});

Future<Counts> fetchCounts() async {
  final db = Supabase.instance.client;
  final (players, events, games, boardGames) = await (
    db.from('joueur').count(CountOption.exact),
    db.from('evenement').count(CountOption.exact),
    db.from('partie').count(CountOption.exact),
    db.from('jeu').count(CountOption.exact),
  ).wait;
  return (
    players: players,
    events: events,
    games: games,
    boardGames: boardGames,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Les Chevaliers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Thème sombre, aux tons chauds (bronze) : texte clair sur les cartes
        // sombres.
        colorScheme: .fromSeed(
          seedColor: const Color(0xFF8B6B3D),
          brightness: Brightness.dark,
        ),
        // Presque noir (bannières vides).
        scaffoldBackgroundColor: const Color(0xFF120F0D),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    this.loadRows = fetchRows,
    this.loadCounts = fetchCounts,
  });

  final Future<RowTable> Function(String table) loadRows;

  /// Nombres affichés dans l'encoche du haut de l'écran.
  final Future<Counts> Function() loadCounts;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  /// Boutons au-dessus des tableaux : libellé et table affichée au clic.
  static const _sections = [
    ('Joueurs', 'joueur'),
    ('Événements', 'evenement'),
    ('Parties', 'partie'),
    ('Jeux', 'jeu'),
  ];

  // Distances mesurées depuis le haut de la zone (sous sa marge de 12px).
  // Boutons et tableau se règlent indépendamment.

  /// Haut de la barre des boutons.
  static const double _buttonsTop = 52;

  /// Écart entre la barre des boutons et le tableau : le même qu'entre les
  /// deux cartes.
  static const double _tableGap = RowList.gap;

  /// Section affichée au démarrage : les parties.
  static const _startSection = 2;

  late final Future<Counts> _counts = widget.loadCounts();

  /// Marque-pages du bord gauche de l'écran, et celui qui est actif.
  static const _bookmarks = ['Wargame', 'RPG'];
  int _bookmark = 0;

  /// Section affichée, dont le bouton est actif.
  int _active = _startSection;

  /// Lignes de la table affichée.
  late Future<RowTable> _rows = widget.loadRows(_sections[_startSection].$2);

  void _showTable(int index) {
    final rows = widget.loadRows(_sections[index].$2);
    setState(() {
      _active = index;
      _rows = rows;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Image de fond sur tout l'écran, recadrée pour le couvrir. Copie à
      // 2560px de large de assets/Table.png (14173px, 27 Mo).
      body: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/Table.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // Fondu au noir sur les bords gauche et droit de l'écran, sur
            // l'image de fond, sous le reste.
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black,
                        Color(0x00000000),
                        Color(0x00000000),
                        Colors.black,
                      ],
                      stops: [0, 0.18, 0.82, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                child: Column(
                  children: [
                    // Colonne de 1000px centrée : boutons centrés en haut, tableaux
                    // dessous, chacun toujours au même emplacement.
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          // En bas, la même distance que celle entre le haut de
                          // l'écran et les boutons : le pied du tableau reste fixe.
                          padding: const EdgeInsets.fromLTRB(
                            12,
                            12,
                            12,
                            12 + _buttonsTop,
                          ),
                          child: SizedBox(
                            width: RowList.width,
                            child: Column(
                              children: [
                                const SizedBox(height: _buttonsTop),
                                SectionBar(
                                  child: SectionButtons(
                                    buttons: [
                                      for (final (label, _) in _sections) label,
                                    ],
                                    active: _active,
                                    onPressed: _showTable,
                                  ),
                                ),
                                const SizedBox(height: _tableGap),
                                Expanded(
                                  child: RowList(
                                    key: ObjectKey(_rows),
                                    rows: _rows,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Marque-pages contre le bord gauche de l'écran, centrés
            // verticalement.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  for (final (i, label) in _bookmarks.indexed)
                    Bookmark(
                      label: label,
                      active: i == _bookmark,
                      onPressed: () => setState(() => _bookmark = i),
                    ),
                ],
              ),
            ),
            // Encoche contre le bord du haut de l'écran : les nombres de
            // joueurs, d'événements, de parties et de jeux.
            Align(
              alignment: Alignment.topCenter,
              child: FutureBuilder<Counts>(
                future: _counts,
                builder: (context, snapshot) {
                  final c = snapshot.data;
                  return TopNotch(
                    items: [
                      (Icons.person, 'Joueurs', c?.players),
                      (Icons.confirmation_number, 'Événements', c?.events),
                      (Icons.flag, 'Parties', c?.games),
                      (Icons.casino, 'Jeux', c?.boardGames),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
