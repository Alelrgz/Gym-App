class GymInfo {
  final String id;
  final String name;
  final String? logo;

  const GymInfo({required this.id, required this.name, this.logo});

  factory GymInfo.fromJson(Map<String, dynamic> json) {
    return GymInfo(
      id: json['id'].toString(),
      name: json['name'] as String? ?? 'Palestra',
      logo: json['logo'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'logo': logo};
}

class User {
  final String id;
  final String username;
  final String? email;
  final String role;
  final String? profilePicture;
  final String token;
  final List<GymInfo> gyms;

  User({
    required this.id,
    required this.username,
    this.email,
    required this.role,
    this.profilePicture,
    required this.token,
    this.gyms = const [],
  });

  factory User.fromLoginResponse(Map<String, dynamic> json) {
    final gymsList = (json['gyms'] as List<dynamic>?)
        ?.map((g) => GymInfo.fromJson(g as Map<String, dynamic>))
        .toList() ?? [];

    return User(
      id: json['user_id'].toString(),
      username: json['username'] as String,
      email: json['email'] as String?,
      role: json['role'] as String,
      profilePicture: json['profile_picture'] as String?,
      token: json['access_token'] as String,
      gyms: gymsList,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final gymsList = (json['gyms'] as List<dynamic>?)
        ?.map((g) => GymInfo.fromJson(g as Map<String, dynamic>))
        .toList() ?? [];

    return User(
      id: json['id'].toString(),
      username: json['username'] as String,
      email: json['email'] as String?,
      role: json['role'] as String,
      profilePicture: json['profile_picture'] as String?,
      token: json['token'] as String,
      gyms: gymsList,
    );
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? role,
    String? profilePicture,
    String? token,
    List<GymInfo>? gyms,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      profilePicture: profilePicture ?? this.profilePicture,
      token: token ?? this.token,
      gyms: gyms ?? this.gyms,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'profile_picture': profilePicture,
      'token': token,
      'gyms': gyms.map((g) => g.toJson()).toList(),
    };
  }
}
