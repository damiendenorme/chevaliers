import 'package:flutter/material.dart';

import '../data/auth.dart';
import 'top_bar.dart';

/// Petit lien « Connexion » (ou « Déconnexion » une fois connecté) : l'entrée
/// du backoffice. « Connexion » ouvre le formulaire de connexion.
class LoginLink extends StatefulWidget {
  const LoginLink({super.key, required this.auth});

  final AppAuth auth;

  @override
  State<LoginLink> createState() => _LoginLinkState();
}

class _LoginLinkState extends State<LoginLink> {
  late final Stream<bool> _signedIn = widget.auth.signedIn;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return StreamBuilder<bool>(
      stream: _signedIn,
      initialData: false,
      builder: (context, snapshot) {
        final signedIn = !snapshot.hasError && (snapshot.data ?? false);
        return TextButton(
          style: TextButton.styleFrom(
            foregroundColor: color,
            // La police de l'app (Cinzel), en petit.
            textStyle: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontSize: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: signedIn
              ? widget.auth.signOut
              : () => showDialog<void>(
                  context: context,
                  builder: (_) => LoginDialog(auth: widget.auth),
                ),
          child: Text(signedIn ? 'Déconnexion' : 'Connexion'),
        );
      },
    );
  }
}

/// Formulaire de connexion, au design des cartes : e-mail et mot de passe.
/// Se ferme une fois connecté ; affiche l'erreur sinon.
class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key, required this.auth});

  final AppAuth auth;

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.signIn(_email.text.trim(), _password.text);
      if (mounted) Navigator.of(context).pop();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
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
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  const Text(
                    'Connexion',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    enabled: !_busy,
                  ),
                  TextField(
                    controller: _password,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                    ),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    enabled: !_busy,
                    onSubmitted: (_) => _submit(),
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
                            : const Text('Se connecter'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
