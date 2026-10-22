import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class OrderInfoPage extends StatefulWidget {
  final String email;
  final String deliveryMethod;

  const OrderInfoPage({
    super.key,
    required this.email,
    required this.deliveryMethod,
  });

  @override
  State<OrderInfoPage> createState() => _OrderInfoPageState();
}

class _OrderInfoPageState extends State<OrderInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool isLoading = true;
  bool _isUsingProfileInfo = false;
  late String _deliveryMethod;

  LatLng? _selectedLatLng;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    fetchUserInfo();
    _deliveryMethod = widget.deliveryMethod;
  }

  Future<void> fetchUserInfo() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('orderInfo')
            .doc(widget.email)
            .get();

    if (doc.exists && doc.data()!.containsKey('latest')) {
      final latest = doc.data()!['latest'];
      _nameController.text = latest['name'] ?? '';
      _addressController.text = latest['address'] ?? '';
      _phoneController.text = latest['phone'] ?? '';

      if (latest['location'] != null) {
        final parts = latest['location'].split(',');
        if (parts.length == 2) {
          _selectedLatLng = LatLng(
            double.tryParse(parts[0]) ?? 0.0,
            double.tryParse(parts[1]) ?? 0.0,
          );
        }
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _fetchUserProfileInfo() async {
    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: widget.email)
              .limit(1)
              .get();

      if (userDoc.docs.isNotEmpty) {
        final data = userDoc.docs.first.data();

        setState(() {
          _nameController.text = data['fullName'] ?? '';
          _addressController.text = data['address'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          _isUsingProfileInfo = true;
        });

        if (data['location'] != null) {
          final parts = data['location'].split(',');
          if (parts.length == 2) {
            final lat = double.tryParse(parts[0]) ?? 0.0;
            final lon = double.tryParse(parts[1]) ?? 0.0;
            final location = LatLng(lat, lon);
            _selectedLatLng = location;
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(location, 15),
            );
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Loaded info from user profile")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ User profile not found")),
        );
      }
    } catch (e) {
      print("Error fetching profile info: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to load user profile")),
      );
    }
  }

  Future<void> _searchAndUpdateLocation(String query) async {
    if (query.trim().isEmpty) return;

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
    );

    final response = await http.get(
      url,
      headers: {'User-Agent': 'FlutterAppExample/1.0'},
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);

      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);
        final placeName = data[0]['display_name'];

        final LatLng location = LatLng(lat, lon);

        setState(() {
          _selectedLatLng = location;
          _addressController.text = placeName;
        });

        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 15));

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ Location updated")));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ No results for '$query'")));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Error fetching location")),
      );
    }
  }

  Future<void> saveUserInfo() async {
    final trimmedName = _nameController.text.trim();
    final trimmedAddress = _addressController.text.trim();
    final trimmedPhone = _phoneController.text.trim();

    final recordData = {
      'name': trimmedName,
      'address': trimmedAddress,
      'phone': trimmedPhone,
      'timestamp': FieldValue.serverTimestamp(),
      'location':
          _selectedLatLng != null
              ? '${_selectedLatLng!.latitude},${_selectedLatLng!.longitude}'
              : null,
    };

    final userDocRef = FirebaseFirestore.instance
        .collection('orderInfo')
        .doc(widget.email);

    final existing =
        await userDocRef
            .collection('records')
            .where('name', isEqualTo: trimmedName)
            .where('address', isEqualTo: trimmedAddress)
            .where('phone', isEqualTo: trimmedPhone)
            .get();

    if (existing.docs.isEmpty) {
      await userDocRef.collection('records').add(recordData);
    }

    await userDocRef.set({'latest': recordData}, SetOptions(merge: true));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Saved successfully")));

    Navigator.pop(context, {
      'name': trimmedName,
      'address': trimmedAddress,
      'phone': trimmedPhone,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Order Info")),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.person),
                        label: const Text("Use My User Profile Info"),
                        onPressed: _fetchUserProfileInfo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            enabled: !_isUsingProfileInfo,
                            decoration: const InputDecoration(
                              labelText: "Name",
                            ),
                            validator:
                                (value) =>
                                    value == null || value.isEmpty
                                        ? "Required"
                                        : null,
                          ),
                          const SizedBox(height: 12),

                          // Only show below fields if it's Delivery
                          if (_deliveryMethod == 'Delivery') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _addressController,
                                    enabled: !_isUsingProfileInfo,
                                    decoration: const InputDecoration(
                                      labelText: "Search Address",
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed:
                                      () => _searchAndUpdateLocation(
                                        _addressController.text,
                                      ),
                                  child: const Text("Go"),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            SizedBox(
                              height: 200,
                              child:
                                  _selectedLatLng == null
                                      ? const Center(
                                        child: Text("No location selected"),
                                      )
                                      : GoogleMap(
                                        initialCameraPosition: CameraPosition(
                                          target: _selectedLatLng!,
                                          zoom: 15,
                                        ),
                                        onMapCreated:
                                            (controller) =>
                                                _mapController = controller,
                                        markers: {
                                          Marker(
                                            markerId: const MarkerId(
                                              "selected",
                                            ),
                                            position: _selectedLatLng!,
                                          ),
                                        },
                                        myLocationEnabled: true,
                                        zoomControlsEnabled: false,
                                      ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              enabled: !_isUsingProfileInfo,
                              decoration: const InputDecoration(
                                labelText: "Phone Number",
                              ),
                              keyboardType: TextInputType.phone,
                              validator:
                                  (value) =>
                                      value == null || value.isEmpty
                                          ? "Required"
                                          : null,
                            ),
                            const SizedBox(height: 12),
                          ],

                          ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text("Save Info"),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                            ),
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                saveUserInfo();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      "Previous Records",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: FutureBuilder<QuerySnapshot>(
                        future:
                            FirebaseFirestore.instance
                                .collection('orderInfo')
                                .doc(widget.email)
                                .collection('records')
                                .orderBy('timestamp', descending: true)
                                .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = snapshot.data!.docs;
                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data =
                                  docs[index].data() as Map<String, dynamic>;
                              return Card(
                                child: ListTile(
                                  title: Text(data['name'] ?? 'No Name'),
                                  subtitle: Text(
                                    "${data['address']}\n${data['phone']}",
                                  ),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        ),
                                        tooltip: 'Apply this record',
                                        onPressed: () {
                                          Navigator.pop(context, {
                                            'name': data['name'] ?? '',
                                            'address': data['address'] ?? '',
                                            'phone': data['phone'] ?? '',
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Delete this record',
                                        onPressed: () async {
                                          await docs[index].reference.delete();
                                          setState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    _nameController.text = data['name'] ?? '';
                                    _addressController.text =
                                        data['address'] ?? '';
                                    _phoneController.text = data['phone'] ?? '';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Record applied to form"),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
