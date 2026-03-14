import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../providers/client_provider.dart';
import '../providers/community_provider.dart';
import '../widgets/dashboard_sheets.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(communityFeedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(communityFeedProvider);
    final unreadMessages = ref.watch(unreadMessagesProvider);
    final unreadNotifications = ref.watch(unreadNotificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: GestureDetector(
        onTap: () => _showCreatePostSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_rounded, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text('Post', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(communityFeedProvider.notifier).loadFeed(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── Top Bar (same as Dashboard) ──
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 68,
              title: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SvgPicture.asset('assets/fitos-logo.svg', height: 34),
              ),
              centerTitle: false,
              actions: [
                _TopBarIcon(
                  icon: Icons.qr_code_rounded,
                  onTap: () => showQrAccessDialog(context, ref),
                ),
                const SizedBox(width: 8),
                _TopBarIcon(
                  icon: Icons.calendar_today_rounded,
                  onTap: () => showCalendarSheet(context, ref),
                ),
                const SizedBox(width: 8),
                _TopBarIconBadge(
                  icon: Icons.notifications_none_rounded,
                  count: unreadNotifications.valueOrNull ?? 0,
                  onTap: () => showNotificationsSheet(context, ref),
                ),
                const SizedBox(width: 8),
                _TopBarIconBadge(
                  icon: Icons.send_rounded,
                  count: unreadMessages.valueOrNull ?? 0,
                  onTap: () => showConversationsSheet(context, ref),
                ),
                const SizedBox(width: 16),
              ],
            ),

            // ── Content ──
            if (feedState.loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (feedState.posts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.forum_outlined, size: 48, color: Colors.grey[700]),
                      const SizedBox(height: 12),
                      Text('Nessun post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                      const SizedBox(height: 4),
                      Text('Sii il primo a postare!', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == feedState.posts.length) {
                      return feedState.loadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                            )
                          : const SizedBox.shrink();
                    }
                    return _PostCard(
                      post: feedState.posts[index],
                      onLike: () => ref.read(communityFeedProvider.notifier).toggleLike(feedState.posts[index]['id'] as String),
                      onComment: () => _openComments(context, feedState.posts[index]),
                      onDelete: () => _deletePost(feedState.posts[index]['id'] as String),
                    );
                  },
                  childCount: feedState.posts.length + (feedState.hasMore ? 1 : 0),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCreatePostSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreatePostSheet(
        onPostCreated: (post) {
          ref.read(communityFeedProvider.notifier).prependPost(post);
        },
        ref: ref,
      ),
    );
  }

  void _openComments(BuildContext context, Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _CommentsSheet(
          post: post,
          scrollController: scrollController,
          ref: ref,
          onCommentAdded: () {
            ref.read(communityFeedProvider.notifier).incrementCommentCount(post['id'] as String);
          },
        ),
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    try {
      await ref.read(clientServiceProvider).deleteCommunityPost(postId);
      ref.read(communityFeedProvider.notifier).removePost(postId);
    } catch (_) {}
  }
}

