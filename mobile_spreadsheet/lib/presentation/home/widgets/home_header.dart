import 'package:flutter/material.dart';
import 'dart:async';

class HomeHeader extends StatefulWidget {
  const HomeHeader({super.key});

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_currentPage < 2) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _HeaderClipper(),
      child: Container(
        height: 280,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F32B9),
              Color(0xFF2848D3),
              Color(0xFF5E27D8),
              Color(0xFF8633F5),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white, size: 26),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.search, color: Colors.white, size: 26),
                        const SizedBox(width: 16),
                        Stack(
                          children: [
                            const Icon(Icons.notifications_none, color: Colors.white, size: 26),
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.greenAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Slider Layer (PageView)
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: [
                    _buildSlide(
                      title: 'Sheet',
                      subtitle: 'Smart Spreadsheets,\nBetter productivity ✨',
                      graphicType: 1,
                    ),
                    _buildSlide(
                      title: 'Visualize',
                      subtitle: 'Create stunning charts\nand analyze data 📊',
                      graphicType: 2,
                    ),
                    _buildSlide(
                      title: 'Collaborate',
                      subtitle: 'Work together\nin real-time 🚀',
                      graphicType: 3,
                    ),
                  ],
                ),
              ),
              
              // Pagination Dots - INSIDE the curve
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) => _buildDot(index: index)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide({required String title, required String subtitle, required int graphicType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          _build3DGraphic(graphicType),
        ],
      ),
    );
  }

  Widget _buildDot({required int index}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 6,
      width: _currentPage == index ? 20 : 6,
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.white : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _build3DGraphic(int type) {
    return SizedBox(
      width: 110,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Main Container
          Positioned(
            right: 0,
            top: 5,
            child: Transform.rotate(
              angle: type == 1 ? 0.08 : (type == 2 ? -0.08 : 0.04),
              child: Container(
                width: 85,
                height: 105,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: type == 1 
                      ? _buildGridLines()
                      : (type == 2 ? _buildChartLines() : _buildCollabLines()),
                ),
              ),
            ),
          ),
          
          if (type == 1) ...[
            Positioned(left: 0, top: 15, child: _buildFloatingIcon(color: Colors.greenAccent[400]!, icon: Icons.insert_chart_outlined, size: 32)),
            Positioned(left: 5, bottom: 8, child: _buildFloatingIcon(color: Colors.amber, icon: Icons.bar_chart, size: 34)),
            Positioned(right: 0, bottom: 30, child: _buildFloatingIcon(color: Colors.white, iconColor: Colors.blue, icon: Icons.pie_chart, size: 36)),
          ] else if (type == 2) ...[
            Positioned(left: 5, top: 8, child: _buildFloatingIcon(color: Colors.purpleAccent, icon: Icons.auto_graph, size: 34)),
            Positioned(right: 0, bottom: 15, child: _buildFloatingIcon(color: Colors.blueAccent, icon: Icons.analytics, size: 38)),
          ] else ...[
            Positioned(left: 0, top: 22, child: _buildFloatingIcon(color: Colors.orangeAccent, icon: Icons.people, size: 32)),
            Positioned(right: 5, bottom: 10, child: _buildFloatingIcon(color: Colors.green, icon: Icons.check_circle, size: 34)),
          ],
        ],
      ),
    );
  }

  Widget _buildGridLines() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(children: [_buildGridCell(color: Colors.green), _buildGridCell(), _buildGridCell()]),
        Row(children: [_buildGridCell(), _buildGridCell(), _buildGridCell()]),
        Row(children: [_buildGridCell(), _buildGridCell(color: Colors.blue[200]), _buildGridCell()]),
        Row(children: [_buildGridCell(), _buildGridCell(), _buildGridCell()]),
      ],
    );
  }

  Widget _buildChartLines() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Container(height: 20, color: Colors.blue[100], width: double.infinity),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(height: 16, width: 12, color: Colors.amber),
            Container(height: 30, width: 12, color: Colors.green),
            Container(height: 22, width: 12, color: Colors.purple),
            Container(height: 36, width: 12, color: Colors.blue),
          ],
        ),
      ],
    );
  }
  
  Widget _buildCollabLines() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(children: [const CircleAvatar(radius: 10, backgroundColor: Colors.orange), const SizedBox(width: 6), Expanded(child: Container(height: 6, color: Colors.grey[300]))]),
        Row(children: [const CircleAvatar(radius: 10, backgroundColor: Colors.blue), const SizedBox(width: 6), Expanded(child: Container(height: 6, color: Colors.grey[300]))]),
        Row(children: [const CircleAvatar(radius: 10, backgroundColor: Colors.green), const SizedBox(width: 6), Expanded(child: Container(height: 6, color: Colors.grey[300]))]),
      ],
    );
  }

  Widget _buildGridCell({Color? color}) {
    return Expanded(
      child: Container(
        height: 8,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: color ?? Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildFloatingIcon({required Color color, required IconData icon, Color? iconColor, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Center(
        child: Icon(icon, color: iconColor ?? Colors.white, size: size * 0.55),
      ),
    );
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 30);
    
    // Simple gentle curve
    path.quadraticBezierTo(
      size.width / 2, size.height,
      size.width, size.height - 30,
    );
        
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
