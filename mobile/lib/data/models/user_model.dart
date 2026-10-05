class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
    this.nickname,
    this.phone,
    this.birthDate,
    this.avatarUpdatedAt,
  });

  final String id;
  final String email;
  final String name;
  final DateTime createdAt;
  final String? nickname;
  final String? phone;

  /// Tanggal saja, tanpa jam — dikirim API sebagai "YYYY-MM-DD".
  final DateTime? birthDate;

  /// null = belum ada foto. Dipakai juga sebagai kunci cache foto.
  final DateTime? avatarUpdatedAt;

  bool get hasAvatar => avatarUpdatedAt != null;

  /// Nama di sapaan Beranda: nama panggilan, atau kata pertama nama lengkap.
  String get greetingName {
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    return name.trim().split(RegExp(r'\s+')).first;
  }

  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  bool isBirthday(DateTime today) =>
      birthDate != null && birthDate!.month == today.month && birthDate!.day == today.day;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    nickname: json['nickname'] as String?,
    phone: json['phone'] as String?,
    birthDate: json['birthDate'] == null ? null : DateTime.parse(json['birthDate'] as String),
    avatarUpdatedAt: json['avatarUpdatedAt'] == null
        ? null
        : DateTime.parse(json['avatarUpdatedAt'] as String),
  );
}

/// Hasil login/register: user + sepasang token.
class AuthResult {
  const AuthResult({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final UserModel user;
  final String accessToken;
  final String refreshToken;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
  );
}
