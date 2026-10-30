/// Shown in Settings → Developer info.
///
/// TODO(group): replace the placeholder entries below with your real group
/// members and what each person actually built. The assignment requires every
/// member and their contribution to be listed.
class Developer {
  const Developer({
    required this.name,
    required this.role,
    required this.contributions,
  });

  final String name;
  final String role;
  final List<String> contributions;
}

const String courseLine = 'Final Project · Cross-Platform Mobile Development';
const String groupName = 'Group Name (replace me)';

const List<Developer> developers = [
  Developer(
    name: 'Member 1 Full Name',
    role: 'Project Lead / Backend',
    contributions: [
      'Supabase schema, row level security and storage buckets',
      'Authentication: register, login, change password',
    ],
  ),
  Developer(
    name: 'Member 2 Full Name',
    role: 'Frontend / Feed',
    contributions: [
      'Newsfeed, post composer and image uploads',
      'Likes and Following / For you timelines',
    ],
  ),
  Developer(
    name: 'Member 3 Full Name',
    role: 'Social / Messaging',
    contributions: [
      'Real-time direct messaging',
      'Follow system and people search',
    ],
  ),
  Developer(
    name: 'Member 4 Full Name',
    role: 'Profile / QA',
    contributions: [
      'Profile management and avatar upload',
      'Testing and release builds',
    ],
  ),
];
