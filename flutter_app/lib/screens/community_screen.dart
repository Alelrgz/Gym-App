import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../providers/client_provider.dart';
import '../providers/community_provider.dart';
import '../widgets/dashboard_sheets.dart';

String relativeTime(String? iso) {
  if (iso == null) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final utc = dt.isUtc ? dt : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
  final diff = DateTime.now().toUtc().difference(utc);
  if (diff.isNegative) return 'ora';
  if (diff.inMinutes < 1) return 'ora';
  if (diff.inMinutes < 60) return '${diff.inMinutes}min';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}g';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} sett';
  return '${(diff.inDays / 30).floor()} mesi';
}

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String get _activeScope => _tabController.index == 0 ? 'local' : 'global';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {})); // rebuild FAB scope
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadMessages = ref.watch(unreadMessagesProvider);
    final unreadNotifications = ref.watch(unreadNotificationsProvider);

    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: Hero(
        tag: 'create_post_fab',
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
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
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            pinned: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            // On desktop (inside sidebar shell), hide the logo/icons toolbar
            toolbarHeight: isDesktop ? 0 : 68,
            title: isDesktop
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SvgPicture.asset('assets/fitos-logo.svg', height: 34),
                  ),
            centerTitle: false,
            actions: isDesktop
                ? null
                : [
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
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey[500],
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              dividerHeight: 0.5,
              dividerColor: Colors.white.withValues(alpha: 0.06),
              tabs: const [
                Tab(text: 'Palestra'),
                Tab(text: 'Globale'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _FeedTab(scope: 'local', onCreatePost: () => _showCreatePostSheet(context)),
            _FeedTab(scope: 'global', onCreatePost: () => _showCreatePostSheet(context)),
          ],
        ),
      ),
    );
  }

  void _showCreatePostSheet(BuildContext context) {
    final scope = _activeScope;
    final clientData = ref.read(clientDataProvider);
    final profilePic = clientData.whenData((d) => d.profilePicture).value;
    String? resolvedPic;
    if (profilePic != null && profilePic.isNotEmpty) {
      resolvedPic = profilePic.startsWith('http') ? profilePic : '${ApiConfig.baseUrl}/$profilePic';
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, _) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: _CreatePostSheet(
              scope: scope,
              onPostCreated: (post) {
                ref.read(communityFeedProvider(scope).notifier).prependPost(post);
              },
              ref: ref,
              profilePicUrl: resolvedPic,
            ),
          );
        },
      ),
    );
  }
}

// ─── FEED TAB (reusable per scope) ─────────────────────────────

class _FeedTab extends ConsumerStatefulWidget {
  final String scope;
  final VoidCallback onCreatePost;
  const _FeedTab({required this.scope, required this.onCreatePost});

  @override
  ConsumerState<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<_FeedTab> with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

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
      ref.read(communityFeedProvider(widget.scope).notifier).loadMore();
    }
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
            ref.read(communityFeedProvider(widget.scope).notifier).incrementCommentCount(post['id'] as String);
          },
        ),
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    try {
      await ref.read(clientServiceProvider).deleteCommunityPost(postId);
      ref.read(communityFeedProvider(widget.scope).notifier).removePost(postId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feedState = ref.watch(communityFeedProvider(widget.scope));
    final isGlobal = widget.scope == 'global';

    if (feedState.loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (feedState.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isGlobal ? Icons.public_rounded : Icons.forum_outlined, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text('Nessun post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[500])),
            const SizedBox(height: 4),
            Text(
              isGlobal ? 'Sii il primo a condividere con tutti!' : 'Sii il primo a postare!',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(communityFeedProvider(widget.scope).notifier).loadFeed(),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 600 : double.infinity),
          child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 8),
        itemCount: feedState.posts.length + (feedState.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == feedState.posts.length) {
            return feedState.loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                  )
                : const SizedBox.shrink();
          }
          final postData = feedState.posts[index];
          final postId = postData['id'] as String;
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => _PostDetailPage(
                post: postData,
                ref: ref,
                onDelete: () => _deletePost(postId),
                scope: widget.scope,
              )),
            ),
            child: _PostCard(
              post: postData,
              onLike: () => ref.read(communityFeedProvider(widget.scope).notifier).toggleLike(postId),
              onComment: () => _openComments(context, postData),
              onDelete: () => _deletePost(postId),
              onParticipate: () async {
                final joined = await ref.read(communityFeedProvider(widget.scope).notifier).toggleParticipation(postId);
                if (joined && context.mounted) {
                  HapticFeedback.mediumImpact();
                  final eventTitle = postData['event_title'] as String? ?? 'Evento';
                  final eventDate = postData['event_date'] as String? ?? '';
                  showDialog(
                    context: context,
                    barrierColor: Colors.black54,
                    builder: (_) => _EventConfirmationDialog(title: eventTitle, date: eventDate),
                  );
                }
              },
            ),
          );
        },
      ),
    ),
    ),
    );
  }
}

