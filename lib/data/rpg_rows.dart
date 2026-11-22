import 'package:supabase_flutter/supabase_flutter.dart';

import 'elo.dart';
import 'rows.dart';

/// Une partie de JDR : un jeu, un meneur (MJ), des joueurs, un lieu
/// et un événement facultatifs, et une date (jour).
typedef RpgSession = ({
  int id,
  DateTime date,
  int game,
  int? gm,
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
/// Pas de score au JDR : la Gloire des joueurs reste à son départ (0), sans
/// pastilles de résultats.
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
          'id, date, jeu_id, mj_id, evenement_id, scenario, resume, '
          'place:lieu_id(nom), rpg_partie_joueur(joueur_id)',
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
        gm: r['mj_id'] as int?,
        guests: [
          for (final g in r['rpg_partie_joueur'] as List)
            (g as Map<String, dynamic>)['joueur_id'] as int,
        ],
        place: r['place']?['nom'] as String?,
        event: r['evenement_id'] as int?,
        scenario: r['scenario'] as String?,
        summary: r['resume'] as String?,
      ),
  ];
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

  /// Une partie sur une ligne : son titre, avec son MJ et ses joueurs.
  SessionLine sessionLine(RpgSession s) => (
    label: sessionTitle(s),
    gm: s.gm == null ? null : (s.gm!, nameOf(s.gm)),
    guests: [for (final p in s.guests) (p, nameOf(p))]
      ..sort((a, b) => compareNames(a.$2, b.$2)),
  );

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
              nameOf(s.gm),
              s.guests.isEmpty
                  ? '—'
                  : ([
                      for (final g in s.guests) nameOf(g),
                    ]..sort(compareNames)).join(', '),
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
        summaries: [for (final s in sessions) s.summary],
        sessionDetails: [
          for (final s in sessions)
            (
              date: s.date,
              scenario: s.scenario,
              place: s.place,
              event: s.event == null ? null : eventNames[s.event],
              gm: s.gm == null ? null : (s.gm!, nameOf(s.gm)),
              guests: [for (final g in s.guests) (g, nameOf(g))]
                ..sort((a, b) => compareNames(a.$2, b.$2)),
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
        banners: [
          for (final p in sorted) bannerAsset('rpg_joueur', p['id'] as int),
        ],
        // Pas de score au JDR : pas de pastilles, Gloire de départ.
        forms: [for (final _ in sorted) const []],
        globalScores: [for (final _ in sorted) rpgEloStart.round()],
        globalScoreLabel: 'Gloire',
        // Ses parties (comme MJ ou comme joueur), comme dans le détail d'un
        // jeu : date, scénario, événement, et les bannières des joueurs.
        sessionLines: [
          for (final p in sorted)
            [
              for (final s in sessions)
                if (s.gm == p['id'] || s.guests.contains(p['id']))
                  sessionLine(s),
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
        // Les joueurs ayant joué au moins une fois à l'événement (MJ ou
        // joueurs), par nom.
        playerBanners: [
          for (final e in sorted)
            ([
              for (final id in {
                for (final s in sessions)
                  if (s.event == e['id']) ...[?s.gm, ...s.guests],
              })
                (id, nameOf(id)),
            ]..sort((a, b) => compareNames(a.$2, b.$2))),
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
                if (s.game == g['id']) ...[?s.gm, ...s.guests],
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
      );
  }
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
  int gm,
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
        'mj_id': party.gm,
        'lieu_id': ?party.place,
        'evenement_id': ?party.event,
        'scenario': ?party.scenario,
        'date': '${d.year}-${two(d.month)}-${two(d.day)}',
      })
      .select('id')
      .single();
  if (party.guests.isEmpty) return;
  await db.from('rpg_partie_joueur').insert([
    for (final g in party.guests) {'partie_id': row['id'], 'joueur_id': g},
  ]);
}
