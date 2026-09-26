import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../widgets/profile_image_widget.dart';
import 'create_post_screen.dart';
import '../profile/profile_screen.dart';

class InfoScreen extends StatefulWidget {
  final String? initialPostId;

  const InfoScreen({super.key, this.initialPostId});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _currentUser;
  final Set<String> _loadingReactions = {};
  int _selectedTab = 0; // 0 for Posts, 1 for My Posts
  final Set<String> _pinnedPostIds = {};
  String _searchQuery = '';

  String get _initialPostId => widget.initialPostId?.trim() ?? '';
  bool get _isNotificationDeepLinkMode => _initialPostId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isNotificationDeepLinkMode) {
      _selectedTab = 0;
    }
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        final userData = await _firestoreService.getUser(user.uid);
        if (mounted) {
          setState(() {
            _currentUser = userData;
          });
          _loadPinnedPosts();
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadPinnedPosts() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    try {
      final pinnedSnapshot = await _firestoreService
          .getPinnedPosts(user.uid)
          .first;
      final now = DateTime.now();
      final validPinnedIds = <String>{};

      for (var doc in pinnedSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();

        if (now.isBefore(expiresAt)) {
          validPinnedIds.add(doc.id);
        } else {
          // Clean up expired pin
          await _firestoreService.unpinPost(user.uid, doc.id);
        }
      }

      if (mounted) {
        setState(() {
          _pinnedPostIds.clear();
          _pinnedPostIds.addAll(validPinnedIds);
        });
      }
    } catch (e) {
      print('Error loading pinned posts: $e');
    }
  }

  Future<void> _handleReactionTap(String postId, String reactionType) async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    final loadingKey = '$postId-$reactionType';
    if (_loadingReactions.contains(loadingKey)) return;

    setState(() {
      _loadingReactions.add(loadingKey);
    });

    try {
      await _firestoreService.toggleReaction(postId, user.uid, reactionType);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update reaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingReactions.remove(loadingKey);
        });
      }
    }
  }

  Future<void> _showPinDurationDialog(String postId) async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pin Post'),
        content: const Text('Select pin duration:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pinPost(postId, const Duration(hours: 1));
            },
            child: const Text('1 hour'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pinPost(postId, const Duration(hours: 6));
            },
            child: const Text('6 hours'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pinPost(postId, const Duration(hours: 12));
            },
            child: const Text('12 hours'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pinPost(postId, const Duration(days: 1));
            },
            child: const Text('1 day'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pinPost(postId, const Duration(days: 7));
            },
            child: const Text('7 days'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _pinPost(String postId, Duration duration) async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestoreService.pinPost(user.uid, postId, duration);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post pinned successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPinnedPosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pin post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unpinPost(String postId) async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestoreService.unpinPost(user.uid, postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post unpinned'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPinnedPosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unpin post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditPostDialog(PostModel post) async {
    final titleController = TextEditingController(text: post.title);
    final descriptionController = TextEditingController(text: post.description);

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Post'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty ||
                    descriptionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Title and description are required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                await _updatePost(
                  post.postId,
                  titleController.text.trim(),
                  descriptionController.text.trim(),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePost(
    String postId,
    String title,
    String description,
  ) async {
    try {
      final updates = <String, dynamic>{
        'title': title,
        'description': description,
        'editedAt': FieldValue.serverTimestamp(),
      };

      await _firestoreService.updatePost(postId, updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmationDialog(String postId) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost(postId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    try {
      // Note: Cloudinary images are not deleted for now

      // Delete post document and reactions
      await _firestoreService.deletePost(postId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text(
          'Community Posts',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreatePostScreen(),
                ),
              ).then((_) => _loadCurrentUser());
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          _buildProfileAvatarButton(),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: _currentUser == null
            ? const Center(child: CircularProgressIndicator())
            : _currentUser!.village.isEmpty || _currentUser!.mandal.isEmpty
            ? _buildProfileIncompleteMessage()
            : Column(
                children: [
                  if (!_isNotificationDeepLinkMode) _buildSearchBar(),
                  if (!_isNotificationDeepLinkMode) _buildTabBar(),
                  Expanded(child: _buildPostsStream()),
                ],
              ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(24),
        ),
        child: TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search posts...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          _buildTabButton('Posts', 0),
          const SizedBox(width: 8),
          _buildTabButton('My Posts', 1),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.primary : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileIncompleteMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Profile Incomplete',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please update your village and mandal in your profile to view and create posts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatarButton() {
    return GestureDetector(
      onTap: () async {
        if (_currentUser != null) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(user: _currentUser!),
            ),
          );
          if (result == true && mounted) {
            _loadCurrentUser();
          }
        }
      },
      child: ProfileImageWidget(
        imageUrl: _currentUser?.photoUrl,
        name: _currentUser?.name ?? 'User',
        size: 36,
        showBorder: true,
      ),
    );
  }

  Widget _buildPostsStream() {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final stream = _selectedTab == 0
        ? _firestoreService.getPostsByVillageAndMandal(
            _currentUser!.village,
            _currentUser!.mandal,
          )
        : _firestoreService.getPostsByUserId(currentUser.uid);

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error loading posts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final posts = snapshot.data!.docs
            .map(
              (doc) => PostModel.fromFirestore(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ),
            )
            .where((post) => post != null)
            .cast<PostModel>()
            .toList();

        // Apply search filter
        List<PostModel> filteredPosts = posts;
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          filteredPosts = posts.where((post) {
            return post.userName.toLowerCase().contains(query) ||
                post.title.toLowerCase().contains(query) ||
                post.description.toLowerCase().contains(query);
          }).toList();
        }

        if (_isNotificationDeepLinkMode) {
          filteredPosts = filteredPosts
              .where((post) => post.postId == _initialPostId)
              .toList();
        }

        if (filteredPosts.isEmpty) {
          if (_isNotificationDeepLinkMode) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'The linked community post is not available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], fontSize: 16),
                ),
              ),
            );
          }
          return _buildEmptyState();
        }

        // For Community Posts tab (tab 0), sort pinned posts first
        List<PostModel> sortedPosts;
        if (_selectedTab == 0) {
          // Separate pinned and unpinned posts
          final pinnedPosts = <PostModel>[];
          final unpinnedPosts = <PostModel>[];

          for (final post in filteredPosts) {
            if (_pinnedPostIds.contains(post.postId)) {
              pinnedPosts.add(post);
            } else {
              unpinnedPosts.add(post);
            }
          }

          // Combine: pinned posts first, then unpinned posts
          sortedPosts = [...pinnedPosts, ...unpinnedPosts];
        } else {
          // My Posts tab - keep original order
          sortedPosts = filteredPosts;
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            _loadPinnedPosts();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedPosts.length,
            itemBuilder: (context, index) {
              return _buildPostCard(sortedPosts[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final isMyPostsTab = _selectedTab == 1;
    final isSearching = _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching
                  ? Icons.search_off
                  : (isMyPostsTab ? Icons.person_off : Icons.post_add),
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isSearching
                  ? 'No matching posts found'
                  : (isMyPostsTab ? 'No Posts Yet' : 'No Community Posts Yet'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try adjusting your search terms'
                  : (isMyPostsTab
                        ? 'You haven\'t created any posts yet'
                        : 'No community posts yet'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            if (!isMyPostsTab && !isSearching) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreatePostScreen(),
                    ),
                  ).then((_) => _loadCurrentUser());
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Post'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(PostModel post) {
    final User? currentUser = _auth.currentUser;
    final isPinned = _pinnedPostIds.contains(post.postId);
    final isOwnPost = currentUser != null && post.userId == currentUser.uid;

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
              children: [
                ProfileImageWidget(
                  imageUrl: post.userProfileImage,
                  name: post.userName,
                  size: 40,
                  showBorder: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              post.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (isOwnPost)
                            Text(
                              '(You)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          if (post.userType.toLowerCase() == 'admin')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.purple.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'ADMIN',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${post.userVillage}, ${post.userMandal}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isOwnPost && _selectedTab == 0)
                  const SizedBox(width: 48)
                else
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      switch (value) {
                        case 'pin':
                          _showPinDurationDialog(post.postId);
                          break;
                        case 'unpin':
                          _unpinPost(post.postId);
                          break;
                        case 'edit':
                          _showEditPostDialog(post);
                          break;
                        case 'delete':
                          _showDeleteConfirmationDialog(post.postId);
                          break;
                      }
                    },
                    itemBuilder: (context) {
                      if (_selectedTab == 1) {
                        // My Posts tab - show Edit and Delete for own posts
                        return [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Edit Post'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete Post',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ];
                      } else {
                        // Community Posts tab - show Pin/Unpin for other users' posts only
                        if (isPinned) {
                          return [
                            const PopupMenuItem(
                              value: 'unpin',
                              child: Row(
                                children: [
                                  Icon(Icons.push_pin, size: 20),
                                  SizedBox(width: 8),
                                  Text('Unpin Post'),
                                ],
                              ),
                            ),
                          ];
                        } else {
                          return [
                            const PopupMenuItem(
                              value: 'pin',
                              child: Row(
                                children: [
                                  Icon(Icons.push_pin, size: 20),
                                  SizedBox(width: 8),
                                  Text('Pin Post'),
                                ],
                              ),
                            ),
                          ];
                        }
                      }
                    },
                  ),
              ],
            ),
            if (isPinned) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.push_pin, size: 14, color: Colors.orange),
                    SizedBox(width: 4),
                    Text(
                      'Pinned',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              post.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Display media if exists
            if (post.media != null && post.media!.isNotEmpty) ...[
              _buildMediaDisplay(post.media!),
              const SizedBox(height: 12),
            ],
            // Backward compatibility: display old postImage if exists and media is null
            if (post.postImage != null &&
                post.postImage!.isNotEmpty &&
                (post.media == null || post.media!.isEmpty)) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: post.postImage!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              post.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(post.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                if (post.editedAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(edited)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (currentUser != null)
              StreamBuilder<DocumentSnapshot>(
                stream: _firestoreService.getUserReactionStream(
                  post.postId,
                  currentUser.uid,
                ),
                builder: (context, reactionSnapshot) {
                  String? currentReaction;
                  if (reactionSnapshot.data?.exists == true) {
                    final data =
                        reactionSnapshot.data!.data() as Map<String, dynamic>?;
                    currentReaction = data?['reaction'] as String?;
                  }

                  return _buildReactionButtons(post, currentReaction);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionButtons(PostModel post, String? currentReaction) {
    return Row(
      children: [
        _buildReactionButton(
          icon: Icons.thumb_up,
          count: post.likeCount,
          isSelected: currentReaction == 'like',
          onTap: () => _handleReactionTap(post.postId, 'like'),
          isLoading: _loadingReactions.contains('${post.postId}-like'),
        ),
        const SizedBox(width: 16),
        _buildReactionButton(
          icon: Icons.thumb_down,
          count: post.dislikeCount,
          isSelected: currentReaction == 'dislike',
          onTap: () => _handleReactionTap(post.postId, 'dislike'),
          isLoading: _loadingReactions.contains('${post.postId}-dislike'),
        ),
        const SizedBox(width: 16),
        _buildReactionButton(
          icon: Icons.favorite,
          count: post.heartCount,
          isSelected: currentReaction == 'heart',
          onTap: () => _handleReactionTap(post.postId, 'heart'),
          isLoading: _loadingReactions.contains('${post.postId}-heart'),
        ),
      ],
    );
  }

  Widget _buildReactionButton({
    required IconData icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isLoading,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isSelected ? AppColors.primary : Colors.grey[600]!,
                  ),
                ),
              )
            else
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? AppColors.primary
                    : Colors.grey.shade600,
              ),
            const SizedBox(width: 6),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppColors.primary
                    : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget _buildMediaDisplay(List<Map<String, dynamic>> media) {
    // Separate images and PDFs
    final images = media.where((m) => m['type'] == 'image').toList();
    final pdfs = media.where((m) => m['type'] == 'pdf').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display images
        if (images.isNotEmpty) ...[
          _buildImageGrid(images),
          const SizedBox(height: 12),
        ],
        // Display PDFs
        if (pdfs.isNotEmpty) ...[...pdfs.map((pdf) => _buildPDFCard(pdf))],
      ],
    );
  }

  Widget _buildImageGrid(List<Map<String, dynamic>> images) {
    if (images.length == 1) {
      return _buildSingleImage(images[0]['url'] as String);
    } else if (images.length == 2) {
      return Row(
        children: [
          Expanded(child: _buildImageTile(images[0]['url'] as String)),
          const SizedBox(width: 8),
          Expanded(child: _buildImageTile(images[1]['url'] as String)),
        ],
      );
    } else if (images.length == 3) {
      return Column(
        children: [
          _buildImageTile(images[0]['url'] as String),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildImageTile(images[1]['url'] as String)),
              const SizedBox(width: 8),
              Expanded(child: _buildImageTile(images[2]['url'] as String)),
            ],
          ),
        ],
      );
    } else if (images.length == 4) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildImageTile(images[0]['url'] as String)),
              const SizedBox(width: 8),
              Expanded(child: _buildImageTile(images[1]['url'] as String)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildImageTile(images[2]['url'] as String)),
              const SizedBox(width: 8),
              Expanded(child: _buildImageTile(images[3]['url'] as String)),
            ],
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSingleImage(String imageUrl) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 200,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            height: 200,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageTile(String imageUrl) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 150,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            height: 150,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, size: 32, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPDFCard(Map<String, dynamic> pdf) {
    final fileName = pdf['fileName'] as String? ?? 'Document';
    final url = pdf['url'] as String;

    return GestureDetector(
      onTap: () => _launchPDF(url),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.red[700], size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to open',
                    style: TextStyle(fontSize: 14, color: Colors.red[700]),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, color: Colors.red[700], size: 24),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(imageUrl: imageUrl),
      ),
    );
  }

  Future<void> _launchPDF(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch PDF'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) =>
                const CircularProgressIndicator(color: Colors.white),
            errorWidget: (context, url, error) =>
                const Icon(Icons.broken_image, color: Colors.white, size: 64),
          ),
        ),
      ),
    );
  }
}
