import 'dart:isolate';
import 'package:flutter/material.dart';
import 'enhanced_paginator.dart';

class PaginationIsolateParams {
  final String text;
  final double screenWidth;
  final double screenHeight;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final String? fontFamily;
  final List<String>? fontFamilyFallback;
  final double paddingLeft;
  final double paddingRight;
  final double paddingTop;
  final double paddingBottom;
  final bool supportImages;
  final SendPort sendPort;

  PaginationIsolateParams({
    required this.text,
    required this.screenWidth,
    required this.screenHeight,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.fontFamily,
    required this.fontFamilyFallback,
    required this.paddingLeft,
    required this.paddingRight,
    required this.paddingTop,
    required this.paddingBottom,
    required this.supportImages,
    required this.sendPort,
  });
}

class PaginationIsolateResult {
  final List<String> pages;
  final List<int> pageCharOffsets;

  PaginationIsolateResult({
    required this.pages,
    required this.pageCharOffsets,
  });
}

Future<void> paginationIsolateEntry(PaginationIsolateParams params) async {
  try {
    final result = await EnhancedPaginator.paginatePrecise(
      text: params.text,
      screenSize: Size(params.screenWidth, params.screenHeight),
      fontSize: params.fontSize,
      lineHeight: params.lineHeight,
      padding: EdgeInsets.fromLTRB(
        params.paddingLeft,
        params.paddingTop,
        params.paddingRight,
        params.paddingBottom,
      ),
      letterSpacing: params.letterSpacing,
      fontFamily: params.fontFamily,
      fontFamilyFallback: params.fontFamilyFallback,
      supportImages: params.supportImages,
    );
    params.sendPort.send(
      PaginationIsolateResult(
        pages: result.pages,
        pageCharOffsets: result.pageCharOffsets,
      ),
    );
  } catch (e, stackTrace) {
    params.sendPort.send({
      'error': e.toString(),
      'stack': stackTrace.toString(),
    });
  }
}
