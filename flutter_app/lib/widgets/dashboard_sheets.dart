import 'dart:async';
import 'package:dio/dio.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:record/record.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/calendar_event.dart';
import '../providers/client_provider.dart';
import '../providers/websocket_provider.dart';
import 'chat_camera_stub.dart'
    if (dart.library.html) 'chat_camera_web.dart'
    if (dart.library.io) 'chat_camera_native.dart';
import 'glass_card.dart';

// ─── HELPERS ────────────────────────────────────────────────────

void showSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: AppColors.textPrimary)),
      backgroundColor: isError ? AppColors.danger : AppColors.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ),
  );
}

Widget _sheetHandle() => Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.textTertiary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

Widget _sheetTitle(String title) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );

Widget _emptyState(String message, IconData icon) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );

String _timeAgo(String? dateStr) {
  if (dateStr == null) return '';
  try {
    final date = DateTime.parse(dateStr);
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'ora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}g';
    return '${(diff.inDays / 7).floor()}s';
  } catch (_) {
    return '';
  }
}

// ─── 1. NOTIFICATIONS SHEET ────────────────────────────────────

Future<void> showNotificationsSheet(BuildContext context, WidgetRef ref) {
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: _NotificationsContent(ref: ref),
        ),
      ),
    ),
  );
}

class _NotificationsContent extends StatefulWidget {
  final WidgetRef ref;

  const _NotificationsContent({required this.ref});

  @override
  State<_NotificationsContent> createState() => _NotificationsContentState();
}

class _NotificationsContentState extends State<_NotificationsContent> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = widget.ref.read(clientServiceProvider);
      final data = await service.getNotifications();
      if (mounted) setState(() { _notifications = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      final service = widget.ref.read(clientServiceProvider);
      await service.markAllNotificationsRead();
      widget.ref.invalidate(unreadNotificationsProvider);
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sheetTitle('Notifiche'),
              if (_notifications.isNotEmpty)
                TextButton(
                  onPressed: _markAllRead,
                  child: const Text('Segna tutte lette', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _notifications.isEmpty
                    ? _emptyState('Nessuna notifica', Icons.notifications_off_rounded)
                    : ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (_, i) {
                          final n = _notifications[i] as Map<String, dynamic>;
                          final isRead = n['read'] == true;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isRead
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _notifIcon(n['type']?.toString() ?? ''),
                                  color: isRead ? AppColors.textTertiary : AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n['message']?.toString() ?? '',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _timeAgo(n['created_at']?.toString()),
                                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

IconData _notifIcon(String type) {
  switch (type) {
    case 'message': return Icons.chat_bubble_outline_rounded;
    case 'friend_request': return Icons.person_add_rounded;
    case 'workout': return Icons.fitness_center_rounded;
    case 'appointment': return Icons.calendar_today_rounded;
    case 'achievement': return Icons.emoji_events_rounded;
    default: return Icons.notifications_none_rounded;
  }
}

// ─── 2. CONVERSATIONS SHEET ────────────────────────────────────

Future<void> showConversationsSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => _ConversationsContent(
        scrollController: scrollController,
        ref: ref,
        parentContext: context,
      ),
    ),
  );
}

class _ConversationsContent extends StatefulWidget {
  final ScrollController scrollController;
  final WidgetRef ref;
  final BuildContext parentContext;

  const _ConversationsContent({
    required this.scrollController,
    required this.ref,
    required this.parentContext,
  });

  @override
  State<_ConversationsContent> createState() => _ConversationsContentState();
}

class _ConversationsContentState extends State<_ConversationsContent> {
  List<dynamic> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = widget.ref.read(clientServiceProvider);
      final data = await service.getConversations();
      if (mounted) setState(() { _conversations = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _profilePictureUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          _sheetTitle('Messaggi'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _conversations.isEmpty
                    ? _emptyState('Nessuna conversazione', Icons.chat_bubble_outline_rounded)
                    : ListView.builder(
                        controller: widget.scrollController,
                        itemCount: _conversations.length,
                        itemBuilder: (_, i) {
                          final c = _conversations[i] as Map<String, dynamic>;
                          final unread = (c['unread_count'] as int?) ?? 0;
                          final name = c['other_user_name']?.toString() ?? 'Utente';
                          final picUrl = _profilePictureUrl(c['other_user_profile_picture']?.toString());
                          final lastMsg = c['last_message_preview']?.toString() ?? '';
                          final lastTime = _timeAgo(c['last_message_at']?.toString());

                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              showChatSheet(widget.parentContext, widget.ref, c);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: unread > 0
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: picUrl.isEmpty
                                          ? const LinearGradient(
                                              colors: [AppColors.primary, Color(0xFFE04E1A)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: picUrl.isNotEmpty
                                        ? Image.network(picUrl, fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => const Icon(Icons.person, color: Colors.white70, size: 22))
                                        : const Icon(Icons.person, color: Colors.white70, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  // Name + last message
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          lastMsg,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: unread > 0 ? AppColors.textSecondary : AppColors.textTertiary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Time + badge
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(lastTime,
                                          style: TextStyle(
                                            color: unread > 0 ? AppColors.primary : AppColors.textTertiary,
                                            fontSize: 11,
                                          )),
                                      if (unread > 0) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '$unread',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── 2b. CHAT SHEET (single conversation) ──────────────────────

Future<void> showChatSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> conversation) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => _ChatContent(
        scrollController: scrollController,
        ref: ref,
        conversation: conversation,
      ),
    ),
  );
}

class _ChatContent extends StatefulWidget {
  final ScrollController scrollController;
  final WidgetRef ref;
  final Map<String, dynamic> conversation;

  const _ChatContent({
    required this.scrollController,
    required this.ref,
    required this.conversation,
  });

  @override
  State<_ChatContent> createState() => _ChatContentState();
}

class _ChatContentState extends State<_ChatContent> {
  List<dynamic> _messages = [];
  bool _loading = true;
  final _msgController = TextEditingController();
  bool _sending = false;
  bool _hasText = false;
  final _listScrollController = ScrollController();

  // Voice recording
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  DateTime? _recordStart;

  // Voice playback
  final _audioPlayer = AudioPlayer();
  String? _playingUrl;
  Duration _playPosition = Duration.zero;
  Duration _playDuration = Duration.zero;

  String get _convId => widget.conversation['id']?.toString() ?? '';
  String get _otherName => widget.conversation['other_user_name']?.toString() ?? 'Utente';
  String get _otherUserId => widget.conversation['other_user_id']?.toString() ?? '';
  String? get _otherPicture => widget.conversation['other_user_profile_picture']?.toString();

  String _profilePictureUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  String _mediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}$url';
  }

  @override
  void initState() {
    super.initState();
    _msgController.addListener(() {
      final hasText = _msgController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _playPosition = pos);
    });
    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _playDuration = dur);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playingUrl = null; _playPosition = Duration.zero; });
    });
    _load();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _listScrollController.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_convId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final service = widget.ref.read(clientServiceProvider);
      final data = await service.getConversationMessages(_convId);
      final msgs = data['messages'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() { _messages = msgs; _loading = false; });
        _scrollToBottom();
      }
      await service.markConversationRead(_convId);
      widget.ref.invalidate(unreadMessagesProvider);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listScrollController.hasClients) {
        _listScrollController.animateTo(
          _listScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _sending) return;
    _msgController.clear();
    setState(() => _sending = true);
    try {
      final service = widget.ref.read(clientServiceProvider);
      final result = await service.sendMessage(receiverId: _otherUserId, content: text);
      // Add the message locally for instant feedback
      final msg = result['message'] as Map<String, dynamic>?;
      if (msg != null && mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Errore invio messaggio', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
      if (picked == null) return;
      setState(() => _sending = true);
      final service = widget.ref.read(clientServiceProvider);
      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : ext == 'gif' ? 'image/gif' : 'image/jpeg';
      final result = await service.uploadMediaBytes(
        receiverId: _otherUserId,
        bytes: bytes,
        fileName: 'photo_${DateTime.now().millisecondsSinceEpoch}.$ext',
        mimeType: mime,
      );
      final msg = result['message'] as Map<String, dynamic>?;
      if (msg != null && mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Errore invio immagine', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendCamera() async {
    try {
      final bytes = await capturePhotoForChat(context);
      if (bytes == null || !mounted) return;
      setState(() => _sending = true);
      final service = widget.ref.read(clientServiceProvider);
      final result = await service.uploadMediaBytes(
        receiverId: _otherUserId,
        bytes: bytes,
        fileName: 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg',
        mimeType: 'image/jpeg',
      );
      final msg = result['message'] as Map<String, dynamic>?;
      if (msg != null && mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Camera non disponibile', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Voice recording ──

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.opus, bitRate: 64000),
          path: '', // empty path = records to memory on web
        );
        setState(() {
          _isRecording = true;
          _recordStart = DateTime.now();
        });
      } else {
        if (mounted) showSnack(context, 'Permesso microfono negato', isError: true);
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Microfono non disponibile', isError: true);
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;
    try {
      final path = await _recorder.stop();
      final duration = _recordStart != null
          ? DateTime.now().difference(_recordStart!).inSeconds.toDouble()
          : 0.0;
      setState(() => _isRecording = false);

      if (duration < 1) {
        if (mounted) showSnack(context, 'Tieni premuto per registrare');
        return;
      }
      if (path == null) return;

      setState(() => _sending = true);
      final service = widget.ref.read(clientServiceProvider);

      // On web, record returns a blob URL; read bytes from XFile
      final xFile = XFile(path);
      final bytes = await xFile.readAsBytes();

      final result = await service.uploadMediaBytes(
        receiverId: _otherUserId,
        bytes: bytes,
        fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.opus',
        mimeType: 'audio/opus',
        duration: duration,
      );
      final msg = result['message'] as Map<String, dynamic>?;
      if (msg != null && mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Errore invio vocale', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _cancelRecording() async {
    if (!_isRecording) return;
    await _recorder.stop();
    setState(() => _isRecording = false);
  }

  Future<void> _togglePlayVoice(String url) async {
    if (_playingUrl == url) {
      // Already playing this — pause/resume
      final state = _audioPlayer.state;
      if (state == PlayerState.playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
    } else {
      // Play new URL
      await _audioPlayer.stop();
      setState(() { _playingUrl = url; _playPosition = Duration.zero; _playDuration = Duration.zero; });
      await _audioPlayer.play(UrlSource(url));
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final picUrl = _profilePictureUrl(_otherPicture);

    return Column(
      children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 10),
          decoration: const BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              _sheetHandle(),
              const SizedBox(height: 4),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: picUrl.isEmpty
                          ? const LinearGradient(
                              colors: [AppColors.primary, Color(0xFFE04E1A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: picUrl.isNotEmpty
                        ? Image.network(picUrl, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.person, color: Colors.white70, size: 16))
                        : const Icon(Icons.person, color: Colors.white70, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_otherName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // ── Messages ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _messages.isEmpty
                  ? _emptyState('Nessun messaggio', Icons.chat_bubble_outline_rounded)
                  : ListView.builder(
                      controller: _listScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i] as Map<String, dynamic>;
                        final isMe = m['sender_id']?.toString() != _otherUserId;
                        final mediaType = m['media_type']?.toString();
                        final fileUrl = _mediaUrl(m['file_url']?.toString());
                        final content = m['content']?.toString() ?? '';
                        final time = _formatTime(m['created_at']?.toString());
                        final isRead = m['is_read'] == true;
                        final duration = m['duration'];

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isMe ? 18 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 18),
                              ),
                            ),
                            child: _buildMessageContent(
                              mediaType: mediaType,
                              fileUrl: fileUrl,
                              content: content,
                              time: time,
                              isMe: isMe,
                              isRead: isRead,
                              duration: duration,
                            ),
                          ),
                        );
                      },
                    ),
        ),
        // ── Input bar ──
        Container(
          padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).viewInsets.bottom + 12),
          decoration: const BoxDecoration(
            color: AppColors.elevated,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              // Attach button
              _ChatIconButton(
                icon: Icons.attach_file_rounded,
                onTap: _sending ? null : _pickAndSendImage,
              ),
              // Camera button
              _ChatIconButton(
                icon: Icons.camera_alt_rounded,
                onTap: _sending ? null : _pickAndSendCamera,
              ),
              const SizedBox(width: 4),
              // Text input / recording indicator
              Expanded(
                child: _isRecording
                    ? Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.danger,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Registrando...',
                              style: TextStyle(color: AppColors.danger, fontSize: 14),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _cancelRecording,
                              child: const Icon(Icons.close_rounded, color: AppColors.danger, size: 18),
                            ),
                          ],
                        ),
                      )
                    : TextField(
                        controller: _msgController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Scrivi un messaggio...',
                          hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
              ),
              const SizedBox(width: 6),
              // Send / mic button
              GestureDetector(
                onTap: _hasText
                    ? _send
                    : _isRecording
                        ? _stopAndSendRecording
                        : _sending
                            ? null
                            : _startRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording
                        ? AppColors.danger
                        : _hasText
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.08),
                  ),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          _hasText ? Icons.send_rounded : Icons.mic_rounded,
                          color: _isRecording
                              ? Colors.white
                              : _hasText
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.6),
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageContent({
    required String? mediaType,
    required String fileUrl,
    required String content,
    required String time,
    required bool isMe,
    required bool isRead,
    required dynamic duration,
  }) {
    final textColor = isMe ? Colors.black : AppColors.textPrimary;
    final metaColor = isMe ? Colors.black.withValues(alpha: 0.5) : AppColors.textTertiary;

    // Image message
    if (mediaType == 'image' && fileUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220, maxHeight: 200),
                child: Image.network(fileUrl, fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const SizedBox(width: 120, height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
                  errorBuilder: (_, _, _) => Container(
                    width: 120, height: 80,
                    color: Colors.white.withValues(alpha: 0.05),
                    child: const Icon(Icons.broken_image_rounded, color: AppColors.textTertiary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [_buildTimestamp(time, isMe, isRead, metaColor)],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Video message
    if (mediaType == 'video' && fileUrl.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 200, height: 140,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.play_circle_fill_rounded, size: 48, color: Colors.white.withValues(alpha: 0.8)),
                    if (duration != null)
                      Positioned(
                        bottom: 6, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(_formatDuration(duration), style: const TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [_buildTimestamp(time, isMe, isRead, metaColor)],
              ),
            ],
          ),
        ),
      );
    }

    // Voice message
    if (mediaType == 'voice') {
      final isThisPlaying = _playingUrl == fileUrl && fileUrl.isNotEmpty;
      final isActuallyPlaying = isThisPlaying && _audioPlayer.state == PlayerState.playing;
      final totalDur = isThisPlaying && _playDuration.inMilliseconds > 0
          ? _playDuration
          : Duration(seconds: (duration is num ? duration.toInt() : 0));
      final progress = totalDur.inMilliseconds > 0
          ? (_playPosition.inMilliseconds / totalDur.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;
      final displayTime = isThisPlaying
          ? _formatDuration(_playPosition.inSeconds)
          : (duration != null ? _formatDuration(duration) : '0:00');

      return GestureDetector(
        onTap: fileUrl.isNotEmpty ? () => _togglePlayVoice(fileUrl) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isMe ? Colors.black.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.15),
                ),
                child: Icon(
                  isActuallyPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: textColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: isThisPlaying ? progress : 0.0,
                        minHeight: 3,
                        backgroundColor: isMe ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(displayTime, style: TextStyle(color: metaColor, fontSize: 10)),
                        _buildTimestamp(time, isMe, isRead, metaColor),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Text message (default) — shrink-wrap like WhatsApp
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(content, style: TextStyle(color: textColor, fontSize: 14)),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildTimestamp(time, isMe, isRead, metaColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestamp(String time, bool isMe, bool isRead, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(time, style: TextStyle(fontSize: 10, color: color)),
        if (isMe) ...[
          const SizedBox(width: 3),
          Icon(
            isRead ? Icons.done_all_rounded : Icons.done_rounded,
            size: 14,
            color: isRead ? const Color(0xFF60A5FA) : color,
          ),
        ],
      ],
    );
  }

  String _formatDuration(dynamic d) {
    final seconds = (d is num) ? d.toInt() : 0;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _ChatIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ChatIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
        ),
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 18),
      ),
    );
  }
}

