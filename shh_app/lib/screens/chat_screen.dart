import 'dart:math';
import 'safety_number_screen.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../widgets/widgets.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _isRefreshing = false;
  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadMessages(widget.conversation.id);
    });
  }

  Future<void> _sendMessage(String content) async {
    if (_isSending) return;

    setState(() => _isSending = true);

    final provider = context.read<AppProvider>();
    await provider.sendMessage(
      widget.conversation.id,
      content,
      isGroup: widget.conversation.isGroup,
    );

    setState(() => _isSending = false);

    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final messages = provider.getMessages(widget.conversation.id);

          return ScanlineOverlay(
            child: NoiseOverlay(
              opacity: 0.02,
              child: SafeArea(
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildBackgroundPattern()),
                    Column(
                      children: [
                        _buildHeader(),

                        const CyberStatusBar(),

                        Expanded(
                          child: messages.isEmpty
                              ? _buildEmptyChat()
                              : _buildMessageList(messages, provider),
                        ),

                        MessageInput(
                          onSend: _sendMessage,
                          isLoading: _isSending,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          CyberIconButton(
            icon: Icons.arrow_back,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          _buildConversationAvatar(),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (widget.conversation.isGroup)
                      Text(
                        '#',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.hotPink,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        widget.conversation.name,
                        style: AppTextStyles.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.conversation.isGroup
                      ? '${widget.conversation.members?.length ?? 0} MEMBERS'
                      : '@${widget.conversation.id}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          _isRefreshing
              ? const SizedBox(
                  width: 36,
                  height: 36,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.neonGreen,
                    ),
                  ),
                )
              : CyberIconButton(
                  icon: Icons.refresh,
                  onPressed: () async {
                    setState(() => _isRefreshing = true);
                    final provider = context.read<AppProvider>();
                    try {
                      await provider.fetchMessages();
                      await provider.loadMessages(widget.conversation.id);

                      _scrollToBottom();
                    } finally {
                      if (mounted) setState(() => _isRefreshing = false);
                    }
                  },
                ),
          const SizedBox(width: 8),
          CyberIconButton(
            icon: Icons.info_outline,
            onPressed: () => _showConversationInfo(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Icon(
                widget.conversation.isGroup ? Icons.group : Icons.lock,
                size: 64,
                color: AppColors.neonGreen.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ENCRYPTED_CHANNEL_READY',
              style: AppTextStyles.headlineSmall.copyWith(
                color: AppColors.neonGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '// All messages are end-to-end encrypted',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield, size: 14, color: AppColors.neonGreen),
                const SizedBox(width: 8),
                Text(
                  'RSA-2048 + AES-256-GCM',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.neonGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const TypewriterText(
              text: '> Send your first encrypted message...',
              showCursor: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(List<Message> messages, AppProvider provider) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isSent = message.senderId == provider.currentUser?.uniqueUsername;

        final showDateSeparator =
            index == 0 ||
            !_isSameDay(message.timestamp, messages[index - 1].timestamp);

        return Column(
          children: [
            if (showDateSeparator) _buildDateSeparator(message.timestamp),
            MessageBubble(
              content: message.decryptedContent ?? '[ENCRYPTED]',
              isSent: isSent,
              timestamp: message.timestamp,
              status: message.status.name,
              senderName: widget.conversation.isGroup && !isSent
                  ? message.senderId
                  : null,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate == today) {
      dateText = 'TODAY';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      dateText = 'YESTERDAY';
    } else {
      dateText =
          '${date.day.toString().padLeft(2, '0')}.'
          '${date.month.toString().padLeft(2, '0')}.'
          '${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: AppColors.borderColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '// $dateText',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: AppColors.borderColor)),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildBackgroundPattern() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          return CustomPaint(
            painter: _SnakeSkinPainter(progress: _bgController.value),
          );
        },
      ),
    );
  }

  void _showConversationInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.neonGreen, width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.conversation.isGroup ? Icons.group : Icons.person,
                  color: AppColors.neonGreen,
                ),
                const SizedBox(width: 12),
                Text('CONVERSATION_INFO', style: AppTextStyles.headlineSmall),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoRow('NAME', widget.conversation.name),
            _buildInfoRow('ID', widget.conversation.id),
            _buildInfoRow(
              'TYPE',
              widget.conversation.isGroup ? 'GROUP' : 'DIRECT_MESSAGE',
            ),
            if (widget.conversation.members != null)
              _buildInfoRow('MEMBERS', widget.conversation.members!.join(', ')),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(
                  color: AppColors.neonGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user,
                        color: AppColors.neonGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'END-TO-END ENCRYPTED',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.neonGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!widget.conversation.isGroup) ...[
                    const Divider(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.neonGreen.withOpacity(0.1),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(
                          Icons.fingerprint,
                          color: AppColors.neonGreen,
                        ),
                        label: const Text(
                          'VERIFY IDENTITY',
                          style: TextStyle(
                            color: AppColors.neonGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(context); // Close bottom sheet
                          final provider = context.read<AppProvider>();
                          if (provider.currentUser == null) return;

                          final contact = await provider.getContact(
                            widget.conversation.id,
                          ); // id is username in DM

                          if (contact != null &&
                              contact.dhPublicKey != null &&
                              provider.currentUser!.dhPublicKey != null) {
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SafetyNumberScreen(
                                    myIdentityKey:
                                        provider.currentUser!.dhPublicKey! +
                                        (provider.currentUser!.rsaPublicKey ??
                                            ''),
                                    theirIdentityKey:
                                        contact.dhPublicKey! +
                                        (contact.rsaPublicKey ?? ''),
                                    remoteUsername: contact.username,
                                  ),
                                ),
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Unabled to load keys for verification',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatarImage() {
    return Image.asset('assets/profil.png', fit: BoxFit.cover);
  }

  Widget _buildConversationAvatar() {
    final borderColor = widget.conversation.isGroup
        ? AppColors.hotPink
        : AppColors.neonGreen;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: borderColor, width: 2),
      ),
      clipBehavior: Clip.hardEdge,
      child:
          widget.conversation.avatarUrl != null &&
              widget.conversation.avatarUrl!.isNotEmpty
          ? Image.network(
              widget.conversation.avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildDefaultAvatarImage(),
            )
          : _buildDefaultAvatarImage(),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _SnakeSkinPainter extends CustomPainter {
  final double progress;

  const _SnakeSkinPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final phase = progress * 2 * pi;
    const double cell = 22;
    const double gap = 12;

    for (double y = -cell; y < size.height + cell; y += cell + gap) {
      for (double x = -cell; x < size.width + cell; x += cell + gap) {
        final wave = sin((x * 0.08) + (y * 0.08) + phase);
        final opacity = 0.02 + (max(0, wave) * 0.07);
        if (opacity < 0.025) continue;

        paint.color = AppColors.neonGreen.withValues(alpha: opacity);
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SnakeSkinPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
