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
  late BehaviorSubject<CameraImage> _imageStream;

  bool _cameraInitialized = false;

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
    var faceDetector = FaceDetector(
      options: FaceDetectorOptions(enableClassification: true),
    );
    var faces = await faceDetector.processImage(_getInputImage(image));
    if (faces.isNotEmpty) {
      if (faces[0].leftEyeOpenProbability! < 0.25 &&
          faces[0].rightEyeOpenProbability! < 0.25) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _cameraController.stopImageStream();
          _capture();
        });
      }
      _faceStream.add(faces[0]);
    }
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
        _cameraController.startImageStream((image) {
          _imageStream.add(image);
        });
        _cameraInitialized = true;
      });
    });
  }

  @override
  void initState() {
    _initializeCamera();
    _faceStream = BehaviorSubject();
    _imageStream = BehaviorSubject()
      ..debounceTime(const Duration(milliseconds: 500));
    _imageStream.listen((image) {
      _processImage(image);
    });
    super.initState();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _faceStream.close();
    _imageStream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          _cameraInitialized
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
              : const Center(
                  child: CircularProgressIndicator(),
                ),
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
