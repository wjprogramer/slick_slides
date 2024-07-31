import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:slick_slides/slick_slides.dart';
import 'package:slick_slides/src/widgets/device_frame.dart';

class DeviceSlide extends Slide {
  DeviceSlide({
    String? title,
    required Widget app,
    FormattedCode? formattedCode,
    List<String>? bullets,
    SlickTransition? transition,
    final SlideThemeData? theme,
    Duration? autoplayDuration,
    String? notes,
    Source? audioSource,
  }) : super(
          builder: (context) {
            return ContentLayout(
              title: title != null ? Text(title) : null,
              content: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (formattedCode != null)
                    Expanded(
                      child: ColoredCode(
                        code: formattedCode.code,
                      ),
                    ),
                  if (bullets != null)
                    Expanded(
                      child: Bullets(
                        bullets: bullets,
                      ),
                    ),
                  DeviceFrame(
                    child: app,
                  ),
                ],
              ),
            );
          },
          onPrecache: (context) async {
            DeviceFrame.precache(context);
          },
          notes: notes,
          transition: transition,
          theme: theme,
          autoplayDuration: autoplayDuration,
          audioSource: audioSource,
        );
}
