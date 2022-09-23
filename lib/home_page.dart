import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:rxdart/rxdart.dart';

class HomePage extends StatefulWidget {
  final String title;
  final List<CameraDescription> availableCameras;

  const HomePage(
      {required this.title, required this.availableCameras, Key? key})
      : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late CameraController _cameraController;
  late BehaviorSubject<Face> _faceStream;
  late FaceDetector _faceDetector;

  bool _isProcessingImage = false;

  bool _cameraInitialized = false;

  Rect? _faceBox;

  Future<XFile> _capture() async {
    return _cameraController.takePicture();
  }

  InputImage _getInputImage(CameraImage image) {
    var allBytes = WriteBuffer();
    for (var plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    var bytes = allBytes.done().buffer.asUint8List();

    var imageSize = Size(image.width.toDouble(), image.height.toDouble());

    var imageRotation = InputImageRotationValue.fromRawValue(
        _cameraController.description.sensorOrientation);

    var imageFormat = InputImageFormatValue.fromRawValue(image.format.raw);

    var planeData = image.planes
        .map(
          (plane) => InputImagePlaneMetadata(
            bytesPerRow: plane.bytesPerRow,
            width: plane.width,
            height: plane.height,
          ),
        )
        .toList();

    var imageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation!,
      inputImageFormat: imageFormat!,
      planeData: planeData,
    );

    return InputImage.fromBytes(bytes: bytes, inputImageData: imageData);
  }

  void _processImage(CameraImage image) async {
    _isProcessingImage = true;
    var faces = await _faceDetector.processImage(_getInputImage(image));
    if (faces.isNotEmpty) {
      if (faces[0].leftEyeOpenProbability! < 0.25 &&
          faces[0].rightEyeOpenProbability! < 0.25) {
        Future.delayed(const Duration(milliseconds: 500), () async {
          await _cameraController.stopImageStream();
          _capture();
        });
      }
      _faceBox = faces[0].boundingBox;
      _faceStream.add(faces[0]);
    }
    _isProcessingImage = false;
  }

  void _initializeCamera() async {
    var selectedCamera =
        widget.availableCameras[widget.availableCameras.length > 1 ? 1 : 0];
    _cameraController = CameraController(selectedCamera, ResolutionPreset.high);
    _cameraController.initialize().then((_) async {
      var androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.isPhysicalDevice != null &&
          !androidInfo.isPhysicalDevice!) {
        await _cameraController
            .lockCaptureOrientation(DeviceOrientation.landscapeLeft);
      } else {
        await _cameraController
            .lockCaptureOrientation(DeviceOrientation.portraitUp);
      }
      setState(() {
        _cameraController.startImageStream((image) {
          if (!_isProcessingImage && !_cameraController.value.isTakingPicture) {
            _processImage(image);
          }
        });
        _cameraInitialized = true;
      });
    });
  }

  @override
  void initState() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
      ),
    );
    _initializeCamera();
    _faceStream = BehaviorSubject();
    super.initState();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _faceStream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var screenRatio = MediaQuery.of(context).size.aspectRatio;
    var cameraRatio =
        _cameraInitialized ? _cameraController.value.aspectRatio : 1;
    var scale = screenRatio * cameraRatio;
    if (scale < 1) scale = 1 / scale;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          _cameraInitialized
              ? SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: Transform.scale(
                    scale: scale,
                    child: CameraPreview(_cameraController),
                  ),
                )
              : const Center(
                  child: CircularProgressIndicator(),
                ),
          _faceBox != null
              ? Positioned(
                  right: _faceBox!.left * _cameraController.value.aspectRatio,
                  top: _faceBox!.top * _cameraController.value.aspectRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.red,
                        width: 4,
                      ),
                    ),
                    width:
                        _faceBox!.width * _cameraController.value.aspectRatio,
                    height: _faceBox!.height *
                        _cameraController.value.aspectRatio /
                        2.5,
                  ),
                )
              : const SizedBox(),
          Positioned(
            top: 20,
            left: MediaQuery.of(context).size.width / 2 - 110 / 2,
            child: Container(
              width: 110,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Blink your eyes',
                style: TextStyle(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: MediaQuery.of(context).size.width / 2 - 170 / 2,
            child: Container(
              width: 170,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: StreamBuilder<Face>(
                stream: _faceStream,
                builder: (context, snapshot) {
                  return Column(
                    children: [
                      Text(
                        'Left Eye Probability: ${snapshot.hasData ? snapshot.data!.leftEyeOpenProbability : '-'}',
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Right Eye Probability: ${snapshot.hasData ? snapshot.data!.rightEyeOpenProbability : '-'}',
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Smiling Probability: ${snapshot.hasData ? snapshot.data!.smilingProbability : '-'}',
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
