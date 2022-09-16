import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_face_detection/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var cameras = await availableCameras();
  runApp(App(
    availableCameras: cameras,
  ));
}

class App extends StatelessWidget {
  final List<CameraDescription> availableCameras;

  const App({required this.availableCameras, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Face Detection',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(
        title: 'Flutter Face Detection',
        availableCameras: availableCameras,
      ),
    );
  }
}
