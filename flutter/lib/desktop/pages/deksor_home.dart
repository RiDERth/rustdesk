import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/peer_tab_page.dart';
import 'package:flutter_hbb/desktop/widgets/deksor_gate.dart';
import 'package:flutter_hbb/desktop/widgets/deksor_update.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

const String kDeksorDisplayFont = 'DeksorDisplay';
const List<String> kDeksorDisplayFallback = ['Bahnschrift', 'Segoe UI'];
const List<String> kDeksorTextFallback = [
  'DB Heavent',
  'Leelawadee UI',
  'Segoe UI'
];

const Color _ink = Color(0xFF160F0E);
const Color _paper = Color(0xFFF6F1EC);
const Color _mute = Color(0xFF6B5F5B);
const Color _red = Color(0xFFFF2D3A);
const Color _redDeep = Color(0xFFC81E2B);
const Color _orange = Color(0xFFFF9A2E);
const Color _gold = Color(0xFFFFC23D);
const Color _goldPale = Color(0xFFFFE07A);

const LinearGradient _fire = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_goldPale, _orange, _red],
  stops: [0.0, 0.45, 1.0],
);

TextStyle _display(double size, {Color? color, double spacing = 1}) {
  return TextStyle(
    fontFamily: kDeksorDisplayFont,
    fontFamilyFallback: kDeksorDisplayFallback,
    fontSize: size,
    fontWeight: FontWeight.w900,
    fontVariations: const [ui.FontVariation('wght', 900)],
    letterSpacing: spacing,
    color: color ?? _ink,
    height: 1.05,
  );
}

TextStyle _text(double size,
    {Color color = _ink, FontWeight weight = FontWeight.w500}) {
  return TextStyle(
    fontFamilyFallback: kDeksorTextFallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
  );
}

class DeksorHome extends StatefulWidget {
  final Widget passwordBoard;
  final Widget helpCards;
  final Widget menuButton;

  const DeksorHome({
    Key? key,
    required this.passwordBoard,
    required this.helpCards,
    required this.menuButton,
  }) : super(key: key);

  @override
  State<DeksorHome> createState() => _DeksorHomeState();
}

class _DeksorHomeState extends State<DeksorHome> with TickerProviderStateMixin {
  static bool _introPlayed = false;

