import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shh_app/services/crypto_service.dart';

class SafetyNumberScreen extends StatefulWidget {
  final String myIdentityKey;
  final String theirIdentityKey;
  final String remoteUsername;

  const SafetyNumberScreen({
    Key? key,
    required this.myIdentityKey,
    required this.theirIdentityKey,
    required this.remoteUsername,
  }) : super(key: key);

  @override
  _SafetyNumberScreenState createState() => _SafetyNumberScreenState();
}

class _SafetyNumberScreenState extends State<SafetyNumberScreen> {
  String? safetyNumber;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _computeSafetyNumber();
  }

  void _computeSafetyNumber() {
    setState(() {
      safetyNumber = CryptoService.generateSafetyNumber(
        widget.myIdentityKey,
        widget.theirIdentityKey,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vérifier ${widget.remoteUsername}'),
        actions: [
          IconButton(
            icon: Icon(isScanning ? Icons.close : Icons.qr_code_scanner),
            onPressed: () {
              setState(() {
                isScanning = !isScanning;
              });
            },
          ),
        ],
      ),
      body: isScanning ? _buildScanner() : _buildSafetyNumberDisplay(),
    );
  }

  Widget _buildScanner() {
    return MobileScanner(
      onDetect: (capture) {
        final List<Barcode> barcodes = capture.barcodes;
        for (final barcode in barcodes) {
          if (barcode.rawValue != null) {
            _verifyScannedCode(barcode.rawValue!);
            break; // Stop after first valid code
          }
        }
      },
    );
  }

  void _verifyScannedCode(String code) {
    if (code == safetyNumber) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Identité VÉRIFIÉE ✓'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        isScanning = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ECHEC de la vérification - Code incorrect !'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSafetyNumberDisplay() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.shield_outlined, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            Text(
              'Numéro de sécurité avec ${widget.remoteUsername}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const Text(
              'Comparez ce numéro avec celui sur l\'appareil de votre contact.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            if (safetyNumber != null) ...[
              QrImageView(
                data: safetyNumber!,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 32),
              Text(
                safetyNumber!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Monospace',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
            ] else
              const CircularProgressIndicator(),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Si les numéros correspondent, vous êtes protégé contre les attaques de type 'Man-In-The-Middle'.",
                      style: TextStyle(fontSize: 12),
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
}
