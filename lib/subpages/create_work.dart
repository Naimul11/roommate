import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateWorkPage extends StatefulWidget {
  const CreateWorkPage({super.key});

  @override
  State<CreateWorkPage> createState() => _CreateWorkPageState();
}

class _CreateWorkPageState extends State<CreateWorkPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String? _selectedRoomId;
  Map<String, dynamic>? _selectedRoomData;
  final List<Map<String, TextEditingController>> _workFields = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addWorkField();
  }

  void _addWorkField() {
    setState(() {
      _workFields.add({
        'workName': TextEditingController(),
        'assignedTo': TextEditingController(),
      });
    });
  }

  void _removeWorkField(int index) {
    setState(() {
      _workFields[index]['workName']?.dispose();
      _workFields[index]['assignedTo']?.dispose();
      _workFields.removeAt(index);
    });
  }

  Future<void> _saveWork() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a room'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validate at least one work field
    bool hasValidWork = false;
    for (var field in _workFields) {
      final workName = field['workName']?.text.trim() ?? '';
      final assignedTo = field['assignedTo']?.text.trim() ?? '';
      if (workName.isNotEmpty && assignedTo.isNotEmpty) {
        hasValidWork = true;
        break;
      }
    }

    if (!hasValidWork) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one work assignment'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Save each work as a document in the room's work subcollection
      for (var field in _workFields) {
        final workName = field['workName']?.text.trim() ?? '';
        final assignedTo = field['assignedTo']?.text.trim() ?? '';

        if (workName.isNotEmpty && assignedTo.isNotEmpty) {
          await _firestore
              .collection('rooms')
              .doc(_selectedRoomId)
              .collection('work')
              .add({
                'workName': workName,
                'assignedTo': assignedTo,
                'isDone': false,
                'createdAt': FieldValue.serverTimestamp(),
                'createdBy': user.email,
              });
        }
      }

      if (mounted) {
        // Clear fields
        for (var field in _workFields) {
          field['workName']?.clear();
          field['assignedTo']?.clear();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Work schedule created successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
    for (var field in _workFields) {
      field['workName']?.dispose();
      field['assignedTo']?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Work',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 0, 107, 194),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Room Selection Dropdown
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color.fromARGB(255, 0, 107, 194),
                  Colors.blue[700]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildRoomSelector(),
            ),
          ),

          // Work Fields
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Work Assignments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Work Fields List
                    ..._workFields.asMap().entries.map((entry) {
                      final index = entry.key;
                      final field = entry.value;
                      return _buildWorkFieldCard(index, field);
                    }),

                    const SizedBox(height: 16),

                    // Add Work Button
                    OutlinedButton.icon(
                      onPressed: _addWorkField,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Work'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Update Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveWork,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Update',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSelector() {
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('rooms').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Error loading rooms',
            style: TextStyle(color: Colors.white),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final allRooms = snapshot.data?.docs ?? [];
        // Filter rooms where current user is the creator
        final rooms = allRooms.where((doc) {
          final roomData = doc.data() as Map<String, dynamic>;
          return roomData['creatorEmail'] == currentUserEmail;
        }).toList();

        if (rooms.isEmpty) {
          return const Text(
            'You have not created any rooms',
            style: TextStyle(color: Colors.white),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: _selectedRoomId,
            hint: const Text('Select a room'),
            isExpanded: true,
            underline: const SizedBox(),
            items: rooms.map((room) {
              final roomData = room.data() as Map<String, dynamic>;
              return DropdownMenuItem(
                value: room.id,
                child: Text(roomData['roomName'] ?? 'Unnamed Room'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedRoomId = value;
                if (value != null) {
                  final selectedRoom = rooms.firstWhere((r) => r.id == value);
                  _selectedRoomData =
                      selectedRoom.data() as Map<String, dynamic>;
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildWorkFieldCard(
    int index,
    Map<String, TextEditingController> field,
  ) {
    final users = _selectedRoomData?['users'] as List? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Work ${index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_workFields.length > 1)
                  IconButton(
                    onPressed: () => _removeWorkField(index),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Remove Work',
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Work Name Field
            TextFormField(
              controller: field['workName'],
              decoration: InputDecoration(
                labelText: 'Work Name',
                hintText: 'Enter work name',
                prefixIcon: const Icon(Icons.work_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter work name';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Roommate Dropdown
            if (_selectedRoomData != null && users.isNotEmpty)
              DropdownButtonFormField<String>(
                value: field['assignedTo']?.text.isEmpty == true
                    ? null
                    : field['assignedTo']?.text,
                decoration: InputDecoration(
                  labelText: 'Assign To',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                hint: const Text('Select roommate'),
                items: users.map<DropdownMenuItem<String>>((user) {
                  final name = user['name'] ?? 'Unknown';
                  return DropdownMenuItem<String>(
                    value: name,
                    child: Text(name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    field['assignedTo']?.text = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a roommate';
                  }
                  return null;
                },
              )
            else
              TextFormField(
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Assign To',
                  hintText: 'Select a room first',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
