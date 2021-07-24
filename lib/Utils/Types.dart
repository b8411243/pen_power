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

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:pen_power/Utils/ImageProcess.dart';

enum PenPowerPages { CREATE, NOTEBOOK_LIST, NOTEBOOK_VIEW, UNKNOWN }

class DrawingPixel {
  int brushWidth = 10;
  Offset position;
  Color color;

  DrawingPixel.brush()
      : position = Offset(0, 0),
        color = Color(0x7FFFFF00);

  DrawingPixel.draw(this.position, DrawingPixel brush)
      : brushWidth = brush.brushWidth,
        color = brush.color;

  void resetBrush() {
    brushWidth = 10;
    color = Color(0x7FFFFF00);
  }
}

class DrawingStack<T> {
  List<T> _stack = [];

  DrawingStack();
  DrawingStack.fromList(this._stack);

  int get length => _stack.length;
  List<T> get items => _stack;
  bool get isEmpty => _stack.isEmpty;

  void push(T data) {
    _stack.add(data);
  }

  T? pop() {
    if (_stack.length < 1) return null;
    return _stack.removeLast();
  }

  void clear() {
    _stack.clear();
  }

  DrawingStack<T> clone() {
    return DrawingStack<T>.fromList(List.from(_stack));
  }
}

class PenPowerPixel implements Comparable<PenPowerPixel> {
  late Point<double> position2D;
  late int position1D;
  PenPowerPixel({required this.position2D, required this.position1D});

  PenPowerPixel.from1Dimention({required this.position1D, required int width}) {
    position2D = oneDimension2TwoDimension(position1D, width);
  }
  PenPowerPixel.from2Dimention({required this.position2D, required int width}) {
    position1D = twoDimension2OneDimension(position2D, width);
  }

  Point<double> oneDimension2TwoDimension(int pos1D, int width) =>
      Point((pos1D % width).toDouble(), (pos1D / width).floor().toDouble());

  int twoDimension2OneDimension(Point<double> pos2D, int width) =>
      (pos2D.y * width + pos2D.x).round();

  double get x => position2D.x;
  double get y => position2D.y;
  int get index => position1D;

  @override
  int compareTo(PenPowerPixel other) {
    int dx = (this.position2D.x - other.position2D.x).round();
    if (dx != 0)
      return dx;
    else
      return (this.position2D.y - other.position2D.y).round();
  }

  @override
  String toString() =>
      "PEBPOWER_PIXEL{1d:$position1D,x:${position2D.x},y:${position2D.y}}";

  @override
  bool operator ==(other) =>
      other is PenPowerPixel && other.position1D == position1D;

  @override
  int get hashCode => position1D.hashCode;
}

class PenPowerLabel {
  Point center;
  Size size;
  double angle;
  List<Point<double>> fourPoints = List.filled(4, Point<double>(0, 0));
  Point<double> drawStart = Point(0, 0), drawEnd = Point(0, 0);

  double get drawWidth => min(size.width, size.height);

  PenPowerLabel(
      {required this.center, required this.size, required this.angle}) {
    _setFourPoints();
    _setSidePoints();
  }

  PenPowerLabel.fromMap(Map map)
      : center = Point(map["center_x"]!, map["center_y"]!),
        size = Size(map["width"]!, map["height"]!),
        angle = map["angle"]! {
    _setFourPoints();
    _setSidePoints();
  }

  Map toMap() {
    return {
      "center_x": center.x,
      "center_y": center.y,
      "width": size.width,
      "height": size.height,
      "angle": angle
    };
  }

  bool isInBound(Point<double> point) {
    for (int i = 0; i < fourPoints.length; ++i) {
      Point<double> o = fourPoints[i];
      Point<double> a =
          (i + 1 < fourPoints.length) ? fourPoints[i + 1] : fourPoints[0];

      //A <------- o <------ point
      double crossProduct = ImageProcess.crossProduct2D(o - a, point - o);

      //counter-clockwise turn -> the point si outside the label
      if (crossProduct > 0) return false;
    }
    return true;
  }

  void _setSidePoints() {
    int nearestIndex = 1;
    double nearestDistance = fourPoints[0].distanceTo(fourPoints[1]);
    for (int i = 2; i < fourPoints.length; ++i) {
      double distance = fourPoints[0].distanceTo(fourPoints[i]);
      if (distance < nearestDistance) {
        nearestIndex = i;
        nearestDistance = distance;
      }
    }

    drawStart = fourPoints[0] + fourPoints[nearestIndex];
    drawStart = Point(drawStart.x / 2, drawStart.y / 2);

    switch (nearestIndex) {
      case 1:
        drawEnd = fourPoints[2] + fourPoints[3];
        drawEnd = Point(drawEnd.x / 2, drawEnd.y / 2);
        break;
      case 2:
        //this case may never used
        //but leave it here just in case
        drawEnd = fourPoints[1] + fourPoints[3];
        drawEnd = Point(drawEnd.x / 2, drawEnd.y / 2);
        break;
      case 3:
        drawEnd = fourPoints[1] + fourPoints[2];
        drawEnd = Point(drawEnd.x / 2, drawEnd.y / 2);
    }
  }

