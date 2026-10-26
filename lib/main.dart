import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_saver/flutter_file_saver.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

void main() => runApp(const QRGeneratorApp());

class QRGeneratorApp extends StatelessWidget {
  const QRGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QR Generator',
      theme: buildAppTheme(),
      home: const QRHomePage(),
    );
  }
}

class QRHomePage extends StatefulWidget {
  const QRHomePage({super.key});

  @override
  State<QRHomePage> createState() => _QRHomePageState();
}

class _QRHomePageState extends State<QRHomePage> {
  final _controller = TextEditingController();

  String? _qrData;
  String? _error;
  bool _isProcessing = false;
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('qr_history') ?? [];

      if (mounted) {
        setState(() => _history = saved);
      }
    } catch (_) {
      // The generator remains usable if history cannot be loaded.
    }
  }

  Future<void> _remember(String value) async {
    final updated = [
      value,
      ..._history.where((item) => item != value),
    ].take(10).toList();

    setState(() => _history = updated);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('qr_history', updated);
    } catch (_) {
      _showMessage('QR generated, but history could not be saved.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateInput(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      return 'Please enter text or a URL.';
    }

    final looksLikeUrl =
        text.contains('://') ||
        text.toLowerCase().startsWith('www.') ||
        RegExp(
          r'^[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+(:\d+)?([/?#].*)?$',
        ).hasMatch(text);

    if (!looksLikeUrl) return null;

    final candidate = text.toLowerCase().startsWith('www.')
        ? 'https://$text'
        : text;

    final uri = Uri.tryParse(candidate);

    if (uri == null ||
        !['http', 'https'].contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        (!uri.host.contains('.') && uri.host != 'localhost')) {
      return 'Please enter a valid HTTP or HTTPS URL.';
    }

    return null;
  }

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();

    final value = _controller.text.trim();
    final validationError = _validateInput(value);

    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _error = null;
      _qrData = value;
    });

    await _remember(value);
  }

  void _clear() {
    _controller.clear();

    setState(() {
      _qrData = null;
      _error = null;
    });
  }

  void _openHistoryItem(String value) {
    _controller.text = value;

    setState(() {
      _qrData = value;
      _error = null;
    });
  }

  Future<void> _removeHistoryItem(String value) async {
    final updated = _history.where((item) => item != value).toList();

    setState(() => _history = updated);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('qr_history', updated);
    } catch (_) {
      _showMessage('Could not update history.');
    }
  }

  Future<Uint8List?> _getQrImageBytes() async {
    final data = _qrData;
    if (data == null) return null;

    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
    );

    final ByteData? imageData = await painter.toImageData(
      320,
      format: ui.ImageByteFormat.png,
    );

    return imageData?.buffer.asUint8List();
  }

  Future<void> _saveQrCode() async {
    if (_qrData == null || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final bytes = await _getQrImageBytes();

      if (bytes == null) {
        _showMessage('Could not create the QR image.');
        return;
      }

      await FlutterFileSaver().writeFileAsBytes(
        fileName: 'qr_code.png',
        bytes: bytes,
      );

      _showMessage('QR code saved successfully.');
    } catch (e) {
      _showMessage('Could not save QR code. Please try again.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _shareQrCode() async {
    if (_qrData == null || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final bytes = await _getQrImageBytes();

      if (bytes == null) {
        _showMessage('Could not create the QR image.');
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          title: 'QR Code',
          text: 'QR code for: $_qrData',
          files: [XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: ['qr_code.png'],
        ),
      );
    } catch (e) {
      _showMessage('Could not share QR code. Please try again.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _copyText() async {
    if (_qrData == null) return;

    await Clipboard.setData(ClipboardData(text: _qrData!));
    _showMessage('Text copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, size: 29),
            SizedBox(width: 10),
            Text('QR Generator'),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF123B70), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Your QR Code',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Turn text or a website into a QR code.',
                              style: TextStyle(
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(
                        Icons.qr_code_2_rounded,
                        color: Colors.white,
                        size: 68,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your content',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _controller,
                          maxLines: 3,
                          minLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) {
                            if (_error != null) {
                              setState(() => _error = null);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter text or https://example.com',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 42),
                              child: Icon(Icons.edit_note_rounded),
                            ),
                            errorText: _error,
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _isProcessing ? null : _generate,
                          icon: const Icon(Icons.qr_code_rounded),
                          label: const Text('Generate QR Code'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isProcessing ? null : _clear,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isProcessing) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_qrData != null) ...[
                  const SizedBox(height: 22),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            'Your QR Code',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE8EEF6),
                              ),
                            ),
                            child: QrImageView(
                              data: _qrData!,
                              version: QrVersions.auto,
                              size: 220,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SelectableText(
                            _qrData!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(height: 1.5),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isProcessing ? null : _saveQrCode,
                                  icon: const Icon(Icons.download_rounded),
                                  label: const Text('Save'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isProcessing
                                      ? null
                                      : _shareQrCode,
                                  icon: const Icon(Icons.share_rounded),
                                  label: const Text('Share'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              onPressed: _copyText,
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Copy Text'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Recent QR History',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('qr_history');

                          if (mounted) {
                            setState(() => _history = []);
                          }
                        },
                        child: const Text('Clear history'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        for (int i = 0; i < _history.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFEFF6FF),
                              child: Icon(
                                Icons.qr_code_2_rounded,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            title: Text(
                              _history[i],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _openHistoryItem(_history[i]),
                            trailing: IconButton(
                              tooltip: 'Remove from history',
                              onPressed: () => _removeHistoryItem(_history[i]),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'QR Generator â€¢ Simple, fast and useful',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
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
