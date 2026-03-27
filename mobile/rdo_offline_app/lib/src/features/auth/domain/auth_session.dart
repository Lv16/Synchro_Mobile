class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    this.userId,
    this.username,
    this.expiresAt,
  });

  final String accessToken;
  final String tokenType;
  final int? userId;
  final String? username;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!.toLocal());

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'access_token': accessToken,
      'token_type': tokenType,
      'user_id': userId,
      'username': username,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: (json['access_token'] ?? '').toString(),
      tokenType: (json['token_type'] ?? 'Bearer').toString(),
      userId: _coerceInt(json['user_id']),
      username: json['username']?.toString(),
      expiresAt: DateTime.tryParse((json['expires_at'] ?? '').toString()),
    );
  }
}

int? _coerceInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