// ─── POST CARD ─────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onDelete;
  final VoidCallback? onParticipate;

  const _PostCard({required this.post, required this.onLike, required this.onComment, required this.onDelete, this.onParticipate});

  String _relativeTime(String? iso) => relativeTime(iso);

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
                          Row(
                            children: [
                              Text(time, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              if (post['gym_name'] != null) ...[
                                Text('  ·  ', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                                Icon(Icons.fitness_center_rounded, size: 10, color: Colors.grey[500]),
                                const SizedBox(width: 3),
                                Flexible(child: Text(post['gym_name'] as String, style: TextStyle(fontSize: 11, color: Colors.grey[500]), overflow: TextOverflow.ellipsis)),
                              ],
                            ],
                          ),
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
                  _EventQuestCard(post: post, postType: postType, onParticipate: onParticipate),

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
                        animate: true,
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

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;
  final bool animate;

  const _ActionBtn({required this.icon, required this.color, required this.count, required this.onTap, this.animate = false});

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.7), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.animate) {
      _ctrl.forward(from: 0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ScaleTransition(
              scale: _scale,
              child: Icon(widget.icon, size: 18, color: widget.color),
            ),
            if (widget.count > 0) ...[
              const SizedBox(width: 4),
              Text('${widget.count}', style: TextStyle(fontSize: 12, color: widget.color, fontWeight: FontWeight.w600)),
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
  final VoidCallback? onParticipate;

  const _EventQuestCard({required this.post, required this.postType, this.onParticipate});

  @override
  Widget build(BuildContext context) {
    final isEvent = postType == 'event';
    final title = post['event_title'] as String? ?? '';
    final date = post['event_date'] as String? ?? '';
    final time = post['event_time'] as String? ?? '';
    final location = post['event_location'] as String? ?? '';
    final xp = post['quest_xp_reward'] as int? ?? 0;
    final participating = post['is_participating'] as bool? ?? false;
    final participantCount = post['participant_count'] as int? ?? 0;
    final maxParticipants = post['max_participants'] as int?;
    final isFull = maxParticipants != null && participantCount >= maxParticipants && !participating;

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
          // ── Participation section (events only) ──
          if (isEvent) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // Participant count
                Icon(Icons.people_outline_rounded, size: 15, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '$participantCount${maxParticipants != null ? '/$maxParticipants' : ''} partecipanti',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
                const Spacer(),
                // Partecipa button
                GestureDetector(
                  onTap: isFull ? null : onParticipate,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: isFull
                          ? Colors.grey[800]
                          : participating
                              ? AppColors.primary
                              : Colors.transparent,
                      border: Border.all(
                        color: isFull ? Colors.grey[700]! : AppColors.primary,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (participating)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.check_rounded, size: 14, color: Colors.white),
                          ),
                        Text(
                          isFull ? 'Completo' : participating ? 'Partecipo' : 'Partecipa',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isFull ? Colors.grey[500] : participating ? Colors.white : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── CREATE POST SHEET ─────────────────────────────────────────

class _CreatePostSheet extends StatefulWidget {
  final void Function(Map<String, dynamic>) onPostCreated;
  final WidgetRef ref;
  final String? profilePicUrl;
  final String scope;

  const _CreatePostSheet({required this.onPostCreated, required this.ref, this.profilePicUrl, this.scope = 'local'});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  Uint8List? _imageBytes;
  String? _imageFilename;
  bool _posting = false;
  bool _hasText = false;

  // Event mode
  bool _isEventMode = false;
  final _eventTitleController = TextEditingController();
  final _eventLocationController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  DateTime? _eventDate;
  TimeOfDay? _eventTime;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final has = _textController.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _eventTitleController.dispose();
    _eventLocationController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  bool get _canPost {
    if (_isEventMode) return _eventTitleController.text.trim().isNotEmpty && _eventDate != null;
    return _hasText || _imageBytes != null;
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

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(primary: AppColors.primary, surface: AppColors.surface)), child: child!),
    );
    if (date != null) setState(() => _eventDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _eventTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(primary: AppColors.primary, surface: AppColors.surface)), child: child!),
    );
    if (time != null) setState(() => _eventTime = time);
  }

  Future<void> _submit() async {
    if (!_canPost) return;
    final text = _textController.text.trim();

    setState(() => _posting = true);
    try {
      final service = widget.ref.read(clientServiceProvider);
      if (_isEventMode) {
        final maxP = int.tryParse(_maxParticipantsController.text.trim());
        final result = await service.createCommunityPost(
          postType: 'event',
          scope: 'local', // events are always local
          content: text.isNotEmpty ? text : null,
          eventTitle: _eventTitleController.text.trim(),
          eventDate: '${_eventDate!.year}-${_eventDate!.month.toString().padLeft(2, '0')}-${_eventDate!.day.toString().padLeft(2, '0')}',
          eventTime: _eventTime != null ? '${_eventTime!.hour.toString().padLeft(2, '0')}:${_eventTime!.minute.toString().padLeft(2, '0')}' : null,
          eventLocation: _eventLocationController.text.trim().isNotEmpty ? _eventLocationController.text.trim() : null,
          maxParticipants: maxP,
          imageBytes: _imageBytes?.toList(),
          imageFilename: _imageFilename,
        );
        widget.onPostCreated(result);
      } else {
        final result = await service.createCommunityPost(
          postType: _imageBytes != null ? 'image' : 'text',
          scope: widget.scope,
          content: text.isNotEmpty ? text : null,
          imageBytes: _imageBytes?.toList(),
          imageFilename: _imageFilename,
        );
        widget.onPostCreated(result);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('[Community] Post failed: $e');
      try { debugPrint('[Community] Response: ${(e as dynamic).response?.data}'); } catch (_) {}
      if (mounted) {
        setState(() => _posting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  Widget _eventField({required TextEditingController controller, required String hint, required IconData icon, ValueChanged<String>? onChanged, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey[600]),
        prefixIconConstraints: const BoxConstraints(minWidth: 36),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }

  Widget _eventChip({required IconData icon, required String label, required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active ? AppColors.primary.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: active ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: active ? AppColors.primary : Colors.grey[600]),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, color: active ? AppColors.primary : Colors.grey[500])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: 'create_post_fab',
        child: Material(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: (MediaQuery.of(context).size.width - 32).clamp(0, 600),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height - 120),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text('Annulla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textSecondary)),
                  ),
                  const Spacer(),
                  const Text('Nuovo Post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: (_posting || !_canPost) ? null : _submit,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: (_canPost && !_posting) ? AppColors.primary : AppColors.primary.withValues(alpha: 0.35),
                      ),
                      child: _posting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                          : const Text('Pubblica'),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 0.5, color: Colors.white.withValues(alpha: 0.08)),
            // ── Compose area ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: widget.profilePicUrl != null ? NetworkImage(widget.profilePicUrl!) : null,
                    child: widget.profilePicUrl == null
                        ? Icon(Icons.person_rounded, size: 20, color: Colors.grey[500])
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLines: null,
                      minLines: 4,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, height: 1.5),
                      decoration: InputDecoration(
                        hintText: 'Cosa succede?',
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.only(top: 4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Attached image preview ──
            if (_imageBytes != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(68, 8, 20, 0),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(_imageBytes!, height: 160, width: double.infinity, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 6, right: 6,
                      child: GestureDetector(
                        onTap: () => setState(() { _imageBytes = null; _imageFilename = null; }),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // ── Event fields (when in event mode) ──
            if (_isEventMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  children: [
                    _eventField(
                      controller: _eventTitleController,
                      hint: 'Titolo evento *',
                      icon: Icons.title_rounded,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDate,
                            child: _eventChip(
                              icon: Icons.calendar_today_rounded,
                              label: _eventDate != null
                                  ? '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}'
                                  : 'Data *',
                              active: _eventDate != null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickTime,
                            child: _eventChip(
                              icon: Icons.schedule_rounded,
                              label: _eventTime != null
                                  ? '${_eventTime!.hour.toString().padLeft(2, '0')}:${_eventTime!.minute.toString().padLeft(2, '0')}'
                                  : 'Ora',
                              active: _eventTime != null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _eventField(
                            controller: _eventLocationController,
                            hint: 'Luogo',
                            icon: Icons.location_on_outlined,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: _eventField(
                            controller: _maxParticipantsController,
                            hint: 'Max',
                            icon: Icons.people_outline_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            // ── Bottom toolbar ──
            Container(height: 0.5, margin: const EdgeInsets.symmetric(horizontal: 16), color: Colors.white.withValues(alpha: 0.08)),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 14),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _pickImage,
                    icon: Icon(Icons.image_outlined, size: 22, color: AppColors.primary),
                    splashRadius: 20,
                  ),
                  IconButton(
                    onPressed: () => setState(() => _isEventMode = !_isEventMode),
                    icon: Icon(Icons.event_rounded, size: 22, color: _isEventMode ? AppColors.primary : Colors.grey[700]),
                    splashRadius: 20,
                  ),
                  IconButton(
                    onPressed: null,
                    icon: Icon(Icons.poll_outlined, size: 22, color: Colors.grey[700]),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
          ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── POST DETAIL PAGE (full-screen, Twitter-style) ─────────────

class _PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final WidgetRef ref;
  final VoidCallback onDelete;
  final String scope;

  const _PostDetailPage({required this.post, required this.ref, required this.onDelete, this.scope = 'local'});

  @override
  State<_PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<_PostDetailPage> with SingleTickerProviderStateMixin {
  List<dynamic> _comments = [];
  bool _loading = true;
  final _commentController = TextEditingController();
  bool _sending = false;
  late final AnimationController _likeCtrl;
  late final Animation<double> _likeScale;

  String get _postId => widget.post['id'] as String;

  @override
  void initState() {
    super.initState();
    _likeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _likeScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.7), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _likeCtrl, curve: Curves.easeOut));
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _likeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final service = widget.ref.read(clientServiceProvider);
      final data = await service.getPostComments(_postId);
      final comments = data['comments'] as List<dynamic>? ?? [];
      if (mounted) setState(() { _comments = comments; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return;
    _commentController.clear();
    setState(() => _sending = true);
    try {
      final service = widget.ref.read(clientServiceProvider);
      final comment = await service.addComment(_postId, text);
      if (mounted) {
        setState(() { _comments.add(comment); _sending = false; });
        widget.ref.read(communityFeedProvider(widget.scope).notifier).incrementCommentCount(_postId);
      }
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _relativeTime(String? iso) => relativeTime(iso);

  String? _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}$url';
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final authorName = post['author_username'] ?? 'Unknown';
    final authorPic = _resolveUrl(post['author_profile_picture'] as String?);
    final authorRole = post['author_role'] ?? 'client';
    final content = post['content'] as String?;
    final imageUrl = _resolveUrl(post['image_url'] as String?);
    final likeCount = post['like_count'] as int? ?? 0;
    final isLiked = post['is_liked_by_me'] as bool? ?? false;
    final time = _relativeTime(post['created_at'] as String?);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Post', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Author header ──
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      backgroundImage: authorPic != null ? NetworkImage(authorPic) : null,
                      child: authorPic == null ? Text(authorName[0].toUpperCase(), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(authorName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
                            ],
                          ),
                          Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz_rounded, color: Colors.grey[600], size: 20),
                      color: AppColors.surface,
                      onSelected: (v) { if (v == 'delete') { widget.onDelete(); Navigator.pop(context); } },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'delete', child: Text('Elimina', style: TextStyle(fontSize: 13, color: Colors.redAccent))),
                      ],
                    ),
                  ],
                ),

                // ── Content ──
                if (content != null && content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(content, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.5)),
                  ),

                // ── Image ──
                if (imageUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity,
                        errorBuilder: (_, _, _) => const SizedBox.shrink()),
                    ),
                  ),

                // ── Stats row ──
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            _likeCtrl.forward(from: 0);
                            widget.ref.read(communityFeedProvider(widget.scope).notifier).toggleLike(_postId);
                          },
                          child: Row(
                            children: [
                              ScaleTransition(
                                scale: _likeScale,
                                child: Icon(
                                  isLiked ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
                                  size: 22,
                                  color: isLiked ? AppColors.primary : Colors.grey[500],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('$likeCount', style: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Icon(Icons.chat_bubble_outline_rounded, size: 20, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text('${_comments.length}', style: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),

                // ── Comments ──
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                  )
                else
                  ..._comments.map((c) {
                    final cMap = c as Map<String, dynamic>;
                    final cAuthor = cMap['author_username'] ?? '';
                    final cPic = _resolveUrl(cMap['author_profile_picture'] as String?);
                    final cContent = cMap['content'] ?? '';
                    final cTime = _relativeTime(cMap['created_at'] as String?);
                    return Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            backgroundImage: cPic != null ? NetworkImage(cPic) : null,
                            child: cPic == null ? Text(cAuthor.isNotEmpty ? cAuthor[0].toUpperCase() : '?', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)) : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(cAuthor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                    const SizedBox(width: 8),
                                    Text(cTime, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(cContent, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          // ── Comment input ──
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 8, MediaQuery.of(context).viewInsets.bottom + 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
            ),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _sendComment,
                  icon: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, color: AppColors.primary, size: 22),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
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

  String _relativeTime(String? iso) => relativeTime(iso);

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

// ─── EVENT CONFIRMATION DIALOG ───────────────────────────────────

class _EventConfirmationDialog extends StatefulWidget {
  final String title;
  final String date;
  const _EventConfirmationDialog({required this.title, required this.date});

  @override
  State<_EventConfirmationDialog> createState() => _EventConfirmationDialogState();
}

class _EventConfirmationDialogState extends State<_EventConfirmationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _checkAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );
    _checkAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.7, curve: Curves.elasticOut),
    );
    _controller.forward();

    // Auto dismiss after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primary.withValues(alpha:0.3), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha:0.15),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated check circle
                    ScaleTransition(
                      scale: _checkAnim,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primary.withValues(alpha:0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha:0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Iscrizione confermata!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.date.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 6),
                          Text(
                            widget.date,
                            style: TextStyle(color: Colors.grey[400], fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Aggiunto al tuo calendario',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }
}
