import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roommate/menubar.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<Map<String, dynamic>?> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return doc.data();
  }

  static Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue[700]!;
    
    return Scaffold(
  backgroundColor: Colors.white,
      appBar: const MenuAppBar(title: 'Profile'),
      drawer: const MenuDrawer(),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(appBarColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading Profile...',
                    style: TextStyle(
                      color: appBarColor.withAlpha((0.7 * 255).round()),
                    ),
                  ),
                ],
              ),
            );
          }
          
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: appBarColor.withAlpha((0.3 * 255).round()),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No profile data found',
                    style: TextStyle(
                      fontSize: 16,
                      color: appBarColor.withAlpha((0.7 * 255).round()),
                    ),
                  ),
                ],
              ),
            );
          }
          
          final data = snapshot.data!;
          // Calculate age from dateOfBirth
          String ageText = 'Not set';
          if (data['dateOfBirth'] != null && data['dateOfBirth'].toString().isNotEmpty) {
            try {
              DateTime dob;
              final dobStr = data['dateOfBirth'].toString().trim();
              // Try parsing 'YYYY-MM-DD' first
              try {
                dob = DateTime.parse(dobStr);
              } catch (_) {
                final months = {
                  'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
                  'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
                };
                final parts = dobStr.split(' ');
                if (parts.length == 3 && months.containsKey(parts[1])) {
                  int day = int.tryParse(parts[0]) ?? 1;
                  int month = months[parts[1]]!;
                  int year = int.tryParse(parts[2]) ?? 2000;
                  dob = DateTime(year, month, day);
                } else {
                  throw Exception('Unrecognized date format');
                }
              }
              DateTime now = DateTime.now();
              int age = now.year - dob.year;
              if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
                age--;
              }
              ageText = '$age years';
            } catch (e) {
              ageText = 'Invalid date';
            }
          }
          
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[700]!, Colors.blue[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue[700]!.withAlpha((0.3 * 255).round()),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Profile Avatar with decorative ring
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha((0.1 * 255).round()),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            backgroundImage: data['profileImageUrl'] != null && 
                                            data['profileImageUrl'].toString().isNotEmpty
                                ? NetworkImage(data['profileImageUrl'])
                                : null,
                            child: data['profileImageUrl'] == null || 
                                   data['profileImageUrl'].toString().isEmpty
                                ? Icon(
                                    Icons.person_rounded,
                                    size: 60,
                                    color: appBarColor,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          data['nidName']?.toString() ?? 'Not set',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['occupation']?.toString() ?? 'Occupation not set',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Personal Information Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.05 * 255).round()),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: appBarColor.withAlpha((0.08 * 255).round()),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: appBarColor.withAlpha((0.1 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.person_outline_rounded,
                                size: 20,
                                color: appBarColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: appBarColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        _buildModernInfoRow(
                          icon: Icons.cake_rounded,
                          label: 'Age',
                          value: ageText,
                          appBarColor: appBarColor,
                        ),
                        const SizedBox(height: 20),
                        
                        _buildModernInfoRow(
                          icon: Icons.email_rounded,
                          label: 'Email',
                          value: data['email']?.toString() ?? 'Not set',
                          appBarColor: appBarColor,
                        ),
                        const SizedBox(height: 20),
                        
                        _buildModernInfoRow(
                          icon: Icons.phone_iphone_rounded,
                          label: 'WhatsApp Number',
                          value: data['whatsappNumber']?.toString() ?? 'Not set',
                          appBarColor: appBarColor,
                        ),
                        const SizedBox(height: 20),
                        
                        _buildModernInfoRow(
                          icon: Icons.badge_rounded,
                          label: 'NID Number',
                          value: data['nidNumber']?.toString() ?? 'Not set',
                          appBarColor: appBarColor,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Additional Information Card (if available)
                  if (_hasAdditionalInfo(data)) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: appBarColor.withAlpha((0.05 * 255).round()),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: appBarColor.withAlpha((0.08 * 255).round()),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: appBarColor.withAlpha((0.1 * 255).round()),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  size: 20,
                                  color: appBarColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Additional Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: appBarColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          if (data['bloodGroup'] != null && data['bloodGroup'].toString().isNotEmpty)
                            _buildModernInfoRow(
                              icon: Icons.bloodtype_rounded,
                              label: 'Blood Group',
                              value: data['bloodGroup'].toString(),
                              appBarColor: appBarColor,
                            ),
                          
                          if (data['religion'] != null && data['religion'].toString().isNotEmpty) ...[
                            if (data['bloodGroup'] != null && data['bloodGroup'].toString().isNotEmpty)
                              const SizedBox(height: 20),
                            _buildModernInfoRow(
                              icon: Icons.account_balance_rounded,
                              label: 'Religion',
                              value: data['religion'].toString(),
                              appBarColor: appBarColor,
                            ),
                          ],
                          
                          if (data['gender'] != null && data['gender'].toString().isNotEmpty) ...[
                            if ((data['bloodGroup'] != null && data['bloodGroup'].toString().isNotEmpty) || 
                                (data['religion'] != null && data['religion'].toString().isNotEmpty))
                              const SizedBox(height: 20),
                            _buildModernInfoRow(
                              icon: Icons.wc_rounded,
                              label: 'Gender',
                              value: data['gender'].toString(),
                              appBarColor: appBarColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color appBarColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: appBarColor.withAlpha((0.08 * 255).round()),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: appBarColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: appBarColor.withAlpha((0.7 * 255).round()),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: appBarColor,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _hasAdditionalInfo(Map<String, dynamic> data) {
    return (data['bloodGroup'] != null && data['bloodGroup'].toString().isNotEmpty) ||
           (data['religion'] != null && data['religion'].toString().isNotEmpty) ||
           (data['gender'] != null && data['gender'].toString().isNotEmpty);
  }
}