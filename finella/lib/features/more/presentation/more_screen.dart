import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_names.dart';
import '../../home/providers/home_provider.dart';
import '../../auth/viewmodel/auth_view_model.dart';

/// "More" hub — grid layout. Gathers secondary destinations into a 3×3 grid.
/// Existing screens (Settings, Goals, Accounts as "Net Worth", Budgets as
/// "Money Saving", Profile) keep their navigation; not-yet-built screens show a
/// "Coming soon" placeholder.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5EF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page title
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 6, 20, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('More',
                        style: TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: Color(0xFF1A3A1A))),
                    Text('Everything you need. All in one place.',
                        style: TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: 12,
                            color: Color(0xFF999999))),
                  ],
                ),
              ),

              _buildProfileCard(context, ref),

              const Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Text('MANAGE',
                    style: TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Color(0xFFAAAAAA))),
              ),

              _buildGrid(context),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Profile card ──────────────────────────────────────────────
  Widget _buildProfileCard(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final score = ref.watch(homeProvider).aiScore;
    final name = (profile?.fullName.trim().isNotEmpty ?? false)
        ? profile!.fullName
        : 'Finella User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'F';
    final memberSince =
        FirebaseAuth.instance.currentUser?.metadata.creationTime?.year ??
            DateTime.now().year;

    return GestureDetector(
      onTap: () => context.push(RouteNames.profile),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE0ECE0), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          // Avatar with green badge
          Stack(children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ),
              ),
              child: Center(
                child: Text(initial,
                    style: const TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check, size: 8, color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: Color(0xFF111111))),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 12,
                        color: Color(0xFF555555)),
                    children: [
                      const TextSpan(text: 'Financial Score: '),
                      TextSpan(
                        text: '$score',
                        style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 1),
                Text('Member since $memberSince',
                    style: const TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 11,
                        color: Color(0xFFAAAAAA))),
              ],
            ),
          ),
          const Text('›',
              style: TextStyle(fontSize: 18, color: Color(0xFFCCCCCC))),
        ]),
      ),
    );
  }

  // ── 3×3 grid ──────────────────────────────────────────────────
  Widget _buildGrid(BuildContext context) {
    void open(String route) => context.push(route);
    void soon(String title) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _PlaceholderScreen(title: title)),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
        children: [
          _gridItem('Reports', Icons.show_chart, () => soon('Reports')),
          _gridItem('Split', Icons.swap_horiz, () => soon('Split')),
          _gridItem('Settings', Icons.settings_outlined,
              () => open(RouteNames.settings)),
          _gridItem('Tax Returns', Icons.description_outlined,
              () => soon('Tax Returns')),
          // Money Saving → existing Budgets screen
          _gridItem('Money Saving', Icons.savings_outlined,
              () => open(RouteNames.budgets)),
          _gridItem('Documents', Icons.folder_outlined,
              () => soon('Documents')),
          // Net Worth → existing Accounts screen
          _gridItem('Net Worth', Icons.account_balance_outlined,
              () => open(RouteNames.accounts)),
          _gridItem('Investments', Icons.trending_up,
              () => soon('Investments')),
          _gridItem('Goals', Icons.my_location_outlined,
              () => open(RouteNames.goals)),
        ],
      ),
    );
  }

  Widget _gridItem(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE4F0DE), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, color: const Color(0xFF2E7D32), size: 30),
            ),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: Color(0xFF333333))),
        ],
      ),
    );
  }
}

/// Shown for grid destinations whose screens don't exist yet.
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5EF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: const BackButton(color: Color(0xFF2E7D32)),
        title: Text(title,
            style: const TextStyle(
                fontFamily: 'OpenSans',
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E7D32))),
      ),
      body: const Center(
        child: Text('Coming soon',
            style: TextStyle(fontFamily: 'OpenSans', color: Color(0xFF999999))),
      ),
    );
  }
}

/* ───────────── OLD LIST LAYOUT (kept for reference, not used) ─────────────
   The previous More screen was a vertical list of ListTiles. Replaced by the
   grid above. Goals/Accounts/Budgets/Settings/Profile remain reachable from
   the grid (Accounts → "Net Worth", Budgets → "Money Saving").

  Widget _tile(BuildContext context, IconData icon, String title,
      String subtitle, String route) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4F0DE), width: 1),
      ),
      child: ListTile(
        onTap: () => context.push(route),
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: const Color(0xFFEAF5E4),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 19, color: const Color(0xFF2E7D32)),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
      ),
    );
  }

  // List items used:
  //   _tile(context, Icons.track_changes_outlined, 'Goals', '...', RouteNames.goals)
  //   _tile(context, Icons.account_balance_outlined, 'Accounts', '...', RouteNames.accounts)
  //   _tile(context, Icons.pie_chart_outline, 'Budgets', '...', RouteNames.budgets)
  //   _tile(context, Icons.local_fire_department_outlined, 'Streak', '...', RouteNames.streak)
  //   _tile(context, Icons.settings_outlined, 'Settings', '...', RouteNames.settings)
  //   _tile(context, Icons.person_outline, 'Profile', '...', RouteNames.profile)
─────────────────────────────────────────────────────────────────────────── */
