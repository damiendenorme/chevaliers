import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/bracket.dart';
import '../data/championship.dart';
import '../data/rows.dart';
import '../data/rpg_rows.dart';
import 'name_dialog.dart';
import 'top_bar.dart';

/// Liste des lignes d'une table à gauche, détail de la ligne choisie à
/// droite, chacun dans sa carte, au style de la barre de menu.
///
/// Remplit toute la zone qu'on lui donne (voir [width], la largeur prévue
/// pour tous les tableaux) : son pied reste donc fixe quel que soit le nombre
/// de lignes, et ce sont la liste et le détail qui défilent à l'intérieur.
/// Gère aussi le chargement, l'erreur et le cas vide, dans la carte de la
/// liste.
/// Backoffice d'un événement Wargame : la liste de tous les joueurs,
/// l'inscription et le retrait d'un joueur, et l'ajout d'une partie entre
/// ses joueurs (id de l'événement, joueurs proposés).
typedef EventEditor = ({
  Future<List<(int, String)>> Function() players,
  Future<void> Function(int eventId, int playerId) add,
  Future<void> Function(int eventId, int playerId) remove,
  void Function(int eventId, int gameId, List<(int, String)> players) addParty,
  Future<void> Function(int eventId, int gameId) setGame,
  Future<void> Function(int eventId, int position, int side, int playerId)
  setBracketPlayer,
  Future<void> Function(
    int eventId,
    int gameId,
    int round,
    int position,
    PartyScore result,
  )
  playMatch,
  Future<void> Function(
    int eventId, {
    bool? returnLeg,
    Playoffs? playoffs,
    ChampionshipPoints? points,
    int? swissRounds,
    int? groupSize,
  })
  setChampionship,
  Future<void> Function(
    int eventId,
    int gameId,
    PartyScore result, {
    int? round,
  })
  playFixture,
});

class RowList extends StatelessWidget {
  const RowList({
    super.key,
    required this.rows,
    this.onAdd,
    this.onEditSummary,
    this.onAddPhoto,
    this.guestEditor,
    this.onNavigate,
    this.selectId,
    this.onSetEventType,
    this.onSetEventRounds,
    this.eventEditor,
    this.onAddEventSession,
  });

  /// Si non nul : le nombre de tours d'une élimination se choisit
  /// (backoffice).
  final Future<void> Function(int eventId, EliminationRound rounds)?
  onSetEventRounds;

  /// Si non nul : un bouton ajoute une partie de JDR à l'événement affiché
  /// (backoffice), avec son id.
  final ValueChanged<int>? onAddEventSession;

  /// Si non nul : les joueurs et les parties d'un événement s'ajoutent
  /// (backoffice).
  final EventEditor? eventEditor;

  /// Si non nul : le type d'un événement se choisit (backoffice), avec l'id
  /// de l'événement et le type choisi.
  final Future<void> Function(int eventId, EventType type)? onSetEventType;

  /// Si non nul : les joueurs d'une partie de JDR se retirent et s'ajoutent
  /// (backoffice).
  final GuestEditor? guestEditor;

  /// Si non nul : un clic sur un jeu ou une partie du détail y mène (table,
  /// id).
  final void Function(String table, int id)? onNavigate;

  /// Id de la ligne à sélectionner à l'arrivée.
  final int? selectId;

  /// Si non nul : ajout d'une photo à une partie (backoffice), avec l'id de
  /// la partie ; renvoie l'URL de la photo, ou null si rien n'a été choisi.
  final Future<String?> Function(int partyId)? onAddPhoto;

  /// Si non nul : le résumé d'une partie est modifiable (backoffice), avec
  /// l'id de la partie et le nouveau texte (null : effacé).
  final Future<void> Function(int partyId, String? text)? onEditSummary;

  static const double width = 1100;

  /// Largeur de la carte de la liste, à gauche.
  static const double listWidth = 400;

  /// Écart entre la carte de la liste et celle du détail.
  static const double gap = 12;

  final Future<RowTable> rows;

  /// Si non nul : un bouton « + » en bas à droite de la carte de la liste,
  /// pour ajouter un élément (backoffice).
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(child: _content()),
          if (onAdd case final add?)
            Positioned(
              left: listWidth - 12 - AddButton.size,
              bottom: 12,
              child: AddButton(onPressed: add),
            ),
        ],
      ),
    );
  }

  Widget _content() {
    return FutureBuilder<RowTable>(
      future: rows,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _Cards(
            master: _Message('Impossible de charger les données.'),
          );
        }
        if (!snapshot.hasData) {
          // Chargement : spinner au centre de la carte.
          return const _Cards(
            master: Center(
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final table = snapshot.data!;
        if (table.rows.isEmpty) {
          return const _Cards(master: _Message('Aucune ligne.'));
        }
        return _MasterDetail(
          table,
          onEditSummary: onEditSummary,
          onAddPhoto: onAddPhoto,
          guestEditor: guestEditor,
          onNavigate: onNavigate,
          selectId: selectId,
          onSetEventType: onSetEventType,
          onSetEventRounds: onSetEventRounds,
          eventEditor: eventEditor,
          onAddEventSession: onAddEventSession,
        );
      },
    );
  }
}

/// Bouton rond « + » (ou une autre [icon]), au fond texturé des éléments
/// actifs, avec la bordure des éléments choisis et une ombre.
class AddButton extends StatelessWidget {
  const AddButton({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.label = 'Ajouter',
  });

  static const double size = 36;

  final VoidCallback onPressed;

  /// Icône et nom (pour les lecteurs d'écran) du bouton.
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = AccentStyle.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: lightShadow,
        ),
        child: Material(
          shape: CircleBorder(side: BorderSide(color: accent.border)),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: accent.texture,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox.square(
                dimension: size,
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Les deux cartes côte à côte : la liste à gauche, le détail à droite.
class _Cards extends StatelessWidget {
  const _Cards({required this.master, this.detail});

  final Widget master;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    // Dans chaque carte, une barre de défilement toujours visible quand le
    // contenu dépasse, de la couleur des bordures de la page.
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(true),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        crossAxisMargin: BevelEdge.width + 2,
        mainAxisMargin: BevelEdge.width + 2,
        thumbColor: WidgetStatePropertyAll(
          AccentStyle.of(context).border.withValues(alpha: 0.7),
        ),
      ),
      child: _row(),
    );
  }

  Widget _row() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RowList.gap,
      children: [
        // Carte étroite : son image garde ses proportions, sans être étirée.
        SizedBox(
          width: RowList.listWidth,
          child: CardSurface(
            master,
            fit: BoxFit.cover,
            padding: EdgeInsets.zero,
          ),
        ),
        Expanded(
          child: CardSurface(
            detail ?? const SizedBox.shrink(),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

const _text = TextStyle(fontSize: 14);

/// Ombre portée interne en haut d'un élément choisi de la liste : il paraît
/// légèrement en creux.
const _insetShadow = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0x4D000000), Color(0x00000000)],
  stops: [0, 0.3],
);

/// Largeur des colonnes de scores ELO (4 chiffres), alignés à droite.
const double _scoreWidth = 44;

/// Largeur de la colonne des ids (bannières), tout à droite de la liste.
const double _idColumnWidth = 34;

/// Marges des éléments de liste : 1px de hauteur de plus qu'au départ.
const _cellPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 4.5);

class _MasterDetail extends StatefulWidget {
  const _MasterDetail(
    this.table, {
    this.onEditSummary,
    this.onAddPhoto,
    this.guestEditor,
    this.onNavigate,
    this.selectId,
    this.onSetEventType,
    this.onSetEventRounds,
    this.eventEditor,
    this.onAddEventSession,
  });

  final RowTable table;

  /// Connecté : choix du nombre de tours des éliminations.
  final Future<void> Function(int eventId, EliminationRound rounds)?
  onSetEventRounds;

  /// Connecté (RPG) : ajout d'une partie à un événement.
  final ValueChanged<int>? onAddEventSession;

  /// Connecté : joueurs et parties des événements Wargame.
  final EventEditor? eventEditor;

  /// Connecté : choix du type des événements.
  final Future<void> Function(int eventId, EventType type)? onSetEventType;

  /// Aller à un élément d'un autre onglet (table, id).
  final void Function(String table, int id)? onNavigate;

  /// Id de la ligne à sélectionner à l'arrivée (voir [RowTable.rowIds]).
  final int? selectId;

  /// Connecté : modification des joueurs des parties de JDR.
  final GuestEditor? guestEditor;
  final Future<void> Function(int partyId, String? text)? onEditSummary;
  final Future<String?> Function(int partyId)? onAddPhoto;

  @override
  State<_MasterDetail> createState() => _MasterDetailState();
}

/// Colonne de tri de la liste.
enum _SortBy { name, score, id }

class _MasterDetailState extends State<_MasterDetail> {
  /// Ligne affichée à droite, ou null tant qu'aucune n'est choisie. À
  /// l'arrivée depuis un autre onglet, celle de [_MasterDetail.selectId].
  late int? _selected = switch (widget.selectId) {
    final id? => switch (widget.table.rowIds?.indexOf(id)) {
      final i? when i >= 0 => i,
      _ => null,
    },
    null => null,
  };

  /// Résumés modifiés depuis le chargement, par id de partie : affichés sans
  /// recharger la liste (la sélection reste).
  final _editedSummaries = <int, String?>{};

  /// Types d'événements choisis depuis le chargement, par id d'événement :
  /// affichés sans recharger la liste.
  final _editedEventTypes = <int, EventType>{};

  /// Nombres de tours choisis depuis le chargement, par id d'événement.
  final _editedEventRounds = <int, EliminationRound>{};

  /// Photos ajoutées depuis le chargement, par id de partie : affichées sans
  /// recharger la liste.
  final _addedPhotos = <int, List<String>>{};

  /// MJ et joueurs des parties de JDR modifiés depuis le chargement, par id
  /// de partie : affichés sans recharger la liste.
  final _editedGuests = <int, (List<(int, String)>, List<(int, String)>)>{};

  /// Tableau de l'événement [eventId]. Connecté : un clic sur une case
  /// vide du premier tour y place un joueur inscrit ; un clic sur les
  /// scores d'un match prêt (deux joueurs, jeu de l'événement choisi) les
  /// fait saisir, et le match devient une partie.
  ///
  /// Sans [pickable] (playoffs d'un championnat), les joueurs ne se
  /// choisissent pas : ce sont les premiers du classement.
  Widget _eventBracket(
    int eventId,
    List<List<BracketMatch>> bracket, {
    bool pickable = true,
    EdgeInsets padding = const EdgeInsets.only(top: 40, bottom: 16),
  }) {
    final editor = widget.eventEditor;
    final game = widget.table.eventGame(_selected!)?.$1;
    final registered = <(int, String)>[
      for (final p in widget.table.eventDetail(_selected!)?.players ?? const [])
        (p.id, p.name),
    ];
    final placed = {
      for (final m in bracket.first) ...[?m.player1?.$1, ?m.player2?.$1],
    };
    // Bien détaché du jeu de l'événement, au-dessus.
    return Padding(
      padding: padding,
      child: _Bracket(
        bracket,
        onPick: editor == null || !pickable
            ? null
            : (position, side) async {
                final chosen = await showDialog<(int, String)>(
                  context: context,
                  builder: (_) => AccentScope(
                    style: AccentStyle.of(context),
                    child: _PlayerPicker(
                      title: 'Choisir un joueur',
                      players: Future.value(
                        registered..sort((a, b) => compareNames(a.$2, b.$2)),
                      ),
                      exclude: placed,
                    ),
                  ),
                );
                if (chosen != null) {
                  await editor.setBracketPlayer(
                    eventId,
                    position,
                    side,
                    chosen.$1,
                  );
                }
              },
        onPlay: (editor == null || game == null)
            ? null
            : (round, position, match) async {
                final scores = await showDialog<(int, int)>(
                  context: context,
                  builder: (_) => AccentScope(
                    style: AccentStyle.of(context),
                    child: _ScoreDialog(match.player1!.$2, match.player2!.$2),
                  ),
                );
                if (scores == null) return;
                await editor.playMatch(eventId, game, round, position, (
                  player1: match.player1!.$1,
                  player2: match.player2!.$1,
                  score1: scores.$1,
                  score2: scores.$2,
                ));
              },
      ),
    );
  }

  /// Type de l'événement choisi (type choisi depuis le chargement
  /// compris).
  EventType? _eventType() => switch (widget.table.eventId(_selected!)) {
    final id? => _editedEventTypes[id] ?? widget.table.eventType(_selected!),
    null => null,
  };

  /// L'événement choisi a son propre classement de joueurs (championnat,
  /// suisse) : pas de liste des joueurs à part.
  bool _hasStandings() =>
      _eventType() == EventType.championnat || _eventType() == EventType.suisse;