// ─── 3. GYM MEMBERS SHEET ──────────────────────────────────────

Future<void> showGymMembersSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => _GymMembersContent(
        scrollController: scrollController,
        ref: ref,
        parentContext: context,
      ),
    ),
  );
}

class _GymMembersContent extends StatefulWidget {
  final ScrollController scrollController;
  final WidgetRef ref;
  final BuildContext parentContext;

  const _GymMembersContent({required this.scrollController, required this.ref, required this.parentContext});

  @override
  State<_GymMembersContent> createState() => _GymMembersContentState();
}

class _GymMembersContentState extends State<_GymMembersContent> {
  List<dynamic> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = widget.ref.read(clientServiceProvider);
      final data = await service.getGymMembers();
      if (mounted) setState(() { _members = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          _sheetTitle('Membri Palestra'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _members.isEmpty
                    ? _emptyState('Nessun membro trovato', Icons.people_outline_rounded)
                    : ListView.builder(
                        controller: widget.scrollController,
                        itemCount: _members.length,
                        itemBuilder: (_, i) => _memberTile(_members[i] as Map<String, dynamic>),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _memberTile(Map<String, dynamic> member) {
    final name = member['username']?.toString() ?? member['name']?.toString() ?? 'Utente';
    final pic = member['profile_picture']?.toString();
    final memberId = member['id']?.toString();
    final friendship = member['friendship_status']?.toString() ?? 'none';

    // Build avatar URL
    String? avatarUrl;
    if (pic != null && pic.isNotEmpty) {
      avatarUrl = pic.startsWith('http') ? pic : '${ApiConfig.baseUrl}$pic';
    }

    return GestureDetector(
      onTap: memberId != null ? () {
        Navigator.pop(context);
        showMemberProfileSheet(widget.parentContext, widget.ref, memberId);
      } : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  if (friendship == 'friends')
                    Row(
                      children: [
                        Icon(Icons.people_rounded, size: 12, color: Colors.green[400]),
                        const SizedBox(width: 4),
                        Text('Amici', style: TextStyle(fontSize: 11, color: Colors.green[400])),
                      ],
                    ),
                ],
              ),
            ),
            Text('Vedi', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}

// ─── 3b. MEMBER PROFILE SHEET ─────────────────────────────────

Future<void> showMemberProfileSheet(BuildContext context, WidgetRef ref, String memberId) async {
  final service = ref.read(clientServiceProvider);
  try {
    final data = await service.getMemberProfile(memberId);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MemberProfileContent(data: data, ref: ref, parentContext: context),
    );
  } catch (e) {
    if (context.mounted) {
      showSnack(context, 'Errore caricamento profilo', isError: true);
    }
  }
}

class _MemberProfileContent extends StatefulWidget {
  final Map<String, dynamic> data;
  final WidgetRef ref;
  final BuildContext parentContext;

  const _MemberProfileContent({required this.data, required this.ref, required this.parentContext});

  @override
  State<_MemberProfileContent> createState() => _MemberProfileContentState();
}

class _MemberProfileContentState extends State<_MemberProfileContent> {
  late String _friendshipStatus;
  Map<String, dynamic>? _friendProgress;
  bool _progressLoading = false;
  int _progressTab = 0; // 0=Forza, 1=Peso, 2=Salute
  int? _requestId;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _friendshipStatus = widget.data['friendship_status']?.toString() ?? 'none';
    _requestId = widget.data['friendship_request_id'] as int?;
    if (_friendshipStatus == 'friends') _loadFriendProgress();
  }

  Future<void> _loadFriendProgress() async {
    setState(() => _progressLoading = true);
    try {
      final service = widget.ref.read(clientServiceProvider);
      final data = await service.getFriendProgress(_memberId);
      if (mounted) setState(() { _friendProgress = data; _progressLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _progressLoading = false);
    }
  }

  String get _name => widget.data['name']?.toString() ?? widget.data['username']?.toString() ?? '';
  String? get _pic {
    final p = widget.data['profile_picture']?.toString();
    if (p == null || p.isEmpty) return null;
    return p.startsWith('http') ? p : '${ApiConfig.baseUrl}$p';
  }
  String get _bio => widget.data['bio']?.toString() ?? '';
  int get _streak => widget.data['streak'] as int? ?? 0;
  int get _gems => widget.data['gems'] as int? ?? 0;
  int get _health => widget.data['health_score'] as int? ?? 0;
  String get _memberId => widget.data['id']?.toString() ?? '';

  Future<void> _handleFriendAction() async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    final service = widget.ref.read(clientServiceProvider);

    try {
      switch (_friendshipStatus) {
        case 'none':
          // Open friend request dialog
          if (!mounted) return;
          setState(() => _actionLoading = false);
          _showFriendRequestDialog();
          return;
        case 'pending_outgoing':
          // Cancel request
          if (_requestId != null) {
            await service.cancelFriendRequest(_requestId!);
            setState(() => _friendshipStatus = 'none');
          }
          break;
        case 'pending_incoming':
          // Accept request
          if (_requestId != null) {
            await service.respondToFriendRequest(_requestId!, true);
            setState(() => _friendshipStatus = 'friends');
          }
          break;
        case 'friends':
          // Confirm unfriend
          if (!mounted) return;
          setState(() => _actionLoading = false);
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Rimuovi amico', style: TextStyle(color: Colors.white)),
              content: Text('Vuoi rimuovere $_name dalla lista amici?',
                  style: const TextStyle(color: AppColors.textSecondary)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Rimuovi', style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
          );
          if (confirm == true) {
            setState(() => _actionLoading = true);
            await service.removeFriend(_memberId);
            setState(() { _friendshipStatus = 'none'; });
          }
          break;
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Errore: $e', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _showFriendRequestDialog() {
    final msgController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Richiesta di amicizia', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  backgroundImage: _pic != null ? NetworkImage(_pic!) : null,
                  child: _pic == null ? Text(_name.isNotEmpty ? _name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white)) : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: msgController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Messaggio opzionale...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _actionLoading = true);
              try {
                final service = widget.ref.read(clientServiceProvider);
                await service.sendFriendRequest(_memberId, message: msgController.text);
                if (mounted) setState(() => _friendshipStatus = 'pending_outgoing');
              } catch (e) {
                if (mounted) showSnack(context, 'Errore invio richiesta', isError: true);
              } finally {
                if (mounted) setState(() => _actionLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Invia Richiesta', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(),
          const SizedBox(height: 16),
          // Avatar
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            backgroundImage: _pic != null ? NetworkImage(_pic!) : null,
            child: _pic == null
                ? Text(_name.isNotEmpty ? _name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(height: 12),
          // Name
          Text(_name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          if (_bio.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_bio, style: TextStyle(fontSize: 13, color: Colors.grey[500]), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statBadge(Icons.local_fire_department_rounded, '$_streak', 'Streak', const Color(0xFFFB923C)),
              _statBadge(Icons.diamond_outlined, '$_gems', 'Gemme', const Color(0xFFFACC15)),
              _statBadge(Icons.favorite_rounded, '$_health', 'Salute', const Color(0xFF22C55E)),
            ],
          ),
          const SizedBox(height: 20),
          // Weekly Activity Dots (L M M G V S D)
          _weeklyActivityDots(),
          const SizedBox(height: 20),
          // Friend action button + Message button
          Row(
            children: [
              Expanded(child: _friendActionButton()),
              const SizedBox(width: 8),
              _messageButton(),
            ],
          ),
          // Friend Progress Section
          if (_friendshipStatus == 'friends') ...[
            const SizedBox(height: 24),
            _buildFriendProgressSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildFriendProgressSection() {
    if (_progressLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_friendProgress == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Row(
          children: [
            Icon(Icons.insights_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text('Progressi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 12),
        // Tab pills
        Row(
          children: [
            _progressPill('Forza', 0),
            const SizedBox(width: 8),
            _progressPill('Peso', 1),
            const SizedBox(width: 8),
            _progressPill('Salute', 2),
          ],
        ),
        const SizedBox(height: 16),
        // Content
        if (_progressTab == 0) _buildStrengthTab(),
        if (_progressTab == 1) _buildWeightTab(),
        if (_progressTab == 2) _buildHealthTab(),
      ],
    );
  }

  Widget _progressPill(String label, int index) {
    final active = _progressTab == index;
    return GestureDetector(
      onTap: () => setState(() => _progressTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: active ? Colors.white : AppColors.textSecondary,
        )),
      ),
    );
  }

  Widget _buildStrengthTab() {
    final cats = _friendProgress?['strength_by_category']?['categories'] as Map<String, dynamic>? ?? {};
    final goals = _friendProgress?['strength_by_category']?['goals'] as Map<String, dynamic>? ?? {};
    if (cats.isEmpty) return const Text('Nessun dato forza', style: TextStyle(color: AppColors.textTertiary, fontSize: 13));

    final colors = {'upper_body': const Color(0xFFF97316), 'lower_body': const Color(0xFF8B5CF6), 'cardio': const Color(0xFF22C55E)};
    final labels = {'upper_body': 'Parte Superiore', 'lower_body': 'Parte Inferiore', 'cardio': 'Cardio'};

    return Column(
      children: cats.entries.map((entry) {
        final key = entry.key;
        final cat = entry.value as Map<String, dynamic>? ?? {};
        final progress = (cat['progress'] as num?)?.toInt() ?? 0;
        final trend = cat['trend']?.toString() ?? 'stable';
        final color = colors[key] ?? AppColors.primary;
        final goal = goals[key.replaceAll('_body', '')]?.toString();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(
                    key == 'cardio' ? Icons.directions_run : Icons.fitness_center,
                    color: color, size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(labels[key] ?? key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (progress / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation(color),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          trend == 'up' ? Icons.trending_up : trend == 'down' ? Icons.trending_down : Icons.trending_flat,
                          size: 14,
                          color: trend == 'up' ? const Color(0xFF22C55E) : trend == 'down' ? const Color(0xFFEF4444) : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text('$progress%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                      ],
                    ),
                    if (goal != null)
                      Text('Ob: $goal%', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeightTab() {
    final history = (_friendProgress?['weight_history'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final currentWeight = _friendProgress?['current_weight'];

    if (history.isEmpty) return const Text('Nessun dato peso', style: TextStyle(color: AppColors.textTertiary, fontSize: 13));

    // Take last 10
    final entries = history.length > 10 ? history.sublist(history.length - 10) : history;
    final weights = entries.map((e) => (e['weight'] as num).toDouble()).toList();
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final range = (maxW - minW).clamp(1.0, double.infinity);

    return Column(
      children: [
        if (currentWeight != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.monitor_weight_rounded, color: Color(0xFF60A5FA), size: 18),
                const SizedBox(width: 8),
                Text('Peso Attuale: ${(currentWeight as num).toStringAsFixed(1)} kg',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: entries.asMap().entries.map((entry) {
              final w = (entry.value['weight'] as num).toDouble();
              final normalized = ((w - minW) / range * 0.8 + 0.2).clamp(0.2, 1.0);
              final date = entry.value['date']?.toString() ?? '';
              final shortDate = date.length >= 5 ? date.substring(5) : date; // MM-DD

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(w.toStringAsFixed(0), style: TextStyle(fontSize: 8, color: Colors.grey[500])),
                      const SizedBox(height: 2),
                      Container(
                        height: 100 * normalized,
                        decoration: BoxDecoration(
                          color: const Color(0xFF60A5FA),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(shortDate, style: TextStyle(fontSize: 7, color: Colors.grey[600])),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthTab() {
    final scores = (_friendProgress?['weekly_health_scores'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final healthScore = _friendProgress?['health_score'] as int? ?? 0;

    if (scores.isEmpty) return const Text('Nessun dato salute', style: TextStyle(color: AppColors.textTertiary, fontSize: 13));

    final avg = scores.map((e) => (e['score'] as num).toInt()).reduce((a, b) => a + b) ~/ scores.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.favorite_rounded, color: Color(0xFF22C55E), size: 18),
              const SizedBox(width: 8),
              Text('Punteggio: $healthScore', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Spacer(),
              Text('Media: $avg', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: scores.asMap().entries.map((entry) {
              final score = (entry.value['score'] as num).toInt();
              final normalized = (score / 100).clamp(0.1, 1.0);
              final date = entry.value['date']?.toString() ?? '';
              final shortDate = date.length >= 5 ? date.substring(5) : date;
              final dayLabels = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];
              final dayLabel = entry.key < dayLabels.length ? dayLabels[entry.key] : shortDate;
              final color = score >= 80 ? const Color(0xFF22C55E) : score >= 60 ? const Color(0xFFEAB308) : const Color(0xFFEF4444);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('$score', style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Container(
                        height: 80 * normalized,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(dayLabel, style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _statBadge(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _weeklyActivityDots() {
    final days = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (i) {
        final active = i < _streak.clamp(0, 7);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? const Color(0xFFF97316) : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(color: active ? const Color(0xFFF97316) : Colors.white.withValues(alpha: 0.1)),
                ),
                child: active ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
              const SizedBox(height: 4),
              Text(days[i], style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }),
    );
  }

  Widget _friendActionButton() {
    String label;
    Color bgColor;
    Color textColor;
    Color borderColor;

    switch (_friendshipStatus) {
      case 'pending_outgoing':
        label = 'Richiesta Inviata';
        bgColor = Colors.grey.withValues(alpha: 0.15);
        textColor = Colors.grey[400]!;
        borderColor = Colors.grey.withValues(alpha: 0.2);
        break;
      case 'pending_incoming':
        label = 'Accetta Richiesta';
        bgColor = const Color(0xFF22C55E).withValues(alpha: 0.15);
        textColor = const Color(0xFF22C55E);
        borderColor = const Color(0xFF22C55E).withValues(alpha: 0.3);
        break;
      case 'friends':
        label = 'Amici \u2713';
        bgColor = const Color(0xFF7C3AED).withValues(alpha: 0.2);
        textColor = const Color(0xFF7C3AED);
        borderColor = const Color(0xFF7C3AED).withValues(alpha: 0.3);
        break;
      default: // 'none'
        label = 'Aggiungi Amico';
        bgColor = Colors.transparent;
        textColor = const Color(0xFF7C3AED);
        borderColor = const Color(0xFF7C3AED).withValues(alpha: 0.4);
    }

    return GestureDetector(
      onTap: _actionLoading ? null : _handleFriendAction,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: _actionLoading
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: textColor))
              : Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
        ),
      ),
    );
  }

  Widget _messageButton() {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        // Open chat with this user - find or create conversation
        showConversationsSheet(widget.parentContext, widget.ref);
      },
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: const Icon(Icons.chat_bubble_outline_rounded, size: 20, color: AppColors.textSecondary),
      ),
    );
  }
}

// ─── 4. FRIENDS SHEET (with Amici/Richieste tabs) ──────────────

Future<void> showFriendsSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => _FriendsContent(
        scrollController: scrollController,
        ref: ref,
        parentContext: context,
      ),
    ),
  );
}

class _FriendsContent extends StatefulWidget {
  final ScrollController scrollController;
  final WidgetRef ref;
  final BuildContext parentContext;

  const _FriendsContent({required this.scrollController, required this.ref, required this.parentContext});

  @override
  State<_FriendsContent> createState() => _FriendsContentState();
}

class _FriendsContentState extends State<_FriendsContent> {
  int _tabIndex = 0; // 0 = Amici, 1 = Richieste
  List<dynamic> _friends = [];
  List<dynamic> _incoming = [];
  List<dynamic> _outgoing = [];
  bool _loading = true;
  bool _requestsLoading = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadPendingCount();
  }

  Future<void> _loadFriends() async {
    try {
      final service = widget.ref.read(clientServiceProvider);
      final data = await service.getFriends();
      if (mounted) setState(() { _friends = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPendingCount() async {
    try {
      final service = widget.ref.read(clientServiceProvider);
      final incoming = await service.getIncomingFriendRequests();
      if (mounted) setState(() => _pendingCount = incoming.length);
    } catch (_) {}
  }

  Future<void> _loadRequests() async {
    setState(() => _requestsLoading = true);
    try {
      final service = widget.ref.read(clientServiceProvider);
      final results = await Future.wait([
        service.getIncomingFriendRequests(),
        service.getOutgoingFriendRequests(),
      ]);
      if (mounted) {
        setState(() {
        _incoming = results[0];
        _outgoing = results[1];
        _pendingCount = _incoming.length;
        _requestsLoading = false;
      });
      }
    } catch (e) {
      if (mounted) setState(() => _requestsLoading = false);
    }
  }

  Future<void> _respondToRequest(int requestId, bool accept) async {
    try {
      final service = widget.ref.read(clientServiceProvider);
      await service.respondToFriendRequest(requestId, accept);
      showSnack(context, accept ? 'Richiesta accettata!' : 'Richiesta rifiutata');
      _loadRequests();
      if (accept) _loadFriends();
    } catch (e) {
      showSnack(context, 'Errore', isError: true);
    }
  }

  Future<void> _cancelRequest(int requestId) async {
    try {
      final service = widget.ref.read(clientServiceProvider);
      await service.cancelFriendRequest(requestId);
      showSnack(context, 'Richiesta annullata');
      _loadRequests();
    } catch (e) {
      showSnack(context, 'Errore', isError: true);
    }
  }

  Future<void> _removeFriend(String friendId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rimuovi amico', style: TextStyle(color: Colors.white)),
        content: Text('Vuoi rimuovere $name dalla lista amici?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rimuovi', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final service = widget.ref.read(clientServiceProvider);
        await service.removeFriend(friendId);
        showSnack(context, 'Amico rimosso');
        _loadFriends();
      } catch (e) {
        showSnack(context, 'Errore', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          const SizedBox(height: 8),
          // Tab bar
          Row(
            children: [
              _tab('Amici', 0),
              const SizedBox(width: 8),
              _tab('Richieste', 1, badge: _pendingCount),
            ],
          ),
          const SizedBox(height: 16),
          // Tab content
          Expanded(
            child: _tabIndex == 0 ? _friendsTab() : _requestsTab(),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, int index, {int badge = 0}) {
    final active = _tabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _tabIndex = index);
        if (index == 1 && _incoming.isEmpty && _outgoing.isEmpty) _loadRequests();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: active ? AppColors.primary : Colors.grey[500],
            )),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(8)),
                child: Text('$badge', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _friendsTab() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_friends.isEmpty) return _emptyState('Nessun amico ancora', Icons.people_outline_rounded);
    return ListView.builder(
      controller: widget.scrollController,
      itemCount: _friends.length,
      itemBuilder: (_, i) {
        final f = _friends[i] as Map<String, dynamic>;
        final name = f['username']?.toString() ?? 'Utente';
        final friendId = f['id']?.toString() ?? f['user_id']?.toString() ?? '';
        final pic = f['profile_picture']?.toString();
        String? avatarUrl;
        if (pic != null && pic.isNotEmpty) {
          avatarUrl = pic.startsWith('http') ? pic : '${ApiConfig.baseUrl}$pic';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  showMemberProfileSheet(widget.parentContext, widget.ref, friendId);
                },
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    showMemberProfileSheet(widget.parentContext, widget.ref, friendId);
                  },
                  child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
              // Message button
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  showConversationsSheet(widget.parentContext, widget.ref);
                },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.textTertiary),
                ),
              ),
              const SizedBox(width: 6),
              // Remove button
              GestureDetector(
                onTap: () => _removeFriend(friendId, name),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.close_rounded, size: 16, color: AppColors.danger.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _requestsTab() {
    if (_requestsLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

    if (_incoming.isEmpty && _outgoing.isEmpty) {
      return _emptyState('Nessuna richiesta', Icons.mail_outline_rounded);
    }

    return ListView(
      controller: widget.scrollController,
      children: [
        if (_incoming.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('RICEVUTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 1)),
          ),
          ..._incoming.map((r) => _requestCard(r as Map<String, dynamic>, isIncoming: true)),
        ],
        if (_outgoing.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text('INVIATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 1)),
          ),
          ..._outgoing.map((r) => _requestCard(r as Map<String, dynamic>, isIncoming: false)),
        ],
      ],
    );
  }

  Widget _requestCard(Map<String, dynamic> req, {required bool isIncoming}) {
    final name = req['from_username']?.toString() ?? req['to_username']?.toString() ?? req['username']?.toString() ?? 'Utente';
    final pic = req['from_profile_picture']?.toString() ?? req['to_profile_picture']?.toString() ?? req['profile_picture']?.toString();
    final reqId = req['id'] as int? ?? req['request_id'] as int? ?? 0;
    final message = req['message']?.toString();

    String? avatarUrl;
    if (pic != null && pic.isNotEmpty) {
      avatarUrl = pic.startsWith('http') ? pic : '${ApiConfig.baseUrl}$pic';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isIncoming ? const Color(0xFFF97316).withValues(alpha: 0.15) : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    if (message != null && message.isNotEmpty)
                      Text('"$message"', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isIncoming)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _respondToRequest(reqId, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                      ),
                      child: const Center(child: Text('Accetta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF22C55E)))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _respondToRequest(reqId, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                      ),
                      child: const Center(child: Text('Rifiuta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger))),
                    ),
                  ),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: () => _cancelRequest(reqId),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Center(child: Text('Annulla', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── 5. APPOINTMENTS SHEET ─────────────────────────────────────

Future<void> showAppointmentsSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => _AppointmentsContent(
        scrollController: scrollController,
        ref: ref,
      ),
    ),
  );
}

class _AppointmentsContent extends StatefulWidget {
  final ScrollController scrollController;
  final WidgetRef ref;

  const _AppointmentsContent({required this.scrollController, required this.ref});

  @override
  State<_AppointmentsContent> createState() => _AppointmentsContentState();
}

class _AppointmentsContentState extends State<_AppointmentsContent> {
  List<dynamic> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = widget.ref.read(clientServiceProvider);
      final data = await service.getAppointments();
      if (mounted) setState(() { _appointments = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          _sheetTitle('Appuntamenti'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _appointments.isEmpty
                    ? _emptyState('Nessun appuntamento', Icons.calendar_today_rounded)
                    : ListView.builder(
                        controller: widget.scrollController,
                        itemCount: _appointments.length,
                        itemBuilder: (_, i) {
                          final a = _appointments[i] as Map<String, dynamic>;
                          final date = a['date']?.toString() ?? '';
                          final time = a['time']?.toString() ?? '';
                          final trainerName = a['trainer_name']?.toString() ?? '';
                          final sessionType = a['session_type']?.toString() ?? 'Sessione';
                          final status = a['status']?.toString() ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sessionType,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$date • $time',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                      if (trainerName.isNotEmpty)
                                        Text(
                                          'con $trainerName',
                                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                                _statusBadge(status),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color text;
    String label;
    switch (status) {
      case 'confirmed':
        bg = const Color(0xFF22C55E).withValues(alpha: 0.2);
        text = const Color(0xFF22C55E);
        label = 'Confermato';
        break;
      case 'pending':
        bg = const Color(0xFFEAB308).withValues(alpha: 0.2);
        text = const Color(0xFFEAB308);
        label = 'In attesa';
        break;
      case 'cancelled':
        bg = AppColors.danger.withValues(alpha: 0.2);
        text = AppColors.danger;
        label = 'Annullato';
        break;
      default:
        bg = Colors.white.withValues(alpha: 0.1);
        text = AppColors.textSecondary;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── 6. QR ACCESS TOKEN DIALOG ─────────────────────────────────

Future<void> showQrAccessDialog(BuildContext context, WidgetRef ref) async {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (ctx) => _QrAccessDialog(ref: ref),
  );
}

class _QrAccessDialog extends StatefulWidget {
  final WidgetRef ref;
  const _QrAccessDialog({required this.ref});

  @override
  State<_QrAccessDialog> createState() => _QrAccessDialogState();
}

class _QrAccessDialogState extends State<_QrAccessDialog> {
  String? _qrData;
  String? _username;
  int _secondsLeft = 30;
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    _timer?.cancel();
    setState(() { _loading = true; _error = null; });
    try {
      final service = widget.ref.read(clientServiceProvider);
      final data = await service.generateAccessToken();
      if (!mounted) return;

      final token = data['token']?.toString() ?? '';
      final userId = data['user_id']?.toString() ?? '';
      _username = data['username']?.toString();

      // Encode: GYMACCESS + userId (no dashes, 32 chars) + token (12 chars)
      final hexUserId = userId.replaceAll('-', '');
      final qrData = 'GYMACCESS$hexUserId$token';

      setState(() {
        _qrData = qrData;
        _secondsLeft = 30;
        _loading = false;
      });
      _startCountdown();
    } catch (e) {
      if (mounted) setState(() { _error = 'Impossibile generare il codice di accesso'; _loading = false; });
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        // Auto-regenerate after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _generate();
        });
      }
    });
  }

  Color get _timerColor {
    if (_secondsLeft <= 10) return const Color(0xFFEF4444); // red-500
    if (_secondsLeft <= 20) return const Color(0xFFEAB308); // yellow-500
    return const Color(0xFF22C55E); // green-500
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Accesso Palestra',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text('\u00D7', style: TextStyle(fontSize: 28, color: Colors.grey[500])),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 14)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _generate, child: const Text('Riprova')),
                  ],
                ),
              )
            else ...[
              // QR Code (white background, matching web: 220x220 + 16px padding)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: _qrData!,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              const SizedBox(height: 16),

              // Username
              if (_username != null)
                Text(
                  _username!,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              const SizedBox(height: 12),

              // Timer bar (matching web: green → yellow → red)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      // Track
                      Container(color: Colors.white.withValues(alpha: 0.1)),
                      // Fill
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.linear,
                        width: (MediaQuery.of(context).size.width - 128) * (_secondsLeft / 30),
                        decoration: BoxDecoration(
                          color: _timerColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Timer text
              Text(
                _secondsLeft > 0 ? '${_secondsLeft}s' : 'Scaduto',
                style: TextStyle(
                  color: _timerColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),

              // Subtitle
              Text(
                'Scansiona al tornello per entrare',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── 7. JOIN GYM DIALOG ────────────────────────────────────────

Future<void> showJoinGymDialog(BuildContext context, WidgetRef ref) {
  return showDialog(
    context: context,
    builder: (ctx) => _JoinGymDialog(ref: ref, parentContext: context),
  );
}

class _JoinGymDialog extends StatefulWidget {
  final WidgetRef ref;
  final BuildContext parentContext;
  const _JoinGymDialog({required this.ref, required this.parentContext});

  @override
  State<_JoinGymDialog> createState() => _JoinGymDialogState();
}

class _JoinGymDialogState extends State<_JoinGymDialog> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() => _loading = true);
    try {
      final service = widget.ref.read(clientServiceProvider);
      await service.joinGym(code);
      widget.ref.invalidate(clientDataProvider);
      if (mounted) {
        Navigator.pop(context);
        showSnack(widget.parentContext, 'Iscritto alla palestra!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        String msg = 'Codice non valido';
        if (e is DioException && e.response?.data is Map) {
          msg = (e.response!.data as Map)['detail']?.toString() ?? msg;
        }
        showSnack(context, msg, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 40),
            const SizedBox(height: 16),
            const Text(
              'Unisciti a una Palestra',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Inserisci il codice fornito dalla tua palestra',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, letterSpacing: 2),
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'CODICE',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _join,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Unisciti'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 8. LOG WEIGHT DIALOG ──────────────────────────────────────

Future<void> showLogWeightDialog(BuildContext context, WidgetRef ref, {double? currentWeight}) {
  return showDialog(
    context: context,
    builder: (ctx) => _LogWeightDialog(ref: ref, parentContext: context, currentWeight: currentWeight),
  );
}

class _LogWeightDialog extends StatefulWidget {
  final WidgetRef ref;
  final BuildContext parentContext;
  final double? currentWeight;
  const _LogWeightDialog({required this.ref, required this.parentContext, this.currentWeight});

  @override
  State<_LogWeightDialog> createState() => _LogWeightDialogState();
}

class _LogWeightDialogState extends State<_LogWeightDialog> {
  late final TextEditingController _controller;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentWeight != null ? widget.currentWeight!.toStringAsFixed(1) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim().replaceAll(',', '.');
    final weight = double.tryParse(text);
    if (weight == null || weight < 20 || weight > 300) {
      showSnack(context, 'Inserisci un peso valido (20-300 kg)', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final service = widget.ref.read(clientServiceProvider);
      await service.updateProfile({'weight': weight});
      widget.ref.invalidate(clientDataProvider);
      if (mounted) {
        Navigator.pop(context);
        showSnack(widget.parentContext, 'Peso aggiornato: ${weight.toStringAsFixed(1)} kg');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showSnack(context, 'Errore aggiornamento peso', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monitor_weight_rounded, color: AppColors.primary, size: 40),
            const SizedBox(height: 16),
            const Text(
              'Registra Peso',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                suffixText: 'kg',
                suffixStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 20),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Salva'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 7. CALENDAR SHEET ──────────────────────────────────────────

Future<void> showCalendarSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => _CalendarContent(
        scrollController: scrollController,
        ref: ref,
      ),
    ),
  );
}

class _CalendarContent extends StatefulWidget {
  final ScrollController scrollController;
  final WidgetRef ref;

  const _CalendarContent({required this.scrollController, required this.ref});

  @override
  State<_CalendarContent> createState() => _CalendarContentState();
}

class _CalendarContentState extends State<_CalendarContent> {
  late int _currentMonth;
  late int _currentYear;
  DateTime? _selectedDay;
  List<CalendarEvent> _allEvents = [];
  bool _loading = true;

  static const _monthNames = [
    'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
  ];

  static const _dayHeaders = ['Dom', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab'];

  static const _weekdayNames = [
    'Domenica', 'Lunedi', 'Martedi', 'Mercoledi',
    'Giovedi', 'Venerdi', 'Sabato',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = now.month;
    _currentYear = now.year;
    _selectedDay = DateTime(now.year, now.month, now.day);
    _loadEvents();
  }

  void _loadEvents() {
    final asyncProfile = widget.ref.read(clientDataProvider);
    if (asyncProfile.hasValue) {
      setState(() {
        _allEvents = asyncProfile.value!.calendarEvents;
        _loading = false;
      });
    } else if (asyncProfile.hasError) {
      setState(() => _loading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      _currentMonth--;
      if (_currentMonth < 1) {
        _currentMonth = 12;
        _currentYear--;
      }
      _selectedDay = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth++;
      if (_currentMonth > 12) {
        _currentMonth = 1;
        _currentYear++;
      }
      _selectedDay = null;
    });
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  List<CalendarEvent> _eventsForDate(DateTime date) {
    final dateStr = _formatDate(date);
    return _allEvents.where((e) => e.date == dateStr).toList();
  }

  bool _hasCompleted(DateTime date) {
    return _eventsForDate(date).any((e) => e.completed);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  String _formatItalianDate(DateTime d) {
    final weekdayIdx = d.weekday % 7; // 0=Sun..6=Sat
    return '${_weekdayNames[weekdayIdx]} ${d.day} ${_monthNames[d.month - 1]}';
  }

  Color _dotColor(CalendarEvent event) {
    if (event.completed) return const Color(0xFF4ADE80);
    switch (event.type) {
      case 'course':
        return const Color(0xFFC084FC);
      case 'appointment':
        return const Color(0xFF60A5FA);
      default:
        return const Color(0xFFFB923C);
    }
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'workout':
        return Icons.fitness_center_rounded;
      case 'course':
        return Icons.school_rounded;
      case 'appointment':
        return Icons.calendar_today_rounded;
      case 'rest':
        return Icons.self_improvement_rounded;
      case 'milestone':
        return Icons.emoji_events_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          _sheetTitle('Calendario'),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                children: [
                  _buildMonthHeader(),
                  const SizedBox(height: 12),
                  // Calendar grid inside glass card (matching web app)
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildDayHeaders(),
                        const SizedBox(height: 8),
                        _buildCalendarGrid(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_selectedDay != null) _buildDayDetails(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _prevMonth,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.chevron_left_rounded, color: AppColors.textPrimary, size: 20),
          ),
        ),
        Text(
          '${_monthNames[_currentMonth - 1]} $_currentYear',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        GestureDetector(
          onTap: _nextMonth,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildDayHeaders() {
    return Row(
      children: _dayHeaders
          .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCalendarGrid() {
    // weekday % 7: Mon(1)->1, Tue(2)->2, ... Sun(7)->0
    // This gives Sunday=0 offset matching the Dom-first grid.
    final firstDayOffset = DateTime(_currentYear, _currentMonth, 1).weekday % 7;
    final daysInMonth = DateTime(_currentYear, _currentMonth + 1, 0).day;

    final cells = <Widget>[];

    for (var i = 0; i < firstDayOffset; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentYear, _currentMonth, day);
      final dayEvents = _eventsForDate(date);
      final isCompleted = dayEvents.any((e) => e.completed);
      final today = _isToday(date);
      final isSelected = _selectedDay != null &&
          date.year == _selectedDay!.year &&
          date.month == _selectedDay!.month &&
          date.day == _selectedDay!.day;

      // Streak bar connection: check neighbors
      final prevCompleted = _hasCompleted(DateTime(_currentYear, _currentMonth, day - 1));
      final nextCompleted = _hasCompleted(DateTime(_currentYear, _currentMonth, day + 1));

      cells.add(_buildDayCell(
        day: day,
        date: date,
        dayEvents: dayEvents,
        isCompleted: isCompleted,
        isToday: today,
        isSelected: isSelected,
        prevCompleted: prevCompleted,
        nextCompleted: nextCompleted,
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.0,
      mainAxisSpacing: 4,
      crossAxisSpacing: 0,
      children: cells,
    );
  }

  Widget _buildDayCell({
    required int day,
    required DateTime date,
    required List<CalendarEvent> dayEvents,
    required bool isCompleted,
    required bool isToday,
    required bool isSelected,
    required bool prevCompleted,
    required bool nextCompleted,
  }) {
    BorderRadius borderRadius;
    if (isCompleted) {
      borderRadius = BorderRadius.horizontal(
        left: prevCompleted ? Radius.zero : const Radius.circular(8),
        right: nextCompleted ? Radius.zero : const Radius.circular(8),
      );
    } else {
      borderRadius = BorderRadius.circular(8);
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedDay = date),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: isCompleted
              ? const Color(0xFF22C55E).withValues(alpha: 0.2)
              : (isSelected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent),
          borderRadius: borderRadius,
          border: isToday ? Border.all(color: AppColors.primary, width: 1.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: dayEvents.isNotEmpty ? AppColors.textPrimary : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            if (isCompleted)
              const Text(
                '\u2713',
                style: TextStyle(fontSize: 9, color: Color(0xFF4ADE80)),
              )
            else if (dayEvents.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: dayEvents
                    .take(3)
                    .map((e) => Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _dotColor(e),
                          ),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayDetails() {
    final events = _eventsForDate(_selectedDay!);
    final dateLabel = _formatItalianDate(_selectedDay!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateLabel.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Nessun evento programmato.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ...events.asMap().entries.map((entry) {
            final i = entry.key;
            final event = entry.value;
            return TweenAnimationBuilder<double>(
              key: ValueKey('${_formatDate(_selectedDay!)}_$i'),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 200 + (i * 80)),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              ),
              child: _buildEventCard(event),
            );
          }),
      ],
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    final icon = _eventIcon(event.type);
    final statusText = event.completed ? 'COMPLETATO' : 'PROGRAMMATO';
    final statusColor = event.completed ? const Color(0xFF4ADE80) : AppColors.primary;
    final dotColor = _dotColor(event);

    // Don't display raw JSON as subtitle
    String? subtitle;
    if (event.details != null && event.details!.isNotEmpty) {
      final d = event.details!.trim();
      if (!d.startsWith('[') && !d.startsWith('{')) {
        subtitle = d;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: dotColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: dotColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PROGRESS SHEET (Physique Photos + Weight History + Strength)
// ═══════════════════════════════════════════════════════════════════

Future<void> showProgressSheet(BuildContext context, WidgetRef ref) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const _ProgressPage(),
    ),
  );
}

class _ProgressPage extends ConsumerStatefulWidget {
  const _ProgressPage();

  @override
  ConsumerState<_ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends ConsumerState<_ProgressPage> {
  List<Map<String, dynamic>> _photos = [];
  bool _loadingPhotos = true;

  // Weight history
  Map<String, dynamic> _weightResponse = {};
  List<dynamic> _weightData = [];
  bool _loadingWeight = true;
  int _strengthCatPage = 0;
  String _weightPeriod = 'month';

  // Strength progress
  Map<String, dynamic>? _strengthData;
  bool _loadingStrength = true;
  String _strengthPeriod = 'month';

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _loadWeight();
    _loadStrength();
  }

  Future<void> _loadPhotos() async {
    try {
      final service = ref.read(clientServiceProvider);
      final result = await service.getPhysiquePhotos();
      final photos = (result['photos'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      if (mounted) setState(() { _photos = photos; _loadingPhotos = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPhotos = false);
    }
  }

  Future<void> _loadWeight() async {
    try {
      final service = ref.read(clientServiceProvider);
      final result = await service.getWeightHistory(period: _weightPeriod);
      final data = (result['data'] as List<dynamic>?) ?? [];
      if (mounted) setState(() { _weightResponse = result; _weightData = data; _loadingWeight = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingWeight = false);
    }
  }

  Future<void> _loadStrength() async {
    try {
      final service = ref.read(clientServiceProvider);
      final result = await service.getStrengthProgress(period: _strengthPeriod);
      if (mounted) setState(() { _strengthData = result; _loadingStrength = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingStrength = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Foto Fisico', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                  title: const Text('Scatta Foto', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                  title: const Text('Galleria', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      );
      if (source == null || !mounted) return;

      final picker = ImagePicker();
      final image = await picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1600);
      if (image == null) return;

      if (!mounted) return;
      showSnack(context, 'Caricamento foto...');

      final bytes = await image.readAsBytes();
      final service = ref.read(clientServiceProvider);
      await service.uploadPhysiquePhotoBytes(
        bytes: bytes,
        fileName: 'progress_${DateTime.now().millisecondsSinceEpoch}.jpg',
        mimeType: 'image/jpeg',
        title: 'Foto Progressi',
        photoDate: DateTime.now().toIso8601String().substring(0, 10),
      );

      if (!mounted) return;
      showSnack(context, 'Foto caricata!');
      _loadPhotos();
    } catch (e) {
      if (mounted) showSnack(context, 'Errore nel caricamento', isError: true);
    }
  }

  String _resolvePhotoUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}$url';
  }

  void _showAddWeightDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Registra Peso', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: '75.0',
            hintStyle: TextStyle(color: Colors.grey[600]),
            suffixText: 'kg',
            suffixStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annulla', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () async {
              final weight = double.tryParse(controller.text.replaceAll(',', '.'));
              if (weight == null || weight <= 0) return;
              Navigator.pop(ctx);
              try {
                final service = ref.read(clientServiceProvider);
                await service.logWeight(weight);
                if (mounted) {
                  showSnack(context, 'Peso registrato: ${weight.toStringAsFixed(1)} kg');
                  setState(() => _loadingWeight = true);
                  _loadWeight();
                }
              } catch (e) {
                if (mounted) showSnack(context, 'Errore nel salvataggio', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('I Miei Progressi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // ── Physique Photos ──
          _sectionHeader('FOTO FISICO', action: 'Aggiungi', onAction: _pickAndUploadPhoto),
          const SizedBox(height: 12),
          _buildPhotoGallery(),
          const SizedBox(height: 24),

          // ── Weight History ──
          _sectionHeader('PESO', action: '+ Registra', onAction: _showAddWeightDialog),
          const SizedBox(height: 4),
          Row(
            children: [
              _periodChip('Sett', 'week'),
              const SizedBox(width: 6),
              _periodChip('Mese', 'month'),
              const SizedBox(width: 6),
              _periodChip('Anno', 'year'),
            ],
          ),
          const SizedBox(height: 12),
          _buildWeightChart(),
          const SizedBox(height: 24),

          // ── Strength Progress ──
          _sectionHeader('FORZA'),
          const SizedBox(height: 4),
          Row(
            children: [
              _strengthPeriodChip('Sett', 'week'),
              const SizedBox(width: 6),
              _strengthPeriodChip('Mese', 'month'),
              const SizedBox(width: 6),
              _strengthPeriodChip('Anno', 'year'),
            ],
          ),
          const SizedBox(height: 12),
          _buildStrengthSection(),
        ],
      ),
    );
  }

  Widget _periodChip(String label, String value) {
    final isActive = _weightPeriod == value;
    return GestureDetector(
      onTap: () {
        setState(() { _weightPeriod = value; _loadingWeight = true; });
        _loadWeight();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? AppColors.primary : Colors.grey[500]),
        ),
      ),
    );
  }

  Widget _strengthPeriodChip(String label, String value) {
    final isActive = _strengthPeriod == value;
    return GestureDetector(
      onTap: () {
        setState(() { _strengthPeriod = value; _loadingStrength = true; });
        _loadStrength();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? AppColors.primary : Colors.grey[500]),
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, {String? action, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
            letterSpacing: 1.0,
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                action,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
          ),
      ],
    );
  }

  // ── Photo Gallery ──

  Widget _buildPhotoGallery() {
    if (_loadingPhotos) {
      return const SizedBox(
        height: 128,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
      );
    }

    return SizedBox(
      height: 128,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Add photo button
          GestureDetector(
            onTap: _pickAndUploadPhoto,
            child: Container(
              width: 96,
              height: 128,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 28),
                  SizedBox(height: 6),
                  Text('Aggiungi', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          // Photos
          ..._photos.asMap().entries.map((entry) {
            final photo = entry.value;
            final photoIndex = entry.key;
            final url = _resolvePhotoUrl(photo['photo_url'] as String?);
            final date = photo['photo_date'] as String? ?? '';
            final heroTag = 'progress_photo_$photoIndex';
            return GestureDetector(
              onTap: url.isNotEmpty ? () => _openPhotoViewer(context, photoIndex) : null,
              child: Container(
                width: 96,
                height: 128,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Hero(
                  tag: heroTag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        url.isNotEmpty
                            ? Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  child: const Icon(Icons.broken_image_rounded, color: AppColors.textTertiary),
                                ),
                              )
                            : Container(
                                color: Colors.white.withValues(alpha: 0.06),
                                child: const Icon(Icons.image_rounded, color: AppColors.textTertiary),
                              ),
                        if (date.isNotEmpty)
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                                ),
                              ),
                              child: Text(
                                date,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _openPhotoViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, animation, __) => _PhotoViewerPage(
          photos: _photos,
          initialIndex: initialIndex,
          resolveUrl: _resolvePhotoUrl,
          animation: animation,
        ),
        transitionsBuilder: (_, animation, __, child) => child,
      ),
    );
  }

  // ── Weight Chart ──

  String _weightPeriodLabel() {
    return switch (_weightPeriod) {
      'week' => 'Sett',
      'month' => 'Mese',
      'year' => 'Anno',
      _ => 'Mese',
    };
  }

  void _cycleWeightPeriod() {
    setState(() {
      _weightPeriod = switch (_weightPeriod) {
        'week' => 'month',
        'month' => 'year',
        _ => 'week',
      };
      _loadingWeight = true;
    });
    _loadWeight();
  }

  void _showSetGoalDialog() {
    final controller = TextEditingController();
    final goal = _weightResponse['weight_goal'];
    if (goal != null) controller.text = (goal as num).toStringAsFixed(1);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Obiettivo Peso', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: '70.0',
            hintStyle: TextStyle(color: Colors.grey[600]),
            suffixText: 'kg',
            suffixStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4ADE80))),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annulla', style: TextStyle(color: Colors.grey[400]))),
          ElevatedButton(
            onPressed: () async {
              final g = double.tryParse(controller.text.replaceAll(',', '.'));
              if (g == null || g <= 0) return;
              Navigator.pop(ctx);
              try {
                await ref.read(clientServiceProvider).setWeightGoal(g);
                if (mounted) { showSnack(context, 'Obiettivo: ${g.toStringAsFixed(1)} kg'); setState(() => _loadingWeight = true); _loadWeight(); }
              } catch (e) { if (mounted) showSnack(context, 'Errore', isError: true); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4ADE80), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightChart() {
    if (_loadingWeight) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
      );
    }

    // Parse weight data
    final weights = <double>[];
    final labels = <String>[];
    for (final entry in _weightData) {
      if (entry is Map<String, dynamic>) {
        final w = entry['weight'];
        if (w != null) {
          weights.add((w is num) ? w.toDouble() : double.tryParse(w.toString()) ?? 0);
          labels.add(entry['label'] as String? ?? entry['date'] as String? ?? '');
        }
      }
    }

    final goalRaw = _weightResponse['weight_goal'];
    final weightGoal = goalRaw != null ? (goalRaw as num).toDouble() : null;
    final currentW = weights.isNotEmpty ? weights.last : null;
    final changeW = weights.length > 1 ? weights.last - weights.first : 0.0;

    // Determine if getting closer to goal
    bool? gettingCloser; // null = no goal set
    if (weightGoal != null && weights.length >= 2) {
      final distStart = (weights.first - weightGoal).abs();
      final distEnd = (weights.last - weightGoal).abs();
      gettingCloser = distEnd < distStart;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current weight + change badge
          Row(
            children: [
              if (currentW != null) ...[
                Text('${currentW.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                if (weights.length > 1) ...[
                  const SizedBox(width: 8),
                  Builder(builder: (_) {
                    final badgeColor = gettingCloser == null
                        ? Colors.grey
                        : gettingCloser ? const Color(0xFF4ADE80) : const Color(0xFFEF4444);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${changeW >= 0 ? '+' : ''}${changeW.toStringAsFixed(1)} kg',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor),
                      ),
                    );
                  }),
                ],
              ] else
                Text('Nessun dato', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey[500])),
              const Spacer(),
              // Goal badge
              GestureDetector(
                onTap: _showSetGoalDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_rounded, size: 14, color: const Color(0xFF4ADE80)),
                      const SizedBox(width: 4),
                      Text(
                        weightGoal != null ? '${weightGoal.toStringAsFixed(1)} kg' : 'Obiettivo',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4ADE80)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chart — always visual
          if (weights.isEmpty)
            SizedBox(
              height: 120,
              child: Center(child: Text('Registra il peso per vedere il grafico', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontStyle: FontStyle.italic))),
            )
          else ...[
            _InteractiveChart(
              height: 120,
              painterBuilder: (tp) => _WeightChartPainter(
                weights: weights,
                weightGoal: weightGoal,
                labels: labels,
                touchPoint: tp,
              ),
            ),
            if (labels.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(labels.first, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                  if (weightGoal != null)
                    Text('Obiettivo: ${weightGoal.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF4ADE80))),
                  if (labels.length > 1)
                    Text(labels.last, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Strength ──

  Widget _buildStrengthSection() {
    if (_loadingStrength) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
      );
    }

    if (_strengthData == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: Text(
            'Nessun dato disponibile',
            style: TextStyle(fontSize: 14, color: Colors.grey[500], fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final categories = _strengthData!['categories'] as Map<String, dynamic>? ?? {};
    final overall = (_strengthData!['progress'] as num?)?.toDouble() ?? 0;
    final trend = _strengthData!['trend'] as String? ?? 'stable';

    return Column(
      children: [
        // Overall summary card with combined chart
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${overall >= 0 ? "+" : ""}${overall.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Progresso Totale', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text(
                        trend == 'up' ? 'In crescita' : trend == 'down' ? 'In calo' : 'Stabile',
                        style: TextStyle(
                          fontSize: 11,
                          color: trend == 'up' ? const Color(0xFF4ADE80) : trend == 'down' ? AppColors.danger : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(
                    trend == 'up' ? Icons.trending_up_rounded : trend == 'down' ? Icons.trending_down_rounded : Icons.trending_flat_rounded,
                    color: trend == 'up' ? const Color(0xFF4ADE80) : trend == 'down' ? AppColors.danger : Colors.grey[500],
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Combined strength chart — all categories overlaid
              _InteractiveChart(
                height: 120,
                painterBuilder: (tp) => _StrengthChartPainter(categories: categories, touchPoint: tp),
              ),
              const SizedBox(height: 8),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _chartLegend('Upper', const Color(0xFF60A5FA)),
                  const SizedBox(width: 16),
                  _chartLegend('Lower', const Color(0xFF4ADE80)),
                  const SizedBox(width: 16),
                  _chartLegend('Cardio', const Color(0xFFF472B6)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Category carousel
        ..._buildStrengthCarousel(categories),
      ],
    );
  }

  List<Widget> _buildStrengthCarousel(Map<String, dynamic> categories) {
    final catKeys = categories.keys.toList();
    if (catKeys.isEmpty) return [];

    return [
      // Page dots + current category label
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(catKeys.length, (i) {
          final key = catKeys[i];
          final color = key == 'upper_body' ? const Color(0xFF60A5FA)
              : key == 'lower_body' ? const Color(0xFF4ADE80)
              : const Color(0xFFF472B6);
          return GestureDetector(
            onTap: () => setState(() => _strengthCatPage = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _strengthCatPage == i ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _strengthCatPage == i ? color : color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 8),
      // Swipeable card
      SizedBox(
        height: 160,
        child: PageView.builder(
          itemCount: catKeys.length,
          onPageChanged: (i) => setState(() => _strengthCatPage = i),
          controller: PageController(initialPage: _strengthCatPage),
          itemBuilder: (context, index) {
            final key = catKeys[index];
            final cat = categories[key] as Map<String, dynamic>? ?? {};
            final progress = (cat['progress'] as num?)?.toDouble() ?? 0;
            final catTrend = cat['trend'] as String? ?? 'stable';
            final catData = (cat['data'] as List<dynamic>?) ?? [];
            final label = switch (key) {
              'upper_body' => 'Upper Body',
              'lower_body' => 'Lower Body',
              'cardio' => 'Cardio',
              _ => key,
            };
            final icon = switch (key) {
              'upper_body' => Icons.fitness_center_rounded,
              'lower_body' => Icons.directions_run_rounded,
              'cardio' => Icons.favorite_rounded,
              _ => Icons.sports_rounded,
            };
            final barColor = key == 'upper_body' ? const Color(0xFF60A5FA)
                : key == 'lower_body' ? const Color(0xFF4ADE80)
                : const Color(0xFFF472B6);

            final values = <double>[];
            final labels = <String>[];
            for (final d in catData) {
              if (d is Map<String, dynamic> && d['strength'] != null) {
                values.add((d['strength'] as num).toDouble());
                labels.add(d['label'] as String? ?? '');
              }
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: barColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: barColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 18, color: barColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ),
                      Text(
                        '${progress >= 0 ? "+" : ""}${progress.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: barColor),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        catTrend == 'up' ? Icons.arrow_upward_rounded : catTrend == 'down' ? Icons.arrow_downward_rounded : Icons.remove_rounded,
                        size: 16,
                        color: catTrend == 'up' ? const Color(0xFF4ADE80) : catTrend == 'down' ? AppColors.danger : Colors.grey[500],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (values.length >= 2) ...[
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => _InteractiveChart(
                          height: constraints.maxHeight,
                          painterBuilder: (tp) => _MiniLineChartPainter(values: values, color: barColor, labels: labels, touchPoint: tp),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (labels.isNotEmpty) Text(labels.first, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                        if (labels.length > 1) Text(labels.last, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                      ],
                    ),
                  ] else
                    Expanded(
                      child: Center(
                        child: Text('Dati insufficienti', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }
}

// ─── Interactive Chart Wrapper ──────────────────────────────────────

class _InteractiveChart extends StatefulWidget {
  final double height;
  final CustomPainter Function(Offset? touchPoint) painterBuilder;

  const _InteractiveChart({required this.height, required this.painterBuilder});

  @override
  State<_InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<_InteractiveChart> {
  Offset? _touchPoint;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (e) => setState(() => _touchPoint = e.localPosition),
      onExit: (_) => setState(() => _touchPoint = null),
      child: GestureDetector(
        onTapDown: (d) => setState(() => _touchPoint = d.localPosition),
        onPanUpdate: (d) => setState(() => _touchPoint = d.localPosition),
        onPanEnd: (_) => Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _touchPoint = null); }),
        onTapUp: (_) => Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _touchPoint = null); }),
        child: SizedBox(
          height: widget.height,
          child: CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: widget.painterBuilder(_touchPoint),
          ),
        ),
      ),
    );
  }
}

// ─── Shared Chart Helpers ──────────────────────────────────────────

Path _smoothPath(List<Offset> points) {
  if (points.length < 2) return Path()..moveTo(points.first.dx, points.first.dy);
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (int i = 0; i < points.length - 1; i++) {
    final p0 = points[i];
    final p1 = points[i + 1];
    final cpx = (p0.dx + p1.dx) / 2;
    path.cubicTo(cpx, p0.dy, cpx, p1.dy, p1.dx, p1.dy);
  }
  return path;
}

Path _smoothFillPath(List<Offset> points, double baseY) {
  final path = Path()..moveTo(points.first.dx, baseY);
  path.lineTo(points.first.dx, points.first.dy);
  for (int i = 0; i < points.length - 1; i++) {
    final p0 = points[i];
    final p1 = points[i + 1];
    final cpx = (p0.dx + p1.dx) / 2;
    path.cubicTo(cpx, p0.dy, cpx, p1.dy, p1.dx, p1.dy);
  }
  path.lineTo(points.last.dx, baseY);
  path.close();
  return path;
}

void _drawTooltip(Canvas canvas, Size size, Offset anchor, String text, {Color bgColor = const Color(0xE01A1A1A), Color textColor = Colors.white}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w600)),
    textDirection: TextDirection.ltr,
  )..layout();

  final tooltipW = tp.width + 14;
  final tooltipH = tp.height + 10;
  var tx = anchor.dx - tooltipW / 2;
  final ty = anchor.dy - tooltipH - 10;

  // Clamp to chart bounds
  if (tx < 2) tx = 2;
  if (tx + tooltipW > size.width - 2) tx = size.width - tooltipW - 2;
  final tooltipY = ty < 2 ? anchor.dy + 10 : ty;

  final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(tx, tooltipY, tooltipW, tooltipH), const Radius.circular(6));
  canvas.drawRRect(rrect, Paint()..color = bgColor);
  canvas.drawRRect(rrect, Paint()..color = textColor.withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 0.5);
  tp.paint(canvas, Offset(tx + 7, tooltipY + 5));

  // Triangle pointer
  final triPath = Path();
  final triX = anchor.dx.clamp(tx + 6, tx + tooltipW - 6);
  if (tooltipY < anchor.dy) {
    triPath.moveTo(triX - 4, tooltipY + tooltipH);
    triPath.lineTo(triX, tooltipY + tooltipH + 5);
    triPath.lineTo(triX + 4, tooltipY + tooltipH);
  } else {
    triPath.moveTo(triX - 4, tooltipY);
    triPath.lineTo(triX, tooltipY - 5);
    triPath.lineTo(triX + 4, tooltipY);
  }
  triPath.close();
  canvas.drawPath(triPath, Paint()..color = bgColor);
}

void _drawMultiTooltip(Canvas canvas, Size size, Offset anchor, List<(Color, String)> lines) {
  final painters = <(Color, TextPainter)>[];
  double maxW = 0;
  for (final (color, text) in lines) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    painters.add((color, tp));
    if (tp.width > maxW) maxW = tp.width;
  }

  final tooltipW = maxW + 28; // dot + padding
  final lineH = 16.0;
  final tooltipH = painters.length * lineH + 10;
  var tx = anchor.dx - tooltipW / 2;
  final ty = anchor.dy - tooltipH - 12;
  if (tx < 2) tx = 2;
  if (tx + tooltipW > size.width - 2) tx = size.width - tooltipW - 2;
  final tooltipY = ty < 2 ? anchor.dy + 12 : ty;

  final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(tx, tooltipY, tooltipW, tooltipH), const Radius.circular(8));
  canvas.drawRRect(rrect, Paint()..color = const Color(0xE01A1A1A));
  canvas.drawRRect(rrect, Paint()..color = Colors.white.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 0.5);

  var y = tooltipY + 5;
  for (final (color, tp) in painters) {
    canvas.drawCircle(Offset(tx + 10, y + lineH / 2 - 1), 3, Paint()..color = color);
    tp.paint(canvas, Offset(tx + 18, y));
    y += lineH;
  }
}

int _findNearestPointIndex(List<Offset> points, double touchX) {
  int nearest = 0;
  double minDist = double.infinity;
  for (int i = 0; i < points.length; i++) {
    final dist = (points[i].dx - touchX).abs();
    if (dist < minDist) { minDist = dist; nearest = i; }
  }
  return nearest;
}

// ─── Weight Chart Painter ──────────────────────────────────────────

class _WeightChartPainter extends CustomPainter {
  final List<double> weights;
  final double? weightGoal;
  final List<String> labels;
  final Offset? touchPoint;

  _WeightChartPainter({required this.weights, this.weightGoal, this.labels = const [], this.touchPoint});

  @override
  void paint(Canvas canvas, Size size) {
    if (weights.isEmpty) return;

    double minW = weights.reduce((a, b) => a < b ? a : b);
    double maxW = weights.reduce((a, b) => a > b ? a : b);
    if (minW == maxW) { minW -= 5; maxW += 5; }
    final dataRange = maxW - minW;
    if (weightGoal != null) {
      final goalDist = weightGoal! > maxW ? weightGoal! - maxW : (weightGoal! < minW ? minW - weightGoal! : 0.0);
      if (goalDist <= dataRange * 1.5) {
        minW = minW < weightGoal! ? minW : weightGoal!;
        maxW = maxW > weightGoal! ? maxW : weightGoal!;
      }
    }
    final range = maxW - minW;
    final effectiveRange = range < 0.5 ? 1.0 : range;
    final pad = effectiveRange * 0.15;

    double yForWeight(double w) => size.height - ((w - minW + pad) / (effectiveRange + 2 * pad)) * size.height;

    final points = <Offset>[];
    for (int i = 0; i < weights.length; i++) {
      final x = weights.length == 1 ? size.width / 2 : (i / (weights.length - 1)) * size.width;
      points.add(Offset(x, yForWeight(weights[i])));
    }

    // Grid lines
    final gridPaint = Paint()..color = Colors.white.withValues(alpha: 0.05)..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Goal dashed line
    if (weightGoal != null) {
      final rawGoalY = yForWeight(weightGoal!);
      final goalAbove = rawGoalY < 0;
      final goalBelow = rawGoalY > size.height;
      final goalY = rawGoalY.clamp(4.0, size.height - 4.0);
      final goalPaint = Paint()
        ..color = const Color(0xFF4ADE80).withValues(alpha: 0.4)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      const dashWidth = 6.0;
      const dashGap = 4.0;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, goalY), Offset((x + dashWidth).clamp(0, size.width), goalY), goalPaint);
        x += dashWidth + dashGap;
      }
      final goalLabel = goalAbove ? 'GOAL ${weightGoal!.toStringAsFixed(0)} kg ↑' : goalBelow ? 'GOAL ${weightGoal!.toStringAsFixed(0)} kg ↓' : 'GOAL';
      final labelPainter = TextPainter(
        text: TextSpan(text: goalLabel, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF4ADE80))),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(size.width - labelPainter.width - 2, goalY - labelPainter.height - 2));
    }

    if (points.length < 2) {
      final dotColor = weightGoal != null
          ? Color.lerp(const Color(0xFFEF4444), const Color(0xFF4ADE80), 1.0 - ((weights.first - weightGoal!).abs() / effectiveRange).clamp(0.0, 1.0))!
          : AppColors.primary;
      canvas.drawLine(Offset(0, points.first.dy), Offset(size.width, points.first.dy), Paint()..color = dotColor.withValues(alpha: 0.2)..strokeWidth = 1.5);
      canvas.drawCircle(points.first, 6, Paint()..color = dotColor);
      canvas.drawCircle(points.first, 3, Paint()..color = Colors.white);
      if (touchPoint != null) {
        _drawTooltip(canvas, size, points.first, '${weights.first.toStringAsFixed(1)} kg', textColor: dotColor);
      }
      return;
    }

    // Smooth fill
    final fillPath = _smoothFillPath(points, size.height);
    final lastDist = weightGoal != null ? (weights.last - weightGoal!).abs() : double.infinity;
    final firstDist = weightGoal != null ? (weights.first - weightGoal!).abs() : double.infinity;
    final gettingCloser = lastDist < firstDist;
    final fillColor = weightGoal != null ? (gettingCloser ? const Color(0xFF4ADE80) : const Color(0xFFEF4444)) : AppColors.primary;
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [fillColor.withValues(alpha: 0.25), fillColor.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    final maxGoalDist = weightGoal != null ? weights.map((w) => (w - weightGoal!).abs()).reduce((a, b) => a > b ? a : b) : 1.0;

    Color goalColor(double rawCloseness) {
      final closeness = rawCloseness * rawCloseness;
      const red = Color(0xFFDC2626);
      const orange = Color(0xFFF97316);
      const yellow = Color(0xFFFBBF24);
      const green = Color(0xFF22C55E);
      if (closeness < 0.33) return Color.lerp(red, orange, closeness / 0.33)!;
      if (closeness < 0.66) return Color.lerp(orange, yellow, (closeness - 0.33) / 0.33)!;
      return Color.lerp(yellow, green, (closeness - 0.66) / 0.34)!;
    }

    // Smooth colored line — draw using path segments
    for (int i = 0; i < points.length - 1; i++) {
      Color segColor;
      if (weightGoal != null) {
        final dist = ((weights[i] - weightGoal!).abs() + (weights[i + 1] - weightGoal!).abs()) / 2;
        segColor = goalColor(1.0 - (dist / maxGoalDist).clamp(0.0, 1.0));
      } else {
        segColor = AppColors.primary;
      }
      final p0 = points[i]; final p1 = points[i + 1];
      final cpx = (p0.dx + p1.dx) / 2;
      final seg = Path()..moveTo(p0.dx, p0.dy)..cubicTo(cpx, p0.dy, cpx, p1.dy, p1.dx, p1.dy);
      canvas.drawPath(seg, Paint()..color = segColor..strokeWidth = 3.0..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
    }

    // Dots
    for (int i = 0; i < points.length; i++) {
      Color dotColor;
      if (weightGoal != null) {
        dotColor = goalColor(1.0 - ((weights[i] - weightGoal!).abs() / maxGoalDist).clamp(0.0, 1.0));
      } else {
        dotColor = AppColors.primary;
      }
      if (i == points.length - 1) {
        canvas.drawCircle(points[i], 8, Paint()..color = dotColor.withValues(alpha: 0.15)); // glow
        canvas.drawCircle(points[i], 5, Paint()..color = dotColor);
        canvas.drawCircle(points[i], 2.5, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(points[i], 3, Paint()..color = dotColor.withValues(alpha: 0.6));
      }
    }

    // Tooltip on touch
    if (touchPoint != null) {
      final idx = _findNearestPointIndex(points, touchPoint!.dx);
      final pt = points[idx];
      // Vertical line
      final tooltipColor = weightGoal != null
          ? goalColor(1.0 - ((weights[idx] - weightGoal!).abs() / maxGoalDist).clamp(0.0, 1.0))
          : Colors.white;
      canvas.drawLine(Offset(pt.dx, 0), Offset(pt.dx, size.height),
        Paint()..color = tooltipColor.withValues(alpha: 0.2)..strokeWidth = 1);
      // Highlight dot
      canvas.drawCircle(pt, 6, Paint()..color = tooltipColor.withValues(alpha: 0.3));
      final label = idx < labels.length ? labels[idx] : '';
      _drawTooltip(canvas, size, pt, '${weights[idx].toStringAsFixed(1)} kg${label.isNotEmpty ? "\n$label" : ""}', textColor: tooltipColor);
    }
  }

  @override
  bool shouldRepaint(_WeightChartPainter old) => old.touchPoint != touchPoint || old.weights != weights;
}

// ─── Chart Legend Helper ──────────────────────────────────────────

Widget _chartLegend(String label, Color color) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
    ],
  );
}

// ─── Strength Chart Painter (all categories overlaid) ──────────────

class _StrengthChartPainter extends CustomPainter {
  final Map<String, dynamic> categories;
  final Offset? touchPoint;

  _StrengthChartPainter({required this.categories, this.touchPoint});

  @override
  void paint(Canvas canvas, Size size) {
    final categoryColors = {
      'upper_body': const Color(0xFF60A5FA),
      'lower_body': const Color(0xFF4ADE80),
      'cardio': const Color(0xFFF472B6),
    };
    final categoryNames = {'upper_body': 'Upper', 'lower_body': 'Lower', 'cardio': 'Cardio'};

    double minV = 0, maxV = 0;
    int maxPoints = 0;

    final categoryValues = <String, List<double>>{};
    final categoryLabels = <String, List<String>>{};
    for (final entry in categories.entries) {
      final cat = entry.value as Map<String, dynamic>? ?? {};
      final data = (cat['data'] as List<dynamic>?) ?? [];
      final vals = <double>[];
      final lbls = <String>[];
      for (final d in data) {
        if (d is Map<String, dynamic> && d['strength'] != null) {
          final v = (d['strength'] as num).toDouble();
          vals.add(v);
          lbls.add(d['label'] as String? ?? '');
          if (v < minV) minV = v;
          if (v > maxV) maxV = v;
        }
      }
      categoryValues[entry.key] = vals;
      categoryLabels[entry.key] = lbls;
      if (vals.length > maxPoints) maxPoints = vals.length;
    }

    if (maxPoints < 2) {
      final tp = TextPainter(
        text: TextSpan(text: 'Dati insufficienti', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }

    if (minV > 0) minV = 0;
    if (maxV < 0) maxV = 0;
    final range = maxV - minV;
    final effectiveRange = range < 1 ? 1.0 : range;
    final pad = effectiveRange * 0.15;

    double yFor(double v) => size.height - ((v - minV + pad) / (effectiveRange + 2 * pad)) * size.height;

    // Grid lines with Y-axis labels
    final gridPaint = Paint()..color = Colors.white.withValues(alpha: 0.06)..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      // Y label
      final val = maxV + pad - (i / 4) * (effectiveRange + 2 * pad) + minV;
      if (i > 0 && i < 4) {
        final labelTp = TextPainter(
          text: TextSpan(text: '${val.round()}%', style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.25))),
          textDirection: TextDirection.ltr,
        )..layout();
        labelTp.paint(canvas, Offset(2, y - labelTp.height - 1));
      }
    }

    // Zero line (emphasized)
    final zeroY = yFor(0);
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY),
      Paint()..color = Colors.white.withValues(alpha: 0.2)..strokeWidth = 1);
    final zeroTp = TextPainter(
      text: TextSpan(text: '0%', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.35))),
      textDirection: TextDirection.ltr,
    )..layout();
    zeroTp.paint(canvas, Offset(2, zeroY - zeroTp.height - 1));

    // Draw each category with smooth curves
    final allPoints = <String, List<Offset>>{};
    for (final entry in categoryValues.entries) {
      final color = categoryColors[entry.key] ?? Colors.white;
      final vals = entry.value;
      if (vals.length < 2) continue;

      final points = <Offset>[];
      for (int i = 0; i < vals.length; i++) {
        points.add(Offset((i / (vals.length - 1)) * size.width, yFor(vals[i])));
      }
      allPoints[entry.key] = points;

      // Smooth fill
      canvas.drawPath(_smoothFillPath(points, zeroY), Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

      // Smooth line
      canvas.drawPath(_smoothPath(points), Paint()..color = color..strokeWidth = 2.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);

      // Dots
      for (int i = 0; i < points.length; i++) {
        if (i == points.length - 1) {
          canvas.drawCircle(points[i], 7, Paint()..color = color.withValues(alpha: 0.12)); // glow
          canvas.drawCircle(points[i], 4, Paint()..color = color);
          canvas.drawCircle(points[i], 2, Paint()..color = Colors.white);
        } else {
          canvas.drawCircle(points[i], 2.5, Paint()..color = color.withValues(alpha: 0.4));
        }
      }
    }

    // Tooltip on touch
    if (touchPoint != null && allPoints.isNotEmpty) {
      // Find nearest X index based on first category with points
      final firstKey = allPoints.keys.first;
      final refPoints = allPoints[firstKey]!;
      final idx = _findNearestPointIndex(refPoints, touchPoint!.dx);
      final anchorX = refPoints[idx].dx;

      // Vertical line
      canvas.drawLine(Offset(anchorX, 0), Offset(anchorX, size.height),
        Paint()..color = Colors.white.withValues(alpha: 0.25)..strokeWidth = 1);

      // Collect tooltip lines
      final tooltipLines = <(Color, String)>[];
      Offset? topAnchor;
      for (final entry in allPoints.entries) {
        final pts = entry.value;
        final vals = categoryValues[entry.key]!;
        final lbls = categoryLabels[entry.key] ?? [];
        if (idx < pts.length && idx < vals.length) {
          final color = categoryColors[entry.key] ?? Colors.white;
          final name = categoryNames[entry.key] ?? entry.key;
          final label = idx < lbls.length ? lbls[idx] : '';
          tooltipLines.add((color, '$name: ${vals[idx] >= 0 ? "+" : ""}${vals[idx].toStringAsFixed(1)}%'));
          // Highlight dot
          canvas.drawCircle(pts[idx], 5, Paint()..color = color.withValues(alpha: 0.3));
          canvas.drawCircle(pts[idx], 3.5, Paint()..color = color);
          if (topAnchor == null || pts[idx].dy < topAnchor.dy) topAnchor = pts[idx];
        }
      }

      // Add date label
      final firstVals = categoryValues[firstKey]!;
      final firstLbls = categoryLabels[firstKey] ?? [];
      if (idx < firstLbls.length && firstLbls[idx].isNotEmpty) {
        tooltipLines.insert(0, (Colors.white.withValues(alpha: 0.0), firstLbls[idx]));
      }

      if (tooltipLines.isNotEmpty && topAnchor != null) {
        _drawMultiTooltip(canvas, size, Offset(anchorX, topAnchor.dy), tooltipLines);
      }
    }
  }

  @override
  bool shouldRepaint(_StrengthChartPainter old) => old.touchPoint != touchPoint || true;
}

// ─── Mini Line Chart Painter (single category) ──────────────────────

class _MiniLineChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final List<String> labels;
  final Offset? touchPoint;

  _MiniLineChartPainter({required this.values, required this.color, this.labels = const [], this.touchPoint});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    double minV = values.reduce((a, b) => a < b ? a : b);
    double maxV = values.reduce((a, b) => a > b ? a : b);
    if (minV > 0) minV = 0;
    if (maxV < 0) maxV = 0;
    final range = maxV - minV;
    final effectiveRange = range < 1 ? 1.0 : range;
    final pad = effectiveRange * 0.1;

    double yFor(double v) => size.height - ((v - minV + pad) / (effectiveRange + 2 * pad)) * size.height;

    // Zero line
    final zeroY = yFor(0);
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY),
      Paint()..color = Colors.white.withValues(alpha: 0.08)..strokeWidth = 1);

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      points.add(Offset((i / (values.length - 1)) * size.width, yFor(values[i])));
    }

    // Smooth fill
    canvas.drawPath(_smoothFillPath(points, zeroY), Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // Smooth line
    canvas.drawPath(_smoothPath(points), Paint()..color = color..strokeWidth = 2.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);

    // Dots — all points with small dots, last one bigger with glow
    for (int i = 0; i < points.length; i++) {
      if (i == points.length - 1) {
        canvas.drawCircle(points[i], 6, Paint()..color = color.withValues(alpha: 0.12)); // glow
        canvas.drawCircle(points[i], 3.5, Paint()..color = color);
        canvas.drawCircle(points[i], 1.5, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(points[i], 2, Paint()..color = color.withValues(alpha: 0.4));
      }
    }

    // Tooltip on touch
    if (touchPoint != null) {
      final idx = _findNearestPointIndex(points, touchPoint!.dx);
      final pt = points[idx];
      canvas.drawLine(Offset(pt.dx, 0), Offset(pt.dx, size.height),
        Paint()..color = Colors.white.withValues(alpha: 0.15)..strokeWidth = 1);
      canvas.drawCircle(pt, 5, Paint()..color = color.withValues(alpha: 0.3));
      canvas.drawCircle(pt, 3.5, Paint()..color = color);
      canvas.drawCircle(pt, 1.5, Paint()..color = Colors.white);
      final label = idx < labels.length ? labels[idx] : '';
      final valStr = '${values[idx] >= 0 ? "+" : ""}${values[idx].toStringAsFixed(1)}%';
      _drawTooltip(canvas, size, pt, label.isNotEmpty ? '$label: $valStr' : valStr);
    }
  }

  @override
  bool shouldRepaint(_MiniLineChartPainter old) => old.touchPoint != touchPoint || true;
}

// ─── CO-OP MODAL ─────────────────────────────────────────────────

Future<void> showCoopModal(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CoopModalContent(ref: ref, parentContext: context),
  );
}

class _CoopModalContent extends StatefulWidget {
  final WidgetRef ref;
  final BuildContext parentContext;
  const _CoopModalContent({required this.ref, required this.parentContext});

  @override
  State<_CoopModalContent> createState() => _CoopModalContentState();
}

class _CoopModalContentState extends State<_CoopModalContent> {
  List<dynamic> _friends = [];
  bool _loading = true;
  String? _invitingId; // currently inviting this friend
  bool _waiting = false;
  StreamSubscription? _acceptedSub;
  StreamSubscription? _declinedSub;
  StreamSubscription? _failedSub;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _listenWebSocket();
  }

  @override
  void dispose() {
    _acceptedSub?.cancel();
    _declinedSub?.cancel();
    _failedSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final service = widget.ref.read(clientServiceProvider);
      final friends = await service.getFriends();
      if (mounted) setState(() { _friends = friends; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _listenWebSocket() {
    final ws = widget.ref.read(websocketServiceProvider);

    _acceptedSub = ws.coopAccepted.listen((msg) {
      if (!mounted) return;
      final partnerId = msg['partner_id']?.toString() ?? '';
      final partnerName = msg['partner_name']?.toString() ?? '';
      final partnerPic = msg['partner_picture']?.toString();
      widget.ref.read(coopProvider.notifier).setActive(partnerId, partnerName, partnerPic);
      Navigator.pop(context);
      // Navigate to workout with CO-OP params via GoRouter
      final params = 'partner_id=$partnerId&partner_name=${Uri.encodeComponent(partnerName)}'
          '${partnerPic != null ? '&partner_picture=${Uri.encodeComponent(partnerPic)}' : ''}';
      GoRouter.of(widget.parentContext).go('/workouts?$params');
    });

    _declinedSub = ws.coopDeclined.listen((msg) {
      if (!mounted) return;
      final name = msg['partner_name']?.toString() ?? 'Amico';
      setState(() { _waiting = false; _invitingId = null; });
      showSnack(context, '$name ha rifiutato l\'invito');
    });

    _failedSub = ws.coopInviteFailed.listen((msg) {
      if (!mounted) return;
      setState(() { _waiting = false; _invitingId = null; });
      showSnack(context, msg['reason']?.toString() ?? 'Amico non disponibile');
    });
  }

  void _inviteFriend(Map<String, dynamic> friend) {
    final id = friend['id']?.toString() ?? '';
    final ws = widget.ref.read(websocketServiceProvider);
    ws.sendCoopInvite(id);
    widget.ref.read(coopProvider.notifier).setInviting(id);
    setState(() { _invitingId = id; _waiting = true; });
  }

  void _cancelInvite() {
    widget.ref.read(coopProvider.notifier).reset();
    setState(() { _invitingId = null; _waiting = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.textTertiary, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_rounded, color: const Color(0xFF7C3AED), size: 22),
              const SizedBox(width: 8),
              const Text('CO-OP Workout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Scegli un amico con cui allenarti', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 8),
          // Info pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Vi allenate in 2, segna 1 e viene salvato per entrambi!',
              style: TextStyle(fontSize: 11, color: Color(0xFF7C3AED)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(strokeWidth: 2))
          else if (_waiting)
            _buildWaitingState()
          else if (_friends.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.person_off_rounded, size: 40, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text('Nessun amico trovato', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Aggiungi amici dalla classifica!', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _friends.length,
                itemBuilder: (_, i) => _friendCard(_friends[i] as Map<String, dynamic>),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWaitingState() {
    final friend = _friends.firstWhere(
      (f) => (f as Map)['id']?.toString() == _invitingId,
      orElse: () => <String, dynamic>{},
    ) as Map<String, dynamic>;
    final name = friend['name']?.toString() ?? friend['username']?.toString() ?? 'Amico';
    final pic = friend['profile_picture']?.toString();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.2),
            backgroundImage: pic != null ? NetworkImage(pic.startsWith('http') ? pic : '${ApiConfig.baseUrl}$pic') : null,
            child: pic == null ? const Icon(Icons.person, size: 36, color: Color(0xFF7C3AED)) : null,
          ),
          const SizedBox(height: 12),
          Text('Invito inviato a $name', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED))),
          const SizedBox(height: 8),
          Text('In attesa di risposta...', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _cancelInvite,
            child: const Text('Annulla', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Widget _friendCard(Map<String, dynamic> friend) {
    final name = friend['name']?.toString() ?? friend['username']?.toString() ?? '';
    final pic = friend['profile_picture']?.toString();
    final gems = friend['gems'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.2),
              backgroundImage: pic != null ? NetworkImage(pic.startsWith('http') ? pic : '${ApiConfig.baseUrl}$pic') : null,
              child: pic == null ? const Icon(Icons.person, size: 20, color: Color(0xFF7C3AED)) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Row(
                    children: [
                      const Icon(Icons.diamond_outlined, size: 12, color: Color(0xFFFACC15)),
                      const SizedBox(width: 4),
                      Text('$gems', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _inviteFriend(friend),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Invita', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FULL-SCREEN PHOTO VIEWER ────────────────────────────────────

class _PhotoViewerPage extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int initialIndex;
  final String Function(String?) resolveUrl;
  final Animation<double> animation;

  const _PhotoViewerPage({
    required this.photos,
    required this.initialIndex,
    required this.resolveUrl,
    required this.animation,
  });

  @override
  State<_PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<_PhotoViewerPage> {
  late PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.black.withValues(alpha: widget.animation.value),
          body: child,
        );
      },
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) {
              final url = widget.resolveUrl(widget.photos[i]['photo_url'] as String?);
              final heroTag = 'progress_photo_$i';
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Hero(
                    tag: heroTag,
                    child: url.isNotEmpty
                        ? Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
                          )
                        : const Icon(Icons.image_rounded, color: Colors.white38, size: 48),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: FadeTransition(
              opacity: widget.animation,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  Text(
                    widget.photos[_current]['photo_date'] as String? ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
            ),
          ),
          if (widget.photos.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.photos.length, (i) {
                  return Container(
                    width: i == _current ? 20 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _current ? AppColors.primary : Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ─── BOOKING APPOINTMENT SHEET ──────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════

Future<void> showBookAppointmentSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => _BookAppointmentContent(
        scrollController: scrollController,
        ref: ref,
      ),
    ),
  );
}

class _BookAppointmentContent extends StatefulWidget {
  final ScrollController scrollController;
  final WidgetRef ref;

  const _BookAppointmentContent({required this.scrollController, required this.ref});

  @override
  State<_BookAppointmentContent> createState() => _BookAppointmentContentState();
}

class _BookAppointmentContentState extends State<_BookAppointmentContent> {
  List<Map<String, dynamic>> _trainers = [];
  bool _loadingTrainers = true;
  bool _trainerListExpanded = false;

  // Selected trainer
  int? _selectedTrainerId;
  String? _selectedTrainerName;
  String? _selectedTrainerPicture;
  double? _trainerSessionRate;

  // Form
  DateTime? _selectedDate;
  String? _selectedTime;
  int _duration = 60;
  final _notesController = TextEditingController();

  // Slots
  List<Map<String, dynamic>> _availableSlots = [];
  bool _loadingSlots = false;

  // Payment
  String? _paymentMethod; // 'cash' or 'pos'

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadTrainers();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadTrainers() async {
    try {
      final service = widget.ref.read(clientServiceProvider);
      final data = await service.getGymTrainers();
      if (mounted) {
        setState(() {
          _trainers = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loadingTrainers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingTrainers = false);
    }
  }

  Future<void> _selectTrainer(Map<String, dynamic> trainer) async {
    final id = trainer['id'];
    final trainerId = id is int ? id : int.tryParse(id.toString()) ?? 0;
    final name = trainer['name']?.toString() ?? trainer['username']?.toString() ?? '';
    final pic = trainer['profile_picture']?.toString();

    setState(() {
      _selectedTrainerId = trainerId;
      _selectedTrainerName = name;
      _selectedTrainerPicture = pic;
      _trainerListExpanded = false;
      _trainerSessionRate = null;
      _paymentMethod = null;
      _selectedTime = null;
      _availableSlots = [];
    });

    // Fetch session rate
    try {
      final service = widget.ref.read(clientServiceProvider);
      final rateData = await service.getTrainerSessionRate(trainerId);
      if (mounted) {
        final rate = rateData['session_rate'];
        setState(() {
          _trainerSessionRate = rate != null ? (rate as num).toDouble() : null;
        });
      }
    } catch (_) {}

    // If date already selected, fetch slots
    if (_selectedDate != null) {
      _loadAvailableSlots();
    }
  }

  Future<void> _loadAvailableSlots() async {
    if (_selectedTrainerId == null || _selectedDate == null) return;

    setState(() { _loadingSlots = true; _selectedTime = null; });

    try {
      final service = widget.ref.read(clientServiceProvider);
      final dateStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
      final data = await service.getTrainerAvailableSlots(_selectedTrainerId!, dateStr);
      if (mounted) {
        setState(() {
          _availableSlots = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loadingSlots = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loadingSlots = false; });
    }
  }

  double get _sessionPrice {
    if (_trainerSessionRate == null || _trainerSessionRate == 0) return 0;
    return _trainerSessionRate! * (_duration / 60);
  }

  bool get _isFreeSession => _trainerSessionRate == null || _trainerSessionRate == 0;

  Future<void> _confirmBooking() async {
    // Validation
    if (_selectedTrainerId == null) {
      showSnack(context, 'Seleziona un trainer', isError: true);
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      showSnack(context, 'Seleziona data e orario', isError: true);
      return;
    }
    if (!_isFreeSession && _paymentMethod == null) {
      showSnack(context, 'Seleziona un metodo di pagamento', isError: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      final service = widget.ref.read(clientServiceProvider);
      final dateStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

      await service.bookAppointment({
        'trainer_id': _selectedTrainerId,
        'date': dateStr,
        'start_time': _selectedTime,
        'duration': _duration,
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
        'payment_method': _isFreeSession ? null : _paymentMethod,
      });

      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'Appuntamento prenotato con $_selectedTrainerName!');
        // Refresh appointments list
        widget.ref.invalidate(appointmentsProvider);
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Impossibile prenotare: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          _sheetTitle('Prenota Appuntamento'),
          Expanded(
            child: _loadingTrainers
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _trainers.isEmpty
                    ? _emptyState('Nessun trainer disponibile', Icons.person_off_rounded)
                    : ListView(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          // 1. Trainer Selector
                          _buildTrainerSelector(),
                          const SizedBox(height: 16),

                          // 2. Date Picker
                          _buildLabel('Data'),
                          const SizedBox(height: 6),
                          _buildDatePicker(),
                          const SizedBox(height: 16),

                          // 3. Time Slot Selector
                          _buildLabel('Orario'),
                          const SizedBox(height: 6),
                          _buildTimeSelector(),
                          const SizedBox(height: 16),

                          // 4. Duration
                          _buildLabel('Durata'),
                          const SizedBox(height: 6),
                          _buildDurationSelector(),
                          const SizedBox(height: 16),

                          // 5. Notes
                          _buildLabel('Note (Facoltativo)'),
                          const SizedBox(height: 6),
                          _buildNotesField(),
                          const SizedBox(height: 16),

                          // 6. Payment Section (if trainer has rate)
                          if (_selectedTrainerId != null && !_isFreeSession) ...[
                            _buildPaymentSection(),
                            const SizedBox(height: 16),
                          ],

                          // 6b. Free session indicator
                          if (_selectedTrainerId != null && _isFreeSession && _trainerSessionRate != null)
                            _buildFreeSessionBadge(),
                          if (_selectedTrainerId != null && _isFreeSession && _trainerSessionRate != null)
                            const SizedBox(height: 16),

                          // 7. Submit Button
                          _buildSubmitButton(),
                          const SizedBox(height: 16),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // ── TRAINER SELECTOR ────────────────────────────────────────────

  Widget _buildTrainerSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Collapsed view
        GestureDetector(
          onTap: () => setState(() => _trainerListExpanded = !_trainerListExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                  child: _selectedTrainerPicture != null
                      ? ClipOval(
                          child: Image.network(
                            _selectedTrainerPicture!.startsWith('http')
                                ? _selectedTrainerPicture!
                                : '${ApiConfig.baseUrl}$_selectedTrainerPicture',
                            width: 36, height: 36, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 18, color: AppColors.primary),
                          ),
                        )
                      : const Icon(Icons.person, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                // Name + status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedTrainerName ?? 'Scegli un trainer...',
                        style: TextStyle(
                          color: _selectedTrainerName != null ? Colors.white : AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      if (_selectedTrainerName != null)
                        const Text(
                          'Selezionato',
                          style: TextStyle(fontSize: 10, color: AppColors.primary),
                        ),
                    ],
                  ),
                ),
                // Chevron
                AnimatedRotation(
                  turns: _trainerListExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Expanded list
        if (_trainerListExpanded) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _trainers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) => _buildTrainerItem(_trainers[i]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTrainerItem(Map<String, dynamic> trainer) {
    final id = trainer['id'];
    final trainerId = id is int ? id : int.tryParse(id.toString()) ?? 0;
    final isSelected = _selectedTrainerId == trainerId;
    final name = trainer['name']?.toString() ?? trainer['username']?.toString() ?? '';
    final pic = trainer['profile_picture']?.toString();
    final rate = trainer['session_rate'];

    return GestureDetector(
      onTap: () => _selectTrainer(trainer),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
              child: pic != null
                  ? ClipOval(
                      child: Image.network(
                        pic.startsWith('http') ? pic : '${ApiConfig.baseUrl}$pic',
                        width: 44, height: 44, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 22, color: AppColors.primary),
                      ),
                    )
                  : const Icon(Icons.person, size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(
                    rate != null && (rate as num) > 0
                        ? '${(rate as num).toStringAsFixed(0)}\u20AC/ora'
                        : 'Disponibile per prenotazioni',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF3B82F6).withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  // ── LABEL ───────────────────────────────────────────────────────

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey[400],
      ),
    );
  }

  // ── DATE PICKER ─────────────────────────────────────────────────

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 90)),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: Color(0xFF252525),
                onSurface: Colors.white,
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null && mounted) {
          setState(() => _selectedDate = picked);
          _loadAvailableSlots();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 10),
            Text(
              _selectedDate != null
                  ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
                  : 'Seleziona una data...',
              style: TextStyle(
                color: _selectedDate != null ? Colors.white : AppColors.textTertiary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TIME SELECTOR ───────────────────────────────────────────────

  Widget _buildTimeSelector() {
    if (_selectedTrainerId == null || _selectedDate == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Seleziona prima trainer e data',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      );
    }

    if (_loadingSlots) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          ),
        ),
      );
    }

    if (_availableSlots.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Nessun orario disponibile',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
        ),
      );
    }

    // Show time slots as a wrap of chips
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableSlots.where((s) => s['available'] == true).map((slot) {
        final time = slot['start_time']?.toString() ?? '';
        final isSelected = _selectedTime == time;

        return GestureDetector(
          onTap: () => setState(() => _selectedTime = time),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : const Color(0xFF252525),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              time,
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.white,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── DURATION SELECTOR ───────────────────────────────────────────

  Widget _buildDurationSelector() {
    const durations = [
      {'value': 30, 'label': '30 min'},
      {'value': 60, 'label': '1 ora'},
      {'value': 90, 'label': '1.5 ore'},
      {'value': 120, 'label': '2 ore'},
    ];

    return Row(
      children: durations.map((d) {
        final val = d['value'] as int;
        final label = d['label'] as String;
        final isSelected = _duration == val;

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _duration = val),
            child: Container(
              margin: EdgeInsets.only(right: d != durations.last ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : const Color(0xFF252525),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : Colors.white,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── NOTES ───────────────────────────────────────────────────────

  Widget _buildNotesField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _notesController,
        maxLines: 3,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Su cosa vorresti concentrarti in questa sessione?',
          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  // ── PAYMENT SECTION ─────────────────────────────────────────────

  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Pagamento'),
        const SizedBox(height: 6),

        // Price display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF252525),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Prezzo Sessione',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
              ),
              Text(
                '\u20AC${_sessionPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Payment method buttons
        Row(
          children: [
            // Cash
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _paymentMethod = 'cash'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _paymentMethod == 'cash'
                        ? AppColors.success.withValues(alpha: 0.2)
                        : const Color(0xFF252525),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _paymentMethod == 'cash'
                          ? AppColors.success
                          : Colors.white.withValues(alpha: 0.1),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 22,
                        color: _paymentMethod == 'cash' ? AppColors.success : Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contanti',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _paymentMethod == 'cash' ? AppColors.success : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // POS
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _paymentMethod = 'pos'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _paymentMethod == 'pos'
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : const Color(0xFF252525),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _paymentMethod == 'pos'
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.1),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.contactless_rounded,
                        size: 22,
                        color: _paymentMethod == 'pos' ? AppColors.primary : Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'POS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _paymentMethod == 'pos' ? AppColors.primary : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Info message based on payment method
        if (_paymentMethod == 'cash')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
            ),
            child: const Center(
              child: Text(
                'Paga in contanti in palestra prima della sessione',
                style: TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (_paymentMethod == 'pos')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                'Paga con carta al POS in palestra',
                style: TextStyle(color: AppColors.primary.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // ── FREE SESSION BADGE ──────────────────────────────────────────

  Widget _buildFreeSessionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: const Column(
        children: [
          Text('\u2713', style: TextStyle(fontSize: 18, color: Color(0xFF4ADE80))),
          SizedBox(height: 2),
          Text(
            'Sessione Gratuita',
            style: TextStyle(color: Color(0xFF4ADE80), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── SUBMIT BUTTON ───────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _submitting ? null : _confirmBooking,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFFEA580C)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: _submitting
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  'Prenota Appuntamento',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
        ),
      ),
    );
  }
}
