import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminMenuEditor extends StatefulWidget {
  const AdminMenuEditor({super.key});

  @override
  State<AdminMenuEditor> createState() => _AdminMenuEditorState();
}

class _AdminMenuEditorState extends State<AdminMenuEditor> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageController = TextEditingController();

  String category = 'snacks';
  String session = 'all';

  void _openMenuDialog({DocumentSnapshot? doc}) {
    if (doc != null) {
      final data = doc.data() as Map<String, dynamic>;
      _nameController.text = data['name'];
      _priceController.text = data['price'].toString();
      _imageController.text = data['imageAsset'] ?? '';
      category = data['category'] ?? 'snacks';
      session = data['session'] ?? 'all';
    } else {
      _nameController.clear();
      _priceController.clear();
      _imageController.clear();
      category = 'snacks';
      session = 'all';
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(doc == null ? 'Add Menu Item' : 'Edit Menu Item'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              TextField(
                controller: _imageController,
                decoration: const InputDecoration(
                  labelText: 'Image Asset Path',
                  hintText: 'assets/images/item.png',
                ),
              ),
              const SizedBox(height: 12),

              // CATEGORY
              DropdownButtonFormField(
                value: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'snacks', child: Text('Snacks')),
                  DropdownMenuItem(value: 'drinks', child: Text('Drinks')),
                  DropdownMenuItem(value: 'meals', child: Text('Meals')),
                ],
                onChanged: (val) => category = val!,
              ),

              // SESSION
              DropdownButtonFormField(
                value: session,
                decoration: const InputDecoration(labelText: 'Session'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Day')),
                  DropdownMenuItem(value: 'morning', child: Text('Morning')),
                  DropdownMenuItem(value: 'afternoon', child: Text('Afternoon')),
                ],
                onChanged: (val) => session = val!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () async {
              if (_nameController.text.isEmpty ||
                  _priceController.text.isEmpty) return;

              final data = {
                'name': _nameController.text,
                'price': int.parse(_priceController.text),
                'category': category,
                'session': session == 'all' ? null : session,
                'available': true,
                'imageAsset': _imageController.text.isEmpty
                    ? null
                    : _imageController.text,
              };

              if (doc == null) {
                await FirebaseFirestore.instance
                    .collection('menu')
                    .add(data);
              } else {
                await FirebaseFirestore.instance
                    .collection('menu')
                    .doc(doc.id)
                    .update(data);
              }

              Navigator.pop(context);
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
        title: const Text('Menu Editor'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openMenuDialog(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance.collection('menu').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No menu items'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(data['name']),
                  subtitle: Text(
                      '₹${data['price']} • ${data['category']} • ${data['session'] ?? 'All Day'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: data['available'] ?? true,
                        onChanged: (val) {
                          FirebaseFirestore.instance
                              .collection('menu')
                              .doc(doc.id)
                              .update({'available': val});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openMenuDialog(doc: doc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('menu')
                              .doc(doc.id)
                              .delete();
                        },
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
