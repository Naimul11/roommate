import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roommate/services/imagekit_service.dart';
import 'dart:io';

class CreateNewPostPage extends StatefulWidget {
  final String? postId; // For editing existing posts
  
  const CreateNewPostPage({super.key, this.postId});

  @override
  State<CreateNewPostPage> createState() => _CreateNewPostPageState();
}

class _CreateNewPostPageState extends State<CreateNewPostPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Image files
  File? _mainRoomImage;
  File? _mainSpotImage;
  File? _differentAngleImage;
  
  bool _isUploading = false;
  
  // Text controllers
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _facilitiesController = TextEditingController();
  final TextEditingController _rentController = TextEditingController();
  final TextEditingController _foodController = TextEditingController();
  final TextEditingController _utilitiesController = TextEditingController();
  final TextEditingController _numberOfRoommatesController = TextEditingController();
  
  // Dropdown values
  String? _roomType;
  String? _gender;
  String? _preferredReligion;
  
  bool _isEditMode = false;
  bool _isLoadingData = false;
  
  // Calculated total
  double get _totalCost {
    final rent = double.tryParse(_rentController.text) ?? 0;
    final food = double.tryParse(_foodController.text) ?? 0;
    final utilities = double.tryParse(_utilitiesController.text) ?? 0;
    return rent + food + utilities;
  }

  @override
  void initState() {
    super.initState();
    if (widget.postId != null) {
      _isEditMode = true;
      _loadPostData();
    }
  }

  Future<void> _loadPostData() async {
    setState(() => _isLoadingData = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('User not authenticated.', isError: true);
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(user.uid)
          .collection('post')
          .doc(widget.postId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          _showSnackBar('Post not found.', isError: true);
          Navigator.pop(context);
        }
        return;
      }

      final data = doc.data()!;
      setState(() {
        _locationController.text = data['location'] ?? '';
        _floorController.text = data['floor']?.toString() ?? '';
        _facilitiesController.text = data['facilities'] ?? '';
        _rentController.text = data['rent']?.toString() ?? '';
        _foodController.text = data['food']?.toString() ?? '';
        _utilitiesController.text = data['utilities']?.toString() ?? '';
        _numberOfRoommatesController.text = data['numberOfRoommates']?.toString() ?? '';
        _roomType = data['roomType'];
        _gender = data['gender'];
        _preferredReligion = data['preferredReligion'];
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading post data: $e', isError: true);
      }
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _floorController.dispose();
    _facilitiesController.dispose();
    _rentController.dispose();
    _foodController.dispose();
    _utilitiesController.dispose();
    _numberOfRoommatesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String imageType) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        
        // Check file size (max 5MB for room images)
        final fileSize = await imageFile.length();
        const maxSize = 5 * 1024 * 1024; // 5MB
        
        if (fileSize > maxSize) {
          if (mounted) {
            _showSnackBar(
              'Image size must be less than 5MB. Current size: ${ImageKitService.formatFileSize(fileSize)}',
              isError: true,
            );
          }
          return;
        }

        setState(() {
          switch (imageType) {
            case 'main_room':
              _mainRoomImage = imageFile;
              break;
            case 'main_spot':
              _mainSpotImage = imageFile;
              break;
            case 'different_angle':
              _differentAngleImage = imageFile;
              break;
          }
        });

        if (mounted) {
          _showSnackBar('Image selected successfully.', isSuccess: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error selecting image: $e', isError: true);
      }
    }
  }

  void _removeImage(String imageType) {
    setState(() {
      switch (imageType) {
        case 'main_room':
          _mainRoomImage = null;
          break;
        case 'main_spot':
          _mainSpotImage = null;
          break;
        case 'different_angle':
          _differentAngleImage = null;
          break;
      }
    });
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;

    // For edit mode, images are optional (can keep existing images)
    // For create mode, all images are required
    if (!_isEditMode) {
      if (_mainRoomImage == null || _mainSpotImage == null || _differentAngleImage == null) {
        _showSnackBar('Please upload all three images.', isError: true);
        return;
      }
    }

    // Validate number of roommates if shared
    if (_roomType == 'Shared') {
      if (_numberOfRoommatesController.text.isEmpty) {
        _showSnackBar('Please enter number of roommates for shared room.', isError: true);
        return;
      }
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('User not authenticated.', isError: true);
        setState(() {
          _isUploading = false;
        });
        return;
      }

      final uid = user.uid;
      final now = DateTime.now();
      final todayDate = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final postDocId = _isEditMode ? widget.postId! : todayDate;

      // Prepare base post data
      final Map<String, dynamic> postData = {
        'location': _locationController.text.trim(),
        'floor': _floorController.text.trim(),
        'facilities': _facilitiesController.text.trim(),
        'rent': double.tryParse(_rentController.text) ?? 0,
        'food': double.tryParse(_foodController.text) ?? 0,
        'utilities': double.tryParse(_utilitiesController.text) ?? 0,
        'totalCost': _totalCost,
        'roomType': _roomType,
        'numberOfRoommates': _roomType == 'Shared' 
            ? int.tryParse(_numberOfRoommatesController.text) ?? 0 
            : null,
        'gender': _gender,
        'preferredReligion': _preferredReligion,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Upload images if new images are selected
      if (_mainRoomImage != null || _mainSpotImage != null || _differentAngleImage != null) {
        _showSnackBar('Uploading images...', duration: 30);

        if (_mainRoomImage != null) {
          final mainRoomUrl = await ImageKitService.uploadImage(
            imageFile: _mainRoomImage!,
            fileName: 'post_${uid}_${postDocId}_main_room.jpg',
            folder: 'roommate/posts/$uid',
          );
          if (mainRoomUrl != null) {
            postData['mainRoomImageUrl'] = mainRoomUrl;
          }
        }

        if (_mainSpotImage != null) {
          final mainSpotUrl = await ImageKitService.uploadImage(
            imageFile: _mainSpotImage!,
            fileName: 'post_${uid}_${postDocId}_main_spot.jpg',
            folder: 'roommate/posts/$uid',
          );
          if (mainSpotUrl != null) {
            postData['mainSpotImageUrl'] = mainSpotUrl;
          }
        }

        if (_differentAngleImage != null) {
          final differentAngleUrl = await ImageKitService.uploadImage(
            imageFile: _differentAngleImage!,
            fileName: 'post_${uid}_${postDocId}_different_angle.jpg',
            folder: 'roommate/posts/$uid',
          );
          if (differentAngleUrl != null) {
            postData['differentAngleImageUrl'] = differentAngleUrl;
          }
        }
      }

      if (_isEditMode) {
        // Update existing post
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(uid)
            .collection('post')
            .doc(postDocId)
            .update(postData);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _showSnackBar('Post updated successfully!', isSuccess: true, duration: 2);
          
          await Future.delayed(const Duration(seconds: 2));
          
          if (mounted) {
            Navigator.of(context).pop(true); // Return true to indicate success
          }
        }
      } else {
        // Create new post
        postData['createdAt'] = FieldValue.serverTimestamp();

        await FirebaseFirestore.instance
            .collection('posts')
            .doc(uid)
            .collection('post')
            .doc(postDocId)
            .set(postData);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _showSnackBar('Post created successfully!', isSuccess: true, duration: 2);
          
          await Future.delayed(const Duration(seconds: 2));
          
          if (mounted) {
            Navigator.of(context).pop(true); // Return true to indicate success
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error ${_isEditMode ? 'updating' : 'creating'} post: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
    bool isSuccess = false,
    int duration = 3,
  }) {
    final color = isError
        ? Colors.red
        : isSuccess
            ? Colors.green
            : Colors.blue;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : 
              isSuccess ? Icons.check_circle_rounded : 
              Icons.info_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: duration),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Post' : 'Create New Post'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 32),

              // Images Section
              _buildImageSection(),
              const SizedBox(height: 32),

              // Location & Details Section
              _buildLocationSection(),
              const SizedBox(height: 32),

              // Cost Section
              _buildCostSection(),
              const SizedBox(height: 32),

              // Preferences Section
              _buildPreferencesSection(),
              const SizedBox(height: 40),

              // Upload Button
              _buildSubmitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withAlpha(26), // 0.1 * 255 = 25.5
            Theme.of(context).colorScheme.primary.withAlpha(13), // 0.05 * 255 = 12.75
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withAlpha(51), // 0.2 * 255 = 51
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_photo_alternate_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create New Post',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Share your room details with potential roommates',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(153), // 0.6 * 255 = 153
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return _buildSection(
      title: 'Room Images',
      icon: Icons.photo_library_rounded,
      children: [
        const SizedBox(height: 20),
        Text(
          'Upload clear photos of your room (Max 5MB each)',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
        _buildImageUploadCard(
          title: 'Main Room View',
          subtitle: 'Show the entire room',
          imageFile: _mainRoomImage,
          onTap: () => _pickImage('main_room'),
          onRemove: () => _removeImage('main_room'),
        ),
        const SizedBox(height: 16),
        _buildImageUploadCard(
          title: 'Main Spot',
          subtitle: 'Highlight the spot area',
          imageFile: _mainSpotImage,
          onTap: () => _pickImage('main_spot'),
          onRemove: () => _removeImage('main_spot'),
        ),
        const SizedBox(height: 16),
        _buildImageUploadCard(
          title: 'Different Angle',
          subtitle: 'Show another perspective',
          imageFile: _differentAngleImage,
          onTap: () => _pickImage('different_angle'),
          onRemove: () => _removeImage('different_angle'),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return _buildSection(
      title: 'Location & Details',
      icon: Icons.location_city_rounded,
      children: [
        const SizedBox(height: 20),
        _buildModernTextField(
          controller: _locationController,
          label: 'Full Address',
          icon: Icons.place_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter location address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          controller: _floorController,
          label: 'Floor Number',
          icon: Icons.stairs_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter floor number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          controller: _facilitiesController,
          label: 'Available Facilities',
          icon: Icons.emoji_food_beverage_rounded,
          hintText: 'e.g., WiFi, AC, Furniture, Kitchen, etc.',
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please describe available facilities';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCostSection() {
    return _buildSection(
      title: 'Cost Breakdown',
      icon: Icons.attach_money_rounded,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildModernTextField(
                controller: _rentController,
                label: 'Rent',
                icon: Icons.home_rounded,
                prefixText: '৳',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Invalid amount';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModernTextField(
                controller: _foodController,
                label: 'Food Cost',
                icon: Icons.restaurant_rounded,
                prefixText: '৳',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Invalid amount';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildModernTextField(
                controller: _utilitiesController,
                label: 'Utilities Cost',
                icon: Icons.electrical_services_rounded,
                prefixText: '৳',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Invalid amount';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.withAlpha(26),
                      Colors.green.withAlpha(13),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.green.withAlpha(77), // 0.3 * 255 = 76.5
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(51),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.calculate_rounded,
                            color: Colors.green[700],
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '৳${_totalCost.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All costs included',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreferencesSection() {
    return _buildSection(
      title: 'Room Preferences',
      icon: Icons.people_alt_rounded,
      children: [
        const SizedBox(height: 20),
        _buildModernDropdown(
          value: _roomType,
          label: 'Room Type',
          icon: Icons.bed_rounded,
          items: const [
            DropdownMenuItem(value: 'Single', child: Text('Single Room')),
            DropdownMenuItem(value: 'Shared', child: Text('Shared Room')),
          ],
          onChanged: (value) {
            setState(() {
              _roomType = value;
              if (value != 'Shared') {
                _numberOfRoommatesController.clear();
              }
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select room type';
            }
            return null;
          },
        ),
        if (_roomType == 'Shared') ...[
          const SizedBox(height: 16),
          _buildModernTextField(
            controller: _numberOfRoommatesController,
            label: 'Number of Roommates',
            icon: Icons.people_rounded,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (_roomType == 'Shared') {
                if (value == null || value.isEmpty) {
                  return 'Please enter number of roommates';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 16),
        _buildModernDropdown(
          value: _gender,
          label: 'Preferred Gender',
          icon: Icons.wc_rounded,
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Any', child: Text('Any Gender')),
          ],
          onChanged: (value) => setState(() => _gender = value),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select preferred gender';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildModernDropdown(
          value: _preferredReligion,
          label: 'Preferred Religion',
          icon: Icons.account_balance_rounded,
          items: const [
            DropdownMenuItem(value: 'Any', child: Text('Any Religion')),
            DropdownMenuItem(value: 'Islam', child: Text('Islam')),
            DropdownMenuItem(value: 'Hindu', child: Text('Hindu')),
            DropdownMenuItem(value: 'Christian', child: Text('Christian')),
            DropdownMenuItem(value: 'Buddhist', child: Text('Buddhist')),
          ],
          onChanged: (value) => setState(() => _preferredReligion = value),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select preferred religion';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton(
      onPressed: _isUploading ? null : _createPost,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      child: _isUploading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Creating Post...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isEditMode ? Icons.save_rounded : Icons.upload_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  _isEditMode ? 'Update Post' : 'Create Post',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(26),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
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

  Widget _buildImageUploadCard({
    required String title,
    required String subtitle,
    required File? imageFile,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: imageFile != null 
                ? Colors.green.withAlpha(77)
                : Theme.of(context).colorScheme.outline.withAlpha(51),
            width: 2,
          ),
          color: imageFile != null
              ? Colors.green.withAlpha(5)
              : Theme.of(context).colorScheme.surface,
        ),
        child: imageFile != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      imageFile,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(77),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withAlpha(26),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(51),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(26),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, 
                            color: Colors.white, 
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Uploaded',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withAlpha(26),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_rounded,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    String? prefixText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        prefixText: prefixText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(76),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(76),
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
        fillColor: Theme.of(context).colorScheme.surface,
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
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
            color: Theme.of(context).colorScheme.outline.withAlpha(76),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(76),
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
        fillColor: Theme.of(context).colorScheme.surface,
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
      dropdownColor: Theme.of(context).colorScheme.surface,
    );
  }
}