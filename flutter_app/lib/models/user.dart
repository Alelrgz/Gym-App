class User {
  final String id;
  final String username;
  final String? email;
  final String role;
  final String? profilePicture;
  final String token;

  User({
    required this.id,
    required this.username,
    this.email,
    required this.role,
    this.profilePicture,
    required this.token,
  });

  factory User.fromLoginResponse(Map<String, dynamic> json) {
    return User(
      id: json['user_id'].toString(),
      username: json['username'] as String,
      email: json['email'] as String?,
      role: json['role'] as String,
      profilePicture: json['profile_picture'] as String?,
      token: json['access_token'] as String,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      username: json['username'] as String,
      email: json['email'] as String?,
      role: json['role'] as String,
      profilePicture: json['profile_picture'] as String?,
      token: json['token'] as String,
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
    };
  }
}
