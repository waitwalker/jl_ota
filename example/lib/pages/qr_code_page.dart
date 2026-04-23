import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jl_ota_example/widgets/toast_utils.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_localizations.dart';
import '../utils/app_util.dart';
import '../utils/permission_util.dart';
import '../widgets/scan_frame.dart';
import '../widgets/scan_overlay.dart';

/// The main class for the QR code scanning page, responsible for managing the state and logic of the entire page.
class QrCodePage extends StatefulWidget {
  final Function(String)? onScanResult;

  const QrCodePage({super.key, this.onScanResult});

  @override
  State<QrCodePage> createState() => _QrCodePageState();
}

class _QrCodePageState extends State<QrCodePage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  MobileScannerController? cameraController;
  bool _hasGalleryPermission = false;
  bool _isScanning = true;
  bool _isControllerInitialized = false;
  bool _isControllerStarting = false;
  late AnimationController _scanLineController;
  late Animation<Offset> _scanLineAnimation;
  bool _isProcessingGallery = false;
  StreamSubscription<BarcodeCapture>? _barcodeSubscription;
  double _dragStartX = 0;
  bool _isDragging = false;
  Completer<void>? _resultCompleter;
  static const double _kDragCloseThreshold = 0.25; // 滑动关闭阈值（屏幕宽度百分比）
  static final isAndroid = AppUtil.isAndroid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initializeCameraController(isAndroid);

    _scanLineController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
    _scanLineAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(0, 1)).animate(_scanLineController);

    _scanLineController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _scanLineController.reset();
        _scanLineController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return GestureDetector(
      onHorizontalDragStart: (details) {
        _dragStartX = details.globalPosition.dx;
        _isDragging = true;
      },
      onHorizontalDragUpdate: (details) {
        if (!_isDragging) return;

        // 计算滑动距离百分比
        double dragDistance = details.globalPosition.dx - _dragStartX;
        double dragPercentage = dragDistance / MediaQuery.of(context).size.width;

        // 使用阈值进行判断
        bool reachedCloseThreshold = dragPercentage > _kDragCloseThreshold;
        bool shouldClose = !isAndroid && reachedCloseThreshold;

        if (reachedCloseThreshold) {
          if (shouldClose) {
            Navigator.of(context).pop();
          }
          _isDragging = false;
        }
      },
      onHorizontalDragEnd: (details) {
        _isDragging = false;
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            loc.scanQrcode,
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: Image.asset('assets/images/icon_return_white.png', width: 28, height: 28),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: () async {
                if (isAndroid) {
                  if (_hasGalleryPermission && !_isProcessingGallery) {
                    _openGallery(isAndroid);
                  } else {
                    await _requestGalleryPermission(isAndroid);
                  }
                } else {
                  _openGallery(isAndroid);
                }
              },
              child: Text(
                loc.photos,
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        body: Stack(
          children: [
            _isControllerInitialized && !_isProcessingGallery
                ? MobileScanner(
                    controller: cameraController!,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty && _isScanning) {
                        final String code = barcodes.first.rawValue ?? '';
                        _handleScanResult(code, isAndroid);
                      } else if (barcodes.isEmpty && _isScanning) {
                        ToastUtils.show(context, AppLocalizations.of(context)!.notFoundQRCode);
                        _initializeCameraController(isAndroid);
                      }
                    },
                  )
                : Container(),

            // 遮罩层
            const ScanOverlay(),

            // 扫描框、扫描线和四角
            ScanFrame(scanLineAnimation: _scanLineAnimation, hintText: loc.qrcodeIntoBox),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _barcodeSubscription?.cancel(); // Cancel subscription
    if (_isControllerInitialized) {
      cameraController?.dispose();
    }
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && _isControllerInitialized && !_isProcessingGallery) {
      // When app resumes, restart camera if needed
      if (_isScanning && mounted && !_isControllerStarting) {
        _startCameraWithRetry();
      }
    } else if (state == AppLifecycleState.paused && _isControllerInitialized) {
      // When app pauses, stop camera
      cameraController?.stop();
    }
  }

  void _initializeCameraController(bool isAndroid) {
    if (_isControllerInitialized) {
      cameraController?.dispose();
      _barcodeSubscription?.cancel();
    }

    cameraController = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
      autoStart: false, // Don't auto-start, we'll start manually
    );

    // Listen for controller state changes
    _barcodeSubscription = cameraController?.barcodes.listen((barcode) {
      if (barcode.barcodes.isNotEmpty && _isScanning) {
        final String code = barcode.barcodes.first.rawValue ?? '';
        _handleScanResult(code, isAndroid);
      }
    });

    setState(() {
      _isControllerInitialized = true;
      _isControllerStarting = false;
    });

    // Start the camera after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isControllerInitialized) {
        _startCameraWithRetry();
      }
    });
  }

  Future<void> _startCameraWithRetry() async {
    if (_isControllerStarting || !_isControllerInitialized) return;

    setState(() {
      _isControllerStarting = true;
    });

    try {
      await cameraController?.start();
    } catch (e) {
      log("Error starting camera: $e");
      // Retry after a delay if failed
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _isControllerInitialized) {
            _startCameraWithRetry();
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isControllerStarting = false;
        });
      }
    }
  }

  Future<void> _handleScanResult(String result, bool isAndroid) async {
    // 如果已有正在处理的任务，直接返回
    if (_resultCompleter != null && !_resultCompleter!.isCompleted) {
      return;
    }

    _resultCompleter = Completer<void>();

    try {
      // 检查基本格式、验证URL格式、验证网络可访问性
      if (result.isEmpty || !AppUtil.isValidUrl(result) || !await AppUtil.isFileAccessible(result)) {
        if (mounted) {
          ToastUtils.show(context, result);
        }
        _resultCompleter!.complete();
        return;
      }

      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }

      if (_isControllerInitialized) {
        cameraController?.stop();
      }

      if (isAndroid) {
        widget.onScanResult?.call(result);
      }

      if (mounted) {
        Navigator.of(context).pop(result);
      }

      _resultCompleter!.complete();
    } catch (e) {
      _resultCompleter!.completeError(e);
    }
  }

  Future<void> _requestGalleryPermission(bool isAndroid) async {
    try {
      final status = await PermissionUtil.requestGalleryPermission();

      if (mounted) {
        setState(() {
          _hasGalleryPermission = status.isGranted;
        });
      }

      if (status.isGranted) {
        _openGallery(isAndroid);
      } else {
        if (mounted) {
          ToastUtils.show(context, AppLocalizations.of(context)!.failPhotosSystemReason);
        }
      }
    } catch (e) {
      log("Gallery permission error: $e");
    }
  }

  Future<void> _openGallery(bool isAndroid) async {
    if (_isProcessingGallery) return;

    setState(() {
      _isProcessingGallery = true;
      _isScanning = false;
    });

    // 完全停止并释放相机控制器
    if (_isControllerInitialized) {
      await cameraController?.stop();
      await cameraController?.dispose();
      _barcodeSubscription?.cancel();
      setState(() {
        _isControllerInitialized = false;
      });
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final tempController = MobileScannerController(formats: [BarcodeFormat.qrCode]);

        try {
          final BarcodeCapture? capture = await tempController.analyzeImage(pickedFile.path);

          if (capture != null && capture.barcodes.isNotEmpty) {
            final String code = capture.barcodes.first.rawValue ?? '';
            _handleScanResult(code, isAndroid);
          } else {
            if (mounted) {
              ToastUtils.show(context, AppLocalizations.of(context)!.notFoundQRCode);
            }
            _initializeCameraController(isAndroid);
          }
        } finally {
          tempController.dispose();
        }
      } else {
        _initializeCameraController(isAndroid);
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, AppLocalizations.of(context)!.failPhotosSystemReason);
      }
      _initializeCameraController(isAndroid);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingGallery = false;
          _isScanning = true;
        });
      }
    }
  }
}
