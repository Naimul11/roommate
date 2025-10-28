import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roommate/profile.dart';
import 'package:roommate/update_profile.dart';
import 'package:roommate/subpages/notifications.dart';
import 'package:roommate/subpages/createroom.dart';
import 'package:roommate/subpages/roomlist.dart';
import 'package:roommate/subpages/contribution.dart';
import 'package:roommate/subpages/roommate_contri.dart';
import 'package:roommate/subpages/create_work.dart';
import 'package:roommate/subpages/work_schedule.dart';
import 'package:roommate/subpages/notice.dart';
import 'package:roommate/subpages/sos.dart';
import 'package:roommate/subpages/about.dart';

class MenuAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showMenuButton;
  final Color? backgroundColor;

  const MenuAppBar({
    super.key,
    required this.title,
    this.showMenuButton = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return AppBar(
      title: Text(title),
      backgroundColor: backgroundColor ?? Colors.blue[700],
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: showMenuButton
          ? Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            )
          : null,
      actions: currentUser != null
          ? [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .collection('notifications')
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.hasData
                      ? snapshot.data!.docs.length
                      : 0;

                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsPage(),
                            ),
                          );
                        },
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ]
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class MenuDrawer extends StatefulWidget {
  const MenuDrawer({super.key});

  @override
  State<MenuDrawer> createState() => _MenuDrawerState();
}

class _MenuDrawerState extends State<MenuDrawer> {
  bool _isRoomManagementExpanded = false;
  bool _isWorkManagementExpanded = false;

  bool _isProfilePage(BuildContext context) {
    // Check if current route is ProfilePage
    final route = ModalRoute.of(context);
    if (route?.settings.name == '/profile') return true;

    // Also check widget ancestry
    return context.findAncestorWidgetOfExactType<ProfilePage>() != null;
  }

  @override
  Widget build(BuildContext context) {
    final isProfilePage = _isProfilePage(context);

    return Drawer(
      width: 250,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[700]!, Colors.blue[500]!],
          ),
        ),
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: const EdgeInsets.fromLTRB(
                20,
                90,
                20,
                30,
              ), // move everything further down
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo on the left
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: Colors.white,
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/room.png',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Roommate',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.grey[900]),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        children: [
                          if (!isProfilePage)
                            _buildModernMenuItem(
                              context,
                              icon: Icons.person_outline,
                              title: 'Profile',
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ProfilePage(),
                                  ),
                                );
                              },
                            ),
                          if (isProfilePage)
                            _buildModernMenuItem(
                              context,
                              icon: Icons.edit_outlined,
                              title: 'Update Profile',
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const UpdateProfilePage(),
                                  ),
                                );
                              },
                            ),
                          _buildModernMenuItem(
                            context,
                            icon: Icons.hotel,
                            title: 'Find Room',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushReplacementNamed(
                                context,
                                '/findroom',
                              );
                            },
                          ),
                          _buildModernMenuItem(
                            context,
                            icon: Icons.search,
                            title: 'Find Roommate',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushReplacementNamed(
                                context,
                                '/findroommate',
                              );
                            },
                          ),
                          // Room Management with submenu
                          _buildExpandableMenuItem(
                            context,
                            icon: Icons.meeting_room,
                            title: 'Room Management',
                            isExpanded: _isRoomManagementExpanded,
                            onTap: () {
                              setState(() {
                                _isRoomManagementExpanded =
                                    !_isRoomManagementExpanded;
                              });
                            },
                            children: [
                              _buildSubMenuItem(
                                context,
                                icon: Icons.add_circle_outline,
                                title: 'Create Room',
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CreateRoomPage(),
                                    ),
                                  );
                                },
                              ),
                              _buildSubMenuItem(
                                context,
                                icon: Icons.list_alt,
                                title: 'My Rooms',
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RoomListPage(),
                                    ),
                                  );
                                },
                              ),
                              _buildSubMenuItem(
                                context,
                                icon: Icons.payment,
                                title: 'My Contribution',
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ContributionPage(),
                                    ),
                                  );
                                },
                              ),
                              _buildSubMenuItem(
                                context,
                                icon: Icons.people_outline,
                                title: 'Roommate Contribution',
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RoommateContributionPage(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          // Work Management with submenu
                          _buildExpandableMenuItem(
                            context,
                            icon: Icons.assignment,
                            title: 'Work Management',
                            isExpanded: _isWorkManagementExpanded,
                            onTap: () {
                              setState(() {
                                _isWorkManagementExpanded =
                                    !_isWorkManagementExpanded;
                              });
                            },
                            children: [
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('rooms')
                                    .where(
                                      'creatorEmail',
                                      isEqualTo: FirebaseAuth
                                          .instance
                                          .currentUser
                                          ?.email,
                                    )
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final hasCreatedRooms =
                                      snapshot.hasData &&
                                      snapshot.data!.docs.isNotEmpty;

                                  return Column(
                                    children: [
                                      if (hasCreatedRooms)
                                        _buildSubMenuItem(
                                          context,
                                          icon: Icons.add_task,
                                          title: 'Create Work',
                                          onTap: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const CreateWorkPage(),
                                              ),
                                            );
                                          },
                                        ),
                                      _buildSubMenuItem(
                                        context,
                                        icon: Icons.schedule,
                                        title: 'Work Schedule',
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const WorkSchedulePage(),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                          _buildModernMenuItem(
                            context,
                            icon: Icons.announcement,
                            title: 'Notice',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const NoticePage(),
                                ),
                              );
                            },
                          ),
                          _buildModernMenuItem(
                            context,
                            icon: Icons.emergency,
                            title: 'SOS',
                            textColor: Colors.red[300],
                            iconColor: Colors.red[300],
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SOSPage(),
                                ),
                              );
                            },
                          ),
                          _buildModernMenuItem(
                            context,
                            icon: Icons.info_outline,
                            title: 'About',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AboutPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(color: Colors.grey[700], thickness: 1),
                    ),
                    _buildModernMenuItem(
                      context,
                      icon: Icons.logout,
                      title: 'Logout',
                      textColor: Colors.red[400]!,
                      iconColor: Colors.red[400]!,
                      onTap: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.of(
                            context,
                          ).pushNamedAndRemoveUntil('/login', (route) => false);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(icon, color: iconColor ?? Colors.white, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Container(),
          secondChild: Column(children: children),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildSubMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, right: 12, top: 4, bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: 0.05),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white70, size: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
