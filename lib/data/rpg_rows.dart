import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'elo.dart';
import 'rows.dart';

/// Une partie de JDR : un jeu, de 0 à plusieurs meneurs (MJ), des joueurs,
/// un lieu et un événement facultatifs, et une date (jour).
typedef RpgSession = ({
  int id,
  DateTime date,
  int game,
  List<int> gms,
  List<int> guests,
  String? place,
  int? event,
  String? scenario,
  String? summary,
});

/// Lignes d'une table JDR (préfixe rpg_), pour les parties, les joueurs, les
/// jeux et les événements ; null pour les autres tables (lues comme au
/// Wargame).
///
/// Pas de score au JDR (pas de pastilles de résultats) : la Gloire des
/// joueurs se calcule à partir des parties (voir [rpgGlory]).
Future<RowTable?> fetchRpgSessionRows(String table) async {
  if (!const {'partie', 'joueur', 'jeu', 'evenement'}.contains(table)) {
    return null;
  }
  final db = Supabase.instance.client;
  final (players, games, events, sessionRows) = await (
    db.from('rpg_joueur').select('id, nom'),
    db.from('rpg_jeu').select('id, nom'),
    db.from('rpg_evenement').select('id, nom, date'),
    db
        .from('rpg_partie')
        .select(
          'id, date, jeu_id, evenement_id, scenario, resume, '
          'place:lieu_id(nom), rpg_partie_joueur(joueur_id, mj)',
        )
        .order('date', ascending: false)
        .order('id', ascending: false),
  ).wait;
  Map<int, String> names(List<Map<String, dynamic>> rows) => {
    for (final r in rows) r['id'] as int: r['nom'] as String,
  };
  final playerNames = names(players);
  final gameNames = names(games);
  final eventNames = names(events);
  final sessions = <RpgSession>[
    for (final r in sessionRows)
      (
        id: r['id'] as int,
        date: DateTime.parse(r['date'] as String),
        game: r['jeu_id'] as int,
        gms: [
          for (final g in r['rpg_partie_joueur'] as List)
            if ((g as Map<String, dynamic>)['mj'] == true)
              g['joueur_id'] as int,
        ],
        guests: [
          for (final g in r['rpg_partie_joueur'] as List)
            if ((g as Map<String, dynamic>)['mj'] != true)
              g['joueur_id'] as int,
        ],
        place: r['place']?['nom'] as String?,
        event: r['evenement_id'] as int?,
        scenario: r['scenario'] as String?,
        summary: r['resume'] as String?,
      ),
  ];
  final glorySessions = [
    for (final s in sessions)
      (
        id: s.id,
        date: s.date,
        game: s.game,
        event: s.event,
        people: {...s.gms, ...s.guests},
      ),
  ];
  final participation = rpgParticipationPoints(glorySessions);
  final glory = <int, int>{};
  for (final MapEntry(key: (_, player), :value) in participation.entries) {
    glory[player] = (glory[player] ?? 0) + value;
  }

  // Numéro d'ordre de chaque partie dans son événement (1, 2…), par date.
  final eventOrder = <int, int>{};
  final perEvent = <int, int>{};
  for (final s in sessions.reversed) {
    if (s.event case final e?) {
      eventOrder[s.id] = perEvent[e] = (perEvent[e] ?? 0) + 1;
    }
  }

  String nameOf(int? id) => id == null ? '—' : playerNames[id] ?? '—';

  String sessionTitle(RpgSession s) => rpgSessionTitle(
    s.date,
    scenario: s.scenario,
    event: s.event == null ? null : (eventNames[s.event]!, eventOrder[s.id]!),
  );

  /// Joueurs (id, nom), par nom.
  List<(int, String)> named(List<int> ids) =>
      [for (final p in ids) (p, nameOf(p))]
        ..sort((a, b) => compareNames(a.$2, b.$2));

  /// Une partie sur une ligne : son titre, avec ses MJ et ses joueurs.
  SessionLine sessionLine(RpgSession s) =>
      (label: sessionTitle(s), gms: named(s.gms), guests: named(s.guests));

  switch (table) {
    case 'partie':
      final photoRows = await db
          .from('rpg_photo')
          .select('partie_id, chemin')
          .order('created_at', ascending: true)
          .order('id', ascending: true);
      final photos = <int, List<String>>{};
      for (final r in photoRows) {
        photos
            .putIfAbsent(r['partie_id'] as int, () => [])
            .add(db.storage.from('photos').getPublicUrl(r['chemin'] as String));
      }
      return RowTable(
        // Le jeu dans la liste, avec la date complète à droite.
        columns: const ['Jeu', 'MJ', 'Joueurs', 'Lieu', 'Événement', 'Date'],
        rows: [
          for (final s in sessions)
            [
              gameNames[s.game] ?? '—',
              s.gms.isEmpty
                  ? '—'
                  : [for (final (_, n) in named(s.gms)) n].join(', '),
              s.guests.isEmpty
                  ? '—'
                  : [for (final (_, n) in named(s.guests)) n].join(', '),
              s.place ?? '—',
              s.event == null ? '—' : eventNames[s.event] ?? '—',
              formatFullDate(s.date),
            ],
        ],
        dates: [for (final s in sessions) s.date],
        fullDates: true,
        // La bannière d'une partie est celle de son jeu.
        banners: [for (final s in sessions) bannerAsset('rpg_jeu', s.game)],
        photos: [for (final s in sessions) photos[s.id] ?? const []],
        partyIds: [for (final s in sessions) s.id],
        rowIds: [for (final s in sessions) s.id],
        summaries: [for (final s in sessions) s.summary],
        sessionDetails: [
          for (final s in sessions)
            (
              date: s.date,
              scenario: s.scenario,
              place: s.place,
              event: s.event == null ? null : eventNames[s.event],
              gms: named(s.gms),
              guests: named(s.guests),
            ),
        ],
      );
    case 'joueur':
      final sorted = [...players]
        ..sort((a, b) => compareNames(a['nom'] as String, b['nom'] as String));
      return RowTable(
        columns: const ['Nom'],
        rows: [
          for (final p in sorted) [p['nom'] as String],
        ],
        ids: [for (final p in sorted) p['id'] as int],
        rowIds: [for (final p in sorted) p['id'] as int],
        banners: [
          for (final p in sorted) bannerAsset('rpg_joueur', p['id'] as int),
        ],
        // Pas de score au JDR : pas de pastilles. La Gloire vient des
        // parties (voir [rpgGlory]), 0 sans partie.
        forms: [for (final _ in sorted) const []],
        globalScores: [
          for (final p in sorted) glory[p['id'] as int] ?? rpgEloStart.round(),
        ],
        globalScoreLabel: 'Gloire',
        // Ses parties (comme MJ ou comme joueur), comme dans le détail d'un
        // jeu : date, scénario, événement, et les bannières des joueurs.
        sessionLines: [
          for (final p in sorted)
            [
              for (final s in sessions)
                if (s.gms.contains(p['id']) || s.guests.contains(p['id']))
                  sessionLine(s),
            ],
        ],
        // Un clic sur une de ses parties y mène.
        sessionLineIds: [
          for (final p in sorted)
            [
              for (final s in sessions)
                if (s.gms.contains(p['id']) || s.guests.contains(p['id'])) s.id,
            ],
        ],
      );
    case 'evenement':
      final sorted = [...events]
        ..sort((a, b) => compareNames(a['nom'] as String, b['nom'] as String));
      return RowTable(
        // Pas de date dans le détail : seulement dans la liste.
        columns: const ['Nom'],
        rows: [
          for (final e in sorted) [e['nom'] as String],
        ],
        dates: [
          for (final e in sorted)
            if (e['date'] case final String d) DateTime.parse(d) else null,
        ],
        banners: [
          for (final e in sorted) bannerAsset('rpg_evenement', e['id'] as int),
        ],
        // Ses parties, comme dans le détail d'un jeu ; un clic y mène.
        sessionLines: [
          for (final e in sorted)
            [
              for (final s in sessions)
                if (s.event == e['id']) sessionLine(s),
            ],
        ],
        sessionLineIds: [
          for (final e in sorted)
            [
              for (final s in sessions)
                if (s.event == e['id']) s.id,
            ],
        ],
        // Ceux qui ont joué à ses parties, avec leur Gloire à l'événement.
        eventDetails: [
          for (final e in sorted)
            () {
              final played = [
                for (final s in sessions)
                  if (s.event == e['id']) s,
              ];
              // Gloire gagnée à l'événement par chacun (MJ ou joueur) : la
              // somme des points de ses parties.
              final glory = <int, int>{};
              for (final s in played) {
                for (final p in {...s.gms, ...s.guests}) {
                  glory[p] = (glory[p] ?? 0) + participation[(s.id, p)]!;
                }
              }
              return (
                players: [
                  for (final MapEntry(key: id, value: n) in glory.entries)
                    (id: id, name: nameOf(id), glory: n),
                ],
              );
            }(),
        ],
      );
    default: // jeu
      final sorted = [...games]
        ..sort((a, b) => compareNames(a['nom'] as String, b['nom'] as String));
      return RowTable(
        columns: const ['Nom'],
        rows: [
          for (final g in sorted) [g['nom'] as String],
        ],
        banners: [
          for (final g in sorted) bannerAsset('rpg_jeu', g['id'] as int),
        ],
        // Nombre de joueurs différents (MJ et joueurs) à ce jeu.
        badges: [
          for (final g in sorted)
            {
              for (final s in sessions)
                if (s.game == g['id']) ...[...s.gms, ...s.guests],
            }.length,
        ],
        // Ses parties : date, scénario et événement (avec son numéro
        // d'ordre), avec les bannières du MJ et des joueurs.
        sessionLines: [
          for (final g in sorted)
            [
              for (final s in sessions)
                if (s.game == g['id']) sessionLine(s),
            ],
        ],
        // Un clic sur une de ses parties y mène.
        sessionLineIds: [
          for (final g in sorted)
            [
              for (final s in sessions)
                if (s.game == g['id']) s.id,
            ],
        ],
      );
  }
}

