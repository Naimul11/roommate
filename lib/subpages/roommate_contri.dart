import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoommateContributionPage extends StatefulWidget {
  const RoommateContributionPage({super.key});

  @override
  State<RoommateContributionPage> createState() =>
      _RoommateContributionPageState();
}

class _RoommateContributionPageState extends State<RoommateContributionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedRoomId;
  Map<String, dynamic>? _selectedRoomData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Roommate Contributions',
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

          // Contributions List
          Expanded(
            child: _selectedRoomId == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_upward,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select a room to view contributions',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildRoommateContributions(),
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
        final rooms = allRooms.where((doc) {
          final roomData = doc.data() as Map<String, dynamic>;
          final users = roomData['users'] as List? ?? [];
          return users.any((user) => user['gmail'] == currentUserEmail);
        }).toList();

        if (rooms.isEmpty) {
          return const Text(
            'No rooms available',
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

  Widget _buildRoommateContributions() {
    if (_selectedRoomId == null || _selectedRoomData == null) {
      return const SizedBox();
    }

    final users = _selectedRoomData?['users'] as List? ?? [];
    final totalBill = (_selectedRoomData?['bills']?['totalBill'] ?? 0)
        .toDouble();
    final splitAmount = users.isNotEmpty ? totalBill / users.length : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[600]!, Colors.blue[800]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedRoomData?['roomName'] ?? 'Unnamed Room',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.people, color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${users.length} members',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                const Divider(color: Colors.white30, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryItem('Total Bill', totalBill),
                    Container(width: 1, height: 40, color: Colors.white30),
                    _buildSummaryItem('Per Person', splitAmount),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Roommates Contributions
          const Text(
            'Roommate Contributions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Build contribution cards for each user
          ...users.map((user) {
            return _buildUserContributionCard(
              user['name'] ?? 'Unknown',
              user['gmail'] ?? '',
              splitAmount,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 4),
        Text(
          '৳${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildUserContributionCard(
    String userName,
    String userEmail,
    double splitAmount,
  ) {
    return FutureBuilder<DocumentSnapshot?>(
      future: _firestore
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get()
          .then(
            (snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first : null,
          ),
      builder: (context, userSnapshot) {
        String? profileImageUrl;
        if (userSnapshot.hasData && userSnapshot.data != null) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          profileImageUrl = userData?['profileImageUrl'];
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('rooms')
              .doc(_selectedRoomId)
              .collection('contributions')
              .where('userEmail', isEqualTo: userEmail)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final contributions = snapshot.data?.docs ?? [];

            // Sort contributions by date
            final sortedContributions = contributions.toList()
              ..sort((a, b) {
                final aTime =
                    (a.data() as Map<String, dynamic>)['createdAt']
                        as Timestamp?;
                final bTime =
                    (b.data() as Map<String, dynamic>)['createdAt']
                        as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

            // Calculate total contributed
            double totalContributed = 0;
            for (var doc in sortedContributions) {
              final data = doc.data() as Map<String, dynamic>;
              totalContributed += (data['totalAmount'] ?? 0).toDouble();
            }

            final remaining = splitAmount - totalContributed;
            final isPaid = remaining <= 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    backgroundImage:
                        profileImageUrl != null && profileImageUrl.isNotEmpty
                        ? NetworkImage(profileImageUrl)
                        : null,
                    child: profileImageUrl == null || profileImageUrl.isEmpty
                        ? Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    userEmail,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isPaid ? 'PAID' : 'DUE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPaid ? Colors.green : Colors.orange,
                        ),
                      ),
                      Text(
                        '৳${remaining.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isPaid ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildDetailItem(
                                  'Required',
                                  splitAmount,
                                  Colors.blue,
                                ),
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: Colors.grey[300],
                                ),
                                _buildDetailItem(
                                  'Contributed',
                                  totalContributed,
                                  Colors.green,
                                ),
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: Colors.grey[300],
                                ),
                                _buildDetailItem(
                                  'Remaining',
                                  remaining.abs(),
                                  isPaid ? Colors.green : Colors.orange,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Contribution History
                          if (sortedContributions.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'No contributions yet',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            )
                          else ...[
                            const Text(
                              'Contribution History',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...sortedContributions.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return _buildContributionHistoryItem(data);
                            }),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          '৳${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildContributionHistoryItem(Map<String, dynamic> data) {
    final contributions = data['contributions'] as List? ?? [];
    final totalAmount = (data['totalAmount'] ?? 0).toDouble();
    final timestamp = data['createdAt'] as Timestamp?;
    final date = timestamp?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date != null
                    ? '${date.day}/${date.month}/${date.year}'
                    : 'Unknown date',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              Text(
                '৳${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          if (contributions.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...contributions.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item['description'] ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    Text(
                      '৳${(item['amount'] ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
