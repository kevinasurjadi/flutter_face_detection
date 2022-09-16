import 'dart:io';

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  void _capture() async {
    await _cameraController.takePicture();
  }

  void _initializeCamera() async {
    var selectedCamera =
        widget.availableCameras[widget.availableCameras.length > 1 ? 1 : 0];
    _cameraController =
        CameraController(selectedCamera, ResolutionPreset.medium);
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
        onPressed: () {
          if (_cameraInitialized) {
            _capture();
          }
        },
        tooltip: 'Capture',
        child: const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
