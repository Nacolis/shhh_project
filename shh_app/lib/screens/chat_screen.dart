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

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
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
                child: Column(
                  children: [
                    _buildHeader(),

                    const CyberStatusBar(),

                    Expanded(
                      child: messages.isEmpty
                          ? _buildEmptyChat()
                          : _buildMessageList(messages, provider),
                    ),

                    MessageInput(onSend: _sendMessage, isLoading: _isSending),
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

          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(
                color: widget.conversation.isGroup
                    ? AppColors.hotPink
                    : AppColors.neonGreen,
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                widget.conversation.isGroup ? Icons.group : Icons.person,
                color: widget.conversation.isGroup
                    ? AppColors.hotPink
                    : AppColors.neonGreen,
                size: 20,
              ),
            ),
          ),
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
              child: Row(
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
            ),
          ],
        ),
      ),
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
    _scrollController.dispose();
    super.dispose();
  }
}
