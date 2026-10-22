import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tapaolah/home/home_page.dart';
import 'package:tapaolah/home/topup.dart';
import 'package:tapaolah/utilis/navigation_bar.dart';
import 'package:tapaolah/utilis/theme_notifier.dart';

class InfoPage extends StatefulWidget {
  final String email;

  const InfoPage({super.key, required this.email});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  bool isEditing = false;
  Map<String, dynamic> userData = {};
  final _formKey = GlobalKey<FormState>();
  bool _isUploading = false;
  int _selectedIndex = 0;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _introductionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();

  String? _documentId;
  LatLng? _addressLatLng;
  bool _isMapReady = false;
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    debugPrint("Initializing InfoPage for ${widget.email}");
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _introductionController.dispose();
    _addressController.dispose();
    _phoneNumberController.dispose();
    _genderController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    if (index == 2) return;

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TopUpPage(email: widget.email)),
      );
    } else if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MainFoodPage(email: widget.email)),
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
          _addressLatLng = location;
          _addressController.text = placeName;
        });

        // Animate map
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(location, 15),
          );
        }

        // Update in Firestore (optional immediate update)
        if (_documentId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_documentId)
              .update({
                'address': placeName,
                'location': '$lat,$lon',
                'updatedAt': FieldValue.serverTimestamp(),
              });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Location updated successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ No results found for '$query'")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Error fetching location data")),
      );
    }
  }

  Future<void> _parseLocation() async {
    try {
      if (userData['location'] == null) {
        debugPrint('Location data is null');
        return;
      }

      final locationStr = userData['location'].toString();
      debugPrint('Raw location string: $locationStr');

      final coords = locationStr.split(',');
      if (coords.length != 2) {
        debugPrint('Invalid location format. Expected "lat,lng"');
        return;
      }

      final lat = double.tryParse(coords[0].trim());
      final lng = double.tryParse(coords[1].trim());

      if (lat == null || lng == null) {
        debugPrint('Failed to parse coordinates: lat=$lat, lng=$lng');
        return;
      }

      debugPrint('Successfully parsed coordinates: $lat, $lng');

      setState(() {
        _addressLatLng = LatLng(lat, lng);
      });

      if (_mapController != null && _addressLatLng != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_addressLatLng!, 15),
        );
      }
    } catch (e) {
      debugPrint('Error parsing location: $e');
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_documentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Please save basic info first")),
      );
      return;
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 65,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (pickedFile == null) return;

      setState(() {
        _image = pickedFile;
        _isUploading = true;
      });

      final fileName =
          '${_documentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(
        'user_profile_images/$fileName',
      );

      await ref.putFile(
        File(pickedFile.path),
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'uploadedBy': widget.email},
        ),
      );

      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_documentId)
          .update({'profileImage': downloadUrl});

      setState(() {
        userData['profileImage'] = downloadUrl;
        _isUploading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("✅ Profile image updated")));
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Upload failed: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAddressSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Address",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _addressController,
                  enabled: isEditing && !_isUploading,
                  decoration: InputDecoration(
                    hintText: "Search address (e.g. KLCC, APU...)",
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    filled: true,
                    fillColor: isEditing ? Colors.white : Colors.grey.shade100,
                  ),
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'This field is required'
                              : null,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed:
                    () => _searchAndUpdateLocation(_addressController.text),
                child: const Text('Go'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Profile"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.wb_sunny
                  : Icons.nightlight_round,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              final themeNotifier = Provider.of<ThemeNotifier>(
                context,
                listen: false,
              );
              themeNotifier.toggleTheme();
            },
          ),
          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit),
            onPressed: () async {
              if (isEditing) {
                await _saveChanges();
              } else {
                setState(() => isEditing = true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Logout function here
            },
          ),
        ],
      ),

      body: FutureBuilder<QuerySnapshot>(
        future:
            FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: widget.email)
                .limit(1)
                .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("User not found"));
          }

          final doc = snapshot.data!.docs.first;
          if (!mounted) return const SizedBox();

          userData = doc.data() as Map<String, dynamic>;
          _documentId = doc.id;

          if (!isEditing) {
            _fullNameController.text = userData['fullName'] ?? '';
            _usernameController.text = userData['username'] ?? '';
            _introductionController.text = userData['introduction'] ?? '';
            _addressController.text = userData['address'] ?? '';
            _phoneNumberController.text = userData['phoneNumber'] ?? '';
            _genderController.text = userData['gender'] ?? '';
          }

          if (_addressLatLng == null && userData['location'] != null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _parseLocation(),
            );
          }

          DateTime createdAt = (userData['createdAt'] as Timestamp).toDate();
          String formattedDate = DateFormat(
            'MMMM d, y - h:mm a',
          ).format(createdAt);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildProfilePicture(),
                  const SizedBox(height: 20),
                  _buildEditableField(
                    "Full Name",
                    _fullNameController,
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Full name is required';
                      if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value))
                        return 'Only letters allowed';
                      return null;
                    },
                  ),

                  _buildEditableField("Username", _usernameController),
                  _buildInfoField("Email", userData['email']),
                  _buildEditableField(
                    "Phone Number",
                    _phoneNumberController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Phone number is required';
                      }
                      if (!RegExp(r'^1\d{8,9}$').hasMatch(value)) {
                        return 'Phone number must start with 1 and be 9 or 10 digits';
                      }
                      return null;
                    },
                  ),

                  _buildInfoField("Gender", userData['gender']),
                  isEditing
                      ? _buildEditableField(
                        "Introduction",
                        _introductionController,
                        maxLines: 3,
                      )
                      : _buildInfoField(
                        "Introduction",
                        userData['introduction'],
                      ),
                  isEditing
                      ? _buildAddressSearchField()
                      : _buildInfoField("Address", userData['address']),
                  _buildMapWidget(),
                  _buildInfoField("Member Since", formattedDate),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar:
          isEditing
              ? null
              : BottomNavBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
              ),
    );
  }

  Widget _buildProfilePicture() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: _getProfileImage(),
            child:
                _isUploading
                    ? const CircularProgressIndicator()
                    : userData['profileImage'] == null
                    ? const Icon(Icons.person, size: 60)
                    : null,
          ),
          if (!_isUploading)
            Positioned(
              right: 5,
              bottom: 5,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),

                child: IconButton(
                  icon: const Icon(Icons.camera_alt, size: 20),
                  onPressed: _pickAndUploadImage,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapWidget() {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          '📍 Location',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              _addressLatLng == null
                  ? const Center(child: CircularProgressIndicator())
                  : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _addressLatLng!,
                      zoom: 15,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLngZoom(_addressLatLng!, 15),
                      );
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('userLocation'),
                        position: _addressLatLng!,
                        infoWindow: InfoWindow(
                          title: userData['address'] ?? 'Your Location',
                        ),
                      ),
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                  ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  ImageProvider? _getProfileImage() {
    if (_image != null) {
      return FileImage(File(_image!.path));
    } else if (userData['profileImage'] != null) {
      return NetworkImage(userData['profileImage']);
    }
    return null;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      // Update user document first
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_documentId)
          .update({
            'fullName': _fullNameController.text,
            'username': _usernameController.text,
            'introduction': _introductionController.text,
            'address': _addressController.text,
            'phoneNumber': _phoneNumberController.text,
            'gender': _genderController.text,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Then synchronize to orderInfo
      final ordersUpdated = await _syncToOrderInfo();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ordersUpdated > 0
                ? '✅ Profile and $ordersUpdated order(s) updated'
                : '✅ Profile updated (no orders found)',
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() => isEditing = false);
    } catch (e) {
      final errorMessage = _getUserFriendlyError(e);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $errorMessage'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(label: 'Retry', onPressed: _saveChanges),
        ),
      );

      debugPrint(
        'Update Error: ${e.toString()}\n${e is Error ? e.stackTrace : ''}',
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<int> _syncToOrderInfo() async {
    if (_documentId == null) {
      throw Exception('User document not loaded');
    }

    try {
      final orderSnapshot =
          await FirebaseFirestore.instance
              .collection('orderInfo')
              .where('email', isEqualTo: widget.email)
              .get();

      if (orderSnapshot.docs.isEmpty) return 0;

      final batch = FirebaseFirestore.instance.batch();
      final updateData = {
        'userFullName': _fullNameController.text,
        'userPhone': _phoneNumberController.text,
        'userAddress': _addressController.text,
        'userGender': _genderController.text,
        'userProfileImage': userData['profileImage'] ?? '',
        'username': _usernameController.text,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      for (final doc in orderSnapshot.docs) {
        batch.update(doc.reference, updateData);
      }

      await batch.commit();
      return orderSnapshot.docs.length;
    } catch (e) {
      debugPrint('Order Sync Error: $e');
      rethrow;
    }
  }

  String _getUserFriendlyError(dynamic error) {
    final message = error.toString();

    if (message.contains('PERMISSION_DENIED')) {
      return 'You don\'t have permission to update';
    } else if (message.contains('network error')) {
      return 'Network connection failed';
    } else if (message.contains('user document not loaded')) {
      return 'User data not loaded properly';
    } else if (message.contains('firestore')) {
      return 'Database operation failed';
    }

    return 'Something went wrong. Please try again';
  }

  Widget _buildInfoField(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value?.toString() ?? 'Not specified',
            style: const TextStyle(fontSize: 16),
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            enabled: isEditing && !_isUploading,
            maxLines: maxLines,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              filled: true,
              fillColor: isEditing ? Colors.white : Colors.grey.shade100,
            ),
            validator:
                validator ??
                (value) =>
                    value == null || value.isEmpty
                        ? 'This field is required'
                        : null,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
