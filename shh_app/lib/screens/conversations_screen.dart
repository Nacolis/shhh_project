import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../providers/app_provider.dart';
import '../widgets/widgets.dart';
import 'chat_screen.dart';
import 'auth_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with SingleTickerProviderStateMixin {
  static const String _asciiLogo = '''
███████╗██╗  ██╗██╗  ██╗██╗  ██╗
██╔════╝██║  ██║██║  ██║██║  ██║
███████╗███████║███████║███████║
╚════██║██╔══██║██╔══██║██╔══██║
███████║██║  ██║██║  ██║██║  ██║
╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝''';

  late final AnimationController _asciiController;
  @override
  void initState() {
    super.initState();
    _asciiController = AnimationController(
      duration: const Duration(seconds: 7),
      vsync: this,
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      provider.loadConversations();
      provider.fetchMessages();
    });
  }

  void _showNewConversationDialog() {
    showDialog(
      context: context,
      builder: (context) => const NewConversationDialog(),
    );
  }

  void _showNewGroupDialog() {
    showDialog(context: context, builder: (context) => const NewGroupDialog());
  }

  Future<void> _logout() async {
    final provider = context.read<AppProvider>();
    await provider.logout();
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  Future<void> _resetApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const ResetConfirmDialog(),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<AppProvider>();
      await provider.resetApp();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      }
    }
  }

  void _showReLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ReLoginDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          if (provider.tokenExpired) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showReLoginDialog();
            });
          }

          return ScanlineOverlay(
            child: NoiseOverlay(
              opacity: 0.02,
              child: SafeArea(
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildAsciiFlicker()),
                    Column(
                      children: [
                        _buildHeader(provider),
                        const CyberStatusBar(),
                        Expanded(
                          child: provider.conversations.isEmpty
                              ? _buildEmptyState()
                              : _buildConversationList(provider),
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
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            'SHHH',
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.neonGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '// ${provider.currentUser?.username ?? 'UNKNOWN'}',
                  style: AppTextStyles.labelMedium,
                ),
                Text(
                  '@${provider.currentUser?.uniqueUsername ?? ''}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.hotPink,
                  ),
                ),
              ],
            ),
          ),
          CyberIconButton(
            icon: Icons.refresh,
            onPressed: () {
              provider.fetchMessages();
              provider.loadConversations();
            },
          ),
          CyberIconButton(
            icon: Icons.delete_forever,
            color: AppColors.error,
            onPressed: _resetApp,
          ),
          CyberIconButton(
            icon: Icons.logout,
            color: AppColors.safetyOrange,
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '''
 ╔══════════════════════════╗
 ║                          ║
 ║    NO_CONVERSATIONS      ║
 ║                          ║
 ║    START_ENCRYPTED_CHAT  ║
 ║                          ║
 ╚══════════════════════════╝''',
              style: AppTextStyles.code.copyWith(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const GlitchText(text: 'INBOX_EMPTY', glitchIntensity: 0.02),
            const SizedBox(height: 16),
            Text(
              '// Press + to start a new secure conversation',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationList(AppProvider provider) {
    return RefreshIndicator(
      color: AppColors.neonGreen,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        await provider.fetchMessages();
        await provider.loadConversations();
      },
      child: ListView.builder(
        itemCount: provider.conversations.length,
        itemBuilder: (context, index) {
          final conversation = provider.conversations[index];
          return ConversationTile(
            name: conversation.name,
            lastMessage: conversation.lastMessage?.decryptedContent,
            timestamp: conversation.lastActivityAt,
            unreadCount: conversation.unreadCount,
            isGroup: conversation.isGroup,
            avatarUrl: conversation.avatarUrl,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(conversation: conversation),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFAB() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'new_group',
          backgroundColor: AppColors.hotPink,
          onPressed: _showNewGroupDialog,
          child: const Icon(Icons.group_add, color: AppColors.background),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'new_dm',
          backgroundColor: AppColors.neonGreen,
          onPressed: _showNewConversationDialog,
          child: const Icon(Icons.add, color: AppColors.background),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _asciiController.dispose();
    super.dispose();
  }

  Widget _buildAsciiFlicker() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _asciiController,
        builder: (context, _) {
          final t = _asciiController.value;
          final pulse = (sin(2 * pi * (t * 3.1)) + 1) * 0.12; // 0..0.24
          final noise = (sin(2 * pi * (t * 7.7 + 0.3)) + 1) * 0.05; // 0..0.10
          final opacity = 0.04 + pulse + noise; // ~0.04..0.38
          final yJitter = sin(2 * pi * (t * 1.3)) * 2;

          return Center(
            child: Transform.translate(
              offset: Offset(0, yJitter),
              child: Opacity(
                opacity: opacity.clamp(0.05, 0.35).toDouble(),
                child: Text(
                  _asciiLogo,
                  style: AppTextStyles.code.copyWith(
                    fontSize: 8,
                    height: 1.0,
                    letterSpacing: 0,
                    color: AppColors.neonGreen.withValues(alpha: 0.95),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class NewConversationDialog extends StatefulWidget {
  const NewConversationDialog({super.key});

  @override
  State<NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<NewConversationDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _startConversation() async {
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = 'UNIQUE_ID_REQUIRED');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final provider = context.read<AppProvider>();
    final conversation = await provider.startConversation(
      _controller.text.trim(),
    );

    if (mounted) {
      if (conversation != null) {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(conversation: conversation),
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _error = provider.error ?? 'USER_NOT_FOUND';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.neonGreen, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_add, color: AppColors.neonGreen),
                const SizedBox(width: 12),
                Text('NEW_SECURE_CHAT', style: AppTextStyles.headlineSmall),
              ],
            ),
            const SizedBox(height: 24),
            CyberTextField(
              label: 'RECIPIENT_UNIQUE_ID',
              hint: 'Enter exact unique ID...',
              controller: _controller,
              autofocus: true,
              prefixIcon: const Icon(
                Icons.fingerprint,
                color: AppColors.neonGreen,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                'ERROR: $_error',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'CANCEL',
                    style: AppTextStyles.button.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CyberButton(
                  text: 'CONNECT',
                  onPressed: _startConversation,
                  isLoading: _isLoading,
                  icon: Icons.link,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class NewGroupDialog extends StatefulWidget {
  const NewGroupDialog({super.key});

  @override
  State<NewGroupDialog> createState() => _NewGroupDialogState();
}

class _NewGroupDialogState extends State<NewGroupDialog> {
  final _nameController = TextEditingController();
  final _memberController = TextEditingController();
  final List<String> _members = [];
  bool _isLoading = false;
  String? _error;

  void _addMember() {
    final member = _memberController.text.trim();
    if (member.isNotEmpty && !_members.contains(member)) {
      setState(() {
        _members.add(member);
        _memberController.clear();
      });
    }
  }

  void _removeMember(String member) {
    setState(() {
      _members.remove(member);
    });
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'GROUP_NAME_REQUIRED');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final provider = context.read<AppProvider>();
    final conversation = await provider.createGroup(
      _nameController.text.trim(),
      _members,
    );

    if (mounted) {
      if (conversation != null) {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(conversation: conversation),
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _error = provider.error ?? 'FAILED_TO_CREATE_GROUP';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.hotPink, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group_add, color: AppColors.hotPink),
                const SizedBox(width: 12),
                Text('CREATE_SECURE_GROUP', style: AppTextStyles.headlineSmall),
              ],
            ),
            const SizedBox(height: 24),
            CyberTextField(
              label: 'GROUP_NAME',
              hint: 'Enter group name...',
              controller: _nameController,
              autofocus: true,
              prefixIcon: const Icon(Icons.tag, color: AppColors.hotPink),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CyberTextField(
                    label: 'ADD_MEMBERS',
                    hint: 'Enter unique ID...',
                    controller: _memberController,
                    prefixIcon: const Icon(
                      Icons.person_add,
                      color: AppColors.hotPink,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CyberIconButton(
                  icon: Icons.add,
                  color: AppColors.hotPink,
                  onPressed: _addMember,
                ),
              ],
            ),
            if (_members.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _members
                    .map(
                      (member) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          border: Border.all(color: AppColors.hotPink),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '@$member',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.hotPink,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _removeMember(member),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                'ERROR: $_error',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'CANCEL',
                    style: AppTextStyles.button.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CyberButton(
                  text: 'CREATE',
                  onPressed: _createGroup,
                  isLoading: _isLoading,
                  icon: Icons.group_add,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _memberController.dispose();
    super.dispose();
  }
}

class ResetConfirmDialog extends StatelessWidget {
  const ResetConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.error, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: AppColors.error),
                const SizedBox(width: 12),
                Text(
                  'FULL_RESET',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '// WARNING: This will permanently delete:',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            _buildDeleteItem('All messages'),
            _buildDeleteItem('All conversations'),
            _buildDeleteItem('RSA & DH keys'),
            _buildDeleteItem('Shared secrets'),
            _buildDeleteItem('Authentication data'),
            const SizedBox(height: 16),
            Text(
              '// This action cannot be undone!',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'CANCEL',
                    style: AppTextStyles.button.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CyberButton(
                  text: 'RESET_ALL',
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: Icons.delete_forever,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.remove, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Text(text, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class ReLoginDialog extends StatefulWidget {
  const ReLoginDialog({super.key});

  @override
  State<ReLoginDialog> createState() => _ReLoginDialogState();
}

class _ReLoginDialogState extends State<ReLoginDialog> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _reLogin() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'PASSWORD_REQUIRED');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final provider = context.read<AppProvider>();
    final success = await provider.reLogin(_passwordController.text);

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
        provider.fetchMessages();
        provider.loadConversations();
      } else {
        setState(() {
          _isLoading = false;
          _error = provider.error ?? 'AUTHENTICATION_FAILED';
        });
      }
    }
  }

  void _logout() {
    final provider = context.read<AppProvider>();
    provider.logout();
    Navigator.of(context).pop();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.safetyOrange, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_clock, color: AppColors.safetyOrange),
                const SizedBox(width: 12),
                Text(
                  'SESSION_EXPIRED',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.safetyOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '// Your session has expired. Please re-enter your password to continue.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'User: @${provider.currentUser?.uniqueUsername ?? 'unknown'}',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.hotPink,
              ),
            ),
            const SizedBox(height: 24),
            CyberTextField(
              label: 'PASSWORD',
              hint: 'Enter your password...',
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              prefixIcon: const Icon(Icons.lock, color: AppColors.neonGreen),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textMuted,
                ),
                onPressed: () {
                  setState(() => _isPasswordVisible = !_isPasswordVisible);
                },
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                'ERROR: $_error',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _logout,
                  child: Text(
                    'LOGOUT',
                    style: AppTextStyles.button.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CyberButton(
                  text: 'LOGIN',
                  onPressed: _reLogin,
                  isLoading: _isLoading,
                  icon: Icons.login,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