// ─── POST CARD ─────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onDelete;

  const _PostCard({required this.post, required this.onLike, required this.onComment, required this.onDelete});

  String _relativeTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().toUtc().difference(dt);
      if (diff.inMinutes < 1) return 'ora';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}g';
      return '${(diff.inDays / 7).floor()}s';
    } catch (_) {
      return '';
    }
  }

  String? _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}$url';
  }

  @override
  Widget build(BuildContext context) {
    final authorName = post['author_username'] ?? 'Unknown';
    final authorPic = _resolveUrl(post['author_profile_picture'] as String?);
    final authorRole = post['author_role'] ?? 'client';
    final postType = post['post_type'] ?? 'text';
    final content = post['content'] as String?;
    final imageUrl = _resolveUrl(post['image_url'] as String?);
    final likeCount = post['like_count'] as int? ?? 0;
    final commentCount = post['comment_count'] as int? ?? 0;
    final isLiked = post['is_liked_by_me'] as bool? ?? false;
    final isPinned = post['is_pinned'] as bool? ?? false;
    final time = _relativeTime(post['created_at'] as String?);
    final firstCommentData = post['first_comment'] as Map<String, dynamic>?;
    final firstComment = firstCommentData?['content'] as String?;
    final firstCommentAuthor = firstCommentData?['author_username'] as String? ?? '';
    final firstCommentPic = _resolveUrl(firstCommentData?['author_profile_picture'] as String?);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar column ──
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            backgroundImage: authorPic != null ? NetworkImage(authorPic) : null,
            child: authorPic == null ? Text(authorName[0].toUpperCase(), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)) : null,
          ),
          const SizedBox(width: 12),

          // ── Content column ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Name + Role + Pin + Time + Menu ──
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(authorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                              ),
                              if (authorRole == 'owner' || authorRole == 'trainer') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: authorRole == 'owner' ? AppColors.primary.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    authorRole == 'owner' ? 'Gym' : 'Trainer',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: authorRole == 'owner' ? AppColors.primary : Colors.blue),
                                  ),
                                ),
                              ],
                              if (isPinned) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.push_pin_rounded, size: 12, color: AppColors.primary),
                              ],
                            ],
                          ),
                          Text(time, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz_rounded, color: Colors.grey[600], size: 20),
                      color: AppColors.surface,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (v) {
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'delete', child: Text('Elimina', style: TextStyle(fontSize: 13, color: Colors.redAccent))),
                      ],
                    ),
                  ],
                ),

                // ── Content ──
                if (content != null && content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(content, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4)),
                  ),

                // ── Image ──
                if (imageUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),

                // ── Event Card ──
                if (postType == 'event' || postType == 'quest')
                  _EventQuestCard(post: post, postType: postType),

                // ── Action Bar ──
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      _ActionBtn(
                        icon: isLiked ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
                        color: isLiked ? AppColors.primary : Colors.grey[600]!,
                        count: likeCount,
                        onTap: onLike,
                      ),
                      const SizedBox(width: 28),
                      _ActionBtn(
                        icon: Icons.chat_bubble_outline_rounded,
                        color: Colors.grey[600]!,
                        count: commentCount,
                        onTap: onComment,
                      ),
                      const SizedBox(width: 28),
                      _ActionBtn(
                        icon: Icons.copy_rounded,
                        color: Colors.grey[600]!,
                        count: post['repost_count'] as int? ?? 0,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                // ── First Comment Preview ──
                if (firstComment != null)
                  GestureDetector(
                    onTap: onComment,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            backgroundImage: firstCommentPic != null ? NetworkImage(firstCommentPic) : null,
                            child: firstCommentPic == null
                                ? Text(firstCommentAuthor[0].toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textPrimary))
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '$firstCommentAuthor  ',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                  TextSpan(
                                    text: firstComment,
                                    style: TextStyle(fontSize: 13, color: Colors.grey[400], height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.color, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text('$count', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── EVENT / QUEST CARD ────────────────────────────────────────

class _EventQuestCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final String postType;

  const _EventQuestCard({required this.post, required this.postType});

  @override
  Widget build(BuildContext context) {
    final isEvent = postType == 'event';
    final title = post['event_title'] as String? ?? '';
    final date = post['event_date'] as String? ?? '';
    final time = post['event_time'] as String? ?? '';
    final location = post['event_location'] as String? ?? '';
    final xp = post['quest_xp_reward'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isEvent
              ? [AppColors.primary.withValues(alpha: 0.12), AppColors.primary.withValues(alpha: 0.04)]
              : [Colors.purple.withValues(alpha: 0.12), Colors.purple.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isEvent ? AppColors.primary.withValues(alpha: 0.2) : Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isEvent ? Icons.event_rounded : Icons.emoji_events_rounded, size: 18, color: isEvent ? AppColors.primary : Colors.purple),
              const SizedBox(width: 8),
              Text(isEvent ? 'EVENTO' : 'QUEST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isEvent ? AppColors.primary : Colors.purple, letterSpacing: 1)),
              if (!isEvent && xp > 0) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('+$xp XP', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.amber)),
                ),
              ],
            ],
          ),
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
          if (date.isNotEmpty || time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('$date${time.isNotEmpty ? " alle $time" : ""}', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
          if (location.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(location, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── CREATE POST SHEET ─────────────────────────────────────────

class _CreatePostSheet extends StatefulWidget {
  final void Function(Map<String, dynamic>) onPostCreated;
  final WidgetRef ref;

  const _CreatePostSheet({required this.onPostCreated, required this.ref});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _textController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageFilename;
  bool _posting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageFilename = picked.name;
      });
    }
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _imageBytes == null) return;

    setState(() => _posting = true);
    try {
      final service = widget.ref.read(clientServiceProvider);
      final result = await service.createCommunityPost(
        postType: _imageBytes != null ? 'image' : 'text',
        content: text.isNotEmpty ? text : null,
        imageBytes: _imageBytes != null ? _imageBytes!.toList() : null,
        imageFilename: _imageFilename,
      );
      widget.onPostCreated(result);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Nuovo Post', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              GestureDetector(
                onTap: _posting ? null : _submit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: _posting ? Colors.grey[700] : AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _posting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Pubblica', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            maxLines: 5,
            minLines: 3,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Cosa hai in mente?',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          if (_imageBytes != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_imageBytes!, height: 150, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () => setState(() { _imageBytes = null; _imageFilename = null; }),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_rounded, size: 18, color: Colors.green[400]),
                      const SizedBox(width: 6),
                      Text('Foto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400])),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── COMMENTS SHEET ────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  final ScrollController scrollController;
  final WidgetRef ref;
  final VoidCallback onCommentAdded;

  const _CommentsSheet({required this.post, required this.scrollController, required this.ref, required this.onCommentAdded});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final service = widget.ref.read(clientServiceProvider);
      final data = await service.getPostComments(widget.post['id'] as String);
      if (mounted) {
        setState(() {
          _comments = ((data['comments'] as List?) ?? []).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final service = widget.ref.read(clientServiceProvider);
      final result = await service.addComment(widget.post['id'] as String, text);
      _commentController.clear();
      widget.onCommentAdded();
      setState(() {
        _comments.insert(0, result);
        _sending = false;
      });
    } catch (_) {
      setState(() => _sending = false);
    }
  }

  String? _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}$url';
  }

  String _relativeTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().toUtc().difference(dt);
      if (diff.inMinutes < 1) return 'ora';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}g';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Text('Commenti', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                : _comments.isEmpty
                    ? Center(child: Text('Nessun commento', style: TextStyle(fontSize: 13, color: Colors.grey[600])))
                    : ListView.builder(
                        controller: widget.scrollController,
                        itemCount: _comments.length,
                        itemBuilder: (_, i) {
                          final c = _comments[i];
                          final pic = _resolveUrl(c['author_profile_picture'] as String?);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                                  backgroundImage: pic != null ? NetworkImage(pic) : null,
                                  child: pic == null
                                      ? Text((c['author_username'] as String? ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary))
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(c['author_username'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                          const SizedBox(width: 6),
                                          Text(_relativeTime(c['created_at'] as String?), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(c['content'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          // ── Comment Input ──
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Scrivi un commento...',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendComment,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: _sending
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── TOP BAR ICONS ──────────────────────────────────────────────

class _TopBarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopBarIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

class _TopBarIconBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  const _TopBarIconBadge({required this.icon, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Icon(icon, size: 20, color: AppColors.textPrimary),
            ),
            if (count > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      count > 99 ? '99' : '$count',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
