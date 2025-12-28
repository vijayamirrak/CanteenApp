import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_status_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final Map<String, bool> selectedItems = {};

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final currentSession = hour < 12 ? 'morning' : 'afternoon';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Menu"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 🕒 SESSION LABEL
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Text(
              currentSession == 'morning'
                  ? '☀️ Morning Menu'
                  : '🌤️ Afternoon Menu',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // 🍽️ GRID MENU WITH ANIMATION
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('menu')
                  .where('available', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (!data.containsKey('session')) return true;
                  return data['session'] == currentSession;
                }).toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final doc = items[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final id = doc.id;
                    final name = data['name'];
                    final price = data['price'];
                    final imageAsset = data['imageAsset'];

                    selectedItems.putIfAbsent(id, () => false);

                    final isSelected = selectedItems[id]!;

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          selectedItems[id] = !isSelected;
                        });
                      },
                      child: AnimatedScale(
                        scale: isSelected ? 1.05 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: Card(
                          elevation: isSelected ? 10 : 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 🖼️ IMAGE
                              Expanded(
                                child: ClipRRect(
                                  borderRadius:
                                      const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: imageAsset != null
                                      ? Image.asset(
                                          imageAsset,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: Colors.grey.shade300,
                                          child: const Icon(
                                            Icons.fastfood,
                                            size: 48,
                                          ),
                                        ),
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '₹$price',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        AnimatedSwitcher(
                                          duration: const Duration(
                                              milliseconds: 200),
                                          transitionBuilder:
                                              (child, animation) =>
                                                  ScaleTransition(
                                            scale: animation,
                                            child: child,
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  Icons.check_circle,
                                                  color: Colors.green,
                                                  key: ValueKey('selected'),
                                                )
                                              : const Icon(
                                                  Icons
                                                      .radio_button_unchecked,
                                                  color: Colors.grey,
                                                  key:
                                                      ValueKey('unselected'),
                                                ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 🛒 PLACE ORDER BUTTON
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text('Place Order'),
                onPressed: _placeOrder,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🧾 PLACE ORDER
  Future<void> _placeOrder() async {
    final selected = selectedItems.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item')),
      );
      return;
    }

    final docRef =
        await FirebaseFirestore.instance.collection('orders').add({
      'items': selected,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastOrderId', docRef.id);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Order Placed ✅'),
        content: Text('Order ID:\n\n${docRef.id}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      OrderStatusScreen(orderId: docRef.id),
                ),
              );
            },
            child: const Text('Track Order'),
          ),
        ],
      ),
    );

    setState(() {
      selectedItems.updateAll((key, value) => false);
    });
  }
}
