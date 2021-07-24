/*M///////////////////////////////////////////////////////////////////////////////////////
//
//  IMPORTANT: READ BEFORE DOWNLOADING, COPYING, INSTALLING OR USING.
//
//  By downloading, copying, installing or using the software you agree to this license.
//  If you do not agree to this license, do not download, install,
//  copy or use the software.
//
//
//                           License Agreement
//                For Open Source Computer Vision Library
//
// Copyright (C) 2000, Intel Corporation, all rights reserved.
// Third party copyrights are property of their respective owners.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
//   * Redistribution's of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//   * Redistribution's in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//   * The name of OpenCV Foundation may not be used to endorse or promote products
//     derived from this software without specific prior written permission.
//
// This software is provided by the copyright holders and contributors "as is" and
// any express or implied warranties, including, but not limited to, the implied
// warranties of merchantability and fitness for a particular purpose are disclaimed.
// In no event shall the OpenCV Foundation or contributors be liable for any direct,
// indirect, incidental, special, exemplary, or consequential damages
// (including, but not limited to, procurement of substitute goods or services;
// loss of use, data, or profits; or business interruption) however caused
// and on any theory of liability, whether in contract, strict liability,
// or tort (including negligence or otherwise) arising in any way out of
// the use of this software, even if advised of the possibility of such damage.
//
//M*/

import 'dart:math';

import 'package:pen_power/Utils/ImageProcess.dart';
import 'package:pen_power/Utils/Types.dart';

class RotatingCalipers {
  static List<Point<double>> rotatingCalipers(List<PenPowerPixel> pixels) {
    int left = 0, bottom = 0, right = 0, top = 0;
    List<int> seq = [-1, -1, -1, -1];
    List<Point<double>> vector =
        List.filled(pixels.length, Point<double>(0, 0));
    List<double> invertVectorLength = List.filled(pixels.length, 0.0);

    List<double> buffer = List.filled(7, 0.0);

    PenPowerPixel pixel0 = pixels[0];
    double leftX, rightX, topY, bottomY;
    leftX = rightX = pixel0.x;
    topY = bottomY = pixel0.y;
    for (int i = 0; i < pixels.length; ++i) {
      double dx, dy;

      if (pixel0.x < leftX) {
        leftX = pixel0.x;
        left = i;
      }
      if (pixel0.x > rightX) {
        rightX = pixel0.x;
        right = i;
      }
      if (pixel0.y > topY) {
        topY = pixel0.y;
        top = i;
      }
      if (pixel0.y < bottomY) {
        bottomY = pixel0.y;
        bottom = i;
      }

      PenPowerPixel pixel = (i + 1 < pixels.length) ? pixels[i + 1] : pixels[0];
      dx = pixel.x - pixel0.x;
      dy = pixel.y - pixel0.y;
      vector[i] = Point<double>(dx, dy);
      invertVectorLength[i] = 1 / sqrt(dx * dx + dy * dy);
      pixel0 = pixel;
    }

    // find convex hull orientation
    double orientation = 0;

    {
      Point<double> vectorA = vector[pixels.length - 1];

      for (int i = 0; i < pixels.length; ++i) {
        Point<double> vectorB = vector[i];

        double convexity = ImageProcess.crossProduct2D(vectorA, vectorB);

        if (convexity != 0) {
          orientation = (convexity > 0) ? 1 : -1;
          break;
        }
        vectorA = vectorB;
      }
    }

    //init calipers position
    seq[0] = bottom;
    seq[1] = right;
    seq[2] = top;
    seq[3] = left;

    /// rotating calipers sides will always have coordinates
    /// (a,b) (-b,a) (-a,-b) (b, -a)
    double baseA = orientation;
    double baseB = 0;

    double minArea = double.infinity;
    for (int k = 0; k < pixels.length; ++k) {
      // compute cosine of angle between calipers side and polygon edge
      List<double> dotProduct = [
        baseA * vector[seq[0]].x + baseB * vector[seq[0]].y,
        -baseB * vector[seq[1]].x + baseA * vector[seq[1]].y,
        -baseA * vector[seq[2]].x - baseB * vector[seq[2]].y,
        baseB * vector[seq[3]].x - baseA * vector[seq[3]].y
      ];

      double maxCos = dotProduct[0] * invertVectorLength[seq[0]];
      //number of calipers edges, that has minimal angle with edge
      int mainElement = 0;

      //get minimal angle (max Cosine)
      for (int i = 1; i < 4; ++i) {
        double cosAlpha = dotProduct[i] * invertVectorLength[seq[i]];
        if (cosAlpha > maxCos) {
          mainElement = i;
          maxCos = cosAlpha;
        }
      }

      //rotate calipers to minimal angle
      {
        //get next base
        int pIndex = seq[mainElement];

        Point<double> lead = vector[pIndex] * invertVectorLength[pIndex];
        switch (mainElement) {
          case 0:
            baseA = lead.x;
            baseB = lead.y;
            break;
          case 1:
            baseA = lead.y;
            baseB = -lead.x;
            break;
          case 2:
            baseA = -lead.x;
            baseB = -lead.y;
            break;
          case 3:
            baseA = -lead.y;
            baseB = lead.x;
            break;
          default:
            throw Exception("mainElement should be 0, 1, 2 or 3");
        }
      }
      // change base point of main edge
      seq[mainElement] += 1;
      seq[mainElement] =
          (seq[mainElement] == pixels.length) ? 0 : seq[mainElement];

      // find area of rectangle
      {
        // find vector left-right
        Point<double> delta =
            pixels[seq[1]].position2D - pixels[seq[3]].position2D;
        double width = delta.x * baseA + delta.y * baseB;

        delta = pixels[seq[2]].position2D - pixels[seq[0]].position2D;
        double height = -delta.x * baseB + delta.y * baseA;

        double area = width * height;
        if (area <= minArea) {
          minArea = area;
          /* leftist point */
          buffer[0] = seq[3].toDouble();
          buffer[1] = baseA;
          buffer[2] = width;
          buffer[3] = baseB;
          buffer[4] = height;
          /* bottom point */
          buffer[5] = seq[0].toDouble();
          buffer[6] = area;
        }
      }
    }

    {
      double a1 = buffer[1];
      double b1 = buffer[3];

      double a2 = -buffer[3];
      double b2 = buffer[1];

      double c1 =
          a1 * pixels[buffer[0].round()].x + pixels[buffer[0].round()].y * b1;
      double c2 =
          a2 * pixels[buffer[5].round()].x + pixels[buffer[5].round()].y * b2;

      double idet = 1 / (a1 * b2 - a2 * b1);

      double px = (c1 * b2 - c2 * b1) * idet;
      double py = (a1 * c2 - a2 * c1) * idet;

      return [
        Point<double>(px, py),
        Point<double>(a1 * buffer[2], b1 * buffer[2]),
        Point<double>(a2 * buffer[4], b2 * buffer[4])
      ];
    }
  }
}
