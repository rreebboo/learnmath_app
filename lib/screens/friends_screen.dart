import 'package:flutter/material.dart';
import '../services/friends_service.dart';
import '../services/firestore_service.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
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
      if (mounted) {
        setState(() {
          _searchResults = results;
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
                  Container(
                    width: isSmallScreen ? 40 : 50,
                    height: isSmallScreen ? 40 : 50,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF7ED321), Color(0xFF9ACD32)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        friend['avatar'] ?? '🦊',
                        style: TextStyle(fontSize: isSmallScreen ? 20 : 24),
                      ),
                    ),
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
                          Icons.emoji_events,
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

              // Challenge Button - Flexible size
              Flexible(
                flex: 1,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : isMediumScreen ? 12 : 16,
                    vertical: isSmallScreen ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8B4FF), Color(0xFFC490FF)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: GestureDetector(
                    onTap: () => _challengeFriend(friend),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isSmallScreen ? 'Battle' : 'Challenge',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 10 : 12,
                          fontWeight: FontWeight.bold,
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
                  Container(
                    width: isSmallScreen ? 40 : 50,
                    height: isSmallScreen ? 40 : 50,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF7ED321), Color(0xFF9ACD32)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        request['avatar'] ?? '🦊',
                        style: TextStyle(fontSize: isSmallScreen ? 20 : 24),
                      ),
                    ),
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
              Container(
                width: isSmallScreen ? 40 : 50,
                height: isSmallScreen ? 40 : 50,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF7ED321), Color(0xFF9ACD32)],
                  ),
                ),
                child: Center(
                  child: Text(
                    user['avatar'] ?? '🦊',
                    style: TextStyle(fontSize: isSmallScreen ? 20 : 24),
                  ),
                ),
              ),
              SizedBox(width: isSmallScreen ? 10 : 15),

              Flexible(
                flex: 3,
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

              SizedBox(width: isSmallScreen ? 8 : 15),
              
              Flexible(
                flex: 1,
                child: ElevatedButton(
                  onPressed: () => _sendFriendRequest(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B9EF3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: isSmallScreen ? 6 : 8,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Add',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 10 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
              Navigator.pop(context);
              final success = await _friendsService.challengeFriend(friend['id']);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Challenge sent to ${friend['name']}!'),
                    backgroundColor: const Color(0xFF7ED321),
                  ),
                );
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
              Navigator.pop(context);
              final success = await _friendsService.removeFriend(friend['id']);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${friend['name']} removed from friends'),
                    backgroundColor: Colors.orange,
                  ),
                );
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
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${request['name']} is now your friend!'),
          backgroundColor: const Color(0xFF7ED321),
        ),
      );
    }
  }

  void _declineFriendRequest(Map<String, dynamic> request) async {
    final success = await _friendsService.declineFriendRequest(request['id']);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request declined'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _sendFriendRequest(Map<String, dynamic> user) async {
    final success = await _friendsService.sendFriendRequest(
      user['id'],
      message: 'Hi! Let\'s be friends and play math games together!',
    );
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request sent to ${user['name']}!'),
          backgroundColor: const Color(0xFF5B9EF3),
        ),
      );
    }
  }
}