import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_menu_editor.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.hourglass_bottom;
    }
  }

  // 🔓 Logout confirmation
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Logout'),
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          // 🍽️ MENU EDITOR
          IconButton(
            icon: const Icon(Icons.restaurant_menu),
            tooltip: 'Edit Menu',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminMenuEditor(),
                ),
              );
            },
          ),

          // 🔓 LOGOUT
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),

      // 📦 ORDERS LIST
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No orders yet'));
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'pending';
              final itemIds = List<String>.from(data['items'] ?? []);

              return Card(
                elevation: 6,
                margin: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🆔 HEADER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order #${orders.length - index}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Chip(
                            avatar: Icon(
                              _statusIcon(status),
                              size: 18,
                              color: _statusColor(status),
                            ),
                            label: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: _statusColor(status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor:
                                _statusColor(status).withOpacity(0.15),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),
                      Text(
                        'Order ID: ${doc.id}',
                        style: const TextStyle(fontSize: 12),
                      ),

                      const Divider(height: 24),

                      // 🍽️ ITEMS (FETCH NAMES)
                      const Text(
                        'Items',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      ...itemIds.map(
                        (itemId) => FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('menu')
                              .doc(itemId)
                              .get(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Text('Loading item...');
                            }

                            if (!snapshot.data!.exists) {
                              return const Text(
                                'Item removed',
                                style: TextStyle(color: Colors.red),
                              );
                            }

                            final itemData = snapshot.data!.data()
                                as Map<String, dynamic>;

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.fastfood, size: 18),
                                  const SizedBox(width: 8),
                                  Text(itemData['name']),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ✅ ACTION BUTTONS
                      if (status == 'pending')
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check),
                                label: const Text('Accept'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  FirebaseFirestore.instance
                                      .collection('orders')
                                      .doc(doc.id)
                                      .update({'status': 'accepted'});
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  FirebaseFirestore.instance
                                      .collection('orders')
                                      .doc(doc.id)
                                      .update({'status': 'rejected'});
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
