import 'package:flutter/material.dart';

class SafeZoneToolbar extends StatefulWidget {
  final Function(bool)? onMapToggled;
  final Function(bool)? onPanToggled; // Add callback for pan toggle
  final bool initialPanDisabled; // Add initial state
  final VoidCallback? onClosePressed; // Callback for exiting safe zone mode
  final VoidCallback? onSavePressed; // Callback for saving the bounding box

  const SafeZoneToolbar({
    super.key,
    this.onMapToggled,
    this.onPanToggled,
    this.initialPanDisabled = false, // Default to enabled
    this.onClosePressed, // Add this parameter
    this.onSavePressed, // Add this parameter
  });

  @override
  State<SafeZoneToolbar> createState() => _SafeZoneToolbarState();
}

class _SafeZoneToolbarState extends State<SafeZoneToolbar> with SingleTickerProviderStateMixin {
  bool _isMapDisabled = true;
  bool _isPanDisabled = false; // This will be initialized in initState
  bool _isEyeDisabled = false;
  
  // Animation controller and animations
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _isPanDisabled = widget.initialPanDisabled;
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Create animations for width and height
    _heightAnimation = Tween<double>(
      begin: 280, // Full height
      end: 55,   // Collapsed height - just enough for one icon
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _widthAnimation = Tween<double>(
      begin: 55,  // Normal width
      end: 55,    // Same width when collapsed
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Add listener to rebuild UI when animation values change
    _animationController.addListener(() {
      setState(() {});
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Update the toggle method
  void _togglePan() {
    setState(() {
      _isPanDisabled = !_isPanDisabled;
      // When pan is enabled, map must be disabled
      if (!_isPanDisabled) {
        _isMapDisabled = true;
        // Notify parent about map state change
        if (widget.onMapToggled != null) {
          widget.onMapToggled!(_isMapDisabled);
        }
      }
    });

    // Notify parent about pan state change
    if (widget.onPanToggled != null) {
      widget.onPanToggled!(_isPanDisabled);
    }
  }
  
  // Method to toggle eye state with animation
  void _toggleEye() {
    setState(() {
      _isEyeDisabled = !_isEyeDisabled;
      
      // Animate toolbar based on eye state
      if (_isEyeDisabled) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // Calculate if container is mostly expanded or collapsed
        final bool isExpanding = _animationController.status == AnimationStatus.reverse;
        final bool showOtherIcons = isExpanding 
            ? _animationController.value < 0.3  // When expanding, only show when mostly expanded
            : _animationController.value < 0.1; // When collapsing, hide quickly
        
        return Container(
          width: _widthAnimation.value,
          height: _heightAnimation.value,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          // Using Stack and Positioned to avoid layout constraints during animation
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Eye button - always centered/visible
              Positioned.fill(
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _toggleEye,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: Stack(
                            children: [
                              Icon(
                                Icons.remove_red_eye,
                                color: Colors.grey[600],
                                size: 24,
                              ),
                              if (_isEyeDisabled)
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: SlashPainter(
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Other buttons - only visible when expanded enough
              if (!_isEyeDisabled && showOtherIcons)
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Map toggle button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          splashColor: Colors.grey.withOpacity(0.2),
                          highlightColor: Colors.grey.withOpacity(0.1),
                          onTap: () {
                            debugPrint('Map toggle button tapped');
                            setState(() {
                              _isMapDisabled = !_isMapDisabled;
                              if (!_isMapDisabled) {
                                _isPanDisabled = true;
                                if (widget.onPanToggled != null) {
                                  widget.onPanToggled!(_isPanDisabled);
                                }
                              }
                            });
                            if (widget.onMapToggled != null) {
                              widget.onMapToggled!(_isMapDisabled);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: Stack(
                                children: [
                                  Icon(
                                    Icons.map,
                                    color: Colors.grey[600],
                                    size: 24,
                                  ),
                                  if (_isMapDisabled)
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: SlashPainter(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Pan tool toggle button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: _togglePan,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: Stack(
                                children: [
                                  Icon(
                                    Icons.pan_tool_alt,
                                    color: Colors.grey[600],
                                    size: 24,
                                  ),
                                  if (_isPanDisabled)
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: SlashPainter(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Placeholder for eye button (to maintain spacing)
                      const SizedBox(height: 40),
                      
                      // Check button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            debugPrint('Check button pressed');
                            if (widget.onSavePressed != null) {
                              widget.onSavePressed!();
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.check,
                              color: Colors.green,
                              size: 24,
                            ),
                          ),
                        ),
                      ),

                      // Close button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            debugPrint('Close button pressed');
                            if (widget.onClosePressed != null) {
                              widget.onClosePressed!();
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.close,
                              color: Colors.red,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class SlashPainter extends CustomPainter {
  final Color color;

  SlashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.9),
      Offset(size.width * 0.9, size.height * 0.1),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}