class User {
  final String usn;
  final String name;
  final String branch;
  final String semester;
  final String section;
  final String? profileImageUrl;
  final String? lastUpdated;

  const User({
    required this.usn,
    required this.name,
    required this.branch,
    required this.semester,
    required this.section,
    this.profileImageUrl,
    this.lastUpdated,
  });

  String get displayName {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    return parts.map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase()).join(' ');
  }

  String get initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.substring(0, 2).toUpperCase();
  }

  User copyWith({
    String? usn,
    String? name,
    String? branch,
    String? semester,
    String? section,
    String? profileImageUrl,
    String? lastUpdated,
  }) {
    return User(
      usn: usn ?? this.usn,
      name: name ?? this.name,
      branch: branch ?? this.branch,
      semester: semester ?? this.semester,
      section: section ?? this.section,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
