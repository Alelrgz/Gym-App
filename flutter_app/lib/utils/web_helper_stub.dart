import 'package:flutter/material.dart';

/// Stub — platform-specific implementation selected via conditional import.

/// Register an HTML iframe with the given [viewId] and [src] URL.
/// Returns [viewId] on web, null on native.
String? registerIframe(String viewId, String src,
    {String? allow, Function(dynamic)? onCreated}) {
  return null;
}

/// Evaluate JavaScript code. No-op on native.
void evalJs(String code) {}

/// Load an external script tag by [id] and [src]. No-op on native.
void loadScript(String id, String src) {}

/// Check if a script with [id] is already loaded. Always false on native.
bool isScriptLoaded(String id) => false;

/// Post a message to an iframe's contentWindow. No-op on native.
void postMessageToIframe(dynamic iframe, String message, String origin) {}

/// Returns an HtmlElementView for web, or a placeholder for native.
Widget iframeView(String? viewType) => const SizedBox.shrink();
