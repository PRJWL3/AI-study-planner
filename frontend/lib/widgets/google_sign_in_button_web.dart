import 'package:flutter/material.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

Widget buildGoogleSignInButton({
  required Widget child,
}) {
  return Stack(
    alignment: Alignment.center,
    children: [
      child,
      Positioned.fill(
        child: Opacity(
          opacity: 0.01,
          child: (GoogleSignInPlatform.instance as web.GoogleSignInPlugin).renderButton(
            configuration: web.GSIButtonConfiguration(
              type: web.GSIButtonType.standard,
              theme: web.GSIButtonTheme.outline,
              size: web.GSIButtonSize.large,
            ),
          ),
        ),
      ),
    ],
  );
}
