import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class CyberTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final bool autofocus;

  const CyberTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.autofocus = false,
  });

  @override
  State<CyberTextField> createState() => _CyberTextFieldState();
}

class _CyberTextFieldState extends State<CyberTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Row(
            children: [
              Text(
                '// ',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.neonGreen,
                ),
              ),
              Text(
                widget.label!.toUpperCase(),
                style: AppTextStyles.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(
              color: _isFocused ? AppColors.neonGreen : AppColors.borderColor,
              width: _isFocused ? 2 : 1,
            ),
          ),
          child: Focus(
            onFocusChange: (focused) => setState(() => _isFocused = focused),
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              validator: widget.validator,
              onChanged: widget.onChanged,
              maxLines: widget.maxLines,
              autofocus: widget.autofocus,
              style: AppTextStyles.bodyMedium,
              cursorColor: AppColors.neonGreen,
              cursorWidth: 3,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTextStyles.inputHint,
                prefixIcon: widget.prefixIcon != null
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: widget.prefixIcon,
                      )
                    : null,
                suffixIcon: widget.suffixIcon,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CyberButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isPrimary;
  final IconData? icon;
  final double? width;

  const CyberButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isPrimary = true,
    this.icon,
    this.width,
  });

  @override
  State<CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<CyberButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? (_isHovered ? AppColors.neonGreen.withValues(alpha: 0.8) : AppColors.neonGreen)
                : Colors.transparent,
            border: Border.all(
              color: widget.isPrimary ? AppColors.neonGreen : AppColors.neonGreen,
              width: 2,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppColors.neonGreen.withValues(alpha: 0.3),
                      blurRadius: 0,
                      offset: const Offset(4, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.isPrimary ? AppColors.background : AppColors.neonGreen,
                  ),
                ),
                const SizedBox(width: 12),
              ] else if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 18,
                  color: widget.isPrimary ? AppColors.background : AppColors.neonGreen,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.text.toUpperCase(),
                style: AppTextStyles.button.copyWith(
                  color: widget.isPrimary ? AppColors.background : AppColors.neonGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CyberIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  const CyberIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size = 24,
  });

  @override
  State<CyberIconButton> createState() => _CyberIconButtonState();
}

class _CyberIconButtonState extends State<CyberIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.neonGreen;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(
              color: _isHovered ? color : Colors.transparent,
              width: 1,
            ),
          ),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: _isHovered ? color : color.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class MessageInput extends StatefulWidget {
  final void Function(String) onSend;
  final bool isLoading;

  const MessageInput({
    super.key,
    required this.onSend,
    this.isLoading = false,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.isLoading) {
      widget.onSend(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.borderColor),
              ),
              child: TextField(
                controller: _controller,
                style: AppTextStyles.bodyMedium,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                decoration: InputDecoration(
                  hintText: 'ENTER_MESSAGE...',
                  hintStyle: AppTextStyles.inputHint,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.neonGreen,
                border: Border.all(color: AppColors.neonGreen, width: 2),
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.background,
                      ),
                    )
                  : const Icon(
                      Icons.send,
                      color: AppColors.background,
                      size: 24,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class ConversationTile extends StatelessWidget {
  final String name;
  final String? lastMessage;
  final DateTime? timestamp;
  final int unreadCount;
  final bool isGroup;
  final String? avatarUrl;
  final VoidCallback? onTap;

  const ConversationTile({
    super.key,
    required this.name,
    this.lastMessage,
    this.timestamp,
    this.unreadCount = 0,
    this.isGroup = false,
    this.avatarUrl,
    this.onTap,
  });

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inDays > 0) {
      return '${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    } else {
      return 'now';
    }
  }

  Widget _buildDefaultAvatar() {
    return Image.asset(
      'assets/profil.png',
      fit: BoxFit.cover,
    );
  }

  Widget _buildAvatar() {
    final borderColor = unreadCount > 0 ? AppColors.neonGreen : AppColors.borderColor;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: borderColor,
          width: unreadCount > 0 ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? Image.network(
              avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
            )
          : _buildDefaultAvatar(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.borderColor, width: 1),
            ),
          ),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isGroup)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              '#',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.hotPink,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            name,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timestamp != null)
                          Text(
                            _formatTime(timestamp!),
                            style: AppTextStyles.timestamp,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage ?? '// NO_MESSAGES',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: lastMessage != null 
                                  ? AppColors.textSecondary 
                                  : AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: const BoxDecoration(
                              color: AppColors.neonGreen,
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.background,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
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

class MessageBubble extends StatelessWidget {
  final String content;
  final bool isSent;
  final DateTime timestamp;
  final String status;
  final String? senderName;

  const MessageBubble({
    super.key,
    required this.content,
    required this.isSent,
    required this.timestamp,
    this.status = 'sent',
    this.senderName,
  });

  IconData _getStatusIcon() {
    switch (status) {
      case 'pending':
        return Icons.access_time;
      case 'sent':
        return Icons.check;
      case 'delivered':
        return Icons.done_all;
      case 'read':
        return Icons.done_all;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.check;
    }
  }

  Color _getStatusColor() {
    switch (status) {
      case 'read':
        return AppColors.neonGreen;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Column(
          crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (senderName != null && !isSent)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  senderName!,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.hotPink,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSent ? AppColors.sentMessage : AppColors.receivedMessage,
                border: Border.all(
                  color: isSent ? AppColors.neonGreen.withValues(alpha: 0.3) : AppColors.borderColor,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content,
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                        style: AppTextStyles.timestamp,
                      ),
                      if (isSent) ...[
                        const SizedBox(width: 4),
                        Icon(
                          _getStatusIcon(),
                          size: 12,
                          color: _getStatusColor(),
                        ),
                      ],
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
}

class CyberStatusBar extends StatelessWidget {
  final bool isConnected;
  final String? statusText;

  const CyberStatusBar({
    super.key,
    this.isConnected = true,
    this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppColors.surface,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isConnected ? AppColors.neonGreen : AppColors.error,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? AppColors.neonGreen : AppColors.error).withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText ?? (isConnected ? 'SECURE_CONNECTION' : 'DISCONNECTED'),
            style: AppTextStyles.labelSmall.copyWith(
              color: isConnected ? AppColors.neonGreen : AppColors.error,
            ),
          ),
          const Spacer(),
          Text(
            'E2E_ENCRYPTED',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
