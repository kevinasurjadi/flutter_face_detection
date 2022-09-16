import 'dart:io';

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

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

  bool _cameraInitialized = false;

  Future<XFile> _capture() async {
    return _cameraController.takePicture();
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
      }
      setState(() {
        _cameraInitialized = true;
      });
    });
  }

  @override
  void initState() {
    _initializeCamera();
    super.initState();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _cameraInitialized
          ? ClipRect(
              child: OverflowBox(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height /
                        _cameraController.value.aspectRatio,
                    child: AspectRatio(
                      aspectRatio: _cameraController.value.aspectRatio,
                      child: CameraPreview(_cameraController),
                    ),
                  ),
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_cameraInitialized) {
            var image = await _capture();
            var faceDetector = FaceDetector(
              options: FaceDetectorOptions(enableClassification: true),
            );
            var faces = await faceDetector
                .processImage(InputImage.fromFilePath(image.path));
            var result = 'no face detected';
            if (faces.isNotEmpty) {
              result =
                  'Left Eye: ${faces[0].leftEyeOpenProbability}, Right Eye: ${faces[0].rightEyeOpenProbability}, Smile: ${faces[0].smilingProbability}';
            }
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(result)));
          }
        },
        tooltip: 'Capture',
        child: const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
