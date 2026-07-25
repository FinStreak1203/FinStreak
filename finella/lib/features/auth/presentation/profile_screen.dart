import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/user_profile.dart';
import '../viewmodel/auth_view_model.dart';

/// Read-only profile screen showing the registered user's details.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF4),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2E7D32),
          ),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
        ),
        error: (_, _) => const Center(
          child: Text('Could not load profile',
              style: TextStyle(color: Color(0xFF6B7280))),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Not signed in'));
          }
          return _ProfileBody(profile: profile);
        },
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final UserProfile profile;
  const _ProfileBody({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Avatar + name ──────────────────────────────
        Center(
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D32),
                  shape: BoxShape.circle,
                ),
                child: profile.photoUrl.isNotEmpty
                    ? Image.network(
                        profile.photoUrl,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _Initials(profile.initials),
                      )
                    : _Initials(profile.initials),
              ),
              const SizedBox(height: 14),
              Text(
                profile.isGuest
                    ? 'Guest'
                    : (profile.fullName.isEmpty ? 'No name set' : profile.fullName),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              if (profile.email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Detail card ────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEFF1F0)),
          ),
          child: Column(
            children: [
              _Row(label: 'First name', value: profile.firstName),
              const _Divider(),
              _Row(label: 'Last name', value: profile.lastName),
              const _Divider(),
              _Row(label: 'Email', value: profile.email),
              const _Divider(),
              _Row(label: 'Phone number', value: profile.phone),
            ],
          ),
        ),

        if (profile.isGuest) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: const Text(
              'You are signed in as a guest. Sign up to save your details.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Initials extends StatelessWidget {
  final String initials;
  const _Initials(this.initials);

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final shown = value.trim().isEmpty ? '—' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              shown,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: value.trim().isEmpty
                    ? const Color(0xFFD1D5DB)
                    : const Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        thickness: 0.5,
        indent: 16,
        endIndent: 16,
        color: Color(0xFFF3F4F6),
      );
}
