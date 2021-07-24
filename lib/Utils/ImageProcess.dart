//
// Copyright (c) 2021, W. Wu,  all rights reserved.
// Third party copyrights are property of their respective owners.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
//   1. Redistributions of source code must retain the above copyright notice,
//      this list of conditions and the following disclaimer.
//
//   2. Redistributions in binary form must reproduce the above copyright notice,
//      this list of conditions and the following disclaimer in the documentation
//      and/or other materials provided with the distribution.
//
//   3. Neither the name of the copyright holder nor the names of its contributors
//      may be used to endorse or promote products derived from this software without
//      specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
// AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';

import 'package:pen_power/Utils/RotatingCalipers.dart';
import 'package:pen_power/Utils/Types.dart';

class ImageProcess {
  static final int _thumbnailWidth = 200;

  ui.Image _highlightImage;
  Offset _widgetOffset;
  Size _siblingSize;

  late Size _inputImageSize;
  late img.Image _fullcolorMask;
  late img.Image _binaryMask;
  late Map<int, List<int>> _connectedComponentsMap;
  late List<PenPowerLabel> _labels;

  ImageProcess(
      {required ui.Image image,
      required Offset widgetOffset,
      required Size siblingSize})
      : _highlightImage = image,
        _widgetOffset = widgetOffset,
        _siblingSize = siblingSize;

  Size get inputImageSize => _inputImageSize;
  img.Image get fullcolorMask => _fullcolorMask;
  img.Image get binaryMask => _binaryMask;
  Map<int, List<int>> get connectedComponentsMap => _connectedComponentsMap;

  //create thumbnail
  Future<Uint8List> getThumbnail(Uint8List jpgRawFile) async {
    return await compute(generateThumbnail, jpgRawFile);
  }

  static Uint8List generateThumbnail(Uint8List jpgRawFile) {
    img.Image inputImage = img.decodeJpg(jpgRawFile);
    img.Image thumbnailImage =
        img.copyResize(inputImage, width: _thumbnailWidth);
    return Uint8List.fromList(img.encodeJpg(thumbnailImage));
  }

  //get label
  Future<List<PenPowerLabel>> getLabels(Uint8List rawData) async {
    try {
      //get the image size (for scale the mask)
      _inputImageSize = jpegImageSize(rawData);
      //scale the mask(fullcolor)
      _fullcolorMask = await createFullcolorMask();
      //convert to binary
      _binaryMask = await compute(createBinaryMask, _fullcolorMask);
      //connected-components labeling
      _connectedComponentsMap =
          await compute(connectedComponentLabeling, _binaryMask);

      _labels = await minAreaRect();
      return _labels;
    } catch (exp) {
      return Future.error(exp);
    }
  }

  //read JPEG
  static Size jpegImageSize(Uint8List rawData) {
    int readerIndex = 2;

    while (readerIndex < rawData.length) {
      try {
        Uint8List frame = frameReader(rawData, readerIndex);
        if (frame[1] == 0xC0 || frame[1] == 0xC2) {
          int width = raw2Int(frame.sublist(7, 9));
          int height = raw2Int(frame.sublist(5, 7));
          return Size(width.toDouble(), height.toDouble());
        } else {
          readerIndex = readerIndex + frame.length;
        }
      } on Exception catch (exp) {
        throw Exception(exp);
      }
    }
    throw Exception("Could not find the image size from this jpeg file");
  }

  static Uint8List frameReader(Uint8List binary, int start) {
    int frameStart = binary[start].toInt();
    if (frameStart != 0xFF) throw Exception("Unkown header format");
    int frameLength = raw2Int(binary.sublist(start + 2, start + 4)) + 2;
    return binary.sublist(start, start + frameLength);
  }

  static int raw2Int(Uint8List raw) {
    int value = 0;
    raw.forEach((element) {
      value = value << 8 | element;
    });
    return value;
  }

  //get fullcolor mask
  Future<img.Image> createFullcolorMask() async {
    //get byte data
    ByteData? byteData =
        await _highlightImage.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) {
      return Future.error("byteData==null");
    }

