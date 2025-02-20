// ignore_for_file: avoid_print

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macrotracker/AI/gemini.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:camerawesome/camerawesome_plugin.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  String _geminiResponse = '';
  String filePath = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CameraAwesomeBuilder.awesome(
            saveConfig: SaveConfig.photo(),
            onMediaTap: (mediaCapture) async {
              try {
                if (mediaCapture.status == MediaCaptureStatus.success) {
                  final path = mediaCapture.filePath;
                  if (path != null) {
                    final response = await processImageWithGemini(path);
                    setState(() {
                      _geminiResponse = response;
                    });
                  }
                }
              } catch (e) {
                setState(() {
                  _geminiResponse = 'Error: $e';
                });
              }
            },
            builder: (state, preview) {
              return Stack(
                children: [
                  preview,
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      color: Colors.black45,
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _geminiResponse,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
            theme: AwesomeTheme(
              bottomActionsBackgroundColor: Colors.transparent,
              buttonTheme: AwesomeButtonTheme(
                backgroundColor: Colors.white,
                iconColor: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
