import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/rows.dart';
import 'top_bar.dart';

/// Fenêtre au design des cartes pour ajouter une partie : les deux joueurs
/// et le jeu (choisis dans [options]), les deux scores, le lieu (choisi aussi)
/// et la date (facultatifs). Appelle [onSubmit], puis se ferme ; affiche l'erreur sinon.
class PartyDialog extends StatefulWidget {
  const PartyDialog({
    super.key,
    required this.options,
    required this.onSubmit,
    this.event,
    this.game,
  });

  /// Jeu de la partie (pas de champ Jeu) : celui de l'événement.
  final int? game;

  /// Événement de la partie (pas de choix dans la fenêtre) : ajoutée depuis
  /// le détail de l'événement, entre ses joueurs.
  final int? event;

  /// Joueurs et jeux proposés, chargés à l'ouverture.
  final Future<PartyOptions> options;
  final Future<void> Function(NewParty party) onSubmit;

  @override
  State<PartyDialog> createState() => _PartyDialogState();
}

class _PartyDialogState extends State<PartyDialog> {
  int? _player1;
  int? _player2;
  late int? _game = widget.game;
  final _score1 = TextEditingController(text: '0');
  final _score2 = TextEditingController(text: '0');
  int? _place;
  DateTime? _date;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _score1.dispose();
    _score2.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final score1 = int.tryParse(_score1.text);
    final score2 = int.tryParse(_score2.text);
    final error = switch (()) {
      _ when _player1 == null || _player2 == null =>
        'Choisissez les deux joueurs.',
      _ when _player1 == _player2 => 'Choisissez deux joueurs différents.',
      _ when _game == null => 'Choisissez le jeu.',
      _ when score1 == null || score2 == null => 'Les scores sont des nombres.',
      _ => null,
    };
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit((
        player1: _player1!,
        player2: _player2!,
        score1: score1!,
        score2: score2!,
        game: _game!,
        place: _place,
        event: widget.event,
        date: _date,
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = "L'enregistrement a échoué.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _picker({
    required String label,
    required List<(int, String)> items,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) => DropdownButtonFormField<int>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final (id, name) in items)
        DropdownMenuItem(
          value: id,
          child: Text(name, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: _busy ? null : onChanged,
  );

  Widget _score(TextEditingController controller, String label) => TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    textAlign: TextAlign.center,
    enabled: !_busy,
  );

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SizedBox(
        width: 420,
        child: CardSurface(
          Padding(
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<PartyOptions>(
              future: widget.options,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Impossible de charger les joueurs et les jeux.',
                    textAlign: TextAlign.center,
                  );
                }
                final options = snapshot.data;
                if (options == null) {
                  return const Center(
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    const Text(
                      'Nouvelle partie',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                    // Joueur 1 et son score, puis joueur 2 et son score.
                    Row(
                      spacing: 12,
                      children: [
                        Expanded(
                          child: _picker(
                            label: 'Joueur 1',
                            items: options.players,
                            value: _player1,
                            onChanged: (id) => setState(() => _player1 = id),
                          ),
                        ),
                        SizedBox(width: 72, child: _score(_score1, 'Score')),
                      ],
                    ),
                    Row(
                      spacing: 12,
                      children: [
                        Expanded(
                          child: _picker(
                            label: 'Joueur 2',
                            items: options.players,
                            value: _player2,
                            onChanged: (id) => setState(() => _player2 = id),
                          ),
                        ),
                        SizedBox(width: 72, child: _score(_score2, 'Score')),
                      ],
                    ),
                    if (widget.game == null)
                      _picker(
                        label: 'Jeu',
                        items: options.games,
                        value: _game,
                        onChanged: (id) => setState(() => _game = id),
                      ),
                    // Lieu facultatif, parmi ceux de la table des lieux.
                    _picker(
                      label: 'Lieu (facultatif)',
                      items: options.places,
                      value: _place,
                      onChanged: (id) => setState(() => _place = id),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _date == null
                                ? "Date : aujourd'hui"
                                : 'Date : ${formatDate(_date!)}',
                            style: TextStyle(color: muted),
                          ),
                        ),
                        if (_date != null)
                          IconButton(
                            tooltip: "Revenir à aujourd'hui",
                            onPressed: _busy
                                ? null
                                : () => setState(() => _date = null),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        TextButton(
                          onPressed: _busy ? null : _pickDate,
                          child: const Text('Choisir'),
                        ),
                      ],
                    ),
                    if (_error case final error?)
                      Text(
                        error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE5534B),
                        ),
                      ),
                    // Passe à la ligne s'il manque de place.
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: 8,
                      overflowAlignment: OverflowBarAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(foregroundColor: muted),
                          child: const Text('Annuler'),
                        ),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AccentStyle.of(context).color,
                            foregroundColor: Colors.white,
                          ),
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Ajouter'),
                        ),
                      ],
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