  /// Réglages du championnat de l'événement [eventId] : aller simple ou
  /// aller-retour, playoffs et barème, chacun avec son bouton (connecté).
  List<Widget> _championshipSettings(int eventId, Championship c) {
    final editor = widget.eventEditor;
    return [
      _ChoiceLine<bool>(
        value: c.returnLeg,
        options: const [(false, 'Aller simple'), (true, 'Aller-retour')],
        empty: 'Aucune formule',
        tooltip: 'Choisir aller ou aller-retour',
        onChoose: switch (editor) {
          final editor? => (v) => editor.setChampionship(eventId, returnLeg: v),
          null => null,
        },
      ),
      _ChoiceLine<Playoffs>(
        value: c.playoffs,
        options: [for (final p in Playoffs.values) (p, p.label)],
        empty: 'Playoffs non choisis',
        tooltip: 'Choisir les playoffs',
        onChoose: switch (editor) {
          final editor? => (v) => editor.setChampionship(eventId, playoffs: v),
          null => null,
        },
      ),
      _PointsLine(
        c.points,
        onChoose: switch (editor) {
          final editor? => (v) => editor.setChampionship(eventId, points: v),
          null => null,
        },
      ),
    ];
  }

  /// Titre d'une partie du détail d'un tournoi : « Classement »…
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: _text.copyWith(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  /// Classement [standings] de l'événement [eventId], sous son titre
  /// [heading] ; avec [leadLabel], sa valeur en premier sous ce nom
  /// (Gloire, ELO). Connecté : l'inscription et le retrait des joueurs.
  Widget _eventStandings(
    int eventId,
    List<Standing> standings,
    String heading, {
    String? leadLabel,
  }) {
    final editor = widget.eventEditor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (standings.isNotEmpty) _heading(heading),
        _Standings(
          key: ValueKey(('classement', _selected)),
          standings,
          leadLabel: leadLabel,
          onTap: switch (widget.onNavigate) {
            final go? => (id) => go('joueur', id),
            null => null,
          },
          // Connecté : inscrire ou retirer des joueurs ; pas ceux qui ont
          // déjà joué.
          locked: widget.table.eventPlayedBy(_selected!),
          onRemove: switch (editor) {
            final editor? => (player) => editor.remove(eventId, player),
            null => null,
          },
          onAdd: switch (editor) {
            final editor? => () async {
              final chosen = await showDialog<(int, String)>(
                context: context,
                builder: (_) => AccentScope(
                  style: AccentStyle.of(context),
                  child: _PlayerPicker(
                    title: 'Ajouter un joueur',
                    players: editor.players(),
                    exclude: {for (final s in standings) s.player.$1},
                  ),
                ),
              );
              if (chosen != null) await editor.add(eventId, chosen.$1);
            },
            null => null,
          },
        ),
      ],
    );
  }

  /// Saisie des scores d'une rencontre de l'événement [eventId] (du tour
  /// [round] d'un suisse) : connecté, une fois le jeu choisi ; le nul est
  /// permis. La rencontre devient une partie.
  Future<void> Function(Fixture fixture)? _fixturePlayer(
    int eventId, {
    int? round,
  }) {
    final editor = widget.eventEditor;
    final game = widget.table.eventGame(_selected!)?.$1;
    if (editor == null || game == null) return null;
    return (f) async {
      final scores = await showDialog<(int, int)>(
        context: context,
        builder: (_) => AccentScope(
          style: AccentStyle.of(context),
          child: _ScoreDialog(f.player1.$2, f.player2.$2, allowDraw: true),
        ),
      );
      if (scores == null) return;
      await editor.playFixture(eventId, game, (
        player1: f.player1.$1,
        player2: f.player2.$1,
        score1: scores.$1,
        score2: scores.$2,
      ), round: round);
    };
  }

  /// Un clic sur une partie y mène (son id).
  ValueChanged<int>? _toParty() => switch (widget.onNavigate) {
    final go? => (id) => go('partie', id),
    null => null,
  };

  /// Playoffs de l'événement [eventId] : leur tableau, dont les joueurs
  /// viennent du classement.
  Widget _playoffs(int eventId, List<List<BracketMatch>> bracket) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('Playoffs'),
      _eventBracket(
        eventId,
        bracket,
        pickable: false,
        padding: const EdgeInsets.only(top: 8, bottom: 16),
      ),
    ],
  );

  /// Championnat de l'événement [eventId] : son classement, son calendrier
  /// (connecté, une fois le jeu choisi : un clic sur une rencontre fait
  /// saisir ses scores, et elle devient une partie), puis ses playoffs.
  Widget _championshipBoard(int eventId, Championship c) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 24,
        children: [
          if (c.standings.isNotEmpty || widget.eventEditor != null)
            _eventStandings(
              eventId,
              c.standings,
              'Classement',
              leadLabel: c.points.glory ? 'Gloire' : null,
            ),
          if (c.fixtures.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _heading('Calendrier'),
                _Calendar(
                  c.fixtures,
                  onPlay: _fixturePlayer(eventId),
                  onOpen: _toParty(),
                ),
              ],
            ),
          if (c.playoffBracket case final bracket?) _playoffs(eventId, bracket),
        ],
      ),
    );
  }

  /// Réglages du suisse de l'événement [eventId] : nombre de tours, joueurs
  /// par groupe et playoffs, chacun avec son bouton (connecté).
  List<Widget> _swissSettings(int eventId, Swiss sw) {
    final editor = widget.eventEditor;
    return [
      _ChoiceLine<int>(
        value: sw.roundCount,
        options: [
          for (var n = 1; n <= 10; n++) (n, n == 1 ? '1 tour' : '$n tours'),
        ],
        empty: 'Aucun nombre de tours',
        tooltip: 'Choisir le nombre de tours',
        onChoose: switch (editor) {
          final editor? => (v) => editor.setChampionship(
            eventId,
            swissRounds: v,
          ),
          null => null,
        },
      ),
      _ChoiceLine<int>(
        value: sw.groupSize,
        options: [for (var n = 2; n <= 16; n++) (n, 'Groupes de $n joueurs')],
        empty: 'Aucune taille de groupe',
        tooltip: 'Choisir la taille des groupes',
        onChoose: switch (editor) {
          final editor? => (v) => editor.setChampionship(eventId, groupSize: v),
          null => null,
        },
      ),
      _ChoiceLine<Playoffs>(
        value: sw.playoffs,
        options: [for (final p in Playoffs.values) (p, p.label)],
        empty: 'Playoffs non choisis',
        tooltip: 'Choisir les playoffs',
        onChoose: switch (editor) {
          final editor? => (v) => editor.setChampionship(eventId, playoffs: v),
          null => null,
        },
      ),
    ];
  }

  /// Suisse de l'événement [eventId] : son classement général (final une
  /// fois fini), ses tours formés jusqu'ici, groupe par groupe (connecté,
  /// un clic sur une rencontre fait saisir ses scores), le tour suivant à
  /// venir, puis ses playoffs.
  Widget _swissBoard(int eventId, Swiss sw) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final remaining = switch (sw.roundCount) {
      final count? => count - sw.rounds.length,
      null => 0,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 24,
        children: [
          if (sw.standings.isNotEmpty || widget.eventEditor != null)
            _eventStandings(
              eventId,
              sw.standings,
              sw.finished ? 'Classement final' : 'Classement général',
              leadLabel: 'Gloire',
            ),
          for (final (r, groups) in sw.rounds.indexed)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _heading('Tour ${r + 1}'),
                for (final (g, fixtures) in groups.indexed) ...[
                  if (groups.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Groupe ${g + 1}',
                        textAlign: TextAlign.center,
                        style: _text.copyWith(fontSize: 12, color: muted),
                      ),
                    ),
                  _Calendar(
                    fixtures,
                    showDays: false,
                    onPlay: _fixturePlayer(eventId, round: r),
                    onOpen: _toParty(),
                  ),
                ],
              ],
            ),
          // Le tour suivant se forme une fois celui-ci joué.
          if (remaining > 0 && sw.rounds.isNotEmpty)
            Text(
              'Tour ${sw.rounds.length + 1} : formé à la fin du tour '
              '${sw.rounds.length}.',
              textAlign: TextAlign.center,
              style: _text.copyWith(color: muted),
            ),
          if (sw.playoffBracket case final bracket?)
            _playoffs(eventId, bracket),
        ],
      ),
    );
  }

  /// Détail d'une partie de JDR, avec la modification de ses joueurs si
  /// connecté.
  Widget _sessionDetail(SessionDetail s) {
    final id = widget.table.partyId(_selected!);
    final editor = widget.guestEditor;
    final edited = id == null ? null : _editedGuests[id];
    final (gms, guests) = edited ?? (s.gms, s.guests);
    final infos = [formatFullDate(s.date), ?s.scenario, ?s.event, ?s.place];
    // Un clic sur un MJ ou un joueur y mène.
    final toPlayer = switch (widget.onNavigate) {
      final go? => (int playerId) => go('joueur', playerId),
      null => null,
    };
    if (editor == null || id == null) {
      return _SessionDetail(
        infos: infos,
        gms: gms,
        guests: guests,
        onPlayerTap: toPlayer,
      );
    }
    List<(int, String)> sorted(List<(int, String)> list) =>
        list..sort((a, b) => compareNames(a.$2, b.$2));

    Future<void> add({required bool gm}) async {
      final chosen = await showDialog<(int, String)>(
        context: context,
        builder: (_) => AccentScope(
          style: AccentStyle.of(context),
          child: _PlayerPicker(
            title: gm ? 'Ajouter un MJ' : 'Ajouter un joueur',
            players: editor.players(),
            exclude: {
              for (final p in [...gms, ...guests]) p.$1,
            },
          ),
        ),
      );
      if (chosen == null) return;
      await editor.add(id, chosen.$1, gm: gm);
      if (mounted) {
        setState(
          () => _editedGuests[id] = gm
              ? (sorted([...gms, chosen]), guests)
              : (gms, sorted([...guests, chosen])),
        );
      }
    }

    return _SessionDetail(
      infos: infos,
      gms: gms,
      guests: guests,
      onPlayerTap: toPlayer,
      onRemove: (playerId) async {
        await editor.remove(id, playerId);
        if (mounted) {
          setState(
            () => _editedGuests[id] = (
              [
                for (final p in gms)
                  if (p.$1 != playerId) p,
              ],
              [
                for (final p in guests)
                  if (p.$1 != playerId) p,
              ],
            ),
          );
        }
      },
      onAddGm: () => add(gm: true),
      onAdd: () => add(gm: false),
    );
  }

  /// Valeur de tri de chaque ligne, à côté du nom : le score (joueurs), le
  /// nombre de joueurs (jeux) ou la date (événements).
  Comparable<Object>? _value(RowTable table, int i) =>
      table.globalScores != null
      ? table.globalScore(i)
      : table.badges != null
      ? table.badge(i)
      : table.date(i);

  /// Titre de la colonne de cette valeur, ou null : liste sans en-tête.
  String? get _valueLabel {
    final table = widget.table;
    if (table.globalScores != null) return 'Gloire';
    if (table.badges != null) return 'Joueurs';
    if (table.dates != null) return 'Date';
    return null;
  }

  bool get _sortable => _valueLabel != null;

  /// Tri de la liste au départ : les joueurs par score décroissant, les
  /// jeux par nom.
  late _SortBy _sortBy = widget.table.globalScores != null
      ? _SortBy.score
      : _SortBy.name;
  late bool _ascending = _sortBy == _SortBy.name;

  /// Cliquer sur la colonne déjà triée inverse le sens ; sur l'autre, trie
  /// par nom de A à Z, par id croissant, ou par valeur décroissante.
  void _sort(_SortBy by) {
    setState(() {
      _ascending = by == _sortBy ? !_ascending : by != _SortBy.score;
      _sortBy = by;
    });
  }

  /// Positions des lignes dans l'ordre affiché. Sans valeur, toujours en
  /// dernier.
  List<int> _order(RowTable table) {
    final order = [for (var i = 0; i < table.rows.length; i++) i];
    if (!_sortable) return order;
    final direction = _ascending ? 1 : -1;
    return order..sort((a, b) {
      if (_sortBy == _SortBy.id) {
        final byId = (table.id(a) ?? 0).compareTo(table.id(b) ?? 0);
        if (byId != 0) return direction * byId;
      }
      if (_sortBy == _SortBy.score) {
        final (sa, sb) = (_value(table, a), _value(table, b));
        if (sa == null || sb == null) {
          if (sa != sb) return sa == null ? 1 : -1;
        } else if (sa != sb) {
          return direction * sa.compareTo(sb as Object);
        }
      }
      return (_sortBy == _SortBy.name ? direction : 1) *
          compareNames(table.title(a), table.title(b));
    });
  }

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    const divider = BorderSide(color: dividerColor);

    // Trié par score (ou Gloire) : le rang de chacun au classement, du
    // meilleur (1) au moins bon, quel que soit le sens du tri ; à score égal,
    // par nom. Sans score : pas de rang.
    final Map<int, int>? ranks;
    if (_sortBy == _SortBy.score && table.globalScores != null) {
      final ranked =
          [
            for (var i = 0; i < table.rows.length; i++)
              if (table.globalScore(i) != null) i,
          ]..sort((a, b) {
            final byScore = table
                .globalScore(b)!
                .compareTo(table.globalScore(a)!);
            return byScore != 0
                ? byScore
                : compareNames(table.title(a), table.title(b));
          });
      ranks = {for (final (r, i) in ranked.indexed) i: r + 1};
    } else {
      ranks = null;
    }

    final list = SingleChildScrollView(
      // Sans en-tête, le premier élément est baissé de l'épaisseur du
      // bourrelet, comme l'en-tête : il paraît aussi haut que les autres.
      // L'écart de la carte est dans le défilement : la barre reste au bord.
      padding: EdgeInsets.fromLTRB(
        CardSurface.gutter,
        _sortable ? 0 : CardSurface.gutter + BevelEdge.width,
        CardSurface.gutter,
        CardSurface.gutter,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final i in _order(table))
            Material(
              // Transparente : le fond de la carte reste visible. Choisie :
              // le fond texturé doré.
              color: Colors.transparent,
              // Choisie : tout autour, une bordure grise un peu plus claire.
              shape: i == _selected
                  ? Border.all(color: AccentStyle.of(context).border)
                  : const Border(bottom: divider),
              child: Ink(
                decoration: i == _selected
                    ? AccentStyle.of(context).texture
                    : null,
                // Choisie : pas de survol, son fond reste visible. La clé
                // recrée l'encre au changement : un survol affiché disparaît.
                child: InkWell(
                  key: ValueKey(i == _selected),
                  onTap: () => setState(() => _selected = i),
                  // Survol bombé (voir [HoverBulge]), sauf si elle est
                  // choisie.
                  hoverColor: Colors.transparent,
                  child: HoverBulge(
                    enabled: i != _selected,
                    // Choisie : en creux, comme le libellé actif de la barre
                    // (ombre portée interne en haut).
                    child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: i == _selected
                          ? const BoxDecoration(gradient: _insetShadow)
                          : const BoxDecoration(),
                      child: Padding(
                        padding: _cellPadding,
                        child: _MasterLine(
                          table,
                          i,
                          rank: ranks?[i],
                          selected: i == _selected,
                          style: i == _selected
                              ? _text.copyWith(color: Colors.white)
                              : _text,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return _Cards(
      // Avec des scores : un en-tête fixe au-dessus de la liste, pour la
      // trier par nom ou par score.
      master: !_sortable
          ? list
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Baissé de l'épaisseur du bourrelet, avec la hauteur de
                // ligne de la liste : il paraît aussi haut que ses éléments.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CardSurface.gutter,
                    CardSurface.gutter,
                    CardSurface.gutter,
                    0,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(border: Border(bottom: divider)),
                    child: Padding(
                      padding: const EdgeInsets.only(top: BevelEdge.width),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SortHeader(
                              'Nom',
                              arrow: _sortBy == _SortBy.name
                                  ? _ascending
                                  : null,
                              onTap: () => _sort(_SortBy.name),
                              rowHeight: true,
                            ),
                          ),
                          // Sa droite collée à celle des valeurs ; flèche avant.
                          _SortHeader(
                            _valueLabel!,
                            arrow: _sortBy == _SortBy.score ? _ascending : null,
                            onTap: () => _sort(_SortBy.score),
                            rowHeight: true,
                            padding: EdgeInsets.fromLTRB(
                              12,
                              4,
                              table.ids != null ? 0 : 12,
                              4,
                            ),
                            arrowPlacement: _ArrowPlacement.before,
                          ),
                          // Colonne des ids (joueurs) : son titre au-dessus des
                          // bannières, tout à droite.
                          if (table.ids != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 8,
                                right: 12,
                              ),
                              child: SizedBox(
                                width: _idColumnWidth,
                                // Centré sur les bannières, même s'il est plus
                                // large que leur colonne.
                                child: Center(
                                  child: _SortHeader(
                                    'ID',
                                    arrow: _sortBy == _SortBy.id
                                        ? _ascending
                                        : null,
                                    onTap: () => _sort(_SortBy.id),
                                    rowHeight: true,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    arrowPlacement: _ArrowPlacement.centered,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(child: list),
              ],
            ),
      // Rien de choisi : une invitation, au centre de la carte du détail.
      detail: _selected == null
          ? Center(
              child: Text(
                'Sélectionnez un élément à gauche.',
                style: _text.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          // La zone de photos remplit le bas de la carte (son message, s'il
          // n'y a pas de photo, y est centré).
          // L'écart de la carte est dans le défilement : la barre reste au
          // bord.
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    CardSurface.gutter,
                    CardSurface.gutter,
                    CardSurface.gutter,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Banner(table.banner(_selected!)),
                        // Une partie : en grand, à la place de ses colonnes.
                        if (table.matchDetail(_selected!) case final m?)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            child: _MatchDetailLine(m, stacked: true),
                          )
                        else if (table.sessionDetail(_selected!) case final s?)
                          // Sa liste de joueurs occupe toute la largeur.
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: _sessionDetail(s),
                          )
                        else
                          _Detail(table.entries(_selected!)),
                        // Un événement Wargame : son type, et le bouton pour le
                        // choisir une fois connecté.
                        if (table.eventId(_selected!) case final id?)
                          _ChoiceLine<EventType>(
                            value:
                                _editedEventTypes[id] ??
                                table.eventType(_selected!),
                            options: [
                              for (final t in EventType.values) (t, t.label),
                            ],
                            empty: 'Aucun type',
                            tooltip: 'Choisir le type',
                            onChoose: switch (widget.onSetEventType) {
                              final set? => (type) async {
                                await set(id, type);
                                if (mounted) {
                                  setState(() => _editedEventTypes[id] = type);
                                }
                              },
                              null => null,
                            },
                          ),
                        // Élimination : son nombre de tours (premier tour),
                        // choisi de la même façon.
                        if (table.eventId(_selected!) case final id?
                            when (_editedEventTypes[id] ??
                                    table.eventType(_selected!)) ==
                                EventType.elimination)
                          _ChoiceLine<EliminationRound>(
                            value:
                                _editedEventRounds[id] ??
                                table.eventRound(_selected!),
                            options: [
                              for (final r in EliminationRound.values)
                                (r, r.label),
                            ],
                            empty: 'Aucun nombre de tours',
                            tooltip: 'Choisir le nombre de tours',
                            onChoose: switch (widget.onSetEventRounds) {
                              final set? => (rounds) async {
                                await set(id, rounds);
                                if (mounted) {
                                  setState(
                                    () => _editedEventRounds[id] = rounds,
                                  );
                                }
                              },
                              null => null,
                            },
                          ),
                        // Championnat : aller ou aller-retour, playoffs et
                        // barème, choisis de la même façon.
                        if ((
                              table.eventId(_selected!),
                              table.eventChampionship(_selected!),
                            )
                            case (final id?, final c?)
                            when (_editedEventTypes[id] ??
                                    table.eventType(_selected!)) ==
                                EventType.championnat)
                          ..._championshipSettings(id, c),
                        // Suisse : nombre de tours, taille des groupes et
                        // playoffs.
                        if ((
                              table.eventId(_selected!),
                              table.eventSwissOf(_selected!),
                            )
                            case (final id?, final sw?)
                            when _eventType() == EventType.suisse)
                          ..._swissSettings(id, sw),
                        // Puis son jeu, choisi de la même façon.
                        if (table.eventId(_selected!) case final id?)
                          _EventGameLine(
                            table.eventGame(_selected!)?.$2,
                            games: table.gameOptions,
                            onChoose: switch (widget.eventEditor) {
                              final editor? => (game) => editor.setGame(
                                id,
                                game,
                              ),
                              null => null,
                            },
                          ),
                        // Élimination dont le nombre de tours est choisi : son
                        // tableau.
                        if ((
                              table.eventId(_selected!),
                              table.eventBracket(_selected!),
                            )
                            case (final id?, final bracket?)
                            when (_editedEventTypes[id] ??
                                    table.eventType(_selected!)) ==
                                EventType.elimination)
                          _eventBracket(id, bracket),
                        // Championnat : classement, calendrier et playoffs.
                        if ((
                              table.eventId(_selected!),
                              table.eventChampionship(_selected!),
                            )
                            case (final id?, final c?)
                            when (_editedEventTypes[id] ??
                                    table.eventType(_selected!)) ==
                                EventType.championnat)
                          _championshipBoard(id, c),
                        // Suisse : classement, tours et playoffs.
                        if ((
                              table.eventId(_selected!),
                              table.eventSwissOf(_selected!),
                            )
                            case (final id?, final sw?)
                            when _eventType() == EventType.suisse)
                          _swissBoard(id, sw),
                        // Un événement : ceux qui y ont joué, triables. Pas
                        // pour un championnat : son classement les montre.
                        if (table.eventDetail(_selected!) case final e?
                            when !_hasStandings())
                          Padding(
                            // Puis, un peu plus bas, la liste de ses parties.
                            padding: const EdgeInsets.only(top: 16, bottom: 24),
                            child: _EventPlayers(
                              key: ValueKey(('joueurs', _selected)),
                              e.players,
                              // Connecté seulement : « Aucun joueur. ».
                              showEmpty:
                                  widget.eventEditor != null &&
                                  table.eventId(_selected!) != null,
                              // Connecté (Wargame) : inscrire ou retirer des
                              // joueurs ; pas ceux qui ont déjà joué.
                              locked: table.eventPlayedBy(_selected!),
                              onRemove: switch ((
                                widget.eventEditor,
                                table.eventId(_selected!),
                              )) {
                                (final editor?, final id?) => (
                                  player,
                                ) => editor.remove(id, player),
                                _ => null,
                              },
                              onAdd: switch ((
                                widget.eventEditor,
                                table.eventId(_selected!),
                              )) {
                                (final editor?, final id?) => () async {
                                  final chosen =
                                      await showDialog<(int, String)>(
                                        context: context,
                                        builder: (_) => AccentScope(
                                          style: AccentStyle.of(context),
                                          child: _PlayerPicker(
                                            title: 'Ajouter un joueur',
                                            players: editor.players(),
                                            exclude: {
                                              for (final p in e.players) p.id,
                                            },
                                          ),
                                        ),
                                      );
                                  if (chosen != null) {
                                    await editor.add(id, chosen.$1);
                                  }
                                },
                                _ => null,
                              },
                              // Un clic sur un joueur y mène.
                              onTap: switch (widget.onNavigate) {
                                final go? => (id) => go('joueur', id),
                                null => null,
                              },
                            ),
                          ),
                        _SessionLines(
                          table.sessionLinesOf(_selected!),
                          // Connecté (RPG) : sous les parties d'un événement,
                          // un bouton pour en ajouter une.
                          onAdd: switch ((
                            widget.onAddEventSession,
                            table.eventDetail(_selected!),
                            table.rowId(_selected!),
                          )) {
                            (final add?, _?, final id?) => () => add(id),
                            _ => null,
                          },
                          // Un clic sur une partie y mène (si on connaît son id).
                          onTap: switch ((
                            widget.onNavigate,
                            table.sessionLineIds?[_selected!],
                          )) {
                            (final go?, final ids?) => (i) => go(
                              'partie',
                              ids[i],
                            ),
                            _ => null,
                          },
                        ),
                        // Une clé par ligne : le tri repart de zéro à chaque
                        // changement de ligne.
                        _LineList(
                          key: ValueKey(_selected),
                          table.list(_selected!),
                          sortable: table.sortableLists,
                          ranked: table.rankedLists,
                          forms: table.listForm(_selected!),
                          // Un clic sur un élément (jeu, joueur) y mène.
                          onTap: switch ((
                            widget.onNavigate,
                            table.listIds?[_selected!],
                          )) {
                            (final go?, final ids?) => (i) => go(
                              table.listTable,
                              ids[i],
                            ),
                            _ => null,
                          },
                        ),
                        _MatchupList(
                          key: ValueKey(('parties', _selected)),
                          table.matchList(_selected!),
                          showGame: table.matchListShowsGame,
                          // Un clic sur une partie y mène.
                          onTap: switch ((
                            widget.onNavigate,
                            table.matchListIds?[_selected!],
                          )) {
                            (final go?, final ids?) => (i) => go(
                              'partie',
                              ids[i],
                            ),
                            _ => null,
                          },
                        ),
                        // Événement Wargame sans partie, connecté : « Aucune
                        // partie. ».
                        if (widget.eventEditor != null &&
                            table.eventId(_selected!) != null &&
                            table.matchList(_selected!).isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Aucune partie.',
                              textAlign: TextAlign.center,
                              style: _text.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        // Connecté (Wargame) : ajouter une partie à
                        // l'événement, entre ses joueurs.
                        // Seulement une fois le jeu de l'événement choisi.
                        if ((
                              widget.eventEditor,
                              table.eventId(_selected!),
                              table.eventDetail(_selected!),
                              table.eventGame(_selected!),
                            )
                            case (
                              final editor?,
                              final id?,
                              final e?,
                              (final game, _),
                            ))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: AddButton(
                                label: 'Ajouter une partie',
                                onPressed: () => editor.addParty(id, game, [
                                  for (final p in e.players) (p.id, p.name),
                                ]),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Entre les informations et les photos : le résumé.
                if (table.summaries != null)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CardSurface.gutter,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _Summary(
                        switch (table.partyId(_selected!)) {
                          final id? when _editedSummaries.containsKey(id) =>
                            _editedSummaries[id],
                          _ => table.summary(_selected!),
                        },
                        onEdit: switch ((
                          widget.onEditSummary,
                          table.partyId(_selected!),
                        )) {
                          (final edit?, final id?) => (text) async {
                            await edit(id, text);
                            if (mounted) {
                              setState(() => _editedSummaries[id] = text);
                            }
                          },
                          _ => null,
                        },
                      ),
                    ),
                  ),
                if (table.photosOf(_selected!) case final urls?)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      CardSurface.gutter,
                      0,
                      CardSurface.gutter,
                      CardSurface.gutter,
                    ),
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: _PhotoZone(
                        [...urls, ...?_addedPhotos[table.partyId(_selected!)]],
                        onAdd: switch ((
                          widget.onAddPhoto,
                          table.partyId(_selected!),
                        )) {
                          (final add?, final id?) => () async {
                            final url = await add(id);
                            if (url != null && mounted) {
                              setState(
                                () => (_addedPhotos[id] ??= []).add(url),
                              );
                            }
                          },
                          _ => null,
                        },
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(
                    child: SizedBox(height: CardSurface.gutter),
                  ),
              ],
            ),
    );
  }
}

/// Contenu d'une ligne de la liste : son libellé (avec pastille, ou forme et
/// score), ou pour une partie, voir [_MatchupLine].
class _MasterLine extends StatelessWidget {
  const _MasterLine(
    this.table,
    this.index, {
    required this.style,
    this.selected = false,
    this.rank,
  });

  final RowTable table;
  final int index;
  final TextStyle style;

  /// Rang au classement, affiché devant le nom (« 1. »), ou rien.
  final int? rank;

  /// Ligne choisie (fond texturé).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    Text text(String value, {TextStyle? style, TextAlign? align}) => Text(
      value,
      style: style ?? this.style,
      textAlign: align,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );

    final m = table.matchup(index);
    final badge = table.badge(index);
    if (m == null && badge != null) {
      return Row(
        spacing: 8,
        children: [
          Expanded(child: text(table.title(index))),
          _Badge(badge, style: style),
        ],
      );
    }
    final date = table.dates == null ? null : table.date(index);
    if (m == null && table.dates != null) {
      return Row(
        spacing: 8,
        children: [
          Expanded(child: text(table.title(index))),
          text(
            date == null
                ? '—'
                : table.fullDates
                ? formatFullDate(date)
                : formatMonth(date),
          ),
        ],
      );
    }
    final form = table.form(index);
    if (m == null && form != null) {
      final score = table.globalScore(index);
      return Row(
        spacing: 8,
        children: [
          Expanded(
            child: text(
              rank == null
                  ? table.title(index)
                  : '$rank. ${table.title(index)}',
            ),
          ),
          // Un peu à l'écart du score.
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _Form(form),
          ),
          // Largeur fixe : les scores restent alignés d'une ligne à l'autre.
          SizedBox(
            width: _scoreWidth,
            child: text(score?.toString() ?? '', align: TextAlign.right),
          ),
          // Tout à droite, la bannière de l'id.
          if (table.id(index) case final id?)
            SizedBox(
              width: _idColumnWidth,
              // Ligne choisie : bannière plus plate, pour se détacher de son
              // fond texturé.
              child: Center(child: _IdBanner(id, flat: selected)),
            ),
        ],
      );
    }
    if (m == null) return text(table.title(index));
    return _MatchupLine(m, style: style);
  }
}

/// Une partie sur une ligne : le joueur 1 à gauche, les scores au milieu et
/// le joueur 2 à droite. Le gagnant et son score sont en gras, le perdant et
/// son score grisés ; à égalité, aucun des deux.
class _MatchupLine extends StatelessWidget {
  const _MatchupLine(
    this.m, {
    required this.style,
    this.eloDelta1,
    this.hugScores = false,
    this.scoreSize,
    this.form1,
    this.form2,
  });

  /// Pastilles des dernières parties de chaque joueur, collées du côté
  /// extérieur de son nom (et de son évolution d'ELO). Rien si null.
  final List<Outcome>? form1;
  final List<Outcome>? form2;

  final Matchup m;
  final TextStyle style;

  /// Chaque nom collé à son score, au lieu d'être aux extrémités.
  final bool hugScores;

  /// Taille des scores (et du tiret), si elle diffère de celle de [style].
  final double? scoreSize;

  /// Évolution du ELO du joueur 1, affichée à gauche de son nom ; celle du
  /// joueur 2, l'opposée, à droite du sien. Rien si null.
  final double? eloDelta1;

  @override
  Widget build(BuildContext context) {
    Text text(String value, {TextStyle? style, TextAlign? align}) => Text(
      value,
      style: style ?? this.style,
      textAlign: align,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );

    final color = style.color ?? DefaultTextStyle.of(context).style.color!;
    final winner = style.copyWith(fontWeight: FontWeight.bold);
    final loser = style.copyWith(color: color.withValues(alpha: 0.45));
    final (style1, style2) = switch (m.score1.compareTo(m.score2)) {
      > 0 => (winner, loser),
      < 0 => (loser, winner),
      _ => (style, style),
    };

    // Les deux joueurs, puis les deux scores, ont la même largeur : le tiret
    // entre les scores reste au milieu.
    final d = eloDelta1;
    final size = scoreSize ?? style.fontSize ?? 14;
    TextStyle scored(TextStyle s) => s.copyWith(fontSize: size);
    // Largeur d'un score (2 chiffres), proportionnelle à sa taille.
    final scoreWidth = 20 * size / 14;
    return Row(
      // Noms collés aux scores : un peu plus d'écart.
      spacing: hugScores ? 16 : 8,
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: hugScores
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            spacing: 4,
            children: [
              // Pastilles un peu à l'écart (12px avec l'espacement).
              if (form1 case final f?)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Form(f),
                ),
              if (d != null) _EloDelta(d),
              Flexible(child: text(m.player1, style: style1)),
            ],
          ),
        ),
        SizedBox(
          width: scoreWidth,
          child: text(
            '${m.score1}',
            style: scored(style1),
            align: TextAlign.right,
          ),
        ),
        Text('–', style: scored(style)),
        SizedBox(
          width: scoreWidth,
          child: text('${m.score2}', style: scored(style2)),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: hugScores
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            spacing: 4,
            children: [
              Flexible(
                child: text(m.player2, style: style2, align: TextAlign.right),
              ),
              if (d != null) _EloDelta(-d),
              if (form2 case final f?)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _Form(f),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Place de la flèche de tri d'un titre de colonne : après lui, avant lui
/// (sa droite reste alignée sur celle des valeurs), ou dessinée à sa droite
/// sans prendre de place (il reste centré).
enum _ArrowPlacement { after, before, centered }

/// Titre de colonne cliquable, pour trier la liste. [arrow] : flèche vers le
/// haut (true) ou le bas (false) sur la colonne triée, rien sur l'autre.
class _SortHeader extends StatelessWidget {
  const _SortHeader(
    this.label, {
    required this.arrow,
    required this.onTap,
    this.rowHeight = false,
    this.padding = _cellPadding,
    this.arrowPlacement = _ArrowPlacement.after,
  });

  final String label;
  final bool? arrow;
  final VoidCallback onTap;

  /// Marges autour du titre.
  final EdgeInsets padding;

  /// Place de la flèche de tri par rapport au titre.
  final _ArrowPlacement arrowPlacement;

  /// Même hauteur de ligne que les éléments de la liste (texte de 14px),
  /// malgré son texte plus petit.
  final bool rowHeight;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final style = _text.copyWith(fontSize: 12, color: color);
    final icon = arrow == null
        ? null
        : Icon(
            arrow! ? Icons.arrow_upward : Icons.arrow_downward,
            size: 12,
            color: color,
          );
    final text = Text(
      label,
      style: style,
      strutStyle: rowHeight
          ? const StrutStyle(fontSize: 14, forceStrutHeight: true)
          : null,
    );
    // Survol bombé (voir [HoverBulge]).
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      child: HoverBulge(
        child: Padding(
          padding: padding,
          child: arrowPlacement == _ArrowPlacement.centered
              // Centré : seul le titre compte pour la place ; la flèche est
              // dessinée juste à sa droite, sans le décaler.
              ? Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    text,
                    if (icon != null) Positioned(right: -14, child: icon),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    if (arrowPlacement == _ArrowPlacement.before) ?icon,
                    text,
                    if (arrowPlacement == _ArrowPlacement.after) ?icon,
                  ],
                ),
        ),
      ),
    );
  }
}

