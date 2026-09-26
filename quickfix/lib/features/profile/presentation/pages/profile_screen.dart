import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quickfix/core/theme/app_colors.dart';
import 'package:quickfix/core/theme/app_text_styles.dart';
import 'package:quickfix/core/utils/haptics.dart';
import 'package:quickfix/features/home/presentation/controllers/home_providers.dart';
import 'package:quickfix/features/auth/presentation/controllers/auth_providers.dart';
import 'package:quickfix/features/profile/presentation/pages/order_history_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (authState.isLoading && user == null) {
      return Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        body: _buildSkeletonLoader(isDark),
      );
    }

    final String name = user?['name']?.toString() ?? '';
    final String phone = user?['phone']?.toString() ?? '';
    final String email = user?['email']?.toString() ?? '';
    final String avatarUrl = user?['avatarUrl']?.toString() ?? '';
    final bool isPhoneVerified = user?['isPhoneVerified'] as bool? ?? true;
    final int referralCount = (user?['referralCount'] as num?)?.toInt() ?? 0;
    final savedAddresses = user?['savedAddresses'] as List<dynamic>? ?? [];
    final String memberSinceRaw = user?['memberSince']?.toString() ?? '';
    String memberSince = '';
    try {
      if (memberSinceRaw.isNotEmpty) {
        memberSince = DateFormat(
          'MMM yyyy',
        ).format(DateTime.parse(memberSinceRaw));
      }
    } catch (_) {}

    final bookingsAsync = ref.watch(customerBookingsProvider);
    final String bookingsCount = bookingsAsync.maybeWhen(
      data: (list) => list.length.toString(),
      orElse: () => '...',
    );

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(currentNavIndexProvider.notifier).state = 0;
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ---------- Gradient Header ----------
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: AppColors.primary,
              iconTheme: const IconThemeData(color: Colors.white),
              leading: IconButton(
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                tooltip: 'Back',
                onPressed: () {
                  AppHaptics.lightTap();
                  if (Navigator.of(context).canPop()) {
                    context.pop();
                  } else {
                    ref.read(currentNavIndexProvider.notifier).state = 0;
                    context.go('/home');
                  }
                },
              ),
              actions: [
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: Colors.white,
                ),
                onPressed: () {
                  AppHaptics.mediumTap();
                  ref.read(isDarkModeProvider.notifier).toggleTheme();
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () {
                  AppHaptics.lightTap();
                  context.push('/settings');
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      children: [
                        const SizedBox(height: 44), // Space for app bar actions
                        Row(
                          children: [
                            // Avatar
                            GestureDetector(
                              onTap: () {
                                AppHaptics.lightTap();
                                context.push('/edit-profile');
                              },
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    width: 82,
                                    height: 82,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primaryAccent,
                                        width: 2.5,
                                      ),
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        avatarUrl.isNotEmpty
                                            ? avatarUrl
                                            : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
                                        fit: BoxFit.cover,
                                        cacheWidth: 240,
                                        errorBuilder: (_, __, ___) =>
                                            _avatarPlaceholder(name),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 11,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isNotEmpty ? name : 'Set Your Name',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  // Phone with verified badge
                                  Row(
                                    children: [
                                      Text(
                                        phone.isNotEmpty
                                            ? (phone.startsWith('+') ? phone : '+91 ${phone.replaceFirst('+91', '').trim()}')
                                            : 'No phone',
                                        style: GoogleFonts.inter(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (isPhoneVerified &&
                                          phone.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.success.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: AppColors.success
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.verified,
                                                size: 10,
                                                color: AppColors.success,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                'Verified',
                                                style: GoogleFonts.outfit(
                                                  color: AppColors.success,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Email or Add Email CTA
                                  GestureDetector(
                                    onTap: () => context.push('/edit-profile'),
                                    child: Row(
                                      children: [
                                        Icon(
                                          email.isNotEmpty
                                              ? Icons.email_outlined
                                              : Icons.add_circle_outline,
                                          size: 13,
                                          color: Colors.white60,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          email.isNotEmpty
                                              ? email
                                              : 'Add Email Address',
                                          style: GoogleFonts.inter(
                                            color: email.isNotEmpty
                                                ? Colors.white60
                                                : Colors.white.withValues(
                                                    alpha: 0.5,
                                                  ),
                                            fontSize: 12,
                                            fontStyle: email.isEmpty
                                                ? FontStyle.italic
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (memberSince.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  color: Colors.white70,
                                  size: 12,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Member Since $memberSince',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------- Quick Stats ----------
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.25 : 0.04,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildStatItem(
                          icon: Icons.location_on_outlined,
                          label: 'Addresses',
                          value: savedAddresses.length.toString(),
                          color: AppColors.catPlumbingIcon,
                          isDark: isDark,
                          onTap: () => context.push('/addresses'),
                        ),
                        _buildStatDivider(isDark),
                        _buildStatItem(
                          icon: Icons.receipt_long_outlined,
                          label: 'Orders',
                          value: bookingsCount,
                          color: AppColors.info,
                          isDark: isDark,
                          onTap: () {
                            ref.read(currentNavIndexProvider.notifier).state =
                                1;
                            context.go('/orders');
                          },
                        ),
                        _buildStatDivider(isDark),
                        _buildStatItem(
                          icon: Icons.group_outlined,
                          label: 'Referrals',
                          value: referralCount.toString(),
                          color: Colors.purple,
                          isDark: isDark,
                          onTap: () => context.push('/refer-earn'),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05),

                  const SizedBox(height: 20),

                  // ---------- Account Section ----------
                  _buildSectionLabel('Account', isDark),
                  const SizedBox(height: 8),
                  _buildTileGroup(
                    isDark: isDark,
                    tiles: [
                      const _ProfileTile(
                        icon: Icons.person_outline,
                        label: 'Edit Profile',
                        subtitle: 'Name, photo, gender, DOB',
                        color: AppColors.primaryAccent,
                        route: '/edit-profile',
                      ),
                      const _ProfileTile(
                        icon: Icons.location_on_outlined,
                        label: 'Saved Addresses',
                        subtitle: 'Manage home, work & other',
                        color: AppColors.catPlumbingIcon,
                        route: '/addresses',
                      ),
                    ],
                    context: context,
                    ref: ref,
                  ),

                  const SizedBox(height: 20),

                  // ---------- Activity Section ----------
                  _buildSectionLabel('Activity', isDark),
                  const SizedBox(height: 8),
                  _buildTileGroup(
                    isDark: isDark,
                    tiles: [
                      const _ProfileTile(
                        icon: Icons.history_outlined,
                        label: 'Order History',
                        subtitle: 'Track past & current jobs',
                        color: AppColors.info,
                        route: '/orders',
                        isNavTab: true,
                      ),
                      const _ProfileTile(
                        icon: Icons.local_offer_outlined,
                        label: 'Coupons & Offers',
                        subtitle: 'Exclusive deals & discounts',
                        color: AppColors.catElectricianIcon,
                        route: '/offers',
                        isNavTab: true,
                      ),
                      const _ProfileTile(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        subtitle: 'Alerts & updates',
                        color: AppColors.catCleaningIcon,
                        route: '/notifications',
                      ),
                    ],
                    context: context,
                    ref: ref,
                  ),

                  const SizedBox(height: 20),

                  // ---------- Benefits Section ----------
                  _buildSectionLabel('Benefits', isDark),
                  const SizedBox(height: 8),
                  _buildTileGroup(
                    isDark: isDark,
                    tiles: [
                      const _ProfileTile(
                        icon: Icons.share_outlined,
                        label: 'Refer & Earn',
                        subtitle: 'Earn ₹100 per friend invited',
                        color: Colors.purple,
                        route: '/refer-earn',
                      ),
                    ],
                    context: context,
                    ref: ref,
                  ),

                  const SizedBox(height: 20),

                  // ---------- Support Section ----------
                  _buildSectionLabel('Help & Support', isDark),
                  const SizedBox(height: 8),
                  _buildTileGroup(
                    isDark: isDark,
                    tiles: [
                      const _ProfileTile(
                        icon: Icons.support_agent_outlined,
                        label: 'Help & Support',
                        subtitle: 'Live chat • 24×7 helpdesk',
                        color: AppColors.catCarpentryIcon,
                        route: '/support',
                      ),
                      const _ProfileTile(
                        icon: Icons.star_rate_outlined,
                        label: 'Rate the App',
                        subtitle: 'Share feedback on Play Store',
                        color: AppColors.warning,
                        route: '',
                      ),
                      const _ProfileTile(
                        icon: Icons.share_outlined,
                        label: 'Share App',
                        subtitle: 'Invite friends to QuickFix',
                        color: Colors.teal,
                        route: '',
                      ),
                    ],
                    context: context,
                    ref: ref,
                  ),

                  const SizedBox(height: 20),

                  // ---------- Danger Zone ----------
                  _buildSectionLabel('Account & Security', isDark),
                  const SizedBox(height: 8),
                  _buildTileGroup(
                    isDark: isDark,
                    tiles: [
                      const _ProfileTile(
                        icon: Icons.security_outlined,
                        label: 'Privacy & Data',
                        subtitle: 'Account settings & permissions',
                        color: AppColors.textSecondaryLight,
                        route: '/settings',
                      ),
                      const _ProfileTile(
                        icon: Icons.delete_outline,
                        label: 'Delete Account',
                        subtitle: 'Permanently remove your data',
                        color: AppColors.error,
                        route: '',
                      ),
                    ],
                    context: context,
                    ref: ref,
                  ),

                  const SizedBox(height: 24),

                  // ---------- Logout Button ----------
                  ElevatedButton.icon(
                    onPressed: () async {
                      AppHaptics.heavyTap();
                      final confirm = await _showLogoutDialog(context, isDark);
                      if (confirm == true) {
                        ref.read(currentNavIndexProvider.notifier).state = 0;
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      'Logout',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.primaryAccent : AppColors.primary,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'QuickFix v1.0.0',
                      style: AppTextStyles.bodySmall(
                        isDark,
                      ).copyWith(fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _avatarPlaceholder(String name) {
    final initials = name.isNotEmpty
        ? name
              .trim()
              .split(' ')
              .take(2)
              .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
              .join()
        : '?';
    return Container(
      color: AppColors.primary.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.outfit(
            color: AppColors.primary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : AppColors.secondary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 1,
      height: 48,
      color: isDark ? AppColors.borderDark : AppColors.borderLight,
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildTileGroup({
    required bool isDark,
    required List<_ProfileTile> tiles,
    required BuildContext context,
    required WidgetRef ref,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1,
        ),
      ),
      child: Column(
        children: tiles.asMap().entries.map((entry) {
          final i = entry.key;
          final tile = entry.value;
          return Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(20) : Radius.zero,
                  bottom: i == tiles.length - 1
                      ? const Radius.circular(20)
                      : Radius.zero,
                ),
                onTap: () {
                  AppHaptics.lightTap();
                  if (tile.label == 'Logout') return;
                  if (tile.label == 'Rate the App') {
                    final Uri url = Uri.parse(
                      'https://play.google.com/store/apps/details?id=com.quickfix.customer',
                    );
                    try {
                      launchUrl(url, mode: LaunchMode.externalApplication);
                    } catch (_) {}
                    return;
                  }
                  if (tile.label == 'Share App') {
                    Share.share(
                      'Install QuickFix, the fastest hyperlocal service app! Use code QF100 for Rs.100 off: https://quickfix.com/download',
                    );
                    return;
                  }
                  if (tile.label == 'Delete Account') {
                    _showDeleteAccountDialog(context, ref, isDark);
                    return;
                  }
                  if (tile.route.isEmpty) return;
                  if (tile.isNavTab) {
                    int targetIndex = 1;
                    if (tile.route == '/orders') {
                      targetIndex = 1;
                    } else if (tile.route == '/offers') {
                      targetIndex = 4;
                    } else if (tile.route == '/wishlist') {
                      targetIndex = 3;
                    } else if (tile.route == '/home') {
                      targetIndex = 0;
                    }
                    ref.read(currentNavIndexProvider.notifier).state =
                        targetIndex;
                    context.go(tile.route);
                  } else {
                    context.push(tile.route);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tile.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(tile.icon, color: tile.color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tile.label,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.secondary,
                              ),
                            ),
                            Text(
                              tile.subtitle,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ],
                  ),
                ),
              ),
              if (i < tiles.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 58),
                  child: Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<bool?> _showLogoutDialog(BuildContext context, bool isDark) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Logout?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to logout from your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: Text('Logout', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              'Delete Account?',
              style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'This will permanently delete your account and all associated data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(authProvider.notifier).deleteAccount();
                if (context.mounted) {
                  context.go('/login');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader(bool isDark) {
    final baseColor = isDark ? AppColors.surfaceDark : Colors.grey.shade200;
    final highlightColor = isDark ? AppColors.borderDark : Colors.grey.shade100;
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTile {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String route;
  final bool isNavTab;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.route,
    this.isNavTab = false,
  });
}
