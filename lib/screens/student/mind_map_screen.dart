// FILE: lib/screens/student/mind_map_screen.dart
import 'package:flutter/material.dart';
import 'package:claudetest/services/mind_map_generator.dart';

class MindMapScreen extends StatefulWidget {
  final MindMapNode mindMap;
  final String fileName;

  const MindMapScreen({
    super.key,
    required this.mindMap,
    required this.fileName,
  });

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> {
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _previousOffset = Offset.zero;
  final double _minScale = 0.5;
  final double _maxScale = 3.0;

  @override
  void initState() {
    super.initState();
    // Delay to ensure proper layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          // Reset to center on load
          _offset = Offset.zero;
          _scale = 1.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: GestureDetector(
        onScaleStart: (details) {
          _previousScale = _scale;
          _previousOffset = details.focalPoint;
        },
        onScaleUpdate: (details) {
          setState(() {
            _scale = (_previousScale * details.scale).clamp(_minScale, _maxScale);
            
            // Calculate panning
            final currentFocal = details.focalPoint;
            final delta = currentFocal - _previousOffset;
            _offset += delta;
            _previousOffset = currentFocal;
          });
        },
        child: Stack(
          children: [
            // Background grid - FIXED: Full screen
            Positioned.fill(child: _buildGrid()),
            
            // Mind map content - FIXED: Proper centering with Align
            Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: _offset,
                child: Transform.scale(
                  scale: _scale,
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    child: _buildMindMapTree(widget.mindMap),
                  ),
                ),
              ),
            ),

            // Controls
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildControlButton(
                      icon: Icons.zoom_in,
                      onPressed: () => setState(() {
                        _scale = (_scale + 0.2).clamp(_minScale, _maxScale);
                      }),
                    ),
                    _buildControlButton(
                      icon: Icons.zoom_out,
                      onPressed: () => setState(() {
                        _scale = (_scale - 0.2).clamp(_minScale, _maxScale);
                      }),
                    ),
                    _buildControlButton(
                      icon: Icons.center_focus_weak,
                      onPressed: () => setState(() {
                        _scale = 1.0;
                        _offset = Offset.zero;
                      }),
                    ),
                  ],
                ),
              ),
            ),

            // File name indicator
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_tree, size: 16, color: const Color(0xFF4A90E2)),
                    const SizedBox(width: 8),
                    Text(
                      widget.fileName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: CustomPaint(
        painter: _GridPainter(offset: _offset, scale: _scale),
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onPressed}) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Icon(icon, size: 20, color: const Color(0xFF4A90E2)),
        ),
      ),
    );
  }

  Widget _buildMindMapTree(MindMapNode node) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMindMapNode(node),
        if (node.children.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildChildrenConnector(node.level),
          Wrap(
            spacing: 40,
            runSpacing: 40,
            alignment: WrapAlignment.center,
            children: node.children.map((child) => _buildMindMapTree(child)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildChildrenConnector(int level) {
    return Container(
      height: 2,
      width: _nodeChildrenWidth(level),
      color: _getNodeColor(level).withOpacity(0.3),
    );
  }

  double _nodeChildrenWidth(int level) {
    switch (level) {
      case 0: return 300;
      case 1: return 200;
      default: return 150;
    }
  }

  Widget _buildMindMapNode(MindMapNode node) {
    final color = _getNodeColor(node.level);
    final isRoot = node.level == 0;
    
    return GestureDetector(
      onTap: () => _showNodeDetails(node),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: isRoot ? 3 : 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNodeIcon(node),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                node.title,
                style: TextStyle(
                  fontSize: _getNodeFontSize(node.level),
                  fontWeight: isRoot ? FontWeight.bold : FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (node.children.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${node.children.length}',
                  style: const TextStyle(
                    fontSize: 10,
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

  Widget _buildNodeIcon(MindMapNode node) {
    final color = _getNodeColor(node.level);
    final icon = _getNodeIcon(node.level);
    
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  IconData _getNodeIcon(int level) {
    switch (level) {
      case 0: return Icons.center_focus_strong;
      case 1: return Icons.category;
      case 2: return Icons.label_important;
      default: return Icons.label;
    }
  }

  double _getNodeFontSize(int level) {
    switch (level) {
      case 0: return 18.0;
      case 1: return 16.0;
      case 2: return 14.0;
      default: return 12.0;
    }
  }

  Color _getNodeColor(int level) {
    final colors = [
      const Color(0xFF4A90E2), // Blue - Root
      const Color(0xFF66BB6A), // Green - Level 1
      const Color(0xFFFF7043), // Orange - Level 2
      const Color(0xFFAB47BC), // Purple - Level 3
      const Color(0xFF26C6DA), // Cyan - Level 4
    ];
    return colors[level.clamp(0, colors.length - 1)];
  }

  void _showNodeDetails(MindMapNode node) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getNodeIcon(node.level), color: _getNodeColor(node.level)),
            const SizedBox(width: 8),
            const Text('Node Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              node.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getNodeColor(node.level),
              ),
            ),
            const SizedBox(height: 12),
            if (node.children.isNotEmpty)
              Text(
                'Child nodes: ${node.children.length}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            const SizedBox(height: 8),
            Text(
              'Level: ${node.level}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Offset offset;
  final double scale;

  _GridPainter({required this.offset, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    final cellSize = 40.0 * scale; // Increased base size
    
    // Calculate from screen center for better alignment
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // Adjust for offset to keep grid centered relative to mind map
    final startX = centerX - (centerX - offset.dx) % cellSize;
    final startY = centerY - (centerY - offset.dy) % cellSize;

    // Draw vertical lines to the right
    for (double x = startX; x < size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Draw vertical lines to the left
    for (double x = startX - cellSize; x >= 0; x -= cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines downward
    for (double y = startY; y < size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Draw horizontal lines upward
    for (double y = startY - cellSize; y >= 0; y -= cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}