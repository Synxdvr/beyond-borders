import 'dart:io';
import 'package:beyond_borders/authentication/custom_auth_appbar.dart';
import 'package:beyond_borders/components/custom_drawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import '../services/notification_service.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({Key? key}) : super(key: key);

  @override
  _CommunityPageState createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  late DatabaseReference _postsRef;
  late DatabaseReference _usersRef;

  List<Post> _posts = [];
  bool _isLoading = true;
  bool _isPostingLoading = false;
  double _uploadProgress = 0.0;
  String _currentUserFullName = '';
  String _currentUserProfileImage = '';

  // Controllers for creating post form
  final TextEditingController _postTextController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  File? _imageFile;
  String _currentLocation = '';

  // Theme colors for Twitter/Threads style
  final Color _primaryColor = const Color(0xFF1DA1F2); // Twitter blue
  final Color _lightGrayColor = const Color(0xFFE1E8ED);
  final Color _mediumGrayColor = const Color(0xFFAAB8C2);
  final Color _darkGrayColor = const Color(0xFF657786);
  final Color _textColor = const Color(0xFF14171A);

  bool _hasUnreadNotifications = false;
  late DatabaseReference _notificationsRef;

  @override
  void initState() {
    super.initState();
    _database.databaseURL =
        'https://test-project-60c5e-default-rtdb.asia-southeast1.firebasedatabase.app/';
    _postsRef = _database.ref().child('posts');
    _usersRef = _database.ref().child('users');
    _notificationsRef = _database.ref().child('notifications');
    _fetchCurrentUserData();
    _fetchPosts();
  }

  Future<void> _fetchCurrentUserData() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userSnapshot.exists && userSnapshot.data() != null) {
        Map<String, dynamic>? userData =
            userSnapshot.data() as Map<String, dynamic>?;
        if (userData != null) {
          setState(() {
            _currentUserFullName = userData['fullName'] ?? 'User';
            _currentUserProfileImage = userData['profileImage'] ?? '';
          });
        }
      }
    }
  }

  // Check for unread notifications
  Future<void> _checkUnreadNotifications() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      _notificationsRef
          .orderByChild('receiverId')
          .equalTo(currentUser.uid)
          .onValue
          .listen((event) {
        bool hasUnread = false;
        if (event.snapshot.value != null) {
          Map<dynamic, dynamic>? notifications = event.snapshot.value as Map?;
          if (notifications != null) {
            notifications.forEach((key, value) {
              if (value['read'] == false) {
                hasUnread = true;
              }
            });
          }
        }

        setState(() {
          _hasUnreadNotifications = hasUnread;
        });
      });
    }
  }

  void _fetchPosts() {
    _postsRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _posts = [];
          Map<dynamic, dynamic>? values = event.snapshot.value as Map?;
          if (values != null) {
            values.forEach((key, value) {
              _posts.add(Post.fromRTDB(key, value));
            });
            _posts
                .sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _posts = [];
          _isLoading = false;
        });
      }
    }, onError: (error) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading posts: $error')),
      );
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
          maxWidth: 1200,
          maxHeight: 1200);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        print("Image picked successfully: ${pickedFile.path}");
      }
    } catch (e) {
      print("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        print("Photo taken successfully: ${pickedFile.path}");
      }
    } catch (e) {
      print("Error taking photo: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take photo: $e')),
      );
    }
  }

  Future<File> compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Read the file
    final image = img.decodeImage(await file.readAsBytes());
    if (image == null) {
      return file; // Return original if decoding fails
    }

    // Resize and compress
    final compressedImage = img.encodeJpg(image, quality: 85);

    // Save to new file
    final result = await File(targetPath).writeAsBytes(compressedImage);

    return result;
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _locationController.text = "Fetching location...";
      });

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          setState(() {
            _locationController.text = "";
          });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String locality = place.locality ?? '';
        String adminArea = place.administrativeArea ?? '';
        _currentLocation =
            locality.isNotEmpty ? "$locality, $adminArea" : adminArea;

        setState(() {
          _locationController.text = _currentLocation;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
      setState(() {
        _locationController.text = "";
      });
    }
  }

  Future<void> _createPost() async {
    if (_postTextController.text.trim().isEmpty && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add some text or an image to your post')),
      );
      return;
    }

    setState(() {
      _isPostingLoading = true;
      _uploadProgress = 0.0;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      // Get the latest user data
      DataSnapshot userSnapshot = await _usersRef.child(currentUser.uid).get();

      String fullName = _currentUserFullName;
      String userProfileImage = _currentUserProfileImage;

      if (userSnapshot.exists && userSnapshot.value != null) {
        Map<dynamic, dynamic>? userData = userSnapshot.value as Map?;
        if (userData != null) {
          fullName = userData['fullName'] ?? fullName;
          userProfileImage = userData['profileImage'] ?? userProfileImage;
        }
      }

      String? imageUrl;

      if (_imageFile != null) {
        try {
          // Compress image before uploading
          File compressedImage = await compressImage(_imageFile!);

          String fileName =
              'posts/${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          Reference storageRef = _storage.ref().child(fileName);

          // Track upload progress
          UploadTask uploadTask = storageRef.putFile(compressedImage);

          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            double progress = snapshot.bytesTransferred / snapshot.totalBytes;
            setState(() {
              _uploadProgress = progress;
            });
          });

          // Wait for upload to complete
          await uploadTask;
          imageUrl = await storageRef.getDownloadURL();
        } catch (e) {
          print('Error uploading image: $e');
          // Continue without image if upload fails
        }
      }

      Map<String, dynamic> postData = {
        'userId': currentUser.uid,
        'fullName': fullName,
        'userProfileImage': userProfileImage,
        'text': _postTextController.text.trim(),
        'location': _locationController.text.trim(),
        'imageUrl': imageUrl,
        'likes': 0,
        'likedBy': {},
        'timestamp': ServerValue.timestamp,
      };

      DatabaseReference newPostRef = _postsRef.push();
      await newPostRef.set(postData);

      setState(() {
        _postTextController.clear();
        _locationController.clear();
        _imageFile = null;
        _isPostingLoading = false;
      });


      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Post created successfully!'),
          backgroundColor: _primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      );
      return;
    } catch (e) {
      setState(() {
        _isPostingLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create post: $e')),
      );
      rethrow;
    }
  }

  Future<void> _toggleLike(Post post) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to like posts')),
        );
        return;
      }

      DatabaseReference likedByRef =
          _postsRef.child(post.id).child('likedBy').child(currentUser.uid);

      DatabaseReference likesRef = _postsRef.child(post.id).child('likes');

      DataSnapshot likeSnapshot = await likedByRef.get();

      if (likeSnapshot.exists) {
        await likedByRef.remove();
        await likesRef.set(ServerValue.increment(-1));
      } else {
        await likedByRef.set(true);
        await likesRef.set(ServerValue.increment(1));

        NotificationService notificationService = NotificationService();

        await notificationService.createLikeNotification(
          postId: post.id,
          postOwnerId: post.userId,
          postText: post.text,
          postImageUrl: post.imageUrl,
        );

        _checkUnreadNotifications();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like: $e')),
      );
    }
  }

  Future<void> _deletePost(Post post) async {
    // Show confirmation dialog before deleting
    bool confirmDelete = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Post'),
              content: const Text(
                  'Are you sure you want to delete this post? This action cannot be undone.'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child:
                      Text('Cancel', style: TextStyle(color: _darkGrayColor)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child:
                      const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        ) ??
        false;

    // If user didn't confirm, return
    if (!confirmDelete) return;

    try {
      // Check if user is the post owner
      User? currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.uid != post.userId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can only delete your own posts')),
        );
        return;
      }

      // Delete image if exists
      if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
        try {
          // Extract the path from the URL
          Reference imageRef = _storage.refFromURL(post.imageUrl!);
          await imageRef.delete();
        } catch (e) {
          print('Error deleting image: $e');
          // Continue with post deletion even if image deletion fails
        }
      }

      // Delete post from database
      await _postsRef.child(post.id).remove();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Post deleted successfully'),
          backgroundColor: _primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete post: $e')),
      );
    }
  }

  Future<File?> _showImageOptions() async {
    return showModalBottomSheet<File>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _mediumGrayColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: _primaryColor),
                  title: Text('Choose from Gallery',
                      style: TextStyle(color: _textColor)),
                  onTap: () async {
                    final pickedFile = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                    );
                    if (pickedFile != null) {
                      Navigator.pop(context, File(pickedFile.path));
                    } else {
                      Navigator.pop(context, null);
                    }
                  },
                ),
                const Divider(height: 0.5),
                ListTile(
                  leading: Icon(Icons.camera_alt, color: _primaryColor),
                  title: Text('Take a Photo', style: TextStyle(color: _textColor)),
                  onTap: () async {
                    final pickedFile = await ImagePicker().pickImage(
                      source: ImageSource.camera,
                    );
                    if (pickedFile != null) {
                      Navigator.pop(context, File(pickedFile.path));
                    } else {
                      Navigator.pop(context, null);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _viewImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreatePostPopup() {
    // Reset state before showing dialog
    _imageFile = null;
    _postTextController.clear();
    _locationController.clear();

    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (dialogContext, setDialogState) {
          // Add text counter function
          final int charCount = _postTextController.text.length;
          final bool isTextValid = charCount > 0 && charCount <= 200;
          final bool canPost = isTextValid && !_isPostingLoading;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
            backgroundColor: Colors.white,
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header - New Post
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'New Post',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                          // Close button
                          IconButton(
                            icon: Icon(Icons.close, color: _darkGrayColor),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    const Divider(),

                    // Profile and input section
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile avatar
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: _currentUserProfileImage.isNotEmpty
                                ? NetworkImage(_currentUserProfileImage)
                                : null,
                            backgroundColor: _primaryColor,
                            child: _currentUserProfileImage.isEmpty
                                ? const Icon(Icons.person, size: 24, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          // Text input field
                          Expanded(
                            child: TextField(
                              controller: _postTextController,
                              decoration: InputDecoration(
                                hintText: 'What\'s happening?',
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: _mediumGrayColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                // Show error message if text exceeds limit
                                errorText: charCount > 200 ? 'Maximum 200 characters allowed' : null,
                              ),
                              style: TextStyle(
                                fontSize: 18,
                                color: _textColor,
                              ),
                              maxLines: 8,
                              minLines: 1,
                              onChanged: (_) {
                                // Update the dialog state when text changes to refresh counter
                                setDialogState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Character counter
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          '$charCount/200',
                          style: TextStyle(
                            color: charCount > 200 ? Colors.red : _darkGrayColor,
                            fontSize: 12,
                            fontWeight: charCount > 200 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),

                    // Image preview if selected
                    if (_imageFile != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.25,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _lightGrayColor),
                        ),
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.file(
                                _imageFile!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  _imageFile = null;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Location input with rounded border
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: _lightGrayColor.withOpacity(0.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: _primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _locationController,
                              decoration: InputDecoration(
                                hintText: 'Add location',
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: _darkGrayColor),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              style: TextStyle(color: _textColor),
                            ),
                          ),
                          GestureDetector(
                            onTap: _getCurrentLocation,
                            child: Icon(Icons.my_location, color: _primaryColor, size: 20),
                          ),
                        ],
                      ),
                    ),

                    // Upload progress indicator
                    if (_isPostingLoading && _uploadProgress > 0 && _uploadProgress < 1)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Uploading image: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(color: _darkGrayColor, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: _lightGrayColor,
                            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    const Divider(),

                    // Bottom row with image picker and post button
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Image picker button
                          GestureDetector(
                            onTap: _isPostingLoading ? null : () {
                              _showImageOptions().then((selectedImageFile) {
                                if (selectedImageFile != null) {
                                  setDialogState(() {
                                    _imageFile = selectedImageFile;
                                  });
                                }
                              });
                            },
                            child: Opacity(
                              opacity: _isPostingLoading ? 0.5 : 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Icon(
                                  Icons.image,
                                  color: _primaryColor,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),

                          // Post status loading indicator
                          if (_isPostingLoading && (_uploadProgress == 0 || _uploadProgress == 1))
                            Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Posting...',
                                  style: TextStyle(
                                    color: _darkGrayColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),

                          // Post button
                          ElevatedButton(
                            onPressed: canPost ? () {
                              // Validate before posting
                              if (_postTextController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter some text for your post'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }

                              setDialogState(() {
                                _isPostingLoading = true;
                              });

                              _createPost().then((_) {
                                // Handle completion
                                Navigator.pop(context);
                              }).catchError((error) {
                                // Handle error
                                setDialogState(() {
                                  _isPostingLoading = false;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error posting: ${error.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              });
                            } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _primaryColor.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Post',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
        });
      },
    );
  }

  AppBar buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Text(
        'Community',
        style: TextStyle(
          color: _textColor,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      iconTheme: IconThemeData(color: _darkGrayColor),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications_outlined, color: _darkGrayColor),
              onPressed: () {
                Navigator.pushNamed(context, '/notifications');
              },
            ),
            if (_hasUnreadNotifications)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: buildAppBar(context),
      drawer: const CustomDrawer(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: _mediumGrayColor),
                      const SizedBox(height: 16),
                      Text(
                        'No posts yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to share something!',
                        style: TextStyle(
                          color: _darkGrayColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: _primaryColor,
                  onRefresh: () async {
                    setState(() {
                      _isLoading = true;
                    });
                    _fetchPosts();
                  },
                  child: ListView.separated(
                    itemCount: _posts.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, thickness: 0.5),
                    padding: const EdgeInsets.all(10),
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      Post post = _posts[index];
                      bool userLiked = _auth.currentUser != null &&
                          post.likedBy.contains(_auth.currentUser!.uid);
                      bool isOwner = _auth.currentUser != null &&
                          _auth.currentUser!.uid == post.userId;

                      return Container(
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 16, right: 16, top: 16, bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // User avatar
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: post
                                            .userProfileImage.isNotEmpty
                                        ? NetworkImage(post.userProfileImage)
                                        : null,
                                    backgroundColor: _primaryColor,
                                    child: post.userProfileImage.isEmpty
                                        ? const Icon(Icons.person,
                                            color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),

                                  // Content column
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header row with name and time
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Text(
                                                    post.fullName,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: _textColor,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  // Verified badge if needed
                                                  // Icon(Icons.verified, color: _primaryColor, size: 16),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '· ${_formatTimestamp(post.timestamp)}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: _darkGrayColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isOwner)
                                              GestureDetector(
                                                onTap: () => _deletePost(post),
                                                child: Icon(
                                                  Icons.more_horiz,
                                                  color: _darkGrayColor,
                                                  size: 20,
                                                ),
                                              ),
                                          ],
                                        ),

                                        // Location if available
                                        if (post.location.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 2, bottom: 6),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on,
                                                  size: 14,
                                                  color: _darkGrayColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    post.location,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: _darkGrayColor,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        // Post text content
                                        if (post.text.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 8, bottom: 12),
                                            child: Text(
                                              post.text,
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: _textColor,
                                                height: 1.3,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Post image if available
                            if (post.imageUrl != null &&
                                post.imageUrl!.isNotEmpty)
                              GestureDetector(
                                onTap: () => _viewImage(post.imageUrl!),
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                                  ),
                                  width: double.infinity,
                                  child: CachedNetworkImage(
                                    imageUrl: post.imageUrl!,
                                    placeholder: (context, url) => Container(
                                      height: 200,
                                      color: _lightGrayColor.withOpacity(0.5),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  _primaryColor),
                                          strokeWidth: 3,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      height: 200,
                                      color: _lightGrayColor.withOpacity(0.5),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.error,
                                                color: Colors.red),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Failed to load image',
                                              style: TextStyle(
                                                  color: _darkGrayColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),

                            // Post interaction buttons
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Like button
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _toggleLike(post),
                                        child: Icon(
                                          userLiked
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: userLiked
                                              ? Colors.red
                                              : _darkGrayColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${post.likes}',
                                        style: TextStyle(
                                          color: _darkGrayColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePostPopup,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) return 'Just now';

    DateTime postTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    DateTime now = DateTime.now();
    Duration difference = now.difference(postTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(postTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Just now';
    }
  }
}

// Modified Post model for Realtime Database
class Post {
  final String id;
  final String userId;
  final String fullName;
  final String userProfileImage;
  final String text;
  final String location;
  final String? imageUrl;
  final int likes;
  final List<String> likedBy;
  final int? timestamp;

  Post({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.userProfileImage,
    required this.text,
    required this.location,
    this.imageUrl,
    required this.likes,
    required this.likedBy,
    this.timestamp,
  });

  // Factory constructor for Realtime Database
  factory Post.fromRTDB(String key, Map<dynamic, dynamic> data) {
    // Handle likedBy which is a Map in RTDB
    List<String> likedByList = [];
    if (data['likedBy'] != null) {
      (data['likedBy'] as Map).forEach((key, value) {
        if (value == true) {
          likedByList.add(key.toString());
        }
      });
    }

    return Post(
      id: key,
      userId: data['userId'] ?? '',
      fullName: data['fullName'] ?? 'User',
      userProfileImage: data['userProfileImage'] ?? '',
      text: data['text'] ?? '',
      location: data['location'] ?? '',
      imageUrl: data['imageUrl'],
      likes: data['likes'] ?? 0,
      likedBy: likedByList,
      timestamp: data['timestamp'] as int?,
    );
  }
}
