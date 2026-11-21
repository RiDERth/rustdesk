import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/widgets/deksor_gate.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

const String _kReleaseBase =
    'https://github.com/RiDERth/rustdesk/releases/download/deksor';
const String _kLauncherEnvKey = 'DEKSOR_LAUNCHER';

bool deksorIsNewer(String remote, String local) {
  List<int> parse(String v) => v
      .trim()
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList();
  final a = parse(remote);
  final b = parse(local);
  final n = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

Future<String> _fetchText(Uri uri) async {
  final client = HttpClient();
  try {
    client.connectionTimeout = const Duration(seconds: 15);
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > 4096) break;
    }
    return String.fromCharCodes(bytes).trim();
  } finally {
    client.close(force: true);
  }
}

enum _UpdateStage { idle, available, downloading, restarting, failed }

class DeksorUpdateFooter extends StatefulWidget {
  const DeksorUpdateFooter({Key? key}) : super(key: key);

  @override
  State<DeksorUpdateFooter> createState() => _DeksorUpdateFooterState();
}

class _DeksorUpdateFooterState extends State<DeksorUpdateFooter> {
  _UpdateStage _stage = _UpdateStage.idle;
  String _remoteVersion = '';
  double _progress = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _check();
      _timer = Timer.periodic(const Duration(minutes: 30), (_) => _check());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_stage == _UpdateStage.downloading ||
        _stage == _UpdateStage.restarting) {
      return;
    }
    try {
      final text = await _fetchText(Uri.parse(
          '$_kReleaseBase/deksor-version.txt?t=${DateTime.now().millisecondsSinceEpoch}'));
      final remote = text.split('\n').first.trim();
      if (!mounted) return;
      if (RegExp(r'^\d+(\.\d+)*$').hasMatch(remote) &&
          deksorIsNewer(remote, kDeksorVersion)) {
        setState(() {
          _remoteVersion = remote;
          _stage = _UpdateStage.available;
        });
      }
    } catch (e) {
      debugPrint('DEK SOR update check failed: $e');
    }
  }

  bool get _busyWithPeers => gFFI.serverModel.clients.isNotEmpty;

  Future<void> _update() async {
    if (_busyWithPeers) {
      showToast('มีคนเชื่อมต่ออยู่ จบการเชื่อมต่อก่อนแล้วค่อยอัปเดต');
      return;
    }
    setState(() {
      _stage = _UpdateStage.downloading;
      _progress = 0;
    });
    final client = HttpClient();
    try {
      final dir = Directory('${Directory.systemTemp.path}\\DEKSOR-update');
      await dir.create(recursive: true);
      final part = File('${dir.path}\\DEKSOR.exe.part');
      final target = File('${dir.path}\\DEKSOR.exe');
      final request =
          await client.getUrl(Uri.parse('$_kReleaseBase/DEKSOR.exe'));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final total = response.contentLength;
      var received = 0;
      var lastShown = 0.0;
      final sink = part.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            final p = received / total;
            if (p - lastShown >= 0.01 && mounted) {
              lastShown = p;
              setState(() => _progress = p);
            }
          }
        }
      } finally {
        await sink.close();
      }
      if (received < 5 * 1024 * 1024 || (total > 0 && received != total)) {
        throw const FileSystemException('Incomplete download');
      }
      if (await target.exists()) {
        await target.delete();
      }
      await part.rename(target.path);
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _stage = _UpdateStage.restarting;
      });
      await _applyAndRestart(dir, target);
    } catch (e) {
      debugPrint('DEK SOR update failed: $e');
      if (mounted) {
        setState(() => _stage = _UpdateStage.failed);
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _applyAndRestart(Directory dir, File newExe) async {
    final launcher = Platform.environment[_kLauncherEnvKey] ?? '';
    final installed = bind.mainIsInstalled();
    final lines = <String>['@echo off', 'chcp 65001 >nul'];
    if (installed) {
      lines.add(
          'powershell -NoProfile -WindowStyle Hidden -Command "Start-Process -FilePath \'${newExe.path}\' -ArgumentList \'--update\' -Verb RunAs"');
    } else {
      lines.addAll([
        'ping -n 3 127.0.0.1 >nul',
        'taskkill /F /IM rustdesk.exe >nul 2>&1',
        'ping -n 2 127.0.0.1 >nul',
      ]);
      if (launcher.isNotEmpty &&
          launcher.toLowerCase() != newExe.path.toLowerCase()) {
        lines.addAll([
          'copy /y "${newExe.path}" "$launcher" >nul 2>&1',
          'if errorlevel 1 (start "" "${newExe.path}") else (start "" "$launcher")',
        ]);
      } else {
        lines.add('start "" "${newExe.path}"');
      }
    }
    final script = File('${dir.path}\\apply.cmd');
    await script.writeAsString(lines.join('\r\n'));
    await Process.start('cmd', ['/c', script.path],
        mode: ProcessStartMode.detached);
    if (!installed) {
      await Future.delayed(const Duration(milliseconds: 800));
      exit(0);
    }
  }

  Widget _versionLine() {
    return Text.rich(
      const TextSpan(
        children: [
          TextSpan(text: 'v$kDeksorVersion · '),
          TextSpan(
            text: 'By RiDERth',
            style: TextStyle(color: DeksorColors.red),
          ),
        ],
      ),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: DeksorColors.mute,
      ),
    );
  }

  Widget _panel() {
    if (_stage == _UpdateStage.available) {
        return Row(
          children: [
            Expanded(
              child: Text(
                'มี v$_remoteVersion ใหม่',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: DeksorColors.goldText,
                ),
              ),
            ),
            SizedBox(
              width: 104,
              child: DeksorButton(
                label: 'อัปเดต',
                icon: Icons.download_rounded,
                color: DeksorColors.green,
                textColor: Colors.white,
                onTap: _update,
              ),
            ),
          ],
        );
    }
    if (_stage == _UpdateStage.downloading ||
        _stage == _UpdateStage.restarting) {
        final percent = (_progress * 100).clamp(0, 100).toStringAsFixed(0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _stage == _UpdateStage.restarting
                  ? 'เสร็จแล้ว กำลังเปิดตัวใหม่...'
                  : 'กำลังโหลด v$_remoteVersion · $percent%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DeksorColors.goldText,
              ),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: _stage == _UpdateStage.restarting ? null : _progress,
              minHeight: 6,
              backgroundColor: Colors.white,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(DeksorColors.green),
            ),
          ],
        );
    }
    if (_stage == _UpdateStage.failed) {
        return Row(
          children: [
            const Expanded(
              child: Text(
                'โหลดไม่สำเร็จ ตัวเดิมยังใช้ได้',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DeksorColors.goldText,
                ),
              ),
            ),
            SizedBox(
              width: 104,
              child: DeksorButton(
                label: 'ลองใหม่',
                icon: Icons.refresh_rounded,
                color: DeksorColors.green,
                textColor: Colors.white,
                onTap: _update,
              ),
            ),
          ],
        );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_stage != _UpdateStage.idle)
          Material(
            color: const Color(0xFFFFF1D6),
            shape: deksorCut(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: _panel(),
            ),
          ).marginOnly(left: 14, right: 14, bottom: 8),
        _versionLine(),
      ],
    );
  }
}
