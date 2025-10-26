import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _yourNameController = TextEditingController();
  final TextEditingController _yourGmailController = TextEditingController();

  // Bill fields
  final TextEditingController _totalRentController = TextEditingController();
  final List<Map<String, TextEditingController>> _foodFields = [];
  final List<Map<String, TextEditingController>> _utilityFields = [];
  final List<Map<String, TextEditingController>> _otherBillFields = [];

  final List<Map<String, TextEditingController>> _userFields = [];
  bool _isLoading = false;

  double get _totalBill {
    double total = 0;

    // Add rent
    total += double.tryParse(_totalRentController.text) ?? 0;

    // Add food
    for (var field in _foodFields) {
      total += double.tryParse(field['amount']?.text ?? '') ?? 0;
    }

    // Add utilities
    for (var field in _utilityFields) {
      total += double.tryParse(field['amount']?.text ?? '') ?? 0;
    }

    // Add other bills
    for (var field in _otherBillFields) {
      total += double.tryParse(field['amount']?.text ?? '') ?? 0;
    }

    return total;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _addUserField(); // Add one user field by default
    _addFoodField(); // Add one food field by default
    _addUtilityField(); // Add one utility field by default
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && mounted) {
          final userData = userDoc.data();
          setState(() {
            _yourNameController.text = userData?['nidName'] ?? '';
            _yourGmailController.text = user.email ?? '';
          });
        }
      } catch (e) {
        // Handle error silently
      }
    }
  }

  void _addUserField() {
    setState(() {
      _userFields.add({
        'name': TextEditingController(),
        'gmail': TextEditingController(),
      });
    });
  }

  void _removeUserField(int index) {
    setState(() {
      _userFields[index]['name']?.dispose();
      _userFields[index]['gmail']?.dispose();
      _userFields.removeAt(index);
    });
  }

  void _addFoodField() {
    setState(() {
      _foodFields.add({
        'name': TextEditingController(),
        'amount': TextEditingController(),
      });
    });
  }

  void _removeFoodField(int index) {
    setState(() {
      _foodFields[index]['name']?.dispose();
      _foodFields[index]['amount']?.dispose();
      _foodFields.removeAt(index);
    });
  }

  void _addUtilityField() {
    setState(() {
      _utilityFields.add({
        'name': TextEditingController(),
        'amount': TextEditingController(),
      });
    });
  }

  void _removeUtilityField(int index) {
    setState(() {
      _utilityFields[index]['name']?.dispose();
      _utilityFields[index]['amount']?.dispose();
      _utilityFields.removeAt(index);
    });
  }

  void _addOtherBillField() {
    setState(() {
      _otherBillFields.add({
        'name': TextEditingController(),
        'amount': TextEditingController(),
      });
    });
  }

  void _removeOtherBillField(int index) {
    setState(() {
      _otherBillFields[index]['name']?.dispose();
      _otherBillFields[index]['amount']?.dispose();
      _otherBillFields.removeAt(index);
    });
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Prepare user list
      final List<Map<String, String>> users = [];

      // Add creator
      users.add({
        'name': _yourNameController.text.trim(),
        'gmail': _yourGmailController.text.trim(),
        'role': 'creator',
      });

      // Add other users
      for (var userField in _userFields) {
        final name = userField['name']?.text.trim() ?? '';
        final gmail = userField['gmail']?.text.trim() ?? '';
        if (name.isNotEmpty && gmail.isNotEmpty) {
          users.add({'name': name, 'gmail': gmail, 'role': 'member'});
        }
      }

      // Prepare bills data
      final List<Map<String, dynamic>> foodBills = [];
      for (int i = 0; i < _foodFields.length; i++) {
        final name = _foodFields[i]['name']?.text.trim() ?? '';
        final amount =
            double.tryParse(_foodFields[i]['amount']?.text.trim() ?? '') ?? 0;
        if (amount > 0) {
          foodBills.add({'name': name, 'amount': amount});
        }
      }

      final List<Map<String, dynamic>> utilityBills = [];
      for (int i = 0; i < _utilityFields.length; i++) {
        final name = _utilityFields[i]['name']?.text.trim() ?? '';
        final amount =
            double.tryParse(_utilityFields[i]['amount']?.text.trim() ?? '') ??
            0;
        if (amount > 0) {
          utilityBills.add({'name': name, 'amount': amount});
        }
      }

      final List<Map<String, dynamic>> otherBills = [];
      for (int i = 0; i < _otherBillFields.length; i++) {
        final name = _otherBillFields[i]['name']?.text.trim() ?? '';
        final amount =
            double.tryParse(_otherBillFields[i]['amount']?.text.trim() ?? '') ??
            0;
        if (name.isNotEmpty && amount > 0) {
          otherBills.add({'name': name, 'amount': amount});
        }
      }

      // Create room document
      final roomData = {
        'roomName': _roomNameController.text.trim(),
        'location': _locationController.text.trim(),
        'creatorId': user.uid,
        'creatorName': _yourNameController.text.trim(),
        'creatorEmail': _yourGmailController.text.trim(),
        'users': users,
        'bills': {
          'totalRent': double.tryParse(_totalRentController.text.trim()) ?? 0,
          'food': foodBills,
          'utilities': utilityBills,
          'other': otherBills,
          'totalBill': _totalBill,
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('rooms').add(roomData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Room created successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _locationController.dispose();
    _yourNameController.dispose();
    _yourGmailController.dispose();
    _totalRentController.dispose();
    for (var field in _foodFields) {
      field['name']?.dispose();
      field['amount']?.dispose();
    }
    for (var field in _utilityFields) {
      field['name']?.dispose();
      field['amount']?.dispose();
    }
    for (var field in _otherBillFields) {
      field['name']?.dispose();
      field['amount']?.dispose();
    }
    for (var userField in _userFields) {
      userField['name']?.dispose();
      userField['gmail']?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Room',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 0, 107, 194),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSection(
                title: 'Room Information',
                icon: Icons.room_preferences,
                children: [
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _roomNameController,
                    label: 'Room Name',
                    icon: Icons.meeting_room,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter room name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _locationController,
                    label: 'Location',
                    icon: Icons.location_on,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter location';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'Your Information',
                icon: Icons.person,
                children: [
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _yourNameController,
                    label: 'Your Name',
                    icon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _yourGmailController,
                    label: 'Your Gmail',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    enabled: false,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your gmail';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'Room Details',
                icon: Icons.receipt_long,
                children: [
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _totalRentController,
                    label: 'Room Rent',
                    icon: Icons.home,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildBillSection(
                    title: 'Total Food',
                    icon: Icons.restaurant,
                    fields: _foodFields,
                    onAdd: _addFoodField,
                    onRemove: _removeFoodField,
                  ),
                  const SizedBox(height: 16),
                  _buildBillSection(
                    title: 'Total Utilities',
                    icon: Icons.electrical_services,
                    fields: _utilityFields,
                    onAdd: _addUtilityField,
                    onRemove: _removeUtilityField,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.more_horiz, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Other Bills',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _addOtherBillField,
                        icon: const Icon(Icons.add_circle),
                        color: Theme.of(context).colorScheme.primary,
                        tooltip: 'Add bill',
                      ),
                    ],
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _otherBillFields.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _otherBillFields[index]['name'],
                                    decoration: InputDecoration(
                                      labelText: 'Bill Name',
                                      prefixIcon: const Icon(Icons.label),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => _removeOtherBillField(index),
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Remove',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: TextFormField(
                                controller: _otherBillFields[index]['amount'],
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Amount',
                                  prefixIcon: const Icon(Icons.money),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    if (double.tryParse(value) == null) {
                                      return 'Please enter a valid number';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Bill',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          '৳${_totalBill.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'Room Members',
                icon: Icons.group,
                children: [
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _userFields.length,
                    itemBuilder: (context, index) {
                      return _buildUserField(index);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _addUserField,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Member'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isLoading ? null : _createRoom,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Create Room',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      onChanged: onChanged,
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
      validator: validator,
    );
  }

  Widget _buildBillSection({
    required String title,
    required IconData icon,
    required List<Map<String, TextEditingController>> fields,
    required VoidCallback onAdd,
    required void Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle),
              color: Theme.of(context).colorScheme.primary,
              tooltip: 'Add item',
            ),
          ],
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: fields.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: fields[index]['name'],
                          decoration: InputDecoration(
                            labelText: 'Bill Name',
                            prefixIcon: const Icon(Icons.label),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => onRemove(index),
                        icon: const Icon(
                          Icons.remove_circle,
                          color: Colors.red,
                        ),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: TextFormField(
                      controller: fields[index]['amount'],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: const Icon(Icons.money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUserField(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Member ${index + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _removeUserField(index),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Remove member',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _userFields[index]['name']!,
            label: 'User Name',
            icon: Icons.person,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final gmail = _userFields[index]['gmail']?.text ?? '';
                if (gmail.isEmpty) {
                  return 'Gmail is required if name is provided';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _userFields[index]['gmail']!,
            label: 'User Gmail',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                final name = _userFields[index]['name']?.text ?? '';
                if (name.isEmpty) {
                  return 'Name is required if gmail is provided';
                }
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
