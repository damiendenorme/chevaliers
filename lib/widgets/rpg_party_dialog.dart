import 'package:flutter/material.dart';

import '../data/rows.dart';
import '../data/rpg_rows.dart';
import 'top_bar.dart';

/// Fenêtre au design des cartes pour ajouter une partie de JDR : le jeu et
/// le MJ (obligatoires), le scénario (facultatif), les joueurs (plusieurs), le lieu et
/// l'événement (facultatifs), et la date (jour, mois, année ; aujourd'hui par
/// défaut). Appelle [onSubmit], puis se ferme ; affiche l'erreur sinon.
class RpgPartyDialog extends StatefulWidget {
  const RpgPartyDialog({
    super.key,
    required this.options,
    required this.onSubmit,
  });

  final Future<RpgPartyOptions> options;
  final Future<void> Function(NewRpgParty party) onSubmit;

  @override
  State<RpgPartyDialog> createState() => _RpgPartyDialogState();
}

class _RpgPartyDialogState extends State<RpgPartyDialog> {
  int? _game;
  int? _gm;
  final _guests = <int>{};
  int? _place;
  int? _event;
  final _scenario = TextEditingController();
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _scenario.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final error = switch (()) {
      _ when _game == null => 'Choisissez le jeu.',
      _ when _gm == null => 'Choisissez le MJ.',
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
        game: _game!,
        gm: _gm!,
        // Le MJ n'est pas compté parmi les joueurs.
        guests: [
          for (final g in _guests)
            if (g != _gm) g,
        ],
        place: _place,
        event: _event,
        scenario: _scenario.text.trim().isEmpty ? null : _scenario.text.trim(),
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
    bool optional = false,
  }) => DropdownButtonFormField<int?>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      if (optional) const DropdownMenuItem(child: Text('—')),
      for (final (id, name) in items)
        DropdownMenuItem(
          value: id,
          child: Text(name, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: _busy ? null : onChanged,
  );

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final accent = AccentStyle.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SizedBox(
        width: 460,
        child: CardSurface(
          Padding(
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<RpgPartyOptions>(
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
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      const Text(
                        'Nouvelle partie',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18),
                      ),
                      _picker(
                        label: 'Jeu',
                        items: options.games,
                        value: _game,
                        onChanged: (id) => setState(() => _game = id),
                      ),
                      TextField(
                        controller: _scenario,
                        decoration: const InputDecoration(
                          labelText: 'Scénario (facultatif)',
                        ),
                        enabled: !_busy,
                      ),
                      _picker(
                        label: 'MJ',
                        items: options.players,
                        value: _gm,
                        onChanged: (id) => setState(() => _gm = id),
                      ),
                      // Joueurs : plusieurs, à cocher (le MJ exclu).
                      Text(
                        'Joueurs',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final (id, name) in options.players)
                            if (id != _gm)
                              FilterChip(
                                label: Text(name),
                                selected: _guests.contains(id),
                                selectedColor: accent.color,
                                checkmarkColor: Colors.white,
                                onSelected: _busy
                                    ? null
                                    : (on) => setState(
                                        () => on
                                            ? _guests.add(id)
                                            : _guests.remove(id),
                                      ),
                              ),
                        ],
                      ),
                      _picker(
                        label: 'Lieu (facultatif)',
                        items: options.places,
                        value: _place,
                        optional: true,
                        onChanged: (id) => setState(() => _place = id),
                      ),
                      _picker(
                        label: 'Événement (facultatif)',
                        items: options.events,
                        value: _event,
                        optional: true,
                        onChanged: (id) => setState(() => _event = id),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Date : ${formatFullDate(_date)}',
                              style: TextStyle(color: muted),
                            ),
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
                              backgroundColor: accent.color,
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
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
