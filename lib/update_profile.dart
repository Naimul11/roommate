import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roommate/profile.dart';
import 'package:roommate/subpages/menubar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roommate/services/imagekit_service.dart';
import 'dart:io';

class UpdateProfilePage extends StatefulWidget {
  const UpdateProfilePage({super.key});

  @override
  State<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _ageRangeController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _occupationController = TextEditingController();
  String _roommateType = '';
  bool _isLoading = true;
  
  // Profile image
  File? _profileImage;
  String? _currentProfileImageUrl;
  final bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _bioController.text = data['bio'] ?? '';
          _ageRangeController.text = data['ageRange'] ?? '';
          _whatsappController.text = data['whatsappNumber'] ?? '';
          _occupationController.text = data['occupation'] ?? '';
          _roommateType = data['roommateType'] ?? '';
          _currentProfileImageUrl = data['profileImageUrl'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        
        // Check file size (max 2MB)
        final fileSize = await imageFile.length();
        const maxSize = 2 * 1024 * 1024; // 2MB
        
        if (fileSize > maxSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Image size must be less than 2MB. Current size: ${ImageKitService.formatFileSize(fileSize)}',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        setState(() {
          _profileImage = imageFile;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Profile image selected!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Updating profile...'),
                ],
              ),
              duration: Duration(seconds: 30),
            ),
          );
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('No user logged in');

        // Upload profile image to ImageKit if selected
        String? profileImageUrl = _currentProfileImageUrl;
        if (_profileImage != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 16),
                    Text('Uploading profile image...'),
                  ],
                ),
                duration: Duration(seconds: 30),
              ),
            );
          }

          final fileName = 'roommate_profile_${user.uid}.jpg';
          profileImageUrl = await ImageKitService.uploadImage(
            imageFile: _profileImage!,
            fileName: fileName,
            folder: 'roommate/profiles',
          );

          if (profileImageUrl == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(child: Text('Profile image upload failed')),
                    ],
                  ),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            profileImageUrl = _currentProfileImageUrl; // Keep old URL if upload fails
          }
        }

        // Update user data in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'bio': _bioController.text.trim(),
          'ageRange': _ageRangeController.text.trim(),
          'whatsappNumber': _whatsappController.text.trim(),
          'occupation': _occupationController.text.trim(),
          'roommateType': _roommateType,
          'profileImageUrl': profileImageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Profile updated successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
          // Navigate to ProfilePage after a short delay and refresh
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Error updating profile: $e')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _ageRangeController.dispose();
    _whatsappController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const MenuAppBar(title: 'Update Profile'),
      drawer: const MenuDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[700]!, Colors.blue[400]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Update Your Information',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Keep your profile up to date',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Profile Information Section
                    _buildSection(
                      title: 'Profile Information',
                      icon: Icons.person_rounded,
                      children: [
                        const SizedBox(height: 16),
                        
                        // Profile Image Upload Card
                        _buildProfileImageUploadCard(),
                        
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _occupationController,
                          label: 'Occupation',
                          icon: Icons.work_rounded,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your occupation';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _whatsappController,
                          label: 'WhatsApp Number',
                          icon: Icons.chat,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your WhatsApp number';
                            }
                            if (value.length < 10) {
                              return 'Please enter a valid WhatsApp number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildModernDropdown(
                          value: _ageRangeController.text.isEmpty
                              ? null
                              : _ageRangeController.text,
                          label: 'Preferred Age Range',
                          icon: Icons.cake_rounded,
                          items: const [
                            DropdownMenuItem(value: '<20', child: Text('<20')),
                            DropdownMenuItem(value: '<30', child: Text('<30')),
                            DropdownMenuItem(value: '<40', child: Text('<40')),
                            DropdownMenuItem(value: '40+', child: Text('40+')),
                          ],
                          onChanged: (val) => setState(
                            () => _ageRangeController.text = val ?? '',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select your age range';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildModernDropdown(
                          value: _roommateType.isEmpty ? null : _roommateType,
                          label: 'Roommate Type',
                          icon: Icons.groups_rounded,
                          items: const [
                            DropdownMenuItem(
                              value: 'Single',
                              child: Text('Single'),
                            ),
                            DropdownMenuItem(
                              value: 'Shared',
                              child: Text('Shared'),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => _roommateType = val ?? ''),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select roommate type';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _bioController,
                          label: 'Short Bio / Hobby',
                          icon: Icons.emoji_emotions_rounded,
                          maxLines: 3,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Update Button
                    FilledButton(
                      onPressed: _updateProfile,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.blue[700],
                      ),
                      child: const Text(
                        'Update Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Cancel button removed
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
  color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        filled: true,
  fillColor: Colors.white,
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildModernDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required Function(String?)? onChanged,
    required String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        filled: true,
  fillColor: Colors.white,
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildProfileImageUploadCard() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withValues(alpha: .1),
            primaryColor.withValues(alpha: .05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: .3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          if (_profileImage != null) ...[
            // Display newly selected image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _profileImage!,
                height: 150,
                width: 150,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Ready to upload',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_currentProfileImageUrl != null && _currentProfileImageUrl!.isNotEmpty) ...[
            // Display current profile image from URL
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _currentProfileImageUrl!,
                height: 150,
                width: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    width: 150,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 48,
                      color: primaryColor,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_done, color: Colors.blue, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Current Photo',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Icon(
              Icons.person_outline_rounded,
              size: 48,
              color: primaryColor,
            ),
            const SizedBox(height: 12),
            Text(
              'Update Profile Picture',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: onSurface.withValues(alpha: .8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Max size: 2MB • JPG, PNG',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: onSurface.withValues(alpha: .6),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: !_isPickingImage ? _pickProfileImage : null,
            icon: _isPickingImage
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    _profileImage != null || _currentProfileImageUrl != null
                        ? Icons.refresh
                        : Icons.upload_rounded,
                  ),
            label: Text(_isPickingImage
                ? 'Processing...'
                : _profileImage != null || _currentProfileImageUrl != null
                    ? 'Change Photo'
                    : 'Choose Photo'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }
}