/// Une partie, pour le calcul de la Gloire : son id, sa date, son jeu, son
/// événement (facultatif) et tous ceux qui y étaient (MJ et joueurs).
typedef GlorySession = ({
  int id,
  DateTime date,
  int game,
  int? event,
  Set<int> people,
});

/// Gloire de chaque joueur (id → points) : la somme de ses points à chaque
/// partie (voir [rpgParticipationPoints]).
Map<int, int> rpgGlory(Iterable<GlorySession> sessions) {
  final glory = <int, int>{};
  for (final MapEntry(key: (_, player), :value) in rpgParticipationPoints(
    sessions,
  ).entries) {
    glory[player] = (glory[player] ?? 0) + value;
  }
  return glory;
}

/// Plafond du gain d'une série de parties consécutives d'un événement.
const rpgStreakCap = 10;

/// Points de Gloire gagnés par chacun à chaque partie, par (id de partie,
/// id de joueur) :
/// - 1 point par partie jouée ou menée (MJ) ; dans un événement, une série
///   paie : le gain est le nombre de parties consécutives de l'événement
///   auxquelles il a été (1, 2, 3…, au plus [rpgStreakCap]) ; une partie
///   de l'événement manquée, et le compteur repart à 1 ;
/// - +2 points pour avoir été à la première partie d'un événement ;
/// - +5 points pour avoir été à la première partie d'un jeu.
///
/// Ordre des parties (« première », « consécutives ») : par date, puis par
/// id à date égale.
Map<(int, int), int> rpgParticipationPoints(Iterable<GlorySession> sessions) {
  final ordered = [...sessions]
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  final seenGames = <int>{};
  final seenEvents = <int>{};
  // Par événement : ceux de sa partie précédente, et la série de chacun.
  final previous = <int, Set<int>>{};
  final streaks = <(int, int), int>{};
  final points = <(int, int), int>{};
  for (final s in ordered) {
    final bonus =
        (seenGames.add(s.game) ? 5 : 0) +
        (s.event != null && seenEvents.add(s.event!) ? 2 : 0);
    for (final p in s.people) {
      var base = 1;
      if (s.event case final e?) {
        final streak = (previous[e]?.contains(p) ?? false)
            ? (streaks[(e, p)] ?? 0) + 1
            : 1;
        streaks[(e, p)] = streak;
        base = min(streak, rpgStreakCap);
      }
      points[(s.id, p)] = base + bonus;
    }
    if (s.event case final e?) previous[e] = s.people;
  }
  return points;
}