    //create mask image
    img.Image mask = img.Image.fromBytes(_highlightImage.width,
        _highlightImage.height, byteData.buffer.asUint8List(),
        format: img.Format.rgba);
    //remove useless area (keep the area that overlap with the input image)
    mask = img.copyCrop(
        mask,
        _widgetOffset.dx.round(),
        _widgetOffset.dy.round(),
        _siblingSize.width.round(),
        _siblingSize.height.round());
    //resize the mask which let the mask is same size as input image
    mask = img.copyResize(mask,
        width: _inputImageSize.width.round(),
        height: _inputImageSize.height.round());

    return mask;
  }

  //fullcolor -> binary
  static Future<img.Image> createBinaryMask(img.Image fullcolorMask) async {
    List<int> binaryMaskList = [];

    fullcolorMask.data.forEach((pixel) {
      // #RRGGBBAA
      int alpha = pixel & 0x000000FF;

      if (alpha == 0) {
        binaryMaskList.add(0);
      } else {
        binaryMaskList.add(255);
      }
    });

    img.Image binaryMaskImage = img.Image.fromBytes(
        fullcolorMask.width, fullcolorMask.height, binaryMaskList,
        format: img.Format.luminance);

    return binaryMaskImage;
  }

  //connected-components labeling
  static Map<int, List<int>> connectedComponentLabeling(img.Image binaryMask) {
    // mask = #AABBGGRR

    List<int> equivalentLabels = [0];
    List<int> labeled = [];
    int globalLabel = 1;

    int width = binaryMask.width;
    int length = binaryMask.data.length;

    //Using Two-pass

    ///
    ///first pass
    ///

    for (int index = 0; index < length; ++index) {
      if (isColorBlack(binaryMask.data[index])) {
        labeled.add(0);
        continue;
      }
      List<int>? neighborLabel = getNeighborLabel(labeled, index, width);
      if (neighborLabel == null) {
        labeled.add(globalLabel);
        equivalentLabels.add(globalLabel);
        ++globalLabel;
      } else if (neighborLabel.length == 1) {
        labeled.add(neighborLabel[0]);
      } else {
        labeled.add(neighborLabel[0]);
        for (int i = 1; i < neighborLabel.length; ++i) {
          if (equivalentLabels[neighborLabel[i]] > neighborLabel[0])
            equivalentLabels[neighborLabel[i]] = neighborLabel[0];
        }
      }
    }

    //make sure that all of the connected labels point to the smallest one
    for (int checkIndex = 2;
        checkIndex < equivalentLabels.length;
        ++checkIndex) {
      int newIndex = checkIndex;
      while (equivalentLabels[newIndex] != newIndex) {
        newIndex = equivalentLabels[newIndex];
      }
      equivalentLabels[checkIndex] = newIndex;
    }

    Map<int, List<int>> reduceMap = Map();

    //second pass
    for (int pixelIndex = 0; pixelIndex < labeled.length; ++pixelIndex) {
      //skip background
      if (labeled[pixelIndex] == 0) continue;

      if (reduceMap[equivalentLabels[labeled[pixelIndex]]] == null) {
        reduceMap[equivalentLabels[labeled[pixelIndex]]] = [];
        reduceMap[equivalentLabels[labeled[pixelIndex]]]!.add(pixelIndex);
      } else {
        reduceMap[equivalentLabels[labeled[pixelIndex]]]!.add(pixelIndex);
      }
    }

    return reduceMap;
  }

  static List<int>? getNeighborLabel(List<int> label, int index, int width) {
    List<int> neighborLabel = [];

    //top-left
    if (index - width - 1 > 0 && (index - width - 1) % width != (width - 1)) {
      if (label[index - width - 1] != 0)
        neighborLabel.add(label[index - width - 1]);
    }
    //top-center
    if (index - width > 0) {
      if (label[index - width] != 0) neighborLabel.add(label[index - width]);
    }
    //top-right
    if (index - width + 1 > 0 && (index - width + 1) % width != 0) {
      if (label[index - width + 1] != 0)
        neighborLabel.add(label[index - width + 1]);
    }
    //left
    if (index - 1 > 0 && (index - 1) % width != (width - 1)) {
      if (label[index - 1] != 0) neighborLabel.add(label[index - 1]);
    }

    if (neighborLabel.length == 0)
      return null;
    else {
      neighborLabel.sort();
      return neighborLabel;
    }
  }

  static bool isColorBlack(int pixel) {
    //binary image -> check r,g,b != 0
    return (pixel & 0x00FFFFFF == 0);
  }

  //minAreaRect
  Future<List<PenPowerLabel>> minAreaRect() async {
    List<Future<PenPowerLabel>> isolates = [];

    try {
      _connectedComponentsMap.forEach((key, label) {
        isolates.add(compute(singleLabelProcessing,
            Tuple2(label, _inputImageSize.width.round())));
      });
      return await Future.wait(isolates);
    } catch (error) {
      return Future.error(error);
    }
  }

  List<PenPowerLabel> minAreaRectSync() {
    List<PenPowerLabel> labels = [];
    try {
      _connectedComponentsMap.forEach((key, label) {
        labels.add(singleLabelProcessing(
            Tuple2(label, _inputImageSize.width.round())));
      });
      return labels;
    } catch (error) {
      throw Exception(error);
    }
  }

  static PenPowerLabel singleLabelProcessing(Tuple2 data) {
    // create PenPowerPixel list
    List<PenPowerPixel> pixels = (data.item1 as List)
        .map((pixel) =>
            PenPowerPixel.from1Dimention(position1D: pixel, width: data.item2))
        .toList();

    //calculate convex hull
    List<PenPowerPixel> hulls = convexHull(pixels);

    //calculate rotating calipers
    List<Point<double>> vectors = RotatingCalipers.rotatingCalipers(hulls);

    double centerX = vectors[0].x + (vectors[1].x + vectors[2].x) * 0.5;
    double centerY = vectors[0].y + (vectors[1].y + vectors[2].y) * 0.5;
    double width =
        sqrt(vectors[1].x * vectors[1].x + vectors[1].y * vectors[1].y);
    double height =
        sqrt(vectors[2].x * vectors[2].x + vectors[2].y * vectors[2].y);

    //check if parallel to the y-axis
    //double angle = atan2(vectors[1].y, vectors[1].x);
    double angle = (vectors[1].x == 0 && vectors[1].y != 0)
        ? (pi / 2)
        : atan2(vectors[1].y, vectors[1].x);

    return PenPowerLabel(
      center: Point(centerX, centerY),
      size: Size(width, height),
      angle: angle,
    );
  }

  static List<PenPowerPixel> convexHull(List<PenPowerPixel> pixels) {
    ///
    /// Andrew's monotone chain convex hull algorithm
    ///

    pixels.sort();
    List<PenPowerPixel> convexHull = [];

    //lower hull
    convexHull.addAll(buildHull(pixels));
    convexHull.removeLast();

    //upper hull
    convexHull.addAll(buildHull(pixels.reversed.toList()));
    convexHull.removeLast();

    return convexHull;
  }

  static List<PenPowerPixel> buildHull(List<PenPowerPixel> pixels) {
    List<PenPowerPixel> hull = [];
    pixels.forEach((pixel) {
      // hull.length >=2 and
      while (hull.length >= 2 &&
          crossProduct3Point(
                hull[hull.length - 2].position2D,
                hull.last.position2D,
                pixel.position2D,
              ) <=
              0) hull.removeLast();
      hull.add(pixel);
    });

    return hull;
  }

  static double crossProduct3Point(
      Point<double> o, Point<double> a, Point<double> b) {
    // Line OA and Line OB
    // counter-clockwise turn -> positive
    // clockwise turn         -> negative
    // collinear              -> zero
    Point<double> oa = a - o;
    Point<double> ob = b - o;
    return crossProduct2D(oa, ob);
  }

  static double crossProduct2D(Point<double> oa, Point<double> ob) {
    // Line OA and Line OB
    // counter-clockwise turn -> positive
    // clockwise turn         -> negative
    // collinear              -> zero
    return oa.x * ob.y - oa.y * ob.x;
  }
}
