/// Credentials required to authenticate a user with the Kisi SDK.
///
/// Field mapping between platforms:
/// - iOS:     id, token (→ secret), key (→ phoneKey), certificate
/// - Android: id, secret,           phoneKey,          onlineCertificate (→ certificate)
class KisiLogin {
  /// The login ID obtained from the Kisi API.
  final int id;

  /// The login secret/token (iOS: `token`, Android: `secret`).
  final String secret;

  /// The phone key used for cryptographic operations (iOS: `key`, Android: `phoneKey`).
  final String phoneKey;

  /// The online certificate for offline unlock support
  /// (iOS: `certificate`, Android: `onlineCertificate`).
  final String certificate;

  const KisiLogin({
    required this.id,
    required this.secret,
    required this.phoneKey,
    required this.certificate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'secret': secret,
        'phoneKey': phoneKey,
        'certificate': certificate,
      };

  factory KisiLogin.fromMap(Map<dynamic, dynamic> map) => KisiLogin(
        id: map['id'] as int,
        secret: map['secret'] as String,
        phoneKey: map['phoneKey'] as String,
        certificate: map['certificate'] as String,
      );

  @override
  String toString() =>
      'KisiLogin(id: $id, secret: [redacted], phoneKey: [redacted], certificate: [redacted])';
}