/// Joueurs d'un événement, au style des listes : son nom (précédé de son rang
/// quand la liste est triée par Gloire), à droite sa Gloire gagnée à
/// l'événement. Triable par nom ou par Gloire.
class _EventPlayers extends StatefulWidget {
  const _EventPlayers(
    this.players, {
    super.key,
    this.onTap,
    this.onRemove,
    this.onAdd,
    this.locked = const {},
    this.showEmpty = false,
  });

  /// Sans joueur : « Aucun joueur. » (événements Wargame, connecté) ;
  /// sinon rien.
  final bool showEmpty;

  final List<({int id, String name, int glory})> players;

  /// Si non nul : une croix retire chaque joueur, sauf ceux de [locked].
  final Future<void> Function(int playerId)? onRemove;
  final Set<int> locked;

  /// Si non nul : un bouton sous la liste ajoute un joueur.
  final VoidCallback? onAdd;

  /// Si non nul : chaque joueur est cliquable (son id).
  final ValueChanged<int>? onTap;

  @override
  State<_EventPlayers> createState() => _EventPlayersState();
}

class _EventPlayersState extends State<_EventPlayers> {
  _SortBy _sortBy = _SortBy.name;
  bool _ascending = true;

  /// Comme les autres en-têtes : la colonne déjà triée inverse le sens ;
  /// sinon, par nom de A à Z ou par Gloire décroissante.
  void _sort(_SortBy by) => setState(() {
    _ascending = by == _sortBy ? !_ascending : by == _SortBy.name;
    _sortBy = by;
  });

