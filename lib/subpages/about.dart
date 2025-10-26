import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About Us',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue[700]!,
                    Colors.blue[500]!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  // App Logo Placeholder
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.home_work,
                      size: 60,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Roommate',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your Complete Room Management Solution',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // App Description
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About Roommate',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Roommate is a comprehensive room management application designed to make shared living easier and more organized. Whether you\'re managing a apartment, dormitory, or shared house, our app provides all the tools you need to coordinate with your roommates effectively.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // Features Section
            Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Features',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(
                    icon: Icons.person_search,
                    title: 'Find Roommate',
                    description: 'Search and connect with potential roommates based on your preferences.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.hotel,
                    title: 'Find Room',
                    description: 'Browse available rooms and find the perfect place to live.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.meeting_room,
                    title: 'Room Management',
                    description: 'Create and manage your rooms, invite members, and organize your living space.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.payment,
                    title: 'Contribution Tracking',
                    description: 'Track your contributions and expenses. Monitor roommate payments easily.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.assignment,
                    title: 'Work Management',
                    description: 'Assign and track household chores and responsibilities.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.schedule,
                    title: 'Work Schedule',
                    description: 'View and manage work schedules for all roommates.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.announcement,
                    title: 'Notice Board',
                    description: 'Send important notices to all roommates via email.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.emergency,
                    title: 'Emergency SOS',
                    description: 'Quick call feature to contact roommates in case of emergency.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.notifications,
                    title: 'Real-time Notifications',
                    description: 'Stay updated with instant notifications for important events.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.login,
                    title: 'Google Sign-In',
                    description: 'Secure and easy authentication with Google account.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.cloud,
                    title: 'Cloud Storage',
                    description: 'All your data securely stored in the cloud with Firebase.',
                  ),
                ],
              ),
            ),

            // Team Section
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Our Team',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Students of Sonargaon University',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTeamMember('Fahim'),
                  _buildTeamMember('Zuyel Rana'),
                  _buildTeamMember('Ahmed Tamim'),
                  _buildTeamMember('Shadman Sumon'),
                  _buildTeamMember('Mejbaul Alam'),
                ],
              ),
            ),

            // Footer
            Container(
              width: double.infinity,
              color: Colors.grey[800],
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Roommate App',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '© 2025 Sonargaon University. All rights reserved.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMember(String name) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[700],
          radius: 28,
          child: Text(
            name[0].toUpperCase(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: const Text(
          'Developer',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
