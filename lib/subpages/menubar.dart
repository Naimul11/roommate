import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roommate/profile.dart';
import 'package:roommate/update_profile.dart';

class MenuAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showMenuButton;

  const MenuAppBar({
    super.key,
    required this.title,
    this.showMenuButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      backgroundColor: Colors.blue[700],
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
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class MenuDrawer extends StatelessWidget {
  const MenuDrawer({super.key});

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
              padding: const EdgeInsets.fromLTRB(20, 90, 20, 30), // move everything further down
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
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  
                ),
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
                                  MaterialPageRoute(builder: (context) => const ProfilePage()),
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
                                  MaterialPageRoute(builder: (context) => const UpdateProfilePage()),
                                );
                              },
                            ),
                          _buildModernMenuItem(
                            context,
                            icon: Icons.search,
                            title: 'Find Roommate',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushReplacementNamed(context, '/findroommate');
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
                          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: iconColor ?? Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: textColor ?? Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