  @override
  Widget build(BuildContext context) {
    final add = widget.onAdd;
    if (widget.players.isEmpty) {
      if (add == null && !widget.showEmpty) return const SizedBox.shrink();
      // « Aucun joueur. », et dessous le bouton d'ajout (connecté).
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            if (widget.showEmpty)
              Text(
                'Aucun joueur.',
                style: _text.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            if (add != null)
              AddButton(
                icon: Icons.person_add,
                label: 'Ajouter un joueur',
                onPressed: add,
              ),
          ],
        ),
      );
    }
    final remove = widget.onRemove;
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    const divider = BorderSide(color: dividerColor);
    final direction = _ascending ? 1 : -1;
    final players = [...widget.players]
      ..sort((a, b) {
        if (_sortBy == _SortBy.score) {
          final byCount = a.glory.compareTo(b.glory);
          if (byCount != 0) return direction * byCount;
          return compareNames(a.name, b.name);
        }
        return direction * compareNames(a.name, b.name);
      });
    // Trié par Gloire : le rang de chacun au classement (meilleure Gloire :
    // 1 ; à égalité, par nom), quel que soit le sens du tri.
    final Map<int, int>? ranks;
    if (_sortBy == _SortBy.score) {
      final ranked = [...widget.players]
        ..sort((a, b) {
          final byGlory = b.glory.compareTo(a.glory);
          return byGlory != 0 ? byGlory : compareNames(a.name, b.name);
        });
      ranks = {for (final (r, p) in ranked.indexed) p.id: r + 1};
    } else {
      ranks = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(border: Border(bottom: divider)),
          child: Row(
            children: [
              Expanded(
                child: _SortHeader(
                  'Nom',
                  arrow: _sortBy == _SortBy.name ? _ascending : null,
                  onTap: () => _sort(_SortBy.name),
                ),
              ),
              _SortHeader(
                'Gloire',
                arrow: _sortBy == _SortBy.score ? _ascending : null,
                onTap: () => _sort(_SortBy.score),
                arrowPlacement: _ArrowPlacement.before,
              ),
            ],
          ),
        ),
        for (final p in players)
          _detailRow(
            onTap: switch (widget.onTap) {
              final tap? => () => tap(p.id),
              null => null,
            },
            child: Row(
              spacing: 10,
              children: [
                Expanded(
                  child: Text(
                    switch (ranks?[p.id]) {
                      final rank? => '$rank. ${p.name}',
                      null => p.name,
                    },
                    style: _text,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Sa Gloire à l'événement, alignée comme les scores.
                SizedBox(
                  width: _scoreWidth,
                  child: Text(
                    '${p.glory}',
                    style: _text,
                    textAlign: TextAlign.right,
                  ),
                ),
                // Connecté : retirer ce joueur (pas s'il a déjà joué).
                if (remove != null)
                  SizedBox.square(
                    dimension: 24,
                    child: widget.locked.contains(p.id)
                        ? null
                        : IconButton(
                            tooltip: "Retirer de l'événement",
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 24,
                              height: 24,
                            ),
                            iconSize: 16,
                            color: labelColor,
                            onPressed: () => remove(p.id),
                            icon: const Icon(Icons.close),
                          ),
                  ),
              ],
            ),
          ),
        if (add != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: AddButton(
                icon: Icons.person_add,
                label: 'Ajouter un joueur',
                onPressed: add,
              ),
            ),
          ),
      ],
    );
  }
}

