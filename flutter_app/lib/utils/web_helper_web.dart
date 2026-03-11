// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Register an HTML iframe with the given [viewId] and [src] URL.
/// Returns [viewId] on success.
String? registerIframe(String viewId, String src,
    {String? allow, Function(dynamic)? onCreated}) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final iframe = html.IFrameElement()
      ..src = src
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.borderRadius = '12px'
      ..allowFullscreen = true;
    if (allow != null) iframe.allow = allow;
    if (onCreated != null) onCreated(iframe);
    return iframe;
  });
  return viewId;
}

/// Evaluate JavaScript code in the page.
void evalJs(String code) {
  final script = html.ScriptElement()..text = code;
  html.document.body!.append(script);
  script.remove();
}

/// Load an external script tag by [id] and [src].
void loadScript(String id, String src) {
  if (html.document.querySelector('#$id') != null) return;
  final script = html.ScriptElement()
    ..id = id
    ..src = src;
  html.document.head!.append(script);
}

/// Check if a script with [id] is already loaded.
bool isScriptLoaded(String id) {
  return html.document.querySelector('#$id') != null;
}

/// Post a message to an iframe's contentWindow.
void postMessageToIframe(dynamic iframe, String message, String origin) {
  if (iframe is html.IFrameElement) {
    iframe.contentWindow?.postMessage(message, origin);
  }
}

/// Returns an HtmlElementView for the registered [viewType].
Widget iframeView(String? viewType) {
  if (viewType == null) return const SizedBox.shrink();
  return HtmlElementView(viewType: viewType);
}