/// « 28.11.2026 La Tombe de M. Eustache (Paris Éternité 1) » : la date, le
/// scénario et l'événement (nom, numéro d'ordre de la partie dans
/// l'événement), s'il y en a.
String rpgSessionTitle(
  DateTime date, {
  String? scenario,
  (String, int)? event,
}) {
  String two(int n) => n.toString().padLeft(2, '0');
  return [
    '${two(date.day)}.${two(date.month)}.${date.year}',
    ?scenario,
    if (event case (final name, final order)) '($name $order)',
  ].join(' ');
}

/// Choix possibles pour une nouvelle partie de JDR (id, nom), par nom.
typedef RpgPartyOptions = ({
  List<(int, String)> players,
  List<(int, String)> games,
  List<(int, String)> places,
  List<(int, String)> events,
});

Future<RpgPartyOptions> fetchRpgPartyOptions() async {
  final db = Supabase.instance.client;
  final (players, games, places, events) = await (
    db.from('rpg_joueur').select('id, nom'),
    db.from('rpg_jeu').select('id, nom'),
    db.from('rpg_lieu').select('id, nom'),
    db.from('rpg_evenement').select('id, nom'),
  ).wait;
  List<(int, String)> named(List<Map<String, dynamic>> rows) =>
      [for (final r in rows) (r['id'] as int, r['nom'] as String)]
        ..sort((a, b) => compareNames(a.$2, b.$2));
  return (
    players: named(players),
    games: named(games),
    places: named(places),
    events: named(events),
  );
}

