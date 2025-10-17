import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roommate/login.dart';
import 'package:roommate/subpages/nidscrape.dart';
import 'package:roommate/services/imagekit_service.dart';
import 'dart:io';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _nidNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _nidNumberController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _religionController = TextEditingController();
  String? _selectedGender;

  // Tell me about yourself fields
  bool _isSmoker = false;
  bool _isPetLover = false;
  String _sleepingHabit = '';
  String _cleanliness = '';
  String _roommateType = '';
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _ageRangeController = TextEditingController();
  final TextEditingController _bloodGroupController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // Profile image
  File? _profileImage;
  final bool _isPickingImage = false;

  @override
  void dispose() {
    _mobileController.dispose();
    _nidNameController.dispose();
    _dobController.dispose();
    _nidNumberController.dispose();
    _whatsappController.dispose();
    _religionController.dispose();
    _occupationController.dispose();
    _ageRangeController.dispose();
    _bloodGroupController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _scanNID() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image != null) {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Processing NID...'),
                ],
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Process image with OCR
        final inputImage = InputImage.fromFilePath(image.path);
        final textRecognizer = TextRecognizer();
        final RecognizedText recognizedText = await textRecognizer.processImage(
          inputImage,
        );
        await textRecognizer.close();

        // Extract NID information
        String extractedText = recognizedText.text;

        // Parse NID data using NIDScraper
        Map<String, String> nidData = NIDScraper.parseNIDData(extractedText);

        setState(() {
          _nidNameController.text = nidData['name'] ?? '';
          _dobController.text = nidData['dob'] ?? '';
          _nidNumberController.text = nidData['nidNumber'] ?? '';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('NID scanned successfully!'),
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
                Text('Error scanning NID'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
                  Text('Profile image selected.'),
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

  Future<void> _register() async {
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
                  Text('Authenticating with Google...'),
                ],
              ),
              duration: Duration(seconds: 30),
            ),
          );
        }

        // Always show Gmail picker by signing out first
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          // User canceled the sign-in
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Sign-in canceled'),
                  ],
                ),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        // Obtain the auth details from the request
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Create a new credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in to Firebase with the Google credential
        final UserCredential userCredential = await FirebaseAuth.instance
            .signInWithCredential(credential);


        // Check if email already exists in Firestore
        final email = userCredential.user!.email;
        final existingEmail = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (existingEmail.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(child: Text('This email is already registered.')),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        // Check if NID number already exists in Firestore
        final nidNumber = _nidNumberController.text.trim();
        final existingNid = await FirebaseFirestore.instance
            .collection('users')
            .where('nidNumber', isEqualTo: nidNumber)
            .limit(1)
            .get();
        if (existingNid.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(child: Text('This NID number is already registered.')),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        // Upload profile image to ImageKit if selected
        String? profileImageUrl;
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

          final fileName = 'roommate_profile_${userCredential.user!.uid}.jpg';
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
                      Expanded(child: Text('Profile image upload failed, but registration will continue.')),
                    ],
                  ),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }

        // Prepare user data for Firestore
        final userData = {
          'email': userCredential.user!.email,
          'nidName': _nidNameController.text,
          'dateOfBirth': _dobController.text,
          'nidNumber': _nidNumberController.text,
          'mobileNumber': _mobileController.text,
          'gender': _selectedGender,
          'isSmoker': _isSmoker,
          'isPetLover': _isPetLover,
          'sleepingHabit': _sleepingHabit,
          'cleanliness': _cleanliness,
          'roommateType': _roommateType,
          'occupation': _occupationController.text,
          'whatsappNumber': _whatsappController.text,
          'ageRange': _ageRangeController.text,
          'bloodGroup': _bloodGroupController.text,
          'bio': _bioController.text,
          'religion': _religionController.text,
          'profileImageUrl': profileImageUrl,
          'createdAt': FieldValue.serverTimestamp(),
        };

        // Store user data in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userData);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Registration successful!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
          // Wait for the SnackBar to show, then navigate
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => LoginPage()),
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('Authentication failed: ${e.message}')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
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
  }

  bool get _isNidScanned =>
      _nidNameController.text.isNotEmpty &&
      _dobController.text.isNotEmpty &&
      _nidNumberController.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Account',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 0, 107, 194),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // NID Section
              _buildSection(
                title: 'Identity Verification',
                icon: Icons.verified_user_rounded,
                children: [
                  const SizedBox(height: 16),
                  Container(
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
                        Icon(
                          Icons.credit_card_rounded,
                          size: 48,
                          color: primaryColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Scan Your NID Card',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: onSurface.withValues(alpha: .8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Automatically fill your information by scanning your NID',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: onSurface.withValues(alpha: .6),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _scanNID,
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Scan NID Card'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isNidScanned) ...[
                    const SizedBox(height: 20),
                    _buildInfoCard(
                      icon: Icons.person_rounded,
                      label: 'Name',
                      value: _nidNameController.text,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.cake_rounded,
                      label: 'Date of Birth',
                      value: _dobController.text,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.badge_rounded,
                      label: 'NID Number',
                      value: _nidNumberController.text,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 32),

              // Personal Information Section
              _buildSection(
                title: 'Personal Information',
                icon: Icons.person_rounded,
                children: [
                  const SizedBox(height: 16),
                  
                  // Profile Image Upload Card
                  _buildProfileImageUploadCard(),
                  
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _mobileController,
                    label: 'Mobile Number',
                    icon: Icons.phone_rounded,
                    enabled: _isNidScanned,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (!_isNidScanned) return 'Scan NID first';
                      if (value == null || value.isEmpty) {
                        return 'Please enter your mobile number';
                      }
                      if (value.length < 10) {
                        return 'Please enter a valid mobile number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildModernDropdown(
                    value: _selectedGender,
                    label: 'Gender',
                    icon: Icons.wc_rounded,
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                    ],
                    onChanged: _isNidScanned
                        ? (value) {
                            setState(() {
                              _selectedGender = value;
                            });
                          }
                        : null,
                    validator: (value) {
                      if (!_isNidScanned) return 'Scan NID first';
                      if (value == null || value.isEmpty) {
                        return 'Please select your gender';
                      }
                      return null;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Lifestyle Preferences Section
              _buildSection(
                title: 'Lifestyle Preferences',
                icon: Icons.self_improvement_rounded,
                children: [
                  const SizedBox(height: 16),
                  _buildPreferenceRow(
                    label: 'Smoker',
                    value: _isSmoker,
                    onChanged: _isNidScanned
                        ? (val) => setState(() => _isSmoker = val ?? false)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _buildPreferenceRow(
                    label: 'Pet Lover',
                    value: _isPetLover,
                    onChanged: _isNidScanned
                        ? (val) => setState(() => _isPetLover = val ?? false)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _buildModernDropdown(
                    value: _sleepingHabit.isEmpty ? null : _sleepingHabit,
                    label: 'Sleeping Habit',
                    icon: Icons.nightlight_rounded,
                    items: const [
                      DropdownMenuItem(
                        value: 'Early',
                        child: Text('Early sleeper'),
                      ),
                      DropdownMenuItem(
                        value: 'Late',
                        child: Text('Late sleeper'),
                      ),
                    ],
                    onChanged: _isNidScanned
                        ? (val) => setState(() => _sleepingHabit = val ?? '')
                        : null,
                    validator: (value) {
                      if (!_isNidScanned) return 'Scan NID first';
                      if (value == null || value.isEmpty) {
                        return 'Please select sleeping habit';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildModernDropdown(
                    value: _cleanliness.isEmpty ? null : _cleanliness,
                    label: 'Cleanliness',
                    icon: Icons.cleaning_services_rounded,
                    items: const [
                      DropdownMenuItem(
                        value: 'Very tidy',
                        child: Text('Very tidy'),
                      ),
                      DropdownMenuItem(
                        value: 'Moderate',
                        child: Text('Moderate'),
                      ),
                      DropdownMenuItem(
                        value: "Doesn't mind",
                        child: Text("Doesn't mind"),
                      ),
                    ],
                    onChanged: _isNidScanned
                        ? (val) => setState(() => _cleanliness = val ?? '')
                        : null,
                    validator: (value) {
                      if (!_isNidScanned) return 'Scan NID first';
                      if (value == null || value.isEmpty) {
                        return 'Please select cleanliness';
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
                      DropdownMenuItem(value: 'Single', child: Text('Single')),
                      DropdownMenuItem(value: 'Shared', child: Text('Shared')),
                    ],
                    onChanged: _isNidScanned
                        ? (val) => setState(() => _roommateType = val ?? '')
                        : null,
                    validator: (value) {
                      if (!_isNidScanned) return 'Scan NID first';
                      if (value == null || value.isEmpty) {
                        return 'Please select roommate type';
                      }
                      return null;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Additional Information Section
              _buildSection(
                title: 'Additional Information',
                icon: Icons.info_rounded,
                children: [
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _occupationController,
                    label: 'Occupation',
                    icon: Icons.work_rounded,
                    enabled: _isNidScanned,
                    validator: (value) {
                      if (!_isNidScanned) return 'Scan NID first';
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
                    enabled: _isNidScanned,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (!_isNidScanned) return 'Scan NID first';
                      if (value == null || value.isEmpty) {
                        return 'Please enter your WhatsApp number';
                      }
                      if (value.length < 10) {
                        return 'Please enter a valid WhatsApp number';
                      }
                      return null;
                    },
                    onTap: () {
                      if (_whatsappController.text.isEmpty && _mobileController.text.isNotEmpty) {
                        setState(() {
                          _whatsappController.text = _mobileController.text;
                        });
                      }
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
                    onChanged: _isNidScanned
                        ? (val) => setState(
                            () => _ageRangeController.text = val ?? '',
                          )
                        : null,
                    validator: (value) {
                      if (!_isNidScanned) return 'Scan NID first';
                      if (value == null || value.isEmpty) {
                        return 'Please select your age range';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _bloodGroupController,
                    label: 'Blood Group',
                    icon: Icons.bloodtype_rounded,
                    enabled: _isNidScanned,
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _bioController,
                    label: 'Short Bio / Hobby',
                    icon: Icons.emoji_emotions_rounded,
                    enabled: _isNidScanned,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _religionController,
                    label: 'Religion',
                    icon: Icons.account_balance_rounded,
                    enabled: _isNidScanned,
                    validator: (value) {
                      if (!_isNidScanned) return 'Scan NID first';
                      if (value == null || value.isEmpty) {
                        return 'Please enter your religion';
                      }
                      return null;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Register Button
              FilledButton(
                onPressed: _isNidScanned ? _register : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Complete Registration',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),

              const SizedBox(height: 20),

              // Go to Login Text (only 'Log in' clickable, no underline)
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => LoginPage()),
                        );
                      },
                      child: Text(
                        'Log in',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
        color: Theme.of(context).colorScheme.surface,
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
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
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

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.verified_rounded, color: Colors.green, size: 18),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      onTap: onTap,
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
        fillColor: enabled
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
      ),
      enabled: enabled,
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
        fillColor: onChanged != null
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildPreferenceRow({
    required String label,
    required bool value,
    required Function(bool?)? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
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
            // Display uploaded image
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
          ] else ...[
            Icon(
              Icons.person_outline_rounded,
              size: 48,
              color: primaryColor,
            ),
            const SizedBox(height: 12),
            Text(
              'Upload Profile Picture',
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
            onPressed: _isNidScanned && !_isPickingImage
                ? _pickProfileImage
                : null,
            icon: _isPickingImage
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(_profileImage != null ? Icons.refresh : Icons.upload_rounded),
            label: Text(_isPickingImage
                ? 'Processing...'
                : _profileImage != null
                    ? 'Change Image'
                    : 'Choose Image'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
