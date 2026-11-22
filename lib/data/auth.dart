import 'package:supabase_flutter/supabase_flutter.dart';

/// Connexion au backoffice (e-mail + mot de passe). Une interface, pour que
/// les tests puissent la remplacer.
abstract class AppAuth {
  /// Connecté ou non : la valeur actuelle, puis chaque changement.
  Stream<bool> get signedIn;

  /// Lève [AuthFailure] si l'e-mail ou le mot de passe est refusé.
  Future<void> signIn(String email, String password);

  Future<void> signOut();
}

/// Échec de connexion, avec un message à afficher.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}

/// Connexion par Supabase Auth. Les comptes se créent dans le tableau de
/// bord Supabase (l'inscription publique est fermée).
class SupabaseAuth implements AppAuth {
  const SupabaseAuth();

  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  Stream<bool> get signedIn async* {
    yield _auth.currentSession != null;
    yield* _auth.onAuthStateChange.map((state) => state.session != null);
  }

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
    } on AuthException {
      throw const AuthFailure('E-mail ou mot de passe incorrect.');
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
