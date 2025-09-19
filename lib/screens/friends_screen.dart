import 'dart:async';
import 'package:flutter/material.dart';
import '../services/friends_service.dart';
import '../services/firestore_service.dart';
import '../widgets/user_avatar.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with TickerProviderStateMixin {
  final FriendsService _friendsService = FriendsService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  
  late TabController _tabController;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  final Map<String, bool> _sendingRequests = {};
  Map<String, String> _relationshipStatus = {}; // 'friends', 'pending', 'none'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
    _testConnection();
    _startPeriodicStatusRefresh();
  }

  // Automatically refresh status of visible search results periodically
  void _startPeriodicStatusRefresh() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // Only refresh if we have search results visible
      if (_searchResults.isNotEmpty && !_isSearching) {
        _refreshVisibleStatuses();
      }
    });
  }

  Future<void> _refreshVisibleStatuses() async {
    try {
      print('FriendsScreen: Auto-refreshing visible statuses...');
      
      // Check status for all visible search results
      for (var user in _searchResults) {
        final userId = user['id'];
        final currentStatus = _relationshipStatus[userId] ?? 'none';
        
        // Only check if current status might be stale (pending or none)
        if (currentStatus == 'pending' || currentStatus == 'none') {
          final newStatus = await _friendsService.getCleanRelationshipStatus(userId);
          
          if (mounted && newStatus != currentStatus) {
            setState(() {
              _relationshipStatus[userId] = newStatus;
            });
            print('FriendsScreen: Auto-updated $userId: $currentStatus → $newStatus');
          }
        }
      }
    } catch (e) {
      print('FriendsScreen: Error in auto status refresh: $e');
    }
  }

  Future<void> _testConnection() async {
    print('FriendsScreen: Running comprehensive friends functionality test...');
    
    // Run comprehensive test
    final allTestsPassed = await _friendsService.testFriendsFunctionality();
    
    
    // Run debug cleanup to remove any stale requests
    print('FriendsScreen: Running debug cleanup...');
    await _friendsService.debugCleanupAllRequests();
    
    // Provide user feedback based on test results
    if (!allTestsPassed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Friends system not working properly. Check your connection and permissions.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } else {
      print('FriendsScreen: ✅ All friends functionality tests passed!');
    }
  }

  // Method to refresh relationship status for a specific user
  Future<void> _refreshRelationshipStatus(String userId) async {
    try {
      print('FriendsScreen: Refreshing relationship status for $userId');
      
      // Use smart status check that automatically cleans up stale data
      final newStatus = await _friendsService.getCleanRelationshipStatus(userId);
      
      if (mounted) {
        setState(() {
          _relationshipStatus[userId] = newStatus;
        });
      }
      
      print('FriendsScreen: Refreshed relationship status for $userId: $newStatus');
    } catch (e) {
      print('FriendsScreen: Error refreshing relationship status: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      await _firestoreService.getCurrentUserData();
    } catch (e) {
      // print('Error loading user data: $e');
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _friendsService.searchUsers(query);
      
      // FORCE CLEAR CACHE - Always check database for fresh status
      Map<String, String> statusMap = {};
      for (var user in results) {
        final userId = user['id'];
        
        print('🔍 SMART CHECKING status for user: ${user['name']} ($userId)');
        
        // Use smart status check that automatically cleans up stale requests
        final status = await _friendsService.getCleanRelationshipStatus(userId);
        statusMap[userId] = status;
        
        print('   - FINAL STATUS: $status ${status == 'friends' ? '✅' : status == 'pending' ? '⏳' : '🆕'}');
      }
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          // COMPLETELY REPLACE the cache - don't merge with old data
          _relationshipStatus = statusMap;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
      // print('Error searching users: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Friends',
          style: TextStyle(
            color: const Color(0xFF2C3E50),
            fontSize: isSmallScreen ? 18 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // FORCE REFRESH BUTTON for debugging
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Colors.orange,
              size: isSmallScreen ? 20 : 24,
            ),
            onPressed: () async {
              print('🔄 MANUAL FORCE REFRESH ALL DATA');
              
              // Clear ALL cached status
              setState(() {
                _relationshipStatus.clear();
              });
              
              // Aggressive cleanup - removes ALL friend requests to reset stuck states
              await _friendsService.aggressiveCleanupAllRequests();
              
              // Wait for Firestore changes to propagate
              await Future.delayed(const Duration(milliseconds: 1000));
              
              // If there are search results, refresh them
              if (_searchResults.isNotEmpty) {
                final query = _searchController.text;
                if (query.isNotEmpty) {
                  await _searchUsers(query);
                }
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🔄 Force refreshed all friend data!'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.person_add, 
              color: const Color(0xFF5B9EF3),
              size: isSmallScreen ? 20 : 24,
            ),
            onPressed: () => _showAddFriendDialog(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF5B9EF3),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF5B9EF3),
          labelStyle: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            fontWeight: FontWeight.normal,
          ),
          tabs: [
            Tab(text: isSmallScreen ? 'Friends' : 'Friends'),
            Tab(text: isSmallScreen ? 'Requests' : 'Requests'),
            Tab(text: isSmallScreen ? 'Find' : 'Find'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsTab(),
          _buildRequestsTab(),
          _buildFindTab(),
        ],
      ),
    );
  }

  Widget _buildFriendsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _friendsService.getFriends(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B9EF3)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.group,
            title: 'No Friends Yet',
            subtitle: 'Add friends to challenge them to math duels!',
            actionText: 'Find Friends',
            onAction: () => _tabController.animateTo(2),
          );
        }

        final friends = snapshot.data!;
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 360;
        
        return ListView.builder(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return _buildFriendCard(friend);
          },
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _friendsService.getFriendRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B9EF3)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.mail,
            title: 'No Friend Requests',
            subtitle: 'Friend requests will appear here',
            actionText: 'Find Friends',
            onAction: () => _tabController.animateTo(2),
          );
        }

        final requests = snapshot.data!;
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 360;
        
        return ListView.builder(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildRequestCard(request);
          },
        );
      },
    );
  }

  Widget _buildFindTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _searchUsers,
              decoration: InputDecoration(
                hintText: 'Search by name or username...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF5B9EF3)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Search Results
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B9EF3)),
                    ),
                  )
                : _searchResults.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.search,
                        title: 'Search for Friends',
                        subtitle: 'Enter a name or username to find friends',
                        actionText: null,
                        onAction: null,
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          return _buildSearchResultCard(user);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(Map<String, dynamic> friend) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 360;
        final isMediumScreen = screenWidth < 500;
        
        return Container(
          margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with online status
              Stack(
                children: [
                  UserAvatar(
                    avatar: friend['avatar'] ?? '🦊',
                    size: isSmallScreen ? 40 : 50,
                    backgroundColor: Colors.white,
                    showBorder: true,
                    borderColor: const Color(0xFFE5E7EB),
                  ),
                  if (friend['isOnline'] == true)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: isSmallScreen ? 12 : 16,
                        height: isSmallScreen ? 12 : 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7ED321),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: isSmallScreen ? 10 : 15),

              // Friend Info - Flexible to prevent overflow
              Flexible(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend['name'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C3E50),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 2 : 4),
                    Row(
                      children: [
                        Icon(
                          Icons.leaderboard,
                          size: isSmallScreen ? 12 : 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${friend['totalScore'] ?? 0} pts${isMediumScreen ? '' : ' • ${friend['level'] ?? 'Beginner'}'}',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (friend['isOnline'] != true && !isSmallScreen)
                      Text(
                        'Last seen recently',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),

              // Challenge Button - Longer for better visibility
              Flexible(
                flex: 2,
                child: GestureDetector(
                  onTap: () => _challengeFriend(friend),
                  child: Container(
                    height: isSmallScreen ? 36 : 40,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 20,
                      vertical: isSmallScreen ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8B4FF), Color(0xFFC490FF)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isSmallScreen ? 'Battle' : 'Duel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 12 : 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // More Options
              SizedBox(
                width: isSmallScreen ? 32 : 40,
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert, 
                    color: Colors.grey[400],
                    size: isSmallScreen ? 18 : 24,
                  ),
                  onSelected: (value) {
                    if (value == 'remove') {
                      _confirmRemoveFriend(friend);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.person_remove, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Remove Friend'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 360;
        
        return Container(
          margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFF5B9EF3).withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  UserAvatar(
                    avatar: request['avatar'] ?? '🦊',
                    size: isSmallScreen ? 40 : 50,
                    backgroundColor: Colors.white,
                    showBorder: true,
                    borderColor: const Color(0xFFE5E7EB),
                  ),
                  SizedBox(width: isSmallScreen ? 10 : 15),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request['name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2C3E50),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isSmallScreen ? 2 : 4),
                        Text(
                          'Wants to be friends',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (request['message']?.isNotEmpty == true) ...[
                SizedBox(height: isSmallScreen ? 8 : 12),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request['message'],
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10 : 12,
                      color: Colors.grey[700],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              SizedBox(height: isSmallScreen ? 12 : 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptFriendRequest(request),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7ED321),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 8 : 12,
                        ),
                      ),
                      child: Text(
                        'Accept',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _declineFriendRequest(request),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 8 : 12,
                        ),
                      ),
                      child: Text(
                        'Decline',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> user) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 360;
        final isMediumScreen = screenWidth < 500;
        
        return Container(
          margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              UserAvatar(
                avatar: user['avatar'] ?? '🦊',
                size: isSmallScreen ? 40 : 50,
                backgroundColor: Colors.white,
                showBorder: true,
                borderColor: const Color(0xFFE5E7EB),
              ),
              SizedBox(width: isSmallScreen ? 10 : 15),

              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C3E50),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 2 : 4),
                    if (user['username']?.isNotEmpty == true && !isSmallScreen)
                      Text(
                        '@${user['username']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      '${user['totalScore'] ?? 0} pts${isMediumScreen ? '' : ' • ${user['level'] ?? 'Beginner'}'}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              SizedBox(width: isSmallScreen ? 6 : 12),
              
              // BIGGER BUTTON AREA - Fixed width for consistent button size
              SizedBox(
                width: isSmallScreen ? 70 : 100,
                child: _buildActionButton(user, isSmallScreen),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(Map<String, dynamic> user, bool isSmallScreen) {
    final userId = user['id'];
    final relationshipStatus = _relationshipStatus[userId] ?? 'none';
    final isLoading = _sendingRequests[userId] == true;
    
    if (relationshipStatus == 'friends') {
      return Container(
        width: double.infinity,
        height: isSmallScreen ? 36 : 42,
        decoration: BoxDecoration(
          color: const Color(0xFF7ED321),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: isSmallScreen ? 16 : 18,
                color: Colors.white,
              ),
              SizedBox(width: isSmallScreen ? 4 : 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Friends',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 12 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (relationshipStatus == 'pending') {
      return GestureDetector(
        onTap: () async {
          // FORCE REFRESH when pending button is tapped
          print('🔄 FORCE REFRESH tapped for user: ${user['name']}');
          await _refreshRelationshipStatus(userId);
        },
        child: Container(
          width: double.infinity,
          height: isSmallScreen ? 36 : 42,
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule,
                  size: isSmallScreen ? 16 : 18,
                  color: Colors.white,
                ),
                SizedBox(width: isSmallScreen ? 4 : 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Pending',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 12 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: isLoading ? null : () => _sendFriendRequest(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: isLoading ? Colors.grey[400] : const Color(0xFF5B9EF3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: Size(double.infinity, isSmallScreen ? 36 : 42),
          padding: EdgeInsets.symmetric(horizontal: 12),
        ),
        child: isLoading
            ? SizedBox(
                width: isSmallScreen ? 16 : 18,
                height: isSmallScreen ? 16 : 18,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_add,
                    size: isSmallScreen ? 16 : 18,
                    color: Colors.white,
                  ),
                  SizedBox(width: isSmallScreen ? 4 : 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isSmallScreen ? 'Add' : 'Add Friend',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      );
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B9EF3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  actionText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddFriendDialog() {
    _tabController.animateTo(2);
  }

  void _challengeFriend(Map<String, dynamic> friend) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        title: Text(
          'Challenge Friend',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenWidth * 0.8,
          ),
          child: Text(
            'Challenge ${friend['name']} to a math duel?',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              navigator.pop();
              final success = await _friendsService.challengeFriend(friend['id']);
              if (success) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Challenge sent to ${friend['name']}!'),
                      backgroundColor: const Color(0xFF7ED321),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } else {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to send challenge. Please try again.'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B9EF3),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
                vertical: isSmallScreen ? 8 : 12,
              ),
            ),
            child: Text(
              'Challenge',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveFriend(Map<String, dynamic> friend) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        title: Text(
          'Remove Friend',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenWidth * 0.8,
          ),
          child: Text(
            'Remove ${friend['name']} from your friends list?',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              navigator.pop();
              final success = await _friendsService.removeFriend(friend['id']);
              if (success) {
                // Refresh the relationship status to ensure UI updates
                await _friendsService.forceRefreshRelationship(friend['id']);
                await _refreshRelationshipStatus(friend['id']);
                  
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('${friend['name']} removed from friends'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } else {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to remove friend. Please try again.'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
                vertical: isSmallScreen ? 8 : 12,
              ),
            ),
            child: Text(
              'Remove',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _acceptFriendRequest(Map<String, dynamic> request) async {
    final success = await _friendsService.acceptFriendRequest(
      request['id'],
      request['fromUserId'],
    );
    
    if (success) {
      // Force refresh the relationship status with cleanup
      await _friendsService.forceRefreshRelationship(request['fromUserId']);
      await _refreshRelationshipStatus(request['fromUserId']);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${request['name']} is now your friend!'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF7ED321),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept friend request. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _declineFriendRequest(Map<String, dynamic> request) async {
    final success = await _friendsService.declineFriendRequest(request['id']);
    
    if (success) {
      // Force refresh the relationship status with cleanup
      await _friendsService.forceRefreshRelationship(request['fromUserId']);
      await _refreshRelationshipStatus(request['fromUserId']);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request declined'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to decline friend request. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _sendFriendRequest(Map<String, dynamic> user) async {
    final userId = user['id'];
    print('FriendsScreen: Sending friend request to user: ${user['name']} ($userId)');
    
    // Prevent double-tapping
    if (_sendingRequests[userId] == true) return;
    
    // Capture ScaffoldMessenger before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    setState(() {
      _sendingRequests[userId] = true;
    });
    
    try {
      print('FriendsScreen: Checking if already friends...');
      // Check if already friends or request already sent
      final alreadyFriends = await _friendsService.areFriends(userId);
      if (alreadyFriends) {
        print('FriendsScreen: Users are already friends');
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('You are already friends with ${user['name']}!'),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }
      
      print('FriendsScreen: Attempting to send friend request...');
      final success = await _friendsService.sendFriendRequest(
        userId,
        message: 'Hi! Let\'s be friends and play math games together!',
      );
      
      print('FriendsScreen: Friend request result: $success');
      
      if (success) {
        print('FriendsScreen: Friend request sent successfully');
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.send, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Friend request sent to ${user['name']}!'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF5B9EF3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          
          // Immediate status refresh after successful operation
          await _refreshRelationshipStatus(userId);
          
          // Also trigger refresh for other search results (in case of related changes)
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _refreshVisibleStatuses();
          });
        }
      } else {
        print('FriendsScreen: Failed to send friend request');
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Failed to send friend request. Please check your connection and try again.'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('FriendsScreen: Exception in _sendFriendRequest: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingRequests[userId] = false;
        });
      }
    }
  }
}