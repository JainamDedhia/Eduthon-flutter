// FILE: lib/widgets/chatbot_bubble.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ChatbotBubble extends StatefulWidget {
  final VoidCallback onTap;
  final bool showBadge;
  final bool isOnline;

  const ChatbotBubble({
    super.key,
    required this.onTap,
    this.showBadge = false,
    this.isOnline = true,
  });

  @override
  State<ChatbotBubble> createState() => _ChatbotBubbleState();
}

class _ChatbotBubbleState extends State<ChatbotBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Start pulsing animation if badge is shown
    if (widget.showBadge) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ChatbotBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showBadge && !oldWidget.showBadge) {
      _animationController.repeat(reverse: true);
    } else if (!widget.showBadge && oldWidget.showBadge) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primaryDark,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main icon
            Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: widget.showBadge ? _scaleAnimation.value : 1.0,
                    child: Transform.rotate(
                      angle: widget.showBadge ? _rotationAnimation.value : 0.0,
                      child: Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Badge indicator
            if (widget.showBadge)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            // Online/Offline indicator
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: widget.isOnline ? AppColors.success : AppColors.warning,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
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