  late final AnimationController _loop;
  late final AnimationController _intro;
  final TextEditingController _idInput = TextEditingController();
  final FocusNode _idFocus = FocusNode();
  Timer? _clipTimer;
  Timer? _statusTimer;
  Timer? _copiedTimer;
  String _clip = '';
  bool _copied = false;
  Offset _tilt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
    _intro = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));
    if (_introPlayed) {
      _intro.value = 1;
    } else {
      _introPlayed = true;
      _intro.forward();
    }
    _idFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _statusTimer = periodic_immediate(
        const Duration(seconds: 1), () async => _updateStatus());
    _readClipboard();
    _clipTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _readClipboard());
  }

  @override
  void dispose() {
    _clipTimer?.cancel();
    _statusTimer?.cancel();
    _copiedTimer?.cancel();
    _loop.dispose();
    _intro.dispose();
    _idInput.dispose();
    _idFocus.dispose();
    super.dispose();
  }

  String get _myId =>
      gFFI.serverModel.serverId.text.replaceAll(RegExp(r'\s'), '');

  Future<void> _updateStatus() async {
    try {
      final status = jsonDecode(await bind.mainGetConnectStatus())
          as Map<String, dynamic>;
      final n = status['status_num'] as int;
      stateGlobal.svcStatus.value = n == 1
          ? SvcStatus.ready
          : (n == 0 ? SvcStatus.connecting : SvcStatus.notReady);
      try {
        stateGlobal.videoConnCount.value = status['video_conn_count'] as int;
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> _readClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = (data?.text ?? '').trim().replaceAll(RegExp(r'[\s-]'), '');
      final found =
          RegExp(r'^\d{8,10}$').hasMatch(raw) && raw != _myId ? raw : '';
      if (mounted && found != _clip) {
        setState(() => _clip = found);
      }
    } catch (_) {}
  }

  void _go(String id) {
    final clean = id.replaceAll(RegExp(r'[\s-]'), '');
    if (clean.isEmpty) return;
    connect(context, clean);
  }

  void _copyId() {
    Clipboard.setData(ClipboardData(text: _myId));
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _shareLine() async {
    Clipboard.setData(ClipboardData(text: _myId));
    final uri = Uri.parse(
        'https://line.me/R/share?text=${Uri.encodeComponent('DEK SOR $_myId')}');
    await launchUrl(uri);
  }

  Animation<double> _seg(double a, double b, [Curve curve = Curves.easeOutCubic]) {
    return CurvedAnimation(
        parent: _intro,
        curve: Interval(a.clamp(0.0, 1.0), b.clamp(0.0, 1.0), curve: curve));
  }

  Widget _rise(Widget child, double start, {double dy = 26}) {
    final an = _seg(start, start + 0.28, Curves.easeOutQuart);
    return AnimatedBuilder(
      animation: an,
      builder: (_, c) => Opacity(
        opacity: an.value,
        child: Transform.translate(offset: Offset(0, (1 - an.value) * dy), child: c),
      ),
      child: child,
    );
  }

  Widget _lineUp(Widget child, double start) {
    final an = _seg(start, start + 0.3, Curves.easeOutQuart);
    return ClipRect(
      child: AnimatedBuilder(
        animation: an,
        builder: (_, c) => FractionalTranslation(
          translation: Offset(0, 1.1 * (1 - an.value)),
          child: Transform(
            transform: Matrix4.skewY(0.1 * (1 - an.value)),
            child: c,
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _paper,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _DotGridPainter()),
            ),
          ),
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _loop,
                builder: (_, __) =>
                    CustomPaint(painter: _AmbientPainter(_loop.value)),
              ),
            ),
          ),
          Positioned.fill(
            child: Column(
              children: [
                _rise(_header(), 0.58, dy: -14),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 440, child: _leftColumn()),
                      Expanded(child: _rightColumn()),
                    ],
                  ),
                ),
                _rise(_marquee(), 0.86, dy: 20),
              ],
            ),
          ),
          Positioned.fill(child: _introOverlay()),
        ],
      ),
    );
  }

  Widget _header() {
    return SizedBox(
      height: 66,
      child: Row(
        children: [
          const SizedBox(width: 22),
          SizedBox(
            width: 42,
            height: 42,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _loop,
                builder: (_, __) => CustomPaint(
                    painter: _MarkPainter(_loop.value, small: true)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (r) => const LinearGradient(
                  colors: [_orange, _red, _redDeep],
                ).createShader(r),
                child: Text('DEK SOR', style: _display(22)),
              ),
              const SizedBox(height: 3),
              Text('เปิดประตู ไปได้ทุกเครื่อง', style: _text(12.5, color: _mute)),
            ],
          ),
          const Spacer(),
          _statusPill(),
          const SizedBox(width: 8),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: ShapeDecoration(color: _ink, shape: deksorCut(8)),
            child: Text('v$kDeksorVersion',
                style: _display(12, color: _goldPale, spacing: 0.5)),
          ),
          const SizedBox(width: 6),
          widget.menuButton,
          const SizedBox(width: 14),
        ],
      ),
    );
  }

  Widget _statusPill() {
    final stopped = Get.isRegistered<RxBool>(tag: 'stop-service')
        ? Get.find<RxBool>(tag: 'stop-service')
        : false.obs;
    return Obx(() {
      final s = stateGlobal.svcStatus.value;
      final off = stopped.value;
      final Color dot;
      final Color bg;
      final Color fg;
      final String label;
      if (off) {
        dot = _red;
        bg = const Color(0xFFFDE8E6);
        fg = _redDeep;
        label = 'ปิดรับอยู่ · กดเพื่อเปิด';
      } else if (s == SvcStatus.ready) {
        dot = const Color(0xFF16A34A);
        bg = const Color(0xFFE6F6EC);
        fg = const Color(0xFF0E7A36);
        label = 'พร้อมรับการเชื่อมต่อ';
      } else if (s == SvcStatus.connecting) {
        dot = _gold;
        bg = const Color(0xFFFFF4D6);
        fg = const Color(0xFF7A5200);
        label = 'กำลังเชื่อมต่อ...';
      } else {
        dot = _red;
        bg = const Color(0xFFFDE8E6);
        fg = _redDeep;
        label = 'ต่อเซิร์ฟเวอร์ไม่ได้ · เช็กเน็ต';
      }
      final pill = Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: ShapeDecoration(color: bg, shape: deksorCut(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _loop,
              builder: (_, __) {
                final p = (_loop.value * 12 / 1.8) % 1.0;
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: dot.withOpacity(0.55 * (1 - p)),
                        spreadRadius: 7 * p,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Text(label, style: _text(13.5, color: fg, weight: FontWeight.w700)),
          ],
        ),
      );
      if (!off) return pill;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () async => await start_service(true),
          child: pill,
        ),
      );
    });
  }

  Widget _leftColumn() {
    final groups = gFFI.serverModel.serverId.text.trim().split(RegExp(r'\s+'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rise(
            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: ShapeDecoration(
                color: Colors.white.withOpacity(0.85),
                shape: deksorCut(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _red,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: _red, blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text('เลขเครื่องนี้',
                      style: _text(13.5, color: _redDeep, weight: FontWeight.w700)),
                ],
              ),
            ),
            0.62,
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: gFFI.serverModel.serverId,
            builder: (_, __) {
              final parts = gFFI.serverModel.serverId.text
                  .trim()
                  .split(RegExp(r'\s+'))
                  .where((e) => e.isNotEmpty)
                  .toList();
              final shown = parts.isEmpty ? groups : parts;
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedBuilder(
                  animation: _loop,
                  builder: (_, child) {
                    final local = (_loop.value * 12 / 4.5) % 1.0;
                    final dx = local < 0.4
                        ? -2.0
                        : -1.4 + 2.8 * ((local - 0.4) / 0.6);
                    return ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (r) => LinearGradient(
                        colors: const [
                          _ink, _ink, _orange, _goldPale, _red, _ink, _ink
                        ],
                        stops: const [0.0, 0.38, 0.46, 0.5, 0.54, 0.62, 1.0],
                        transform: _SlideGradient(dx),
                      ).createShader(r),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0) const SizedBox(width: 16),
                        _lineUp(
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(shown[i].isEmpty ? '...' : shown[i],
                                style: _display(64, spacing: 1)),
                          ),
                          0.64 + i * 0.05,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          _rise(
            Row(
              children: [
                Container(
                  width: 40,
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0x00FF2D3A), _red]),
                  ),
                ),
                const SizedBox(width: 8),
                Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _gold,
                      boxShadow: [BoxShadow(color: _gold, blurRadius: 8)],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text('บอกเลขนี้ให้คนที่จะเข้ามาช่วย',
                      overflow: TextOverflow.ellipsis,
                      style: _text(15, color: const Color(0xFF3B302D))),
                ),
              ],
            ),
            0.72,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _rise(
                  _DkButton(
                    label: _copied ? 'คัดลอกแล้ว' : 'คัดลอกเลข',
                    icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
                    gradient: const LinearGradient(
                        colors: [_goldPale, _orange]),
                    fg: const Color(0xFF3A1A02),
                    glow: _orange,
                    onTap: _copyId,
                  ),
                  0.74,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _rise(
                  _DkButton(
                    label: 'ส่ง LINE',
                    icon: Icons.send_rounded,
                    gradient: const LinearGradient(
                        colors: [Color(0xFF4FE07E), Color(0xFF06C755)]),
                    fg: Colors.white,
                    glow: const Color(0xFF06C755),
                    onTap: _shareLine,
                  ),
                  0.77,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _rise(
            Material(
              color: _ink,
              shape: deksorCut(14),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: MyTheme.darkTheme,
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 16, right: 4),
                      child: Icon(Icons.shield_rounded, color: _gold, size: 20),
                    ),
                    Expanded(child: widget.passwordBoard),
                  ],
                ),
              ),
            ),
            0.8,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(scrollbars: false),
              child: SingleChildScrollView(
                child: _rise(widget.helpCards, 0.84),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: DeksorUpdateFooter(),
          ),
        ],
      ),
    );
  }

  Widget _rightColumn() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _rise(_connectCard(), 0.6, dy: 40),
          const SizedBox(height: 14),
          Expanded(child: _rise(_peersCard(), 0.86)),
        ],
      ),
    );
  }

  Widget _portal() {
    return LayoutBuilder(builder: (context, c) {
      final side = math.min(c.maxWidth, c.maxHeight);
      return MouseRegion(
        onHover: (e) {
          final dx = e.localPosition.dx / c.maxWidth - 0.5;
          final dy = e.localPosition.dy / c.maxHeight - 0.5;
          setState(() => _tilt = Offset(dx, dy));
        },
        onExit: (_) => setState(() => _tilt = Offset.zero),
        child: Center(
          child: TweenAnimationBuilder<Offset>(
            tween: Tween(end: _tilt),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            builder: (_, t, child) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(-t.dy * 0.3)
                ..rotateY(t.dx * 0.4),
              child: child,
            ),
            child: SizedBox(
              width: side,
              height: side,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _loop,
                  builder: (_, __) =>
                      CustomPaint(painter: _PortalPainter(_loop.value)),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _connectCard() {
    final hasText = _idInput.text.trim().isNotEmpty;
    return Material(
      color: _ink,
      shape: deksorCut(22),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: Stack(
        children: [
          Positioned(
            right: -120,
            top: -140,
            child: Container(
              width: 420,
              height: 420,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x66FF2D3A), Color(0x00FF2D3A)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 18, 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('เปิดประตูไปเครื่องอื่น',
                          style: _text(26,
                              color: Colors.white, weight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      SizedBox(height: 56, child: _clipSlot()),
                      const SizedBox(height: 12),
                      _bigInput(),
                      const SizedBox(height: 12),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: hasText ? 1 : 0.55,
                        child: _DkButton(
                          label: 'เปิดประตู',
                          icon: Icons.arrow_forward_rounded,
                          gradient: const LinearGradient(
                              colors: [_goldPale, _orange, _red]),
                          fg: const Color(0xFF2A0F02),
                          glow: _orange,
                          height: 64,
                          fontSize: 23,
                          iconSize: 26,
                          onTap: () => _go(_idInput.text),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 200, height: 260, child: _portal()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _clipSlot() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (c, a) =>
          ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
      child: _clip.isEmpty
          ? Align(
              key: const ValueKey('noclip'),
              alignment: Alignment.centerLeft,
              child: Text(
                'พิมพ์เลขได้เลย หรือคัดลอกเลขจาก LINE แล้วมันจะเด้งขึ้นมาเอง',
                style: _text(15, color: const Color(0xFFC7BBB6)),
              ),
            )
          : Container(
              key: ValueKey(_clip),
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: ShapeDecoration(
                gradient: const LinearGradient(colors: [_red, _redDeep]),
                shape: deksorCut(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.content_paste_go_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(_groupId(_clip),
                          style: _display(24, color: Colors.white, spacing: 2)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 112,
                    child: _DkButton(
                      label: 'เข้าเลย',
                      icon: Icons.bolt_rounded,
                      gradient: const LinearGradient(
                          colors: [Colors.white, Colors.white]),
                      fg: _redDeep,
                      glow: Colors.black,
                      height: 44,
                      onTap: () => _go(_clip),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _bigInput() {
    final focused = _idFocus.hasFocus;
    return AnimatedBuilder(
      animation: _loop,
      builder: (_, child) {
        final pulse = 0.5 + 0.5 * math.sin(_loop.value * math.pi * 2 * 6);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 84,
          decoration: ShapeDecoration(
            color: const Color(0xFF2A1F1D),
            shape: BeveledRectangleBorder(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
              side: BorderSide(
                color: focused
                    ? _gold
                    : _gold.withOpacity(0.25 + 0.35 * pulse),
                width: focused ? 2.5 : 1.5,
              ),
            ),
            shadows: [
              BoxShadow(
                color: _gold.withOpacity(focused ? 0.35 : 0.12 * pulse),
                blurRadius: 28,
                spreadRadius: -6,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          child: child,
        );
      },
      child: Row(
        children: [
          const Icon(Icons.dialpad_rounded, color: _gold, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _idInput,
              focusNode: _idFocus,
              autofocus: true,
              onSubmitted: _go,
              onChanged: (_) => setState(() {}),
              inputFormatters: [_IdFormatter()],
              keyboardType: TextInputType.number,
              cursorColor: _gold,
              cursorWidth: 3,
              style: _display(38, color: Colors.white, spacing: 3),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'ใส่เลขเครื่อง',
                hintStyle: _text(28,
                    color: const Color(0xFF8F837E), weight: FontWeight.w600),
              ),
            ),
          ),
          if (_idInput.text.isNotEmpty)
            IconButton(
              tooltip: 'ล้าง',
              onPressed: () {
                _idInput.clear();
                _idFocus.requestFocus();
                setState(() {});
              },
              icon: const Icon(Icons.close_rounded,
                  color: Color(0xFF8F837E), size: 24),
            ),
        ],
      ),
    );
  }

  Widget _peersCard() {
    return Container(
      decoration: ShapeDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: deksorCut(18),
        shadows: const [
          BoxShadow(
              color: Color(0x33781E1E),
              blurRadius: 30,
              offset: Offset(0, 16),
              spreadRadius: -18),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('เครื่องที่เคยเข้า', style: _text(17, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Expanded(child: PeerTabPage()),
        ],
      ),
    );
  }

  Widget _marquee() {
    const feats = [
      'ต่อตรง ไม่ผ่านใคร',
      '60 FPS',
      'สลับภาษาเหมือนนั่งหน้าเครื่อง',
      'หลายจอ Alt+1 2 3',
      'กด Win พับกลับ',
      'เข้ารหัสทุกการเชื่อมต่อ',
    ];
    Widget group() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in feats) ...[
              Text(f, style: _text(15, color: const Color(0xFF3A0A0C), weight: FontWeight.w700)),
              const SizedBox(width: 24),
              Transform.rotate(
                angle: math.pi / 4,
                child: Container(width: 6, height: 6, color: const Color(0x803A0A0C)),
              ),
              const SizedBox(width: 24),
            ],
          ],
        );
    return SizedBox(
      height: 46,
      child: Transform.rotate(
        angle: -0.012,
        child: OverflowBox(
          maxWidth: double.infinity,
          child: Container(
            height: 32,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [_goldPale, _orange, _red], stops: [0, 0.4, 1]),
              boxShadow: [
                BoxShadow(color: Color(0x80FF9A2E), blurRadius: 30, spreadRadius: -6)
              ],
            ),
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _loop,
                builder: (_, child) => FractionalTranslation(
                  translation: Offset(-((_loop.value * 12 / 26) % 1.0) * 0.5, 0),
                  child: child,
                ),
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: double.infinity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [group(), group()],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _introOverlay() {
    return AnimatedBuilder(
      animation: _intro,
      builder: (context, _) {
        final v = _intro.value;
        if (v >= 0.8) return const SizedBox.shrink();
        final load = (v / 0.55).clamp(0.0, 1.0);
        final wipe = Curves.easeInOutCubic
            .transform(((v - 0.56) / 0.22).clamp(0.0, 1.0));
        return LayoutBuilder(builder: (context, c) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_intro.value < 0.56) _intro.value = 0.56;
            },
            child: Transform.translate(
              offset: Offset(0, -c.maxHeight * wipe),
              child: Container(
                color: _ink,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: CustomPaint(painter: _IntroMarkPainter(load)),
                    ),
                    const SizedBox(height: 22),
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (r) => _fire.createShader(r),
                      child: Text('DEK SOR', style: _display(30, spacing: 2)),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: 220,
                      height: 3,
                      color: const Color(0x29FFC23D),
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 220 * load,
                        height: 3,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [_goldPale, _orange, _red]),
                          boxShadow: [BoxShadow(color: _orange, blurRadius: 10)],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('${(load * 100).round()}%',
                        style: _display(12, color: const Color(0xFF8F837E), spacing: 3)),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double dx;
  const _SlideGradient(this.dx);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * dx, 0, 0);
  }
}

class _DkButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final Color fg;
  final Color glow;
  final VoidCallback onTap;
  final double height;
  final double fontSize;
  final double iconSize;

  const _DkButton({
    Key? key,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.fg,
    required this.glow,
    required this.onTap,
    this.height = 52,
    this.fontSize = 16.5,
    this.iconSize = 19,
  }) : super(key: key);

  @override
  State<_DkButton> createState() => _DkButtonState();
}

class _DkButtonState extends State<_DkButton> with SingleTickerProviderStateMixin {
  late final AnimationController _sheen;
  bool _hover = false;
  bool _down = false;

  @override
  void initState() {
    super.initState();
    _sheen = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850));
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shape = deksorCut(12);
    final lift = _down ? -1.0 : (_hover ? -3.0 : 0.0);
    final scale = _down ? 0.97 : 1.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hover = true);
        _sheen.forward(from: 0);
      },
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          height: widget.height,
          transform: Matrix4.translationValues(0, lift, 0)..scale(scale, scale),
          transformAlignment: Alignment.center,
          decoration: ShapeDecoration(
            gradient: widget.gradient,
            shape: shape,
            shadows: [
              BoxShadow(
                color: widget.glow.withOpacity(_hover ? 0.55 : 0.32),
                blurRadius: _hover ? 26 : 18,
                offset: const Offset(0, 12),
                spreadRadius: -10,
              ),
            ],
          ),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: shape),
            child: Stack(
              children: [
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (c, a) =>
                            ScaleTransition(scale: a, child: c),
                        child: Icon(widget.icon,
                            key: ValueKey(widget.icon), size: widget.iconSize, color: widget.fg),
                      ),
                      if (widget.label.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(widget.label,
                              overflow: TextOverflow.ellipsis,
                              style: _text(widget.fontSize,
                                  color: widget.fg, weight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _sheen,
                      builder: (_, __) {
                        if (_sheen.value == 0 || _sheen.value == 1) {
                          return const SizedBox.shrink();
                        }
                        final x = -0.6 + 2.0 * Curves.easeOutCubic.transform(_sheen.value);
                        return FractionalTranslation(
                          translation: Offset(x, 0),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.4,
                            child: Transform(
                              transform: Matrix4.skewX(-0.35),
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    Color(0x00FFFFFF),
                                    Color(0xBFFFFFFF),
                                    Color(0x00FFFFFF),
                                  ]),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x80D8C9C1);
    for (double y = 2; y < size.height; y += 24) {
      for (double x = 2; x < size.width; x += 24) {
        canvas.drawCircle(Offset(x, y), 1.1, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AmbientPainter extends CustomPainter {
  final double t;
  _AmbientPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * math.pi;
    final r1 = size.shortestSide * 0.75;
    final c1 = Offset(size.width * 0.02 + math.sin(a) * 70,
        -size.height * 0.08 + math.cos(a) * 50);
    canvas.drawCircle(
      c1,
      r1,
      Paint()
        ..shader = ui.Gradient.radial(c1, r1, const [
          Color(0x42FF4048),
          Color(0x14FF4048),
          Color(0x00FF4048),
        ], const [0.0, 0.4, 1.0]),
    );
    final c2 = Offset(size.width * 0.98 - math.sin(a * 0.8) * 70,
        size.height * 1.05 - math.cos(a * 0.8) * 50);
    canvas.drawCircle(
      c2,
      r1,
      Paint()
        ..shader = ui.Gradient.radial(c2, r1, const [
          Color(0x52FFC23D),
          Color(0x1AFFC23D),
          Color(0x00FFC23D),
        ], const [0.0, 0.4, 1.0]),
    );
    const cols = [_orange, _red, _gold, _goldPale];
    for (var i = 0; i < 18; i++) {
      final speed = 2.0 + (i % 4) * 0.55;
      final ph = (t * speed + i * 0.137) % 1.0;
      final x = size.width * (((i * 0.0577) + 0.03) % 1.0) +
          math.sin(ph * 6 + i) * (18 + i % 5 * 6);
      final y = size.height * (1.02 - ph * 0.62);
      final alpha = math.sin(ph * math.pi).clamp(0.0, 1.0);
      final rad = 1.6 + (i * 7 % 5) * 0.5;
      final col = cols[i % 4];
      canvas.drawCircle(Offset(x, y), rad * 3,
          Paint()..color = col.withOpacity(0.18 * alpha));
      canvas.drawCircle(Offset(x, y), rad, Paint()..color = col.withOpacity(0.9 * alpha));
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) => old.t != t;
}

Path _octagon(double s, double cut) {
  return Path()
    ..moveTo(cut, 0)
    ..lineTo(s - cut, 0)
    ..lineTo(s, cut)
    ..lineTo(s, s - cut)
    ..lineTo(s - cut, s)
    ..lineTo(cut, s)
    ..lineTo(0, s - cut)
    ..lineTo(0, cut)
    ..close();
}

Path _cursorPath() {
  return Path()
    ..moveTo(50, 42)
    ..lineTo(50, 76)
    ..lineTo(58.5, 68)
    ..lineTo(65, 81)
    ..lineTo(71, 78)
    ..lineTo(64.5, 65.5)
    ..lineTo(76, 65.5)
    ..close();
}

void _dashedCircle(Canvas canvas, Offset c, double r, double dash, double gap,
    double rotation, Paint paint) {
  final circ = 2 * math.pi * r;
  final step = dash + gap;
  final n = (circ / step).floor();
  final dashA = dash / r;
  final stepA = 2 * math.pi / n;
  final rect = Rect.fromCircle(center: c, radius: r);
  for (var i = 0; i < n; i++) {
    canvas.drawArc(rect, rotation + i * stepA, dashA, false, paint);
  }
}

void _paintMark(Canvas canvas, double t, {required bool animateCursor, bool thick = false}) {
  final a = t * 2 * math.pi;
  canvas.save();
  canvas.translate(4, 4);
  canvas.drawPath(_octagon(112, 18), Paint()..color = _ink);
  canvas.restore();
  canvas.save();
  canvas.translate(10, 10);
  canvas.drawPath(
      _octagon(100, 16),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _gold.withOpacity(0.22));
  canvas.restore();
  const c = Offset(60, 60);
  final breathe = 1 + 0.12 * math.sin(a * 12 / 3.6);
  canvas.drawCircle(
    c,
    26 * breathe,
    Paint()
      ..shader = ui.Gradient.radial(c, 26 * breathe, const [
        Color(0xFFFFF6D8),
        Color(0x8CFFC23D),
        Color(0x00FFC23D),
      ], const [0.0, 0.55, 1.0]),
  );
  final ringRot = a * 12 / 7;
  canvas.drawArc(
    Rect.fromCircle(center: c, radius: 31),
    ringRot,
    2 * math.pi * 0.77,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thick ? 9 : 7
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
          const Offset(29, 29), const Offset(91, 91), const [_goldPale, _orange, _red], const [0.0, 0.45, 1.0]),
  );
  _dashedCircle(
      canvas,
      c,
      22,
      20,
      18,
      -a * 12 / 11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withOpacity(0.5));
  double off = 0;
  double op = 1;
  if (animateCursor) {
    final p = (t * 12 / 3.4) % 1.0;
    if (p < 0.55) {
      off = 22 * (1 - Curves.easeOutCubic.transform(p / 0.55));
    }
    if (p < 0.18) {
      op = p / 0.18;
    } else if (p > 0.82) {
      op = (1 - p) / 0.18;
      off = -4 * (p - 0.82) / 0.18;
    }
    final sp = (t * 12 / 1.1) % 1.0;
    canvas.save();
    canvas.translate(off, off);
    for (final s in const [
      [74.0, 74.0, 96.0, 96.0, 2.5, 0.0],
      [82.0, 66.0, 100.0, 84.0, 2.0, 0.4],
    ]) {
      final k = (sp + s[5]) % 1.0;
      final from = Offset(s[0], s[1]);
      final to = Offset(s[2], s[3]);
      final d = to - from;
      final st = from + d * k;
      final en = from + d * math.min(1.0, k + 0.33);
      canvas.drawLine(
          st,
          en,
          Paint()
            ..color = (s[4] > 2.2 ? _gold : _red).withOpacity(op)
            ..strokeWidth = s[4]
            ..strokeCap = StrokeCap.round);
    }
    canvas.restore();
  }
  canvas.save();
  canvas.translate(off, off);
  final cursor = _cursorPath();
  canvas.drawPath(cursor, Paint()..color = Colors.white.withOpacity(op));
  canvas.drawPath(
      cursor,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = _ink.withOpacity(op));
  canvas.restore();
}

class _MarkPainter extends CustomPainter {
  final double t;
  final bool small;
  _MarkPainter(this.t, {this.small = false});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 120;
    canvas.save();
    canvas.scale(s, s);
    _paintMark(canvas, t, animateCursor: !small, thick: small);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) => old.t != t;
}

class _PortalPainter extends CustomPainter {
  final double t;
  _PortalPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final a = t * 2 * math.pi;
    final breathe = 1 + 0.1 * math.sin(a * 12 / 3.6);
    final glowR = side * 0.4 * breathe;
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = ui.Gradient.radial(c, glowR, const [
          Color(0xB3FFFFFF),
          Color(0x80FFE9A8),
          Color(0x00FFC23D),
        ], const [0.0, 0.35, 1.0]),
    );
    _dashedCircle(
        canvas,
        c,
        side * 0.49,
        2,
        10,
        -a * 12 / 38,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _redDeep.withOpacity(0.3));
    _dashedCircle(
        canvas,
        c,
        side * 0.43,
        40,
        18,
        a * 12 / 26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _orange.withOpacity(0.5));
    for (final o in [
      [side * 0.46, 12 / 9.0, 5.0, _red],
      [side * 0.4, -12 / 14.0, 4.0, _gold],
    ]) {
      final r = o[0] as double;
      final ang = a * (o[1] as double) - math.pi / 2;
      canvas.drawCircle(c + Offset(math.cos(ang), math.sin(ang)) * r,
          o[2] as double, Paint()..color = o[3] as Color);
    }
    final markSize = side * 0.66;
    canvas.save();
    canvas.translate(c.dx - markSize / 2, c.dy - markSize / 2);
    canvas.scale(markSize / 120, markSize / 120);
    _paintMark(canvas, t, animateCursor: true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PortalPainter old) => old.t != t;
}

class _IntroMarkPainter extends CustomPainter {
  final double p;
  _IntroMarkPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 120;
    canvas.save();
    canvas.scale(s, s);
    final oct = _octagon(112, 18).shift(const Offset(4, 4));
    _drawPartial(
        canvas,
        oct,
        Curves.easeOutCubic.transform((p / 0.6).clamp(0.0, 1.0)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _gold.withOpacity(0.6));
    final ring = Path()
      ..addArc(Rect.fromCircle(center: const Offset(60, 60), radius: 31),
          -math.pi / 2, 2 * math.pi * 0.999);
    _drawPartial(
        canvas,
        ring,
        Curves.easeOutCubic.transform(((p - 0.15) / 0.55).clamp(0.0, 1.0)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(const Offset(29, 29),
              const Offset(91, 91), const [_goldPale, _orange, _red], const [0.0, 0.45, 1.0]));
    final f = ((p - 0.72) / 0.28).clamp(0.0, 1.0);
    if (f > 0) {
      final flash = math.sin(f * math.pi);
      canvas.drawCircle(const Offset(60, 60), 18 * (0.4 + flash),
          Paint()..color = const Color(0xFFFFF4D0).withOpacity(flash));
    }
    final fly = Curves.easeOutCubic.transform(((p - 0.45) / 0.4).clamp(0.0, 1.0));
    if (fly > 0) {
      canvas.save();
      canvas.translate(60 * (1 - fly), 60 * (1 - fly));
      canvas.drawPath(_cursorPath(), Paint()..color = Colors.white.withOpacity(fly));
      canvas.restore();
    }
    canvas.restore();
  }

  void _drawPartial(Canvas canvas, Path path, double k, Paint paint) {
    if (k <= 0) return;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * k), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IntroMarkPainter old) => old.p != p;
}

String _groupId(String raw) {
  final d = raw.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^\d+$').hasMatch(d)) return raw;
  final b = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) b.write(' ');
    b.write(d[i]);
  }
  return b.toString();
}

class _IdFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\d*$').hasMatch(raw)) return newValue;
    final s = _groupId(raw);
    return TextEditingValue(
        text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}