/// Une nouvelle partie de JDR, à enregistrer.
typedef NewRpgParty = ({
  int game,
  List<int> gms,
  List<int> guests,
  int? place,
  int? event,
  String? scenario,
  DateTime date,
});

/// Ajoute une partie de JDR et ses joueurs (backoffice : réservé aux
/// connectés).
Future<void> addRpgParty(NewRpgParty party) async {
  final db = Supabase.instance.client;
  String two(int n) => n.toString().padLeft(2, '0');
  final d = party.date;
  final row = await db
      .from('rpg_partie')
      .insert({
        'jeu_id': party.game,
        'lieu_id': ?party.place,
        'evenement_id': ?party.event,
        'scenario': ?party.scenario,
        'date': '${d.year}-${two(d.month)}-${two(d.day)}',
      })
      .select('id')
      .single();
  if (party.gms.isEmpty && party.guests.isEmpty) return;
  await db.from('rpg_partie_joueur').insert([
    for (final g in party.gms)
      {'partie_id': row['id'], 'joueur_id': g, 'mj': true},
    for (final g in party.guests)
      if (!party.gms.contains(g))
        {'partie_id': row['id'], 'joueur_id': g, 'mj': false},
  ]);
}

/// Ajoute le joueur [playerId] à la partie de JDR [partyId], comme MJ si
/// [gm] (backoffice).
Future<void> addRpgGuest(int partyId, int playerId, {required bool gm}) =>
    Supabase.instance.client.from('rpg_partie_joueur').insert({
      'partie_id': partyId,
      'joueur_id': playerId,
      'mj': gm,
    });

/// Retire le joueur (ou MJ) [playerId] de la partie de JDR [partyId]
/// (backoffice).
Future<void> removeRpgGuest(int partyId, int playerId) => Supabase
    .instance
    .client
    .from('rpg_partie_joueur')
    .delete()
    .eq('partie_id', partyId)
    .eq('joueur_id', playerId);

/// Tous les joueurs de JDR (id, nom), par nom : pour en ajouter à une partie.
Future<List<(int, String)>> fetchRpgPlayers() async {
  final rows = await Supabase.instance.client
      .from('rpg_joueur')
      .select('id, nom');
  return [for (final r in rows) (r['id'] as int, r['nom'] as String)]
    ..sort((a, b) => compareNames(a.$2, b.$2));
}

/// Modification des MJ et des joueurs d'une partie de JDR (backoffice) : la
/// liste de tous les joueurs, l'ajout (comme MJ ou joueur) et le retrait.
typedef GuestEditor = ({
  Future<List<(int, String)>> Function() players,
  Future<void> Function(int partyId, int playerId, {required bool gm}) add,
  Future<void> Function(int partyId, int playerId) remove,
});
