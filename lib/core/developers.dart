/// Shown in Settings → Developer info (every group member and what they did).
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
const String groupName = 'BSCPE-4A';

const List<Developer> developers = [
  Developer(
    name: 'Jairus Legor C. Maniago',
    role: 'Group Leader · Project Lead / Backend',
    contributions: [
      'Project planning, app structure and putting everyone’s work together',
      'Supabase schema, row level security, storage buckets and seed data',
      'Authentication: register, login with e-mail codes, change password',
      'Android and iOS builds (Codemagic) and the GitHub repository',
    ],
  ),
  Developer(
    name: 'Aron Alvarez',
    role: 'Frontend / Newsfeed',
    contributions: [
      'Newsfeed: For you and Following timelines',
      'Post composer: text, photos, polls and replies',
      'Likes, reposts, bookmarks and the post page',
    ],
  ),
  Developer(
    name: 'Lenard Dela Cruz',
    role: 'Messaging / Notifications',
    contributions: [
      'Real-time direct messages',
      'Chat settings and the notifications tab',
      'Notes (short status)',
    ],
  ),
  Developer(
    name: 'Dwayne Guevarra',
    role: 'Profile / Social',
    contributions: [
      'Profile page, edit profile and avatar / header upload',
      'Follow system, followers and following lists',
      'People search and Who to follow',
    ],
  ),
  Developer(
    name: 'Shannon Santos',
    role: 'UI / UX Design',
    contributions: [
      'X-style look: icons, light and dark theme, tab bar',
      'Settings and privacy screens',
      'Communities and Lists screens',
    ],
  ),
  Developer(
    name: 'Adrian Tedios',
    role: 'Testing / Documentation',
    contributions: [
      'Testing on Android and iOS and reporting bugs',
      'Writing the README and the setup guide',
      'Demo accounts and sample posts for the presentation',
    ],
  ),
];
