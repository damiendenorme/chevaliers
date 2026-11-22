import 'package:flutter/material.dart';

import 'top_bar.dart';

/// Fenêtre au design des cartes qui demande un nom ([label]) et, si
/// [askDate], une date facultative ; puis appelle [onSubmit]. Se ferme si
/// tout va bien ; affiche l'erreur sinon.
class NameDialog extends StatefulWidget {
  const NameDialog({
    super.key,
    required this.title,
    required this.label,
    required this.onSubmit,
    this.askDate = false,
  });

  final String title;
  final String label;
  final bool askDate;

  /// Le nom, et la date choisie (null si aucune ou pas demandée).
  final Future<void> Function(String name, DateTime? date) onSubmit;

  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  final _name = TextEditingController();
  DateTime? _date;
  bool _busy = false;
  String? _error;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Le nom est obligatoire.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(name, _date);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = "L'enregistrement a échoué.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
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
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                TextField(
                  controller: _name,
                  autofocus: true,
                  decoration: InputDecoration(labelText: widget.label),
                  enabled: !_busy,
                  onSubmitted: (_) => _submit(),
                ),
                if (widget.askDate)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _date == null
                              ? 'Date : aucune'
                              : 'Date : ${_date!.day}/${_date!.month}/${_date!.year}',
                          style: TextStyle(color: muted),
                        ),
                      ),
                      if (_date != null)
                        IconButton(
                          tooltip: 'Retirer la date',
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
            ),
          ),
        ),
      ),
    );
  }
}
