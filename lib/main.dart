import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/auth.dart';
import 'data/rows.dart';
import 'data/rpg_rows.dart';
import 'supabase_config.dart';
import 'widgets/login.dart';
import 'widgets/name_dialog.dart';
import 'widgets/party_dialog.dart';
import 'widgets/rpg_party_dialog.dart';
import 'widgets/row_list.dart';
import 'widgets/section_buttons.dart';
import 'widgets/title_banner.dart';
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

/// [prefix] : préfixe des tables (voir [fetchRows]).
Future<Counts> fetchCounts({String prefix = ''}) async {
  final db = Supabase.instance.client;
  final (players, events, games, boardGames) = await (
    db.from('${prefix}joueur').count(CountOption.exact),
    db.from('${prefix}evenement').count(CountOption.exact),
    db.from('${prefix}partie').count(CountOption.exact),
    db.from('${prefix}jeu').count(CountOption.exact),
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
      // En français (calendrier, textes des composants).
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        // Police de toute l'app : Cinzel, capitales romaines.
        fontFamily: 'Cinzel',
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

/// Données RPG : mêmes tables que le Wargame, préfixées par rpg_.
/// Parties, joueurs et jeux du JDR : construits à partir des parties de JDR
/// (jeu, MJ, joueurs) ; le reste comme au Wargame.
Future<RowTable> fetchRpgRows(String table) async =>
    await fetchRpgSessionRows(table) ?? await fetchRows(table, prefix: 'rpg_');
Future<Counts> fetchRpgCounts() => fetchCounts(prefix: 'rpg_');
Future<void> addRpgPlayer(String name) => addPlayer(name, prefix: 'rpg_');
Future<void> addRpgEvent(String name, DateTime? date) =>
    addEvent(name, date, prefix: 'rpg_');
Future<void> addRpgGame(String name) => addGame(name, prefix: 'rpg_');
Future<void> saveRpgSummary(int partyId, String? text) =>
    saveSummary(partyId, text, prefix: 'rpg_');
Future<String?> pickAndUploadRpgPhoto(int partyId) =>
    pickAndUploadPhoto(partyId, prefix: 'rpg_');

/// L'écran : le fond, les marque-pages Wargame et RPG à gauche, Discord en
/// haut à droite, et la page du marque-page choisi. Chaque page a ses
/// propres données et garde son état quand on change de marque-page.
class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    this.loadRows = fetchRows,
    this.loadCounts = fetchCounts,
    this.loadRpgRows = fetchRpgRows,
    this.loadRpgCounts = fetchRpgCounts,
    this.auth = const SupabaseAuth(),
    this.savePlayer = addPlayer,
    this.saveRpgPlayer = addRpgPlayer,
    this.saveEvent = addEvent,
    this.saveRpgEvent = addRpgEvent,
    this.saveGame = addGame,
    this.saveRpgGame = addRpgGame,
    this.saveParty = addParty,
    this.loadPartyOptions = fetchPartyOptions,
    this.saveRpgParty = addRpgParty,
    this.loadRpgPartyOptions = fetchRpgPartyOptions,
    this.writeSummary = saveSummary,
    this.writeEventType = saveEventType,
    this.writeRpgSummary = saveRpgSummary,
    this.uploadPhoto = pickAndUploadPhoto,
    this.uploadRpgPhoto = pickAndUploadRpgPhoto,
    this.rpgGuests = (
      players: fetchRpgPlayers,
      add: addRpgGuest,
      remove: removeRpgGuest,
    ),
  });

  /// Modification des joueurs d'une partie de JDR (backoffice).
  final GuestEditor rpgGuests;

  /// Choix du type d'un événement Wargame (backoffice).
  final Future<void> Function(int eventId, EventType type) writeEventType;

  /// Ajout d'une photo à une partie (backoffice), au Wargame et au RPG.
  final Future<String?> Function(int partyId) uploadPhoto;
  final Future<String?> Function(int partyId) uploadRpgPhoto;

  /// Enregistrement du résumé d'une partie (backoffice), au Wargame et au
  /// RPG.
  final Future<void> Function(int partyId, String? text) writeSummary;
  final Future<void> Function(int partyId, String? text) writeRpgSummary;

  /// Ajout d'une partie de JDR (backoffice) : l'enregistrement et les
  /// choix proposés.
  final Future<void> Function(NewRpgParty party) saveRpgParty;
  final Future<RpgPartyOptions> Function() loadRpgPartyOptions;

  /// Ajout d'une partie (backoffice), au Wargame seulement : l'enregistrement
  /// et les joueurs et jeux proposés.
  final Future<void> Function(NewParty party) saveParty;
  final Future<PartyOptions> Function() loadPartyOptions;

  /// Ajout d'un jeu (backoffice), au Wargame et au RPG.
  final Future<void> Function(String name) saveGame;
  final Future<void> Function(String name) saveRpgGame;

  /// Ajout d'un joueur (backoffice), au Wargame et au RPG.
  final Future<void> Function(String name) savePlayer;
  final Future<void> Function(String name) saveRpgPlayer;

  /// Ajout d'un événement (backoffice), au Wargame et au RPG.
  final Future<void> Function(String name, DateTime? date) saveEvent;
  final Future<void> Function(String name, DateTime? date) saveRpgEvent;

  /// Connexion au backoffice.
  final AppAuth auth;

  /// Données de la page Wargame.
  final Future<RowTable> Function(String table) loadRows;
  final Future<Counts> Function() loadCounts;

  /// Données de la page RPG.
  final Future<RowTable> Function(String table) loadRpgRows;
  final Future<Counts> Function() loadRpgCounts;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  /// Marque-pages du bord gauche de l'écran, et celui qui est actif.
  static const _bookmarks = [
    ('Wargame', AccentStyle.wargame, 'assets/icons/wargame.svg'),
    ('RPG', AccentStyle.rpg, 'assets/icons/rpg.svg'),
  ];
  int _bookmark = 0;

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
            // La page du marque-page choisi ; l'autre reste en mémoire.
            Positioned.fill(
              child: IndexedStack(
                index: _bookmark,
                children: [
                  AccentScope(
                    style: AccentStyle.wargame,
                    child: GamePage(
                      loadRows: widget.loadRows,
                      loadCounts: widget.loadCounts,
                      auth: widget.auth,
                      addPlayer: widget.savePlayer,
                      addEvent: widget.saveEvent,
                      addGame: widget.saveGame,
                      addParty: widget.saveParty,
                      loadPartyOptions: widget.loadPartyOptions,
                      saveSummary: widget.writeSummary,
                      addPhoto: widget.uploadPhoto,
                      saveEventType: widget.writeEventType,
                    ),
                  ),
                  // RPG : accentuation bronze.
                  AccentScope(
                    style: AccentStyle.rpg,
                    child: GamePage(
                      loadRows: widget.loadRpgRows,
                      loadCounts: widget.loadRpgCounts,
                      auth: widget.auth,
                      addPlayer: widget.saveRpgPlayer,
                      addEvent: widget.saveRpgEvent,
                      addGame: widget.saveRpgGame,
                      addRpgParty: widget.saveRpgParty,
                      loadRpgPartyOptions: widget.loadRpgPartyOptions,
                      saveSummary: widget.writeRpgSummary,
                      addPhoto: widget.uploadRpgPhoto,
                      guestEditor: widget.rpgGuests,
                    ),
                  ),
                ],
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
                  for (final (i, (label, accent, icon)) in _bookmarks.indexed)
                    Bookmark(
                      label: label,
                      accent: accent,
                      icon: icon,
                      active: i == _bookmark,
                      onPressed: () => setState(() => _bookmark = i),
                    ),
                ],
              ),
            ),
            // En bas à gauche : le lien de connexion au backoffice, aux
            // couleurs de la page affichée.
            Positioned(
              left: 12,
              bottom: 12,
              child: AccentScope(
                style: _bookmarks[_bookmark].$2,
                child: LoginLink(auth: widget.auth),
              ),
            ),
            // En haut à gauche, collée au bord du haut : la bannière du
            // site, aux couleurs de la page affichée.
            Positioned(
              top: 0,
              left: 24,
              child: AccentScope(
                style: _bookmarks[_bookmark].$2,
                child: const TitleBanner(),
              ),
            ),
            // En haut à droite, à l'écart des bords : Discord, puis Facebook
            // et Instagram dessous, de même largeur, aux couleurs de la page
            // affichée.
            Positioned(
              top: 12,
              right: 12,
              child: AccentScope(
                style: _bookmarks[_bookmark].$2,
                child: const IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [
                      _SocialPlate(Icon(Icons.discord, size: 18), 'Discord'),
                      _SocialPlate(Icon(Icons.facebook, size: 18), 'Facebook'),
                      _SocialPlate(
                        FaIcon(FontAwesomeIcons.instagram, size: 18),
                        'Instagram',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plaque d'un réseau social : son icône et son nom.
class _SocialPlate extends StatelessWidget {
  const _SocialPlate(this.icon, this.label);

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Plate(
      child: Row(
        spacing: 8,
        children: [
          SizedBox(width: 18, child: Center(child: icon)),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

/// Une page (Wargame ou RPG) : l'encoche des nombres en haut, la barre des
/// sections et les deux cartes, avec les données de [loadRows] et
/// [loadCounts].
class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    required this.loadRows,
    required this.loadCounts,
    required this.auth,
    required this.addPlayer,
    required this.addEvent,
    required this.addGame,
    required this.saveSummary,
    required this.addPhoto,
    this.guestEditor,
    this.addParty,
    this.loadPartyOptions,
    this.addRpgParty,
    this.loadRpgPartyOptions,
    this.saveEventType,
  });

  /// Choix du type d'un événement ; null : pas sur cette page (RPG).
  final Future<void> Function(int eventId, EventType type)? saveEventType;

  /// Ajout d'une partie de JDR et ses choix ; null : pas sur cette page.
  final Future<void> Function(NewRpgParty party)? addRpgParty;
  final Future<RpgPartyOptions> Function()? loadRpgPartyOptions;

  /// Ajout d'une partie et ses choix (joueurs, jeux) ; null : pas d'ajout
  /// de partie sur cette page.
  final Future<void> Function(NewParty party)? addParty;
  final Future<PartyOptions> Function()? loadPartyOptions;

  /// Ajout d'un jeu dans les données de la page.
  final Future<void> Function(String name) addGame;

  /// Enregistrement du résumé d'une partie de la page.
  final Future<void> Function(int partyId, String? text) saveSummary;

  /// Ajout d'une photo à une partie de la page.
  final Future<String?> Function(int partyId) addPhoto;

  /// Modification des joueurs d'une partie (JDR) ; null : pas sur cette page.
  final GuestEditor? guestEditor;

  /// Ajout d'un événement dans les données de la page.
  final Future<void> Function(String name, DateTime? date) addEvent;

  final Future<RowTable> Function(String table) loadRows;

  /// Connexion : une fois connecté, la liste des joueurs a un bouton « + ».
  final AppAuth auth;

  /// Ajout d'un joueur dans les données de la page.
  final Future<void> Function(String name) addPlayer;

  /// Nombres affichés dans l'encoche du haut de l'écran.
  final Future<Counts> Function() loadCounts;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
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

  late Future<Counts> _counts = widget.loadCounts();

  late final Stream<bool> _signedIn = widget.auth.signedIn;

  /// Bouton « + » de la section affichée : joueurs et jeux (nom), événements
  /// (nom et date), parties (Wargame ou JDR selon la page).
  VoidCallback? get _adder => switch (_active) {
    0 => () => _add(
      title: 'Nouveau joueur',
      save: (name, _) => widget.addPlayer(name),
    ),
    1 => () => _add(
      title: 'Nouvel événement',
      askDate: true,
      save: widget.addEvent,
    ),
    2 when widget.addParty != null => _addParty,
    2 when widget.addRpgParty != null => _addRpgParty,
    3 => () => _add(
      title: 'Nouveau jeu',
      save: (name, _) => widget.addGame(name),
    ),
    _ => null,
  };

  /// Demande la partie, l'enregistre, puis recharge la liste et les nombres.
  Future<void> _addParty() => showDialog<void>(
    context: context,
    builder: (_) => AccentScope(
      style: AccentStyle.of(context),
      child: PartyDialog(
        options: widget.loadPartyOptions!(),
        onSubmit: (party) async {
          await widget.addParty!(party);
          _reload();
        },
      ),
    ),
  );

  /// Demande la partie de JDR, l'enregistre, puis recharge.
  Future<void> _addRpgParty() => showDialog<void>(
    context: context,
    builder: (_) => AccentScope(
      style: AccentStyle.of(context),
      child: RpgPartyDialog(
        options: widget.loadRpgPartyOptions!(),
        onSubmit: (party) async {
          await widget.addRpgParty!(party);
          _reload();
        },
      ),
    ),
  );

  /// Recharge la liste affichée et les nombres de l'encoche.
  void _reload() {
    if (!mounted) return;
    setState(() {
      _rows = widget.loadRows(_sections[_active].$2);
      _counts = widget.loadCounts();
    });
  }

  /// Demande le nom (et la date), enregistre, puis recharge la liste et les
  /// nombres.
  Future<void> _add({
    required String title,
    required Future<void> Function(String name, DateTime? date) save,
    bool askDate = false,
  }) => showDialog<void>(
    context: context,
    builder: (_) => AccentScope(
      style: AccentStyle.of(context),
      child: NameDialog(
        title: title,
        label: 'Nom',
        askDate: askDate,
        onSubmit: (name, date) async {
          await save(name, date);
          _reload();
        },
      ),
    ),
  );

  /// Section affichée, dont le bouton est actif.
  int _active = _startSection;

  /// Lignes de la table affichée.
  late Future<RowTable> _rows = widget.loadRows(_sections[_startSection].$2);

  /// Ligne à sélectionner à l'arrivée sur la section (id), après un clic
  /// dans le détail d'un autre onglet.
  int? _selectId;

  void _showTable(int index) {
    final rows = widget.loadRows(_sections[index].$2);
    setState(() {
      _active = index;
      _rows = rows;
      _selectId = null;
    });
  }

  /// Va à l'élément [id] de la section de [table] (« joueur », « jeu »,
  /// « partie »), et le sélectionne.
  void _navigate(String table, int id) {
    final index = _sections.indexWhere((s) => s.$2 == table);
    if (index < 0) return;
    final rows = widget.loadRows(table);
    setState(() {
      _active = index;
      _rows = rows;
      _selectId = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: SafeArea(
            // Colonne centrée (RowList.width) : boutons centrés en haut, tableaux
            // dessous, chacun toujours au même emplacement.
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
                          buttons: [for (final (label, _) in _sections) label],
                          active: _active,
                          onPressed: _showTable,
                        ),
                      ),
                      const SizedBox(height: _tableGap),
                      Expanded(
                        // Connecté : bouton « + » (voir [_adder]).
                        child: StreamBuilder<bool>(
                          stream: _signedIn,
                          initialData: false,
                          builder: (context, snapshot) {
                            final signedIn =
                                !snapshot.hasError && (snapshot.data ?? false);
                            return RowList(
                              key: ObjectKey(_rows),
                              rows: _rows,
                              // Un clic sur un jeu ou une partie du détail y
                              // mène.
                              onNavigate: _navigate,
                              selectId: _selectId,
                              onAdd: signedIn ? _adder : null,
                              // Connecté : résumé des parties modifiable.
                              onEditSummary: signedIn
                                  ? widget.saveSummary
                                  : null,
                              // Connecté : ajout de photos aux parties.
                              onAddPhoto: signedIn ? widget.addPhoto : null,
                              // Connecté : joueurs des parties de JDR.
                              guestEditor: signedIn ? widget.guestEditor : null,
                              // Connecté : type des événements Wargame.
                              onSetEventType: signedIn
                                  ? widget.saveEventType
                                  : null,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
    );
  }
}
