import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'client_provider.dart';

/// Community feed state.
class CommunityFeedState {
  final List<Map<String, dynamic>> posts;
  final String? nextCursor;
  final bool hasMore;
  final bool loading;
  final bool loadingMore;

  const CommunityFeedState({
    this.posts = const [],
    this.nextCursor,
    this.hasMore = true,
    this.loading = true,
    this.loadingMore = false,
  });

  CommunityFeedState copyWith({
    List<Map<String, dynamic>>? posts,
    String? nextCursor,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
  }) => CommunityFeedState(
    posts: posts ?? this.posts,
    nextCursor: nextCursor ?? this.nextCursor,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

class CommunityFeedNotifier extends StateNotifier<CommunityFeedState> {
  final Ref ref;
  final String scope;

  CommunityFeedNotifier(this.ref, this.scope) : super(const CommunityFeedState()) {
    loadFeed();
  }

  Future<void> loadFeed() async {
    state = state.copyWith(loading: true);
    try {
      final service = ref.read(clientServiceProvider);
      final data = await service.getCommunityFeed(scope: scope);
      final posts = (data['posts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      state = CommunityFeedState(
        posts: posts,
        nextCursor: data['next_cursor'] as String?,
        hasMore: data['has_more'] as bool? ?? false,
        loading: false,
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.nextCursor == null) return;
    state = state.copyWith(loadingMore: true);
    try {
      final service = ref.read(clientServiceProvider);
      final data = await service.getCommunityFeed(cursor: state.nextCursor, scope: scope);
      final newPosts = (data['posts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      state = CommunityFeedState(
        posts: [...state.posts, ...newPosts],
        nextCursor: data['next_cursor'] as String?,
        hasMore: data['has_more'] as bool? ?? false,
        loading: false,
        loadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  /// Optimistic like toggle.
  void toggleLike(String postId) {
    final posts = state.posts.map((p) {
      if (p['id'] == postId) {
        final liked = p['is_liked_by_me'] as bool? ?? false;
        return {
          ...p,
          'is_liked_by_me': !liked,
          'like_count': ((p['like_count'] as int? ?? 0) + (liked ? -1 : 1)),
        };
      }
      return p;
    }).toList();
    state = state.copyWith(posts: posts);

    // Fire API call
    ref.read(clientServiceProvider).togglePostLike(postId).catchError((_) {
      // Revert on error
      loadFeed();
      return <String, dynamic>{};
    });
  }

  /// Add a newly created post to the top of the feed.
  void prependPost(Map<String, dynamic> post) {
    state = state.copyWith(posts: [post, ...state.posts]);
  }

  /// Update comment count after adding a comment.
  void incrementCommentCount(String postId) {
    final posts = state.posts.map((p) {
      if (p['id'] == postId) {
        return {...p, 'comment_count': ((p['comment_count'] as int? ?? 0) + 1)};
      }
      return p;
    }).toList();
    state = state.copyWith(posts: posts);
  }

  /// Optimistic participation toggle for events.
  /// Returns true if the user just joined (for showing confirmation popup).
  Future<bool> toggleParticipation(String postId) async {
    bool joined = false;
    final posts = state.posts.map((p) {
      if (p['id'] == postId) {
        final participating = p['is_participating'] as bool? ?? false;
        final count = p['participant_count'] as int? ?? 0;
        final maxP = p['max_participants'] as int?;
        if (!participating && maxP != null && count >= maxP) return p;
        joined = !participating;
        return {
          ...p,
          'is_participating': !participating,
          'participant_count': count + (participating ? -1 : 1),
        };
      }
      return p;
    }).toList();
    state = state.copyWith(posts: posts);

    try {
      await ref.read(clientServiceProvider).toggleEventParticipation(postId);
    } catch (_) {
      loadFeed();
      joined = false;
    }
    return joined;
  }

  /// Remove a deleted post.
  void removePost(String postId) {
    state = state.copyWith(posts: state.posts.where((p) => p['id'] != postId).toList());
  }
}

/// Family provider keyed by scope ("local" or "global").
final communityFeedProvider = StateNotifierProvider.autoDispose
    .family<CommunityFeedNotifier, CommunityFeedState, String>((ref, scope) {
  return CommunityFeedNotifier(ref, scope);
});