/// Fenêtre au design des cartes pour choisir un joueur parmi [players], sauf
/// ceux d'[exclude] (déjà dans la partie). Renvoie le joueur choisi.
class _PlayerPicker extends StatelessWidget {
  const _PlayerPicker({
    required this.title,
    required this.players,
    required this.exclude,
  });

  final String title;
  final Future<List<(int, String)>> players;
  final Set<int> exclude;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    const divider = BorderSide(color: dividerColor);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SizedBox(
        width: 320,
        child: CardSurface(
          // L'écart de la carte, à gauche et à droite, est dans le
          // défilement : la barre reste au bord.
          padding: const EdgeInsets.symmetric(vertical: CardSurface.gutter),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: FutureBuilder<List<(int, String)>>(
              future: players,
              builder: (context, snapshot) {
                final all = snapshot.data;
                if (all == null) {
                  return Center(
                    child: snapshot.hasError
                        ? const Text('Impossible de charger les joueurs.')
                        : const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                  );
                }
                final available = [
                  for (final p in all)
                    if (!exclude.contains(p.$1)) p,
                ];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    if (available.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Tous les joueurs sont déjà dans la partie.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted),
                        ),
                      )
                    else
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: CardSurface.gutter,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final p in available)
                                Material(
                                  color: Colors.transparent,
                                  shape: const Border(bottom: divider),
                                  child: InkWell(
                                    onTap: () => Navigator.of(context).pop(p),
                                    hoverColor: AccentStyle.of(context).hover,
                                    child: Padding(
                                      padding: _cellPadding,
                                      child: Row(
                                        spacing: 10,
                                        children: [
                                          _IdBanner(p.$1),
                                          Expanded(
                                            child: Text(p.$2, style: _text),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 12,
                        right: CardSurface.gutter + 12,
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(foregroundColor: muted),
                          child: const Text('Annuler'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Une partie de JDR : la date, le scénario, l'événement puis le lieu, l'un
/// sous l'autre, centrés et plus petits ; puis la liste de ses joueurs, le
/// MJ en premier, chacun avec la bannière de son id, au style des listes.
/// Connecté : chacun se retire, et deux boutons ajoutent un MJ ou un joueur.
class _SessionDetail extends StatelessWidget {
  const _SessionDetail({
    required this.infos,
    required this.gms,
    required this.guests,
    this.onRemove,
    this.onAdd,
    this.onAddGm,
    this.onPlayerTap,
  });

  /// Si non nul : chaque MJ ou joueur est cliquable (son id).
  final ValueChanged<int>? onPlayerTap;

  /// Lignes d'informations, centrées en haut (date, scénario…).
  final List<String> infos;

  /// MJ et joueurs (id, nom), affichés dans cet ordre.
  final List<(int, String)> gms;
  final List<(int, String)> guests;

  /// Connecté : retirer un MJ ou un joueur (bouton à droite de sa ligne), et
  /// en ajouter (boutons sous la liste).
  final Future<void> Function(int playerId)? onRemove;
  final VoidCallback? onAdd;
  final VoidCallback? onAddGm;

  @override
  Widget build(BuildContext context) {
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget player((int, String) p, {bool gm = false}) => _detailRow(
      onTap: switch (onPlayerTap) {
        final tap? => () => tap(p.$1),
        null => null,
      },
      child: Row(
        spacing: 10,
        children: [
          _IdBanner(p.$1),
          Expanded(
            child: Text(
              p.$2,
              style: _text,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            gm ? 'MJ' : 'Joueur',
            style: _text.copyWith(fontSize: 12, color: labelColor),
          ),
          // Connecté : retirer ce MJ ou ce joueur.
          if (onRemove case final remove?)
            IconButton(
              tooltip: 'Retirer de la partie',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
              iconSize: 16,
              color: labelColor,
              onPressed: () => remove(p.$1),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        // Un peu plus bas sous la bannière, comme une partie de Wargame.
        const SizedBox(height: 20),
        for (final info in infos)
          Text(
            info,
            style: _text.copyWith(fontSize: 12, color: labelColor),
            textAlign: TextAlign.center,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 28),
        // Les MJ, puis les joueurs.
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final g in gms) player(g, gm: true),
            for (final g in guests) player(g),
          ],
        ),
        // Connecté : ajouter un MJ, ou un joueur.
        if (onAdd != null || onAddGm != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 12,
              children: [
                if (onAddGm case final addGm?)
                  AddButton(
                    icon: Icons.auto_stories,
                    label: 'Ajouter un MJ',
                    onPressed: addGm,
                  ),
                if (onAdd case final add?)
                  AddButton(
                    icon: Icons.person_add,
                    label: 'Ajouter un joueur',
                    onPressed: add,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Parties de JDR, au style de la liste de gauche : une ligne par partie, sa
/// date à gauche, à droite la bannière de son MJ puis, un peu à l'écart,
/// celles des joueurs. Le nom de chacun s'affiche au survol. Rien si vide.
class _SessionLines extends StatelessWidget {
  const _SessionLines(this.lines, {this.onTap, this.onAdd});

  final List<SessionLine> lines;

  /// Si non nul (connecté, événement) : un bouton rond sous les parties en
  /// ajoute une ; sans partie, « Aucune partie. » au-dessus.
  final VoidCallback? onAdd;

  /// Si non nul : chaque partie est cliquable (position dans [lines]).
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final add = onAdd;
    if (lines.isEmpty && add == null) return const SizedBox.shrink();
    Widget banner((int, String) player) =>
        Tooltip(message: player.$2, child: _IdBanner(player.$1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, line) in lines.indexed)
          _detailRow(
            onTap: switch (onTap) {
              final tap? => () => tap(i),
              null => null,
            },
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: Text(
                    line.label,
                    style: _text,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (line.gms.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [for (final g in line.gms) banner(g)],
                  ),
                if (line.guests.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [for (final g in line.guests) banner(g)],
                  ),
              ],
            ),
          ),
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Aucune partie.',
              textAlign: TextAlign.center,
              style: _text.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (add != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: AddButton(label: 'Ajouter une partie', onPressed: add),
            ),
          ),
      ],
    );
  }
}

/// Petite bannière héraldique, au fond texturé des boutons activés, avec un
/// id en blanc : un rectangle dont le bas est échancré en queue d'aronde.
class _IdBanner extends StatelessWidget {
  const _IdBanner(this.id, {this.flat = false});

  final int id;

  /// Texture atténuée (voir [AccentStyle.flatTexture]).
  final bool flat;

  static const double width = 24;
  static const double height = 21;

  /// Profondeur de l'échancrure du bas.
  static const double notch = 5;

  @override
  Widget build(BuildContext context) {
    final accent = AccentStyle.of(context);
    // Bordure de la couleur des éléments choisis, qui suit la forme.
    return CustomPaint(
      foregroundPainter: BannerBorderPainter(notch, accent.border),
      child: ClipPath(
        clipper: BannerClipper(notch),
        child: Container(
          width: width,
          height: height,
          padding: EdgeInsets.only(bottom: notch - 1),
          alignment: Alignment.center,
          // Le fond texturé des boutons activés (couleur de la page), ou sa
          // version plus plate.
          decoration: flat ? accent.flatTexture : accent.texture,
          child: Text(
            '$id',
            style: TextStyle(
              fontSize: 10,
              height: 1,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Forme de bannière : rectangle au bas échancré en V.
Path bannerPath(Size size, double notch) => Path()
  ..moveTo(0, 0)
  ..lineTo(size.width, 0)
  ..lineTo(size.width, size.height)
  ..lineTo(size.width / 2, size.height - notch)
  ..lineTo(0, size.height)
  ..close();

class BannerClipper extends CustomClipper<Path> {
  const BannerClipper(this.notch);

  final double notch;

  @override
  Path getClip(Size size) => bannerPath(size, notch);

  @override
  bool shouldReclip(BannerClipper old) => old.notch != notch;
}

/// Bordure de la bannière, le long de sa forme (à l'intérieur).
class BannerBorderPainter extends CustomPainter {
  const BannerBorderPainter(this.notch, this.color);

  final double notch;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(bannerPath(size, notch));
    canvas.drawPath(
      bannerPath(size, notch),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BannerBorderPainter old) =>
      old.notch != notch || old.color != color;
}

/// Pastilles des dernières parties, de la plus ancienne à la plus récente :
/// vertes pour les victoires, grises pour les nuls, rouges pour les défaites.
class _Form extends StatelessWidget {
  const _Form(this.outcomes);

  static const double dot = 8;

  final List<Outcome> outcomes;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 3,
      children: [
        for (final o in outcomes)
          Semantics(
            label: switch (o) {
              Outcome.win => 'Victoire',
              Outcome.draw => 'Nul',
              Outcome.loss => 'Défaite',
            },
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: switch (o) {
                  Outcome.win => const Color(0xFF3FB96A),
                  Outcome.draw => const Color(0xFF8A8F94),
                  Outcome.loss => const Color(0xFFE5534B),
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Pastille avec un nombre, sur un fond légèrement teinté de la couleur du
/// texte (lisible aussi sur la ligne active).
class _Badge extends StatelessWidget {
  const _Badge(this.value, {required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final color = style.color ?? DefaultTextStyle.of(context).style.color!;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$value',
        style: style.copyWith(fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Bannière en haut du détail : l'image (asset en .jpg, .jpeg ou .png) de la
/// ligne sur toute la largeur, en fondu vers le transparent en bas. Sans fichier, un bandeau
/// vide de même taille.
class _Banner extends StatelessWidget {
  const _Banner(this.base);

  static const double height = 160;

  /// Chemin de l'image sans extension (voir [bannerAsset]).
  final String? base;

  /// Liste des assets de l'app, chargée une seule fois.
  static final Future<List<String>> _assets = AssetManifest.loadFromAssetBundle(
    rootBundle,
  ).then((m) => m.listAssets());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _assets,
      builder: (context, snapshot) {
        final assets = snapshot.data;
        final asset = base == null || assets == null
            ? null
            : resolveImageAsset(base!, assets);
        return _faded(context, asset);
      },
    );
  }

  Widget _faded(BuildContext context, String? asset) {
    final empty = ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
    // Fondu vers le transparent en allant vers le bas : la bannière se fond
    // dans le fond de la carte.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.transparent],
      ).createShader(bounds),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: asset == null
            ? empty
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => empty,
              ),
      ),
    );
  }
}

/// Liste au style de la liste de gauche : une ligne par élément, son libellé
/// à gauche et sa valeur à droite.
class _LineList extends StatefulWidget {
  const _LineList(
    this.lines, {
    super.key,
    this.sortable = false,
    this.forms,
    this.onTap,
    this.ranked = false,
  });

  /// Si non nul : chaque ligne est cliquable (position dans [lines]).
  final ValueChanged<int>? onTap;

  /// Classement : trié par valeur, chaque libellé est précédé de son rang
  /// (« 1. »), du meilleur au moins bon, comme la liste des joueurs.
  final bool ranked;

  final List<(String, String)> lines;

  /// Pastilles des dernières parties de chaque ligne (même ordre que
  /// [lines]), affichées avant la valeur.
  final List<List<Outcome>>? forms;

  /// Ajoute un en-tête pour trier par nom ou par valeur (numérique). Les
  /// lignes arrivent triées par valeur décroissante, le tri de départ.
  final bool sortable;

  @override
  State<_LineList> createState() => _LineListState();
}

class _LineListState extends State<_LineList> {
  _SortBy _sortBy = _SortBy.score;
  bool _ascending = false;

  /// Comme l'en-tête de la liste de gauche : la colonne déjà triée inverse
  /// le sens ; l'autre trie par nom de A à Z, ou par valeur décroissante.
  void _sort(_SortBy by) {
    setState(() {
      _ascending = by == _sortBy ? !_ascending : by == _SortBy.name;
      _sortBy = by;
    });
  }

  /// Positions des lignes dans l'ordre affiché.
  List<int> get _order {
    final lines = widget.lines;
    final order = [for (var i = 0; i < lines.length; i++) i];
    if (!widget.sortable) return order;
    final direction = _ascending ? 1 : -1;
    return order..sort((i, j) {
      final (a, b) = (lines[i], lines[j]);
      if (_sortBy == _SortBy.score) {
        final byValue = num.parse(a.$2).compareTo(num.parse(b.$2));
        if (byValue != 0) return direction * byValue;
        return compareNames(a.$1, b.$1);
      }
      return direction * compareNames(a.$1, b.$1);
    });
  }

  /// Rang de chaque ligne au classement (meilleure valeur : 1 ; à valeur
  /// égale, par nom), si la liste en est un et qu'elle est triée par valeur.
  Map<int, int>? get _ranks {
    if (!widget.ranked || _sortBy != _SortBy.score) return null;
    final lines = widget.lines;
    final ranked = [for (var i = 0; i < lines.length; i++) i]
      ..sort((i, j) {
        final byValue = num.parse(lines[j].$2)
            .compareTo(num.parse(lines[i].$2));
        return byValue != 0 ? byValue : compareNames(lines[i].$1, lines[j].$1);
      });
    return {for (final (r, i) in ranked.indexed) i: r + 1};
  }

  @override
  Widget build(BuildContext context) {
    const divider = BorderSide(color: dividerColor);
    final ranks = _ranks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.sortable && widget.lines.isNotEmpty)
          DecoratedBox(
            decoration: BoxDecoration(border: Border(bottom: divider)),
            child: Row(
              children: [
                Expanded(
                  child: _SortHeader(
                    'Nom',
                    arrow: _sortBy == _SortBy.name ? _ascending : null,
                    onTap: () => _sort(_SortBy.name),
                  ),
                ),
                // Sa droite collée à celle des valeurs ; flèche avant.
                _SortHeader(
                  'Gloire',
                  arrow: _sortBy == _SortBy.score ? _ascending : null,
                  onTap: () => _sort(_SortBy.score),
                  arrowPlacement: _ArrowPlacement.before,
                ),
              ],
            ),
          ),
        for (final i in _order)
          _detailRow(
            onTap: switch (widget.onTap) {
              final tap? => () => tap(i),
              null => null,
            },
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Text(
                    switch (ranks?[i]) {
                      final rank? => '$rank. ${widget.lines[i].$1}',
                      null => widget.lines[i].$1,
                    },
                    style: _text,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.forms case final forms?) ...[
                  _Form(forms[i]),
                  // Largeur fixe, comme dans la liste de gauche : les
                  // valeurs restent alignées.
                  SizedBox(
                    width: _scoreWidth,
                    child: Text(
                      widget.lines[i].$2,
                      style: _text,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ] else
                  Text(widget.lines[i].$2, style: _text),
              ],
            ),
          ),
      ],
    );
  }
}

/// Ligne d'une liste du détail, cliquable si [onTap] (avec le survol bombé),
/// sous un filet.
Widget _detailRow({required Widget child, VoidCallback? onTap}) {
  const divider = BorderSide(color: dividerColor);
  final content = Padding(padding: _cellPadding, child: child);
  return Material(
    color: Colors.transparent,
    shape: const Border(bottom: divider),
    child: onTap == null
        ? content
        : InkWell(
            onTap: onTap,
            hoverColor: Colors.transparent,
            child: HoverBulge(child: content),
          ),
  );
}

/// Évolution d'un ELO : signée, à une décimale (virgule), en vert si elle
/// est positive, en rouge si elle est négative, en gris si elle est nulle.
class _EloDelta extends StatelessWidget {
  const _EloDelta(this.delta);

  final double delta;

  @override
  Widget build(BuildContext context) {
    final rounded = (delta * 10).round() / 10;
    final sign = rounded > 0 ? '+' : (rounded < 0 ? '−' : '±');
    final value = rounded.abs().toStringAsFixed(1).replaceAll('.', ',');
    return Text(
      '$sign$value',
      style: _text.copyWith(
        fontSize: 12,
        color: rounded > 0
            ? const Color(0xFF3FB96A)
            : rounded < 0
            ? const Color(0xFFE5534B)
            : const Color(0xFF8A8F94),
      ),
    );
  }
}

/// Résumé textuel d'une partie : le texte, ou « Aucun résumé. » centré. Avec
/// [onEdit] (connecté), un bouton rond juste dessous ouvre une fenêtre pour
/// l'écrire.
class _Summary extends StatelessWidget {
  const _Summary(this.text, {this.onEdit});

  final String? text;
  final Future<void> Function(String? text)? onEdit;

  @override
  Widget build(BuildContext context) {
    // Déconnecté et sans résumé : rien.
    if (text == null && onEdit == null) return const SizedBox.shrink();
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          // Centré, le résumé comme le message sans résumé.
          Text(
            text ?? 'Aucun résumé.',
            textAlign: TextAlign.center,
            style: text == null ? _text.copyWith(color: labelColor) : _text,
          ),
          // Connecté : un bouton rond, juste sous le texte, pour le modifier.
          if (onEdit case final edit?)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: AddButton(
                  icon: Icons.edit,
                  label: 'Modifier le résumé',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => AccentScope(
                      style: AccentStyle.of(context),
                      child: TextDialog(
                        title: 'Résumé',
                        initial: text,
                        onSubmit: edit,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Zone de photos : une grille de vignettes carrées ; un clic ouvre la photo
/// en grand. Sans photo, un message centré dans la zone. Connecté, un bouton
/// « + » dessous pour en ajouter une.
class _PhotoZone extends StatefulWidget {
  const _PhotoZone(this.urls, {this.onAdd});

  static const double thumbnail = 120;

  final List<String> urls;

  /// Si non nul (connecté) : un bouton « + » pour ajouter une photo.
  final Future<void> Function()? onAdd;

  @override
  State<_PhotoZone> createState() => _PhotoZoneState();
}

class _PhotoZoneState extends State<_PhotoZone> {
  bool _busy = false;
  String? _error;

  Future<void> _add(Future<void> Function() add) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await add();
    } catch (_) {
      if (mounted) setState(() => _error = "L'envoi de la photo a échoué.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Le bouton « + » (ou l'envoi en cours), et l'erreur s'il y en a une.
  List<Widget> _addButton() => [
    if (widget.onAdd case final add?)
      _busy
          ? const SizedBox.square(
              dimension: AddButton.size,
              child: Center(
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : AddButton(label: 'Ajouter une photo', onPressed: () => _add(add)),
    if (_error case final error?)
      Text(
        error,
        style: const TextStyle(fontSize: 12, color: Color(0xFFE5534B)),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final urls = widget.urls;
    // Déconnecté et sans photo : rien.
    if (urls.isEmpty && widget.onAdd == null) return const SizedBox.shrink();
    if (urls.isEmpty) {
      // « Aucune photo. », et dessous le bouton « + ».
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text('Aucune photo.', style: _text.copyWith(color: labelColor)),
            ..._addButton(),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 32, 12, 12),
      // Vignettes centrées horizontalement, le bouton « + » dessous.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 12,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final url in urls)
                _Thumbnail(
                  url,
                  size: _PhotoZone.thumbnail,
                  onTap: () => _open(context, url),
                ),
            ],
          ),
          ..._addButton(),
        ],
      ),
    );
  }

  /// Photo en grand, par-dessus l'écran ; un clic à côté la ferme.
  void _open(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: InteractiveViewer(
          child: Image.network(url, errorBuilder: (_, _, _) => const _Broken()),
        ),
      ),
    );
  }
}

/// Vignette carrée d'une photo, recadrée, à coins arrondis.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail(this.url, {required this.size, required this.onTap});

  final String url;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink.image(
          image: NetworkImage(url),
          width: size,
          height: size,
          fit: BoxFit.cover,
          onImageError: (_, _) {},
        ),
      ),
    );
  }
}

/// À la place d'une photo qui ne se charge pas.
class _Broken extends StatelessWidget {
  const _Broken();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 200,
      child: Icon(Icons.broken_image_outlined),
    );
  }
}

/// Liste de parties, au style de la liste de gauche, sous un petit titre.
/// Rien si la liste est vide.
/// Tri des parties du détail : par date (de la plus récente à la plus
/// ancienne, l'ordre de départ), par jeu ou par lieu.
enum _MatchSort { date, game, place }

class _MatchupList extends StatefulWidget {
  const _MatchupList(
    this.matchups, {
    super.key,
    this.showGame = true,
    this.onTap,
  });

  /// Si non nul : chaque partie est cliquable (position dans [matchups]).
  final ValueChanged<int>? onTap;

  /// Affiche la colonne du jeu (inutile quand toutes les parties sont du
  /// même jeu).
  final bool showGame;

  /// Largeur des colonnes de la date et du jeu, à gauche, et de celle du
  /// lieu, à droite.
  static const double dateWidth = 72;
  static const double gameWidth = 120;
  static const double placeWidth = 80;

  /// Parties, de la plus récente à la plus ancienne.
  final List<MatchDetail> matchups;

  @override
  State<_MatchupList> createState() => _MatchupListState();
}

class _MatchupListState extends State<_MatchupList> {
  _MatchSort _sortBy = _MatchSort.date;
  bool _ascending = false;

  /// Un clic sur « Date » trie de la plus récente à la plus ancienne, sur
  /// « Jeu » ou « Lieu » de A à Z ; un second clic sur la même colonne
  /// inverse le sens.
  void _sort(_MatchSort by) {
    setState(() {
      _ascending = by == _sortBy ? !_ascending : by != _MatchSort.date;
      _sortBy = by;
    });
  }

  /// Positions des parties dans l'ordre affiché ; à égalité, de la plus
  /// récente à la plus ancienne.
  List<int> _order(List<MatchDetail> matchups) {
    final order = [for (var i = 0; i < matchups.length; i++) i];
    // Les parties arrivent de la plus récente à la plus ancienne.
    if (_sortBy == _MatchSort.date) {
      return _ascending ? order.reversed.toList() : order;
    }
    String key(MatchDetail m) =>
        _sortBy == _MatchSort.game ? m.game : (m.place ?? '');
    final direction = _ascending ? 1 : -1;
    return order..sort((i, j) {
      final byKey = compareNames(key(matchups[i]), key(matchups[j]));
      return byKey != 0 ? direction * byKey : i.compareTo(j);
    });
  }

  @override
  Widget build(BuildContext context) {
    final matchups = widget.matchups;
    if (matchups.isEmpty) return const SizedBox.shrink();
    const dateWidth = _MatchupList.dateWidth;
    const divider = BorderSide(color: dividerColor);
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // Un large espace au-dessus, pour la séparer de la liste précédente.
          padding: const EdgeInsets.fromLTRB(12, 32, 12, 4),
          child: Text(
            'Parties',
            style: _text.copyWith(fontSize: 12, color: labelColor),
          ),
        ),
        // En-tête : trier par date, par jeu ou par lieu. Chaque titre au-dessus
        // de sa colonne.
        DecoratedBox(
          decoration: BoxDecoration(border: Border(bottom: divider)),
          child: Row(
            children: [
              // Au moins la largeur de la colonne : « Jeu » au-dessus des jeux.
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: dateWidth + 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: _SortHeader(
                    'Date',
                    arrow: _sortBy == _MatchSort.date ? _ascending : null,
                    onTap: () => _sort(_MatchSort.date),
                  ),
                ),
              ),
              if (widget.showGame)
                _SortHeader(
                  'Jeu',
                  arrow: _sortBy == _MatchSort.game ? _ascending : null,
                  onTap: () => _sort(_MatchSort.game),
                ),
              const Spacer(),
              _SortHeader(
                'Lieu',
                arrow: _sortBy == _MatchSort.place ? _ascending : null,
                onTap: () => _sort(_MatchSort.place),
              ),
            ],
          ),
        ),
        // La date et le jeu à gauche du joueur 1, le lieu à droite du
        // joueur 2.
        for (final i in _order(matchups))
          _detailRow(
            onTap: switch (widget.onTap) {
              final tap? => () => tap(i),
              null => null,
            },
            child: _MatchDetailLine(matchups[i], showGame: widget.showGame),
          ),
      ],
    );
  }
}

/// Une partie sur une ligne : la date et le jeu, puis la partie avec
/// l'évolution du ELO de chaque joueur, et le lieu à droite.
///
/// Dans une liste, la date, le jeu et le lieu ont des largeurs fixes : ils
/// restent alignés d'une ligne à l'autre. Seule ([stacked], détail d'une
/// partie), la date, le jeu et le lieu passent l'un sous l'autre au-dessus :
/// la partie a toute la largeur.
class _MatchDetailLine extends StatelessWidget {
  const _MatchDetailLine(this.m, {this.stacked = false, this.showGame = true});

  final MatchDetail m;
  final bool stacked;

  /// Affiche le jeu (dans une liste où toutes les parties sont du même jeu,
  /// non).
  final bool showGame;

  @override
  Widget build(BuildContext context) {
    final fixed = !stacked;
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    const style = _text;
    final label = style.copyWith(color: labelColor);
    Widget column(String text, double width, {TextAlign? align}) {
      final child = Text(
        text,
        style: label,
        textAlign: align,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      );
      return fixed ? SizedBox(width: width, child: child) : child;
    }

    // Seule, la partie colle chaque nom à son score, en double taille.
    final matchup = _MatchupLine(
      m.matchup,
      style: style,
      eloDelta1: m.eloDelta1,
      hugScores: stacked,
      scoreSize: stacked ? 28 : null,
      form1: stacked ? m.form1 : null,
      form2: stacked ? m.form2 : null,
    );
    if (!fixed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          // Un peu plus bas sous la bannière.
          const SizedBox(height: 20),
          // La date, le jeu et le lieu l'un sous l'autre, centrés et plus
          // petits, puis la partie.
          for (final info in [formatDate(m.date), m.game, ?m.place])
            Text(
              info,
              style: label.copyWith(fontSize: 12),
              textAlign: TextAlign.center,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          // 36px entre le lieu et le score (avec l'espacement de la colonne).
          const SizedBox(height: 28),
          matchup,
        ],
      );
    }
    return Row(
      spacing: 12,
      children: [
        column(formatDate(m.date), _MatchupList.dateWidth),
        if (showGame) column(m.game, _MatchupList.gameWidth),
        Expanded(child: matchup),
        column(m.place ?? '', _MatchupList.placeWidth, align: TextAlign.right),
      ],
    );
  }
}

/// Détail d'une ligne, en liste : pour chaque information, son nom puis sa
/// valeur dessous. Le nom de la ligne n'est pas repris : il est déjà dans la
/// liste de gauche.
class _Detail extends StatelessWidget {
  const _Detail(this.entries);

  /// Informations affichées : (libellé, valeur).
  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) {
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in entries)
            Padding(
              padding: _cellPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: _text.copyWith(fontSize: 12, color: labelColor),
                  ),
                  Text(value, style: _text),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Choix d'un événement (type, nombre de tours), centré : sa valeur. Avec
/// [onChoose] (connecté), un bouton rond dessous ouvre la liste des
/// [options] pour le choisir ; sans valeur, [empty] (connecté) ou rien.
class _ChoiceLine<T> extends StatelessWidget {
  const _ChoiceLine({
    required this.value,
    required this.options,
    required this.empty,
    required this.tooltip,
    this.onChoose,
  });

  final T? value;
  final List<(T, String)> options;

  /// Texte sans valeur (connecté) : « Aucun type »…
  final String empty;

  /// Nom du bouton : « Choisir le type »…
  final String tooltip;
  final Future<void> Function(T value)? onChoose;

  @override
  Widget build(BuildContext context) {
    final choose = onChoose;
    final current = value;
    if (current == null && choose == null) return const SizedBox.shrink();
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final label = [
      for (final (v, l) in options)
        if (v == current) l,
    ].firstOrNull;
    // Centrés : sa valeur, et dessous le bouton (connecté).
    return Padding(
      padding: _cellPadding,
      child: Column(
        spacing: 6,
        children: [
          Text(
            label ?? empty,
            textAlign: TextAlign.center,
            style: label == null ? _text.copyWith(color: labelColor) : _text,
          ),
          if (choose != null)
            PopupMenuButton<T>(
              tooltip: tooltip,
              initialValue: current,
              onSelected: choose,
              itemBuilder: (context) => [
                for (final (v, l) in options)
                  PopupMenuItem(value: v, child: Text(l)),
              ],
              // Le bouton rond des autres modifications ; le menu reçoit le
              // clic.
              child: IgnorePointer(
                child: AddButton(
                  onPressed: () {},
                  icon: Icons.edit,
                  label: tooltip,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Jeu d'un événement, sous son type, centré : son nom. Avec [onChoose]
/// (connecté), un bouton rond dessous ouvre la liste des [games] pour le
/// choisir ; sans jeu et sans [onChoose], rien.
class _EventGameLine extends StatelessWidget {
  const _EventGameLine(this.game, {required this.games, this.onChoose});

  final String? game;
  final List<(int, String)> games;
  final Future<void> Function(int gameId)? onChoose;

  @override
  Widget build(BuildContext context) {
    final choose = onChoose;
    if (game == null && choose == null) return const SizedBox.shrink();
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: _cellPadding,
      child: Column(
        spacing: 6,
        children: [
          Text(
            game ?? 'Aucun jeu',
            textAlign: TextAlign.center,
            style: game == null ? _text.copyWith(color: labelColor) : _text,
          ),
          if (choose != null)
            PopupMenuButton<int>(
              tooltip: 'Choisir le jeu',
              onSelected: choose,
              itemBuilder: (context) => [
                for (final (id, name) in games)
                  PopupMenuItem(value: id, child: Text(name)),
              ],
              // Le bouton rond des autres modifications ; le menu reçoit le
              // clic.
              child: IgnorePointer(
                child: AddButton(
                  onPressed: () {},
                  icon: Icons.edit,
                  label: 'Choisir le jeu',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tableau d'une élimination : un tour par colonne, du premier tour à la
/// finale, chaque match relié par des traits au match du tour suivant où
/// passe son vainqueur. Défile horizontalement s'il est plus large que la
/// carte.
class _Bracket extends StatelessWidget {
  const _Bracket(this.rounds, {this.onPick, this.onPlay});

  final List<List<BracketMatch>> rounds;

  /// Si non nul : un clic sur une case vide du premier tour (position du
  /// match, case 1 ou 2) y place un joueur.
  final Future<void> Function(int position, int side)? onPick;

  /// Si non nul : un clic sur les scores d'un match prêt à jouer les fait
  /// saisir (tour, position, match).
  final Future<void> Function(int round, int position, BracketMatch match)?
  onPlay;

  static const double _boxWidth = 180;
  static const double _rowHeight = 26;
  static const double _boxHeight = _rowHeight * 2;
  static const double _gap = 12;
  static const double _columnGap = 32;
  static const double _header = 28;

  /// Haut du match [position] du tour [round] : centré sur les deux matchs
  /// du tour précédent dont il reçoit les vainqueurs.
  static double _top(int round, int position) {
    final block = (_boxHeight + _gap) * (1 << round);
    return _header + position * block + (block - _boxHeight) / 2;
  }

  static double _left(int round) => round * (_boxWidth + _columnGap);

  @override
  Widget build(BuildContext context) {
    final accent = AccentStyle.of(context);
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final width = _left(rounds.length - 1) + _boxWidth;
    final height = _header + rounds.first.length * (_boxHeight + _gap);
    // Centré s'il tient dans la carte ; sinon, il défile.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth - 24),
          child: Center(
            child: _board(context, width, height, accent, labelColor),
          ),
        ),
      ),
    );
  }

  Widget _board(
    BuildContext context,
    double width,
    double height,
    AccentStyle accent,
    Color labelColor,
  ) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _BracketLinesPainter(
          rounds.map((r) => r.length).toList(),
          color: accent.border.withValues(alpha: 0.6),
        ),
        child: Stack(
          children: [
            for (final (r, round) in rounds.indexed) ...[
              // Nom du tour, au-dessus de sa colonne.
              Positioned(
                left: _left(r),
                top: 0,
                width: _boxWidth,
                height: _header,
                child: Text(
                  bracketRoundName(rounds.length, r),
                  textAlign: TextAlign.center,
                  style: _text.copyWith(fontSize: 12, color: labelColor),
                ),
              ),
              for (final (p, match) in round.indexed)
                Positioned(
                  left: _left(r),
                  top: _top(r, p),
                  width: _boxWidth,
                  height: _boxHeight,
                  child: _BracketBox(
                    match,
                    onPick: switch (onPick) {
                      final pick? when r == 0 && !isPlayed(match) => (
                        side,
                      ) => pick(p, side),
                      _ => null,
                    },
                    onPlay: switch (onPlay) {
                      final play?
                          when match.player1 != null &&
                              match.player2 != null &&
                              !isPlayed(match) =>
                        () => play(r, p, match),
                      _ => null,
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un match du tableau : deux lignes (joueur, score). Le vainqueur en gras,
/// le perdant grisé, comme dans la liste des parties.
class _BracketBox extends StatelessWidget {
  const _BracketBox(this.match, {this.onPick, this.onPlay});

  final BracketMatch match;

  /// Si non nul : un clic sur une case (1 ou 2) choisit son joueur.
  final ValueChanged<int>? onPick;

  /// Si non nul : un clic sur les scores les fait saisir.
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final accent = AccentStyle.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final winner = winnerOf(match);
    final pick = onPick;
    final play = onPlay;

    Widget line(int side) {
      final player = side == 1 ? match.player1 : match.player2;
      final score = side == 1 ? match.score1 : match.score2;
      final style = switch (winner) {
        null => _text,
        final w when w == player => _text.copyWith(fontWeight: FontWeight.bold),
        _ => _text.copyWith(color: muted),
      };
      return SizedBox(
        height: _Bracket._rowHeight,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: switch (pick) {
                  final pick? => () => pick(side),
                  null => null,
                },
                hoverColor: accent.hover,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      player?.$2 ?? (pick != null ? 'Choisir…' : '—'),
                      style: player == null
                          ? _text.copyWith(color: muted)
                          : style,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
            // Le score ; prêt à jouer, un clic le fait saisir.
            InkWell(
              onTap: play,
              hoverColor: accent.hover,
              child: SizedBox(
                width: 36,
                height: _Bracket._rowHeight,
                child: Center(
                  child: Text(
                    score?.toString() ?? (play != null ? '+' : ''),
                    style: score == null ? _text.copyWith(color: muted) : style,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: const Color(0x66000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: accent.border.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          line(1),
          const Divider(height: 0, thickness: 1, color: dividerColor),
          Expanded(child: line(2)),
        ],
      ),
    );
  }
}

/// Traits du tableau : de chaque match vers le match du tour suivant.
class _BracketLinesPainter extends CustomPainter {
  const _BracketLinesPainter(this.counts, {required this.color});

  /// Nombre de matchs de chaque tour.
  final List<int> counts;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const half = _Bracket._boxHeight / 2;
    for (var r = 0; r + 1 < counts.length; r++) {
      for (var p = 0; p < counts[r]; p++) {
        final from = Offset(
          _Bracket._left(r) + _Bracket._boxWidth,
          _Bracket._top(r, p) + half,
        );
        final to = Offset(
          _Bracket._left(r + 1),
          _Bracket._top(r + 1, p ~/ 2) + half,
        );
        final middle = from.dx + _Bracket._columnGap / 2;
        canvas.drawPath(
          Path()
            ..moveTo(from.dx, from.dy)
            ..lineTo(middle, from.dy)
            ..lineTo(middle, to.dy)
            ..lineTo(to.dx, to.dy),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BracketLinesPainter old) =>
      old.counts.length != counts.length || old.color != color;
}

/// Fenêtre au design des cartes pour saisir les scores d'un match du
/// tableau, entre [player1] et [player2]. Pas d'égalité, sauf avec
/// [allowDraw] (championnat) : il faut un vainqueur. Renvoie les deux
/// scores.
class _ScoreDialog extends StatefulWidget {
  const _ScoreDialog(this.player1, this.player2, {this.allowDraw = false});

  final String player1;
  final String player2;
  final bool allowDraw;

  @override
  State<_ScoreDialog> createState() => _ScoreDialogState();
}

class _ScoreDialogState extends State<_ScoreDialog> {
  final _score1 = TextEditingController();
  final _score2 = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _score1.dispose();
    _score2.dispose();
    super.dispose();
  }

  void _submit() {
    final s1 = int.tryParse(_score1.text);
    final s2 = int.tryParse(_score2.text);
    final error = switch ((s1, s2)) {
      (null, _) || (_, null) => 'Saisissez les deux scores.',
      (final a?, final b?) when a == b && !widget.allowDraw =>
        'Il faut un vainqueur.',
      _ => null,
    };
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop((s1!, s2!));
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget score(String player, TextEditingController controller) => Row(
      spacing: 12,
      children: [
        Expanded(child: Text(player, style: _text)),
        SizedBox(
          width: 72,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Score'),
            onSubmitted: (_) => _submit(),
          ),
        ),
      ],
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SizedBox(
        width: 340,
        child: CardSurface(
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                const Text(
                  'Scores du match',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                score(widget.player1, _score1),
                score(widget.player2, _score2),
                if (_error case final error?)
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE5534B),
                    ),
                  ),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowAlignment: OverflowBarAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(foregroundColor: muted),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AccentStyle.of(context).color,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Enregistrer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barème d'un championnat, centré : « Victoire 3 · Nul 1 · Défaite 0 »,
/// ou la Gloire en guise de points. Avec [onChoose] (connecté), un bouton
/// rond dessous le fait modifier.
class _PointsLine extends StatelessWidget {
  const _PointsLine(this.points, {this.onChoose});

  final ChampionshipPoints points;
  final Future<void> Function(ChampionshipPoints points)? onChoose;

  @override
  Widget build(BuildContext context) {
    final choose = onChoose;
    return Padding(
      padding: _cellPadding,
      child: Column(
        spacing: 6,
        children: [
          Text(
            points.glory
                ? 'Points : Gloire gagnée'
                : 'Victoire ${points.win} · Nul ${points.draw} · '
                      'Défaite ${points.loss}',
            textAlign: TextAlign.center,
            style: _text,
          ),
          if (choose != null)
            AddButton(
              icon: Icons.edit,
              label: 'Modifier les points',
              onPressed: () async {
                final chosen = await showDialog<ChampionshipPoints>(
                  context: context,
                  builder: (_) => AccentScope(
                    style: AccentStyle.of(context),
                    child: _PointsDialog(points),
                  ),
                );
                if (chosen != null) await choose(chosen);
              },
            ),
        ],
      ),
    );
  }
}

/// Fenêtre au design des cartes pour régler le barème d'un championnat :
/// les points à la victoire, au nul et à la défaite, ou la Gloire gagnée en
/// guise de points. Renvoie le barème.
class _PointsDialog extends StatefulWidget {
  const _PointsDialog(this.points);

  final ChampionshipPoints points;

  @override
  State<_PointsDialog> createState() => _PointsDialogState();
}

class _PointsDialogState extends State<_PointsDialog> {
  late final _win = TextEditingController(text: '${widget.points.win}');
  late final _draw = TextEditingController(text: '${widget.points.draw}');
  late final _loss = TextEditingController(text: '${widget.points.loss}');
  late bool _glory = widget.points.glory;
  String? _error;

  @override
  void dispose() {
    _win.dispose();
    _draw.dispose();
    _loss.dispose();
    super.dispose();
  }

  void _submit() {
    final (win, draw, loss) = (
      int.tryParse(_win.text),
      int.tryParse(_draw.text),
      int.tryParse(_loss.text),
    );
    if (win == null || draw == null || loss == null) {
      setState(() => _error = 'Saisissez les trois nombres de points.');
      return;
    }
    Navigator.of(context)
        .pop((win: win, draw: draw, loss: loss, glory: _glory));
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget field(String label, TextEditingController controller) => Row(
      spacing: 12,
      children: [
        Expanded(
          child: Text(
            label,
            style: _glory ? _text.copyWith(color: muted) : _text,
          ),
        ),
        SizedBox(
          width: 72,
          child: TextField(
            controller: controller,
            enabled: !_glory,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Points'),
            onSubmitted: (_) => _submit(),
          ),
        ),
      ],
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SizedBox(
        width: 340,
        child: CardSurface(
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                const Text(
                  'Points du championnat',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                Row(
                  spacing: 12,
                  children: [
                    const Expanded(
                      child: Text(
                        'Gloire gagnée en guise de points',
                        style: _text,
                      ),
                    ),
                    Switch(
                      value: _glory,
                      activeThumbColor: AccentStyle.of(context).color,
                      onChanged: (v) => setState(() => _glory = v),
                    ),
                  ],
                ),
                field('Victoire', _win),
                field('Nul', _draw),
                field('Défaite', _loss),
                if (_error case final error?)
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE5534B),
                    ),
                  ),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowAlignment: OverflowBarAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(foregroundColor: muted),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AccentStyle.of(context).color,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Enregistrer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Classement d'un championnat, au style des listes : le rang et le nom,
/// puis les rencontres jouées (J), gagnées (V), nulles (N), perdues (D) et
/// les points ; ou bien, avec [leadLabel], la valeur (Gloire, ELO) en
/// premier sous ce nom, devant les rencontres. Triable par chaque colonne ; le rang reste celui du
/// classement.
class _Standings extends StatefulWidget {
  const _Standings(
    this.standings, {
    super.key,
    this.leadLabel,
    this.onTap,
    this.onRemove,
    this.onAdd,
    this.locked = const {},
  });

  /// Dans l'ordre du classement.
  final List<Standing> standings;
  final String? leadLabel;

  /// Si non nul : chaque joueur est cliquable (son id).
  final ValueChanged<int>? onTap;

  /// Si non nul : une croix retire chaque joueur, sauf ceux de [locked].
  final Future<void> Function(int playerId)? onRemove;
  final Set<int> locked;

  /// Si non nul : un bouton sous le classement ajoute un joueur ; sans
  /// joueur, « Aucun joueur. » au-dessus.
  final VoidCallback? onAdd;

  static const double _countWidth = 36;

  /// La colonne de [leadLabel], plus large.
  static const double _gloryWidth = 72;

  @override
  State<_Standings> createState() => _StandingsState();
}

/// Colonne de tri du classement.
enum _StandingSort { name, score, played, wins, draws, losses }

class _StandingsState extends State<_Standings> {
  /// Par défaut : l'ordre du classement (points décroissants).
  _StandingSort _sortBy = _StandingSort.score;
  bool _ascending = false;

  /// La colonne déjà triée inverse le sens ; sinon, par nom de A à Z ou
  /// par nombre décroissant.
  void _sort(_StandingSort by) => setState(() {
    _ascending = by == _sortBy ? !_ascending : by == _StandingSort.name;
    _sortBy = by;
  });

  /// Nombre de [s] dans la colonne [by] (0 pour le nom).
  static int _count(Standing s, _StandingSort by) => switch (by) {
    _StandingSort.score => s.points,
    _StandingSort.played => s.played,
    _StandingSort.wins => s.wins,
    _StandingSort.draws => s.draws,
    _StandingSort.losses => s.losses,
    _StandingSort.name => 0,
  };

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final add = widget.onAdd;
    final remove = widget.onRemove;
    final lead = widget.leadLabel;
    final glory = lead != null;
    if (widget.standings.isEmpty) {
      if (add == null) return const SizedBox.shrink();
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text('Aucun joueur.', style: _text.copyWith(color: muted)),
            AddButton(
              icon: Icons.person_add,
              label: 'Ajouter un joueur',
              onPressed: add,
            ),
          ],
        ),
      );
    }
    final ranks = {
      for (final (i, s) in widget.standings.indexed) s.player.$1: i + 1,
    };
    final direction = _ascending ? 1 : -1;
    // Par nombre : à égalité, l'ordre du classement.
    final rows = [...widget.standings]
      ..sort((a, b) {
        if (_sortBy == _StandingSort.name) {
          return direction * compareNames(a.player.$2, b.player.$2);
        }
        final byValue =
            direction * _count(a, _sortBy).compareTo(_count(b, _sortBy));
        return byValue != 0
            ? byValue
            : ranks[a.player.$1]!.compareTo(ranks[b.player.$1]!);
      });

    // Les colonnes de nombres, dans l'ordre affiché : (tri, largeur).
    const counts = [
      _StandingSort.played,
      _StandingSort.wins,
      _StandingSort.draws,
      _StandingSort.losses,
    ];
    final columns = [
      if (glory) (_StandingSort.score, _Standings._gloryWidth),
      for (final c in counts) (c, _Standings._countWidth),
      if (!glory) (_StandingSort.score, _scoreWidth),
    ];
    String title(_StandingSort by) => switch (by) {
      _StandingSort.score => lead ?? 'Pts',
      _StandingSort.played => 'J',
      _StandingSort.wins => 'V',
      _StandingSort.draws => 'N',
      _StandingSort.losses => 'D',
      _StandingSort.name => 'Nom',
    };
    // Place de la croix (connecté), pour aligner l'en-tête.
    const removeWidth = 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _SortHeader(
                    'Nom',
                    arrow: _sortBy == _StandingSort.name ? _ascending : null,
                    onTap: () => _sort(_StandingSort.name),
                  ),
                ),
              ),
              for (final (by, width) in columns)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: SizedBox(
                    width: width,
                    // Le titre à droite, comme les nombres ; la flèche
                    // dessinée à sa gauche, sans prendre de place.
                    child: InkWell(
                      onTap: () => _sort(by),
                      hoverColor: Colors.transparent,
                      child: HoverBulge(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.5),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Text(
                                  title(by),
                                  style: _text.copyWith(
                                    fontSize: 12,
                                    color: muted,
                                  ),
                                ),
                                if (_sortBy == by)
                                  Positioned(
                                    left: -14,
                                    top: 0,
                                    bottom: 0,
                                    child: Icon(
                                      _ascending
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      size: 12,
                                      color: muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Les marges de droite des lignes, et leur croix.
              SizedBox(
                width:
                    _cellPadding.right +
                    (remove != null ? 10 + removeWidth : 0),
              ),
            ],
          ),
        ),
        for (final s in rows)
          _detailRow(
            onTap: switch (widget.onTap) {
              final tap? => () => tap(s.player.$1),
              null => null,
            },
            child: Row(
              spacing: 10,
              children: [
                Expanded(
                  child: Text(
                    // Le rang au classement, sauf trié par nom.
                    _sortBy == _StandingSort.name
                        ? s.player.$2
                        : '${ranks[s.player.$1]}. ${s.player.$2}',
                    style: _text,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final (by, width) in columns)
                  SizedBox(
                    width: width,
                    child: Text(
                      '${_count(s, by)}',
                      style: _text,
                      textAlign: TextAlign.right,
                    ),
                  ),
                // Connecté : retirer ce joueur (pas s'il a déjà joué).
                if (remove != null)
                  SizedBox.square(
                    dimension: removeWidth,
                    child: widget.locked.contains(s.player.$1)
                        ? null
                        : IconButton(
                            tooltip: "Retirer de l'événement",
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: removeWidth,
                              height: removeWidth,
                            ),
                            iconSize: 16,
                            color: muted,
                            onPressed: () => remove(s.player.$1),
                            icon: const Icon(Icons.close),
                          ),
                  ),
              ],
            ),
          ),
        if (add != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: AddButton(
                icon: Icons.person_add,
                label: 'Ajouter un joueur',
                onPressed: add,
              ),
            ),
          ),
      ],
    );
  }
}

/// Calendrier d'un championnat, journée par journée : chaque rencontre sur
/// une ligne, joueur 1, scores, joueur 2 (le vainqueur en gras, le perdant
/// grisé). Avec [onPlay] (connecté), un clic sur les scores d'une rencontre
/// à jouer les fait saisir.
class _Calendar extends StatelessWidget {
  const _Calendar(
    this.fixtures, {
    this.onPlay,
    this.onOpen,
    this.showDays = true,
  });

  final List<Fixture> fixtures;

  /// Si non nul : un clic sur une rencontre jouée mène à sa partie (son
  /// id).
  final ValueChanged<int>? onOpen;

  /// Les rencontres sous le titre de leur journée (pas pour un groupe de
  /// suisse : toutes ensemble).
  final bool showDays;
  final Future<void> Function(Fixture fixture)? onPlay;

  @override
  Widget build(BuildContext context) {
    final accent = AccentStyle.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final play = onPlay;
    final days = <int, List<Fixture>>{};
    for (final f in fixtures) {
      days.putIfAbsent(f.day, () => []).add(f);
    }

    Widget line(Fixture f) {
      final played = isFixturePlayed(f);
      final diff = played ? f.score1!.compareTo(f.score2!) : 0;
      TextStyle style(int sign) => !played || diff == 0
          ? _text
          : diff == sign
          ? _text.copyWith(fontWeight: FontWeight.bold)
          : _text.copyWith(color: muted);
      final scores = played
          ? '${f.score1} – ${f.score2}'
          : (play != null ? '+' : '–');
      return _detailRow(
        onTap: switch ((onOpen, f.party)) {
          (final open?, final party?) => () => open(party),
          _ => null,
        },
        child: Row(
          spacing: 10,
          children: [
            Expanded(
              child: Text(
                f.player1.$2,
                style: style(1),
                textAlign: TextAlign.right,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InkWell(
              onTap: !played && play != null ? () => play(f) : null,
              hoverColor: accent.hover,
              child: SizedBox(
                width: 72,
                child: Text(
                  scores,
                  textAlign: TextAlign.center,
                  style: played ? _text : _text.copyWith(color: muted),
                ),
              ),
            ),
            Expanded(
              child: Text(
                f.player2.$2,
                style: style(-1),
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final MapEntry(key: day, value: list) in days.entries) ...[
          if (showDays)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Journée ${day + 1}',
                textAlign: TextAlign.center,
                style: _text.copyWith(fontSize: 12, color: muted),
              ),
            ),
          for (final f in list) line(f),
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    // Au centre de la carte, comme l'invitation de la carte du détail.
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: _text.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
