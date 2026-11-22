import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/rows.dart';
import 'supabase_config.dart';
import 'widgets/row_list.dart';
import 'widgets/section_buttons.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const MyApp());
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
          brightness: Brightness.light,
        ),
        // Fond gris très clair, avec une pointe de bleu.
        scaffoldBackgroundColor: const Color(0xFFE9ECF2),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, this.loadRows = fetchRows});

  final Future<RowTable> Function(String table) loadRows;

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
                            child: RowList(key: ObjectKey(_rows), rows: _rows),
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
    );
  }
}
