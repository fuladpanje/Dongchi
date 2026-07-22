import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(1.5, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _runLoop();
  }

  Future<void> _runLoop() async {
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('درباره ما'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 32.0, bottom: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Logo + App Name side by side
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SizedBox(
                    width: 80,
                    height: 80,
                    child: Image.asset(
                      'assets/icon/1024.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'دنگ چی',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.teal.shade700,
                      ),
                    ),
                    const Text(
                      'مدیریت هوشمند هزینه‌های گروهی',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Download Section
            _buildDownloadSection(context),

            const SizedBox(height: 12),

            // iOS PWA Guide
            _buildIosGuideButton(context),

            const SizedBox(height: 20),

            // Developer Info Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoRow(
                      context,
                      Icons.person,
                      'سازنده',
                      'رضا فولادپنجه',
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(
                      context,
                      Icons.email,
                      'ایمیل',
                      'fuladpanje@gmail.com',
                      isLink: true,
                      linkTarget: 'mailto:fuladpanje@gmail.com',
                      ltr: true,
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(
                      context,
                      Icons.language,
                      'وب‌سایت',
                      'fuladpanjeh.ir',
                      isLink: true,
                      linkTarget: 'https://fuladpanjeh.ir',
                      ltr: true,
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(
                      context,
                      Icons.info_outline,
                      'نسخه',
                      '1.1.0',
                      ltr: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
      child: Row(
        children: [
          // Android + Windows combined
          Expanded(
            child: _buildDownloadButton(context),
          ),
          const SizedBox(width: 10),
          // Web / iOS
          Expanded(
            child: _buildWebButton(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(BuildContext context) {
    return _HoverScaleButton(
      onTap: () => _launchUrl('https://dl.dongchiapp.ir/'),
      gradient: LinearGradient(
        colors: [Colors.blue.shade400, Colors.green.shade500],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.desktop_windows, color: Colors.white, size: 20),
          const SizedBox(width: 4),
          const Icon(Icons.android, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'دانلود',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'ویندوز & اندروید',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebButton(BuildContext context) {
    return _HoverScaleButton(
      onTap: () => _launchUrl('https://dongchiapp.ir'),
      gradient: LinearGradient(
        colors: [Colors.teal.shade400, Colors.teal.shade700],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.apple, color: Colors.white, size: 20),
          const SizedBox(width: 4),
          const Icon(Icons.language, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'نسخه وب',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'iOS & مرورگر',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIosGuideButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showIosGuideDialog(context),
        icon: const Icon(Icons.apple, size: 20),
        label: const Text('راهنمای نصب در iOS'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.teal.shade700,
          side: BorderSide(color: Colors.teal.shade300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showIosGuideDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final handleColor = isDark ? Colors.grey.shade600 : Colors.grey.shade300;
        final iconBgColor = isDark ? Colors.teal.shade900 : Colors.teal.shade50;

        return Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.apple, color: Colors.teal.shade700, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'نصب برنامه در iOS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Steps
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildStep(
                    context,
                    1,
                    'سایت را در Safari باز کنید',
                    'به آدرس dongchiapp.ir در مرورگر Safari بروید',
                    Icons.public,
                  ),
                  const SizedBox(height: 16),
                  _buildStep(
                    context,
                    2,
                    'دکمه Share را بزنید',
                    'روی آیکون Share (مربع با فلش به بالا) در پایین صفحه کلیک کنید',
                    Icons.ios_share,
                  ),
                  const SizedBox(height: 16),
                  _buildStep(
                    context,
                    3,
                    'Add to Home Screen',
                    'در منوی باز شده، گزینه "Add to Home Screen" را انتخاب کنید',
                    Icons.add_box_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildStep(
                    context,
                    4,
                    'تایید نصب',
                    'نام برنامه را تایید کنید و روی Add بزنید. آیکون برنامه در صفحه اصلی ظاهر می‌شود',
                    Icons.check_circle_outline,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.shade900.withOpacity(0.4) : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'این روش فقط در Safari کار می‌کند و در سایر مرورگرها پشتیبانی نمی‌شود.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
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

  Widget _buildStep(BuildContext context, int number, String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.teal.shade700,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
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
                  Icon(icon, size: 20, color: Colors.teal.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isLink = false,
    String? linkTarget,
    bool ltr = false,
  }) {
    return InkWell(
      onTap: isLink && linkTarget != null ? () => _launchUrl(linkTarget) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  ltr
                      ? Directionality(
                          textDirection: TextDirection.ltr,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isLink ? Colors.blue : null,
                                decoration: isLink ? TextDecoration.underline : null,
                                decorationColor: Colors.blue,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          value,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isLink ? Colors.blue : null,
                            decoration: isLink ? TextDecoration.underline : null,
                            decorationColor: Colors.blue,
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

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $url');
    }
  }
}

class _HoverScaleButton extends StatefulWidget {
  final VoidCallback onTap;
  final LinearGradient gradient;
  final Widget child;

  const _HoverScaleButton({
    required this.onTap,
    required this.gradient,
    required this.child,
  });

  @override
  State<_HoverScaleButton> createState() => _HoverScaleButtonState();
}

class _HoverScaleButtonState extends State<_HoverScaleButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                gradient: widget.gradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: widget.child,
            ),
            if (_hovered)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
