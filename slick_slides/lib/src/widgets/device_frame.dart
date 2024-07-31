import 'package:flutter/material.dart';

const _deviceFrameAsset = 'assets/device-frame.webp';
const _deviceFrameAssetPackage = 'slick_slides';
const _deviceFrameSize = Size(1071, 2048);
const _deviceResolution = Size(804, 1735);
const _deviceResolutionScale = 3.0;

class DeviceFrame extends StatelessWidget {
  const DeviceFrame({
    super.key,
    required this.child,
    this.scale = 1.0,
    this.theme,
  });

  final Widget child;
  final double scale;
  final ThemeData? theme;

  static Future<void> precache(BuildContext context) async {
    await precacheImage(
      const AssetImage(
        _deviceFrameAsset,
        package: _deviceFrameAssetPackage,
      ),
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    var appTheme = theme ??
        ThemeData(
            colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ));

    return Focus(
      canRequestFocus: false,
      child: Transform.scale(
        scale: 1.15,
        child: AspectRatio(
          aspectRatio: _deviceFrameSize.width / _deviceFrameSize.height,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: _deviceFrameSize.width,
              height: _deviceFrameSize.height,
              child: Stack(
                children: [
                  Image.asset(
                    _deviceFrameAsset,
                    package: _deviceFrameAssetPackage,
                  ),
                  Positioned(
                    left: 134,
                    top: 161,
                    width: 804,
                    height: 1735,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(106),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FittedBox(
                        fit: BoxFit.fitWidth,
                        child: SizedBox(
                          width: _deviceResolution.width /
                              (_deviceResolutionScale * scale),
                          height: _deviceResolution.height /
                              (_deviceResolutionScale * scale),
                          child: MaterialApp(
                            theme: appTheme,
                            debugShowCheckedModeBanner: false,
                            home: child,
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