  void _setFourPoints() {
    double cosAngle = cos(angle);
    double sinAngle = sin(angle);

    //left-top
    fourPoints[0] = Point(
        center.x - sinAngle * 0.5 * size.height - cosAngle * 0.5 * size.width,
        center.y + cosAngle * 0.5 * size.height - sinAngle * 0.5 * size.width);

    //left-bottom
    fourPoints[1] = Point(
        center.x + sinAngle * 0.5 * size.height - cosAngle * 0.5 * size.width,
        center.y - cosAngle * 0.5 * size.height - sinAngle * 0.5 * size.width);

    //right-top
    fourPoints[2] =
        Point(2 * center.x - fourPoints[0].x, 2 * center.y - fourPoints[0].y);

    //right-bottom
    fourPoints[3] =
        Point(2 * center.x - fourPoints[1].x, 2 * center.y - fourPoints[1].y);
  }

  @override
  String toString() {
    return "PENPOWER_LABEL(" + this.toMap().toString() + ")";
  }

  @override
  bool operator ==(other) =>
      other is PenPowerLabel && center == other.center && angle == other.angle;

  @override
  int get hashCode => (center.hashCode + angle.hashCode).hashCode;
}

class PenPowerNote {
  //Keys
  final int noteId; //p.k (noteId == createTime)
  int notebookId; //f.k
  String userId; //f.k

  //Elements
  String title;
  String description;
  int imageWidth;
  int imageHeight;
  String npkgPath;
  String thumbnailPath;

  PenPowerNote(
      {required this.noteId,
      required this.notebookId,
      required this.userId,
      required this.title,
      required this.description,
      required this.imageWidth,
      required this.imageHeight,
      required this.npkgPath,
      required this.thumbnailPath});

  PenPowerNote.fromMap(Map<String, dynamic> map)
      : noteId = map["note_id"],
        notebookId = map["notebook_id"],
        userId = map["user_id"],
        title = map["title"],
        description = map["description"],
        imageWidth = map["image_width"],
        imageHeight = map["image_height"],
        npkgPath = map["npkg_path"],
        thumbnailPath = map["thumbnail_path"];

  Map<String, dynamic> toMap() => {
        "note_id": noteId,
        "notebook_id": notebookId,
        "user_id": userId,
        "title": title,
        "description": description,
        "image_width": imageWidth,
        "image_height": imageHeight,
        "npkg_path": npkgPath,
        "thumbnail_path": thumbnailPath,
      };

  Map<String, dynamic> toUpdateMap() => {
        "notebook_id": notebookId,
        "user_id": userId,
        "title": title,
        "description": description,
        "image_width": imageWidth,
        "image_height": imageHeight,
        "npkg_path": npkgPath,
        "thumbnail_path": thumbnailPath,
      };

  @override
  String toString() {
    return "PENPOWER_NOTE(" + toMap().toString() + ")";
  }

  @override
  bool operator ==(other) =>
      other is PenPowerNote && this.noteId == other.noteId;

  @override
  int get hashCode => this.noteId.hashCode;
}

class PenPowerNotebook {
  //Keys
  final int notebookId; //p.k
  String userId; //f.k

  //Elements
  String title;
  String description;

  PenPowerNotebook(
      {required this.notebookId,
      required this.userId,
      required this.title,
      required this.description});

  PenPowerNotebook.empty(this.userId)
      : notebookId = DateTime.now().millisecondsSinceEpoch,
        title = "New Notebook",
        description = "";

  PenPowerNotebook.fromMap(Map<String, dynamic> map)
      : notebookId = map["notebook_id"],
        userId = map["user_id"],
        title = map["title"],
        description = map['description'];

  Map<String, dynamic> toMap() => {
        "notebook_id": notebookId,
        "user_id": userId,
        "title": title,
        "description": description,
      };

  Map<String, dynamic> toUpdateMap() => {
        "title": title,
        "description": description,
      };

  @override
  String toString() {
    return "PENPOWER_NOTEBOOK(" + toMap().toString() + ")";
  }

  @override
  bool operator ==(other) =>
      other is PenPowerNotebook && other.hashCode == hashCode;

  @override
  int get hashCode {
    return notebookId.hashCode;
  }
}

class PenPowerUser {
  //Keys
  final String userId; //p.k

  //Elements
  String name;
  int latestColor;
  int latestWidth;
  int showWelcome;

  PenPowerUser(
      {required this.userId,
      required this.name,
      required this.latestColor,
      required this.latestWidth,
      required this.showWelcome});

  PenPowerUser.fromMap(Map<String, dynamic> map)
      : this.userId = map["user_id"],
        this.name = map["name"],
        this.latestColor = map["latest_color"],
        this.latestWidth = map["latest_width"],
        this.showWelcome = map["show_welcome"];

  Map<String, dynamic> toMap() => {
        "user_id": userId,
        "name": name,
        "latest_color": latestColor,
        "latest_width": latestWidth,
        "show_welcome": showWelcome
      };

  @override
  String toString() {
    return "PENPOWER_USER(" + toMap().toString() + ")";
  }
}
