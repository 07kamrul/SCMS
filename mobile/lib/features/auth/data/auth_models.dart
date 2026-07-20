import 'package:mobile/core/auth/permission.dart';

/// Mirrors `backend/app/models/enums.py::UserStatus` exactly.
enum UserStatus {
  active('active'),
  inactive('inactive'),
  suspended('suspended');

  const UserStatus(this.value);

  final String value;

  static UserStatus fromWire(String value) {
    return UserStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw ArgumentError('Unknown user status wire value: $value'),
    );
  }
}

/// Mirrors `backend/app/schemas/auth.py::UserPublic`.
class UserPublic {
  const UserPublic({
    required this.id,
    required this.companyId,
    required this.fullName,
    this.email,
    this.phone,
    required this.role,
    required this.status,
    this.profilePhotoUrl,
    this.jobTitle,
    required this.isIdentityVerified,
  });

  final String id;
  final String companyId;
  final String fullName;
  final String? email;
  final String? phone;
  final Role role;
  final UserStatus status;
  final String? profilePhotoUrl;
  final String? jobTitle;
  final bool isIdentityVerified;

  factory UserPublic.fromJson(Map<String, dynamic> json) {
    return UserPublic(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: Role.fromWire(json['role'] as String),
      status: UserStatus.fromWire(json['status'] as String),
      profilePhotoUrl: json['profile_photo_url'] as String?,
      jobTitle: json['job_title'] as String?,
      isIdentityVerified: json['is_identity_verified'] as bool,
    );
  }
}

/// Mirrors `backend/app/schemas/auth.py::TokenPair`.
class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }
}

/// Mirrors `backend/app/schemas/auth.py::LoginResponse`.
class LoginResponse {
  const LoginResponse({required this.user, required this.tokens});

  final UserPublic user;
  final TokenPair tokens;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      user: UserPublic.fromJson(json['user'] as Map<String, dynamic>),
      tokens: TokenPair.fromJson(json['tokens'] as Map<String, dynamic>),
    );
  }
}
