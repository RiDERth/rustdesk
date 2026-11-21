import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:url_launcher/url_launcher.dart';

const String kDeksorVersion = '0.7';

class DeksorColors {
  static const Color red = Color(0xFFE0312B);
  static const Color redDark = Color(0xFFB8221D);
  static const Color gold = Color(0xFFF2B544);
  static const Color goldText = Color(0xFF2E1E02);
  static const Color ink = Color(0xFF17110F);
  static const Color paper = Color(0xFFF4F0EC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color soft = Color(0xFFF3EDE9);
  static const Color mute = Color(0xFF6F6461);
  static const Color line = Color(0xFF06C755);
  static const Color green = Color(0xFF16A34A);
}

ShapeBorder deksorCut(double size) {
  return BeveledRectangleBorder(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(size),
      bottomRight: Radius.circular(size),
    ),
  );
}

class DeksorButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const DeksorButton({
    Key? key,
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: deksorCut(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: textColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeksorGate extends StatefulWidget {
  const DeksorGate({Key? key}) : super(key: key);

  @override
  State<DeksorGate> createState() => _DeksorGateState();
}

class _DeksorGateState extends State<DeksorGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _open;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _open = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        _open.animateTo(0.72, curve: Curves.easeInOutCubic);
      }
    });
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  void _setHover(bool value) {
    if (_hover == value) return;
    _hover = value;
    _open.animateTo(
      value ? 1.0 : 0.72,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  Widget _door(double offset, bool left) {
    return Transform.translate(
      offset: Offset(left ? -offset : offset, 0),
      child: Container(
        width: 44,
        decoration: BoxDecoration(
          color: DeksorColors.red,
          border: Border(
            left: left
                ? BorderSide.none
                : const BorderSide(color: DeksorColors.redDark, width: 1),
            right: left
                ? const BorderSide(color: DeksorColors.redDark, width: 1)
                : BorderSide.none,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 18),
            Container(
              height: 34,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.35)),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: SizedBox(
        height: 132,
        child: Center(
          child: Material(
            color: DeksorColors.ink,
            shape: BeveledRectangleBorder(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 7, 7, 0),
              child: ClipPath(
                clipper: const ShapeBorderClipper(
                  shape: BeveledRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                ),
                child: SizedBox(
                  width: 88,
                  height: 125,
                  child: AnimatedBuilder(
                    animation: _open,
                    builder: (context, _) {
                      final t = _open.value;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Opacity(
                            opacity: t.clamp(0.0, 1.0),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(0, 0.2),
                                  radius: 0.9,
                                  colors: [
                                    Color(0xFFFFFFFF),
                                    Color(0xFFFFE7A6),
                                    Color(0xFFF7B84A),
                                  ],
                                  stops: [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _door(t * 36, true),
                              _door(t * 36, false),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DeksorIdCard extends StatelessWidget {
  final TextEditingController idController;

  const DeksorIdCard({Key? key, required this.idController}) : super(key: key);

  String get _plainId => idController.text.replaceAll(' ', '');

  void _copy() {
    Clipboard.setData(ClipboardData(text: _plainId));
    showToast(translate('Copied'));
  }

  Future<void> _shareLine() async {
    final text = 'DEK SOR $_plainId';
    Clipboard.setData(ClipboardData(text: _plainId));
    final uri = Uri.parse(
        'https://line.me/R/share?text=${Uri.encodeComponent(text)}');
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DeksorColors.card,
      shape: deksorCut(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFFBF7F3),
            padding: const EdgeInsets.only(top: 14),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 190,
                  height: 132,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0xB3FFD98A), Color(0x00FFD98A)],
                    ),
                  ),
                ),
                const DeksorGate(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เลขเครื่องนี้',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: DeksorColors.mute,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedBuilder(
                  animation: idController,
                  builder: (context, _) {
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        idController.text.isEmpty ? '...' : idController.text,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 34,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: DeksorColors.ink,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(width: 26, height: 3, color: DeksorColors.red),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'บอกเลขนี้ให้คนที่จะเข้ามาช่วย',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: DeksorColors.mute,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DeksorButton(
                        label: 'คัดลอก',
                        icon: Icons.copy_rounded,
                        color: DeksorColors.gold,
                        textColor: DeksorColors.goldText,
                        onTap: _copy,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DeksorButton(
                        label: 'ส่ง LINE',
                        icon: Icons.send_rounded,
                        color: DeksorColors.line,
                        textColor: Colors.white,
                        onTap: _shareLine,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DeksorBrand extends StatelessWidget {
  const DeksorBrand({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: DeksorColors.ink,
          shape: deksorCut(8),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(child: loadIcon(24)),
          ),
        ),
        const SizedBox(width: 10),
        Text.rich(
          const TextSpan(
            children: [
              TextSpan(text: 'DEK'),
              TextSpan(text: '·', style: TextStyle(color: DeksorColors.red)),
              TextSpan(text: 'SOR'),
            ],
          ),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
      ],
    );
  }
}

class DeksorFooter extends StatelessWidget {
  const DeksorFooter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: DeksorColors.mute,
        ),
        children: [
          TextSpan(text: 'v$kDeksorVersion · '),
          TextSpan(
            text: 'By RiDERth',
            style: TextStyle(color: DeksorColors.red),
          ),
        ],
      ),
    );
  }
}
