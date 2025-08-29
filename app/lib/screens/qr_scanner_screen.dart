import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import '../providers/users_provider.dart';
import '../providers/auth_provider.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController controller = MobileScannerController();
  final _manualIdController = TextEditingController();
  bool _showManualInput = false;
  bool _isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    _manualIdController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        if (mounted) {
          _showPermissionDialog();
        }
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permission requise'),
        content: const Text(
          'L\'accès à la caméra est nécessaire pour scanner les QR codes. '
          'Vous pouvez également saisir l\'ID manuellement.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _showManualInput = true;
              });
            },
            child: const Text('Saisie manuelle'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: const Text('Paramètres'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleScanResult(String code) async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      final usersProvider = Provider.of<UsersProvider>(context, listen: false);
      await usersProvider.loadUser(code);
      
      if (mounted && usersProvider.selectedUser != null) {
        controller.stop();
        context.push('/user-details/$code');
      } else {
        _showErrorDialog('Utilisateur non trouvé', 
          'Aucun utilisateur trouvé avec ce QR code ou cet ID.');
      }
    } catch (e) {
      _showErrorDialog('Erreur de scan', e.toString());
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleManualSearch() async {
    final id = _manualIdController.text.trim();
    if (id.isEmpty) {
      _showErrorDialog('Erreur', 'Veuillez saisir un ID utilisateur.');
      return;
    }

    await _handleScanResult(id);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null || !user.canScanQR) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scanner QR')),
        body: const Center(
          child: Text(
            'Vous n\'avez pas l\'autorisation de scanner les QR codes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner QR Code'),
        actions: [
          IconButton(
            icon: Icon(_showManualInput ? Icons.qr_code_scanner : Icons.keyboard),
            onPressed: () {
              setState(() {
                _showManualInput = !_showManualInput;
              });
            },
            tooltip: _showManualInput ? 'Scanner QR' : 'Saisie manuelle',
          ),
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Text(
              _showManualInput
                  ? 'Saisissez l\'ID utilisateur pour rechercher ses informations'
                  : 'Pointez la caméra vers un QR code pour scanner les informations utilisateur',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Scanner or Manual input
          Expanded(
            child: _showManualInput ? _buildManualInput() : _buildQRScanner(),
          ),
        ],
      ),
    );
  }

  Widget _buildQRScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: controller,
          onDetect: (capture) {
            if (!_isProcessing && capture.barcodes.isNotEmpty) {
              final String? code = capture.barcodes.first.rawValue;
              if (code != null) {
                _handleScanResult(code);
              }
            }
          },
        ),
        
        // Simple overlay with instructions
        Positioned(
          bottom: 100,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Pointez la caméra vers un QR code',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        
        // Processing indicator
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Recherche en cours...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildManualInput() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          
          TextField(
            controller: _manualIdController,
            decoration: const InputDecoration(
              labelText: 'ID Utilisateur',
              hintText: 'Saisissez l\'ID ou le code utilisateur',
              prefixIcon: Icon(Icons.tag),
              border: OutlineInputBorder(),
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
            ),
            onSubmitted: (_) => _handleManualSearch(),
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _handleManualSearch,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_isProcessing ? 'Recherche...' : 'Rechercher'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
