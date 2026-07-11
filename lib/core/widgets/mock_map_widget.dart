import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../../models/models.dart';

class MockMapWidget extends StatefulWidget {
  final TripStatus? status;
  final bool showRoute;
  final bool animateCar;

  const MockMapWidget({
    super.key,
    this.status,
    this.showRoute = false,
    this.animateCar = false,
  });

  @override
  State<MockMapWidget> createState() => _MockMapWidgetState();
}

class _MockMapWidgetState extends State<MockMapWidget> with SingleTickerProviderStateMixin {
  late AnimationController _carController;
  late Animation<double> _carAnimation;

  @override
  void initState() {
    super.initState();
    _carController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );

    _carAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _carController, curve: Curves.easeInOut),
    );

    if (widget.animateCar) {
      _carController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MockMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateCar != oldWidget.animateCar) {
      if (widget.animateCar) {
        _carController.repeat();
      } else {
        _carController.stop();
      }
    }
  }

  @override
  void dispose() {
    _carController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE2E8F0), // Map canvas background
      child: Stack(
        children: [
          // City Blocks Grids
          _buildMapGridBlock(50, 40, 100, 80),
          _buildMapGridBlock(180, 20, 90, 120),
          _buildMapGridBlock(30, 220, 140, 90),
          _buildMapGridBlock(200, 240, 110, 140),
          _buildMapGridBlock(330, 60, 120, 100),
          _buildMapGridBlock(430, 200, 100, 80),
          _buildMapGridBlock(490, 30, 120, 100),
          
          // Streets / Roads (Lines)
          _buildRoadLine(0, 150, double.infinity, 24, true), // Main horizontal road
          _buildRoadLine(160, 0, 24, double.infinity, false), // Main vertical road
          _buildRoadLine(0, 320, double.infinity, 16, true), // Secondary horizontal road
          _buildRoadLine(300, 0, 16, double.infinity, false), // Secondary vertical road
          
          // Show simulated trip route if requested
          if (widget.showRoute) ...[
            // Draw path line from Pickup (100, 220) to Destination (250, 80)
            CustomPaint(
              size: Size.infinite,
              painter: RoutePainter(),
            ),
            
            // Pickup Marker
            const Positioned(
              left: 100 - 15,
              top: 220 - 30,
              child: Tooltip(
                message: 'موقع الانطلاق',
                child: Icon(
                  Icons.location_pin,
                  color: AppColors.success,
                  size: 36,
                ),
              ),
            ),
            
            // Destination Marker
            const Positioned(
              left: 250 - 15,
              top: 80 - 30,
              child: Tooltip(
                message: 'الوجهة',
                child: Icon(
                  Icons.location_pin,
                  color: AppColors.error,
                  size: 36,
                ),
              ),
            ),
            
            // Animated taxi icon representing driver location
            AnimatedBuilder(
              animation: _carAnimation,
              builder: (context, child) {
                // Calculate position along route path
                double t = _carAnimation.value;
                
                // Route changes shape based on status
                double x = 100.0;
                double y = 220.0;
                
                if (widget.status == TripStatus.accepted || widget.status == TripStatus.enRoute) {
                  // Captain en-route to pickup (Start far away and move to pickup (100, 220))
                  x = 350.0 - (250.0 * t);
                  y = 150.0 + (70.0 * t);
                } else if (widget.status == TripStatus.started) {
                  // Trip in progress: move from pickup (100, 220) to destination (250, 80)
                  x = 100.0 + (150.0 * t);
                  y = 220.0 - (140.0 * t);
                } else if (widget.status == TripStatus.arrived) {
                  // Parked at pickup
                  x = 100;
                  y = 220;
                } else {
                  // Static position near pickup
                  x = 105;
                  y = 210;
                }
                
                return Positioned(
                  left: x - 14,
                  top: y - 14,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.local_taxi_rounded,
                      color: AppColors.darkText,
                      size: 16,
                    ),
                  ),
                );
              },
            ),
          ],
          
          // Standard map UI elements (Compass, zoom buttons)
          Positioned(
            left: 20,
            top: 100,
            child: Column(
              children: [
                _buildMapButton(Icons.add, () {}),
                const SizedBox(height: 8),
                _buildMapButton(Icons.remove, () {}),
                const SizedBox(height: 8),
                _buildMapButton(Icons.my_location, () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapGridBlock(double left, double top, double w, double h) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildRoadLine(double left, double top, double w, double h, bool isHorizontal) {
    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: Container(
        color: const Color(0xFFF1F5F9),
        child: isHorizontal
            ? CustomPaint(painter: DashLinePainter(isHorizontal: true))
            : CustomPaint(painter: DashLinePainter(isHorizontal: false)),
      ),
    );
  }

  Widget _buildMapButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.darkText, size: 20),
        onPressed: onTap,
      ),
    );
  }
}

class DashLinePainter extends CustomPainter {
  final bool isHorizontal;
  DashLinePainter({required this.isHorizontal});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw central dashed line
    final dashPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    double maxExtent = isHorizontal ? size.width : size.height;
    double dashWidth = 8;
    double dashSpace = 8;
    double start = 0;
    
    while (start < maxExtent) {
      if (isHorizontal) {
        canvas.drawLine(
          Offset(start, size.height / 2),
          Offset(start + dashWidth, size.height / 2),
          dashPaint,
        );
      } else {
        canvas.drawLine(
          Offset(size.width / 2, start),
          Offset(size.width / 2, start + dashWidth),
          dashPaint,
        );
      }
      start += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.8)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(100, 220)  // Pickup
      ..lineTo(160, 220)  // To vertical street junction
      ..lineTo(160, 80)   // Drive north along vertical street
      ..lineTo(250, 80);  // To Destination

    canvas.drawPath(path, paint);
    
    // Overlay thin bright path line
    final innerPaint = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
      
    canvas.drawPath(path, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
