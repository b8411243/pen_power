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
import 'dart:math';
import 'dart:io';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:wakelock/wakelock.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import 'package:pen_power/Utils/ImageProcess.dart';
import 'package:pen_power/Utils/StringL10N.dart';
import 'package:pen_power/Utils/Database.dart';
import 'package:pen_power/Utils/Package.dart';
import 'package:pen_power/Utils/Types.dart';

class StepperChangeNotifier extends ChangeNotifier {
  final int _maxStep = 3;
  int _currentStep = 0;
  late void Function() _removeLastPage;
  bool _nextButtonEnable = false;

  StepperChangeNotifier(this._removeLastPage);

  int get currentStep => _currentStep;
  bool get nextButtonEnable => _nextButtonEnable;

  set nextButtonEnable(bool enable) {
    _nextButtonEnable = enable;
    notifyListeners();
  }

  void tapped(int step) {
    _currentStep = step;
    _nextButtonEnable = true;
    notifyListeners();
  }

  void continued() {
    if (_currentStep < (_maxStep - 1)) {
      _currentStep++;
      _nextButtonEnable = false;
      notifyListeners();
    } else {
      _removeLastPage();
    }
  }

  void cancel() {
    if (_currentStep > 0) {
      _currentStep--;
      _nextButtonEnable = true;
      notifyListeners();
    } else {
      _removeLastPage();
    }
  }
}

class DisplayStatusOnViewer extends ChangeNotifier {
  bool _isShowProgressIndicator = false;
  bool _isShowWarning = false;
  String _warningMessage = "Unknown error has occurred";

  bool get isShowProgressIndicator => _isShowProgressIndicator;
  bool get isShowWarning => _isShowWarning;
  String get warningMessage => _warningMessage;

  set isShowProgressIndicator(bool isShown) {
    _isShowProgressIndicator = isShown;

    //the warning and the progress indicator
    //are not shown in the same time
    if (isShown) _isShowWarning = false;
    notifyListeners();
  }

  set isShowWarning(bool isShown) {
    _isShowWarning = isShown;

    //the warning and the progress indicator
    //are not shown in the same time
    if (isShown) isShowProgressIndicator = false;
    notifyListeners();
  }

  set warningMessage(String msg) {
    _warningMessage = msg;
    notifyListeners();
  }

  void initAllStatus() {
    _isShowProgressIndicator = false;
    _isShowWarning = false;
    _warningMessage = "Unknown error has occurred";
  }
}

///
/// Step 1
///
class InputViewChangeNotifier extends DisplayStatusOnViewer {
  Uint8List? _imageFileBytes;

  bool get isEmpty => _imageFileBytes == null;
  Uint8List get image => _imageFileBytes!;

  set image(Uint8List inputImage) {
    _imageFileBytes = inputImage;
    notifyListeners();
  }

  void cleanAll({bool notify = true}) {
    _imageFileBytes = null;
    initAllStatus();
    if (notify) notifyListeners();
  }

  Future<bool> inputButtonOnPressed(
      BuildContext context, bool isFromCamera) async {
    cleanAll();
    isShowProgressIndicator = true;
    try {
      image = await _pickImage(context, isFromCamera);
      isShowProgressIndicator = false;
      return true;
    } catch (error) {
      warningMessage = "Error\n" + error.toString();
      isShowWarning = true;
      return false;
    }
  }

  Future<Uint8List> _pickImage(BuildContext context, bool isFromCamera) async {
    final pickedFile = await ImagePicker().getImage(
        source: isFromCamera ? ImageSource.camera : ImageSource.gallery);
    if (pickedFile != null) {
      if (extension(pickedFile.path) == ".jpg") {
        return File(pickedFile.path).readAsBytesSync();
      } else {
        return Future.error(StrL10N.of(context).error_image_not_support);
      }
    } else {
      return Future.error(StrL10N.of(context).error_image_no_selected);
    }
  }
}

///
/// Step 2
///
class HighlightViewChangeNotifier extends DisplayStatusOnViewer {
  ///
  /// Gestures
  ///

  DrawingStack<List<DrawingPixel>> drawStack = DrawingStack();
  DrawingStack<List<DrawingPixel>> redoStack = DrawingStack();
  DrawingStack<DrawingStack<List<DrawingPixel>>> undoAll = DrawingStack();
  List<DrawingPixel> drawingList = [];
  late GlobalKey _siblingKey, _canvasKey;
  DrawingPixel _brush = DrawingPixel.brush();

  void setKeys(GlobalKey siblingkey, GlobalKey canvasKey) {
    _siblingKey = siblingkey;
    _canvasKey = canvasKey;
  }

  void onPointerDownEvent(PointerDownEvent event) {
    if (!_isInBorder(event.localPosition)) return;

    //clean the redo list
    redoStack.clear();

    //the user need to submit the new highlight drawing
    submitEnable = true;

    //cleanup and add it in the list
    drawingList = [DrawingPixel.draw(event.localPosition, _brush)];

    notifyListeners();
  }

  void onPointerMoveEvent(PointerMoveEvent event) {
    Offset loc = event.localPosition;
    if (!_isInBorder(loc)) return;
    drawingList.add(DrawingPixel.draw(loc, _brush));
    notifyListeners();
  }

  void onPointerUpEvent(PointerUpEvent event) {
    if (_isInBorder(event.localPosition)) {
      drawingList.add(DrawingPixel.draw(event.localPosition, _brush));
    }

    drawStack.push(List.from(drawingList));
    drawingList.clear();

    notifyListeners();
  }

  bool _isInBorder(Offset location) {
    try {
      Size siblingSize = _siblingKey.currentContext!.size!;
      Offset siblingPos =
          (_siblingKey.currentContext!.findRenderObject() as RenderBox)
              .localToGlobal(Offset.zero);
      Offset myPos =
          (_canvasKey.currentContext!.findRenderObject() as RenderBox)
              .localToGlobal(Offset.zero);

      Offset widgetOffset = siblingPos - myPos;
      return !(location.dx < (widgetOffset.dx) ||
          location.dy < (widgetOffset.dy) ||
          location.dx > (siblingSize.width + widgetOffset.dx) ||
          location.dy > (siblingSize.height + widgetOffset.dy));
    } catch (trace) {
      return false;
    }
  }

  void initCanvas() {
    drawStack.clear();
    redoStack.clear();
    undoAll.clear();
    drawingList.clear();
  }

  ///
  /// Brush
  ///
  bool get undoable => !drawStack.isEmpty || !undoAll.isEmpty;
  bool get redoable => !redoStack.isEmpty;
  bool get cleanable => !drawStack.isEmpty;

  Color get color => _brush.color;
  int get width => _brush.brushWidth;

  set color(Color color) {
    //make sure that the alpha == 0x7F
    int colorCode = color.value & 0x00FFFFFF;
    colorCode = colorCode | 0x7F000000;

    //set color
    _brush.color = Color(colorCode);
    notifyListeners();
  }

  set markerWidth(int brushWidth) {
    //set width
    _brush.brushWidth = brushWidth;
    notifyListeners();
  }

  void undo() {
    if (drawStack.length != 0) {
      redoStack.push(drawStack.pop()!);
      //the user need to submit the new highlight drawing
      if (drawStack.length > 1) submitEnable = true;
      notifyListeners();
    } else if (!undoAll.isEmpty) {
      drawStack = undoAll.pop()!;

      notifyListeners();
    }
  }

  void redo() {
    //the user need to submit the new highlight drawing
    submitEnable = true;

    //avoid exception occurs
    if (redoStack.length == 0) return;

    drawStack.push(redoStack.pop()!);

    notifyListeners();
  }

  void deleteAll() {
    undoAll.push(drawStack.clone());
    drawStack.clear();
    redoStack.clear();
    notifyListeners();
  }

  void colorPickerDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
              titlePadding: const EdgeInsets.all(0.0),
              contentPadding: const EdgeInsets.all(0.0),
              content: SingleChildScrollView(
                  child: MaterialPicker(
                      pickerColor: color,
                      enableLabel: true,
                      onColorChanged: (newColor) {
                        color = newColor;
                        Navigator.pop(context);
                      })));
        });
  }

  ///
  /// Submit button and results
  ///
  bool _submitEnable = false;
  PenPowerNotePackage? _results;

  bool get submitEnable => _submitEnable;
  bool get isProcessed => _results != null;
  PenPowerNotePackage get results => _results!;

  void _setSubmitEnable(bool enable) {
    _submitEnable = enable;
    _results = null;
  }

  set submitEnable(bool enable) {
    _setSubmitEnable(enable);
    notifyListeners();
  }

  set results(PenPowerNotePackage package) => _results = package;

  Future<bool> submitButtonOnPressed(
      BuildContext context, Uint8List imageJpgRaw) async {
    //set status
    isShowProgressIndicator = true;
    submitEnable = false;

    try {
      await Wakelock.enable();
      results = await _maskProcess(context, imageJpgRaw);
      await Wakelock.disable();
      isShowProgressIndicator = false;
      return true;
    } catch (error) {
      // failed to process
      isShowWarning = true;
      warningMessage = "Error\n" + error.toString();
      return false;
    }
  }

  Future<PenPowerNotePackage> _maskProcess(
      BuildContext context, Uint8List imageJpgRawData) async {
    // get widget size and position
    if (_siblingKey.currentContext == null) {
      return Future.error(StrL10N.of(context).error_mask_sibling_key);
    } else if (_canvasKey.currentContext == null) {
      return Future.error(StrL10N.of(context).error_mask_canvas_key);
    }
    Size siblingSize = _siblingKey.currentContext!.size!;
    Offset widgetOffset = _getWidgetOffset();

    //get full color mask
    RenderRepaintBoundary? boundary =
        _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

    ImageProcess imageProcess = ImageProcess(
        image: await boundary.toImage(),
        widgetOffset: widgetOffset,
        siblingSize: siblingSize);

    // connected component labeling
    List<PenPowerLabel> labels;
    try {
      labels = await imageProcess.getLabels(imageJpgRawData);
    } catch (exp) {
      return Future.error(exp);
    }

    //get application folder
    Directory dir = await getApplicationDocumentsDirectory();

    //paint connected-components labels for debugging
    assert(() {
      img.Image debugCCLabel = imageProcess.binaryMask.clone();

      print("create " + dir.path + "/debug_binary.jpg");
      File(join(dir.path, "debug_binary.jpg"))
          .writeAsBytesSync(img.encodeJpg(debugCCLabel));

      print("create " + dir.path + "/debug_cclabel.jpg");
      imageProcess.connectedComponentsMap.forEach((key, pixels) {
        int color = _randomColor();
        pixels.forEach((element) {
          debugCCLabel[element] = color;
        });
      });
      File(join(dir.path, "debug_cclabel.jpg"))
          .writeAsBytesSync(img.encodeJpg(debugCCLabel));

      return true;
    }());

    //paint landmark and label for debugging
    assert(() {
      print("create " + dir.path + "/debug_landmark.jpg");
      print("create " + dir.path + "/debug_label.jpg");
      img.Image debugPoints = imageProcess.binaryMask.clone();
      img.Image debugLabel = imageProcess.binaryMask.clone();
      labels.forEach((element) {
        ///
        /// PAINT ON debugPoints(debug_landmark.jpg)
        ///

        //inscribed and circumscribed circle
        img.drawCircle(
            debugPoints,
            element.center.x.round(),
            element.center.y.round(),
            (element.size.width / 2).round(),
            0xFFFFFF00);
        img.drawCircle(
            debugPoints,
            element.center.x.round(),
            element.center.y.round(),
            (element.size.height / 2).round(),
            0xFFFFFF00);

        //label start and end point
        img.drawCircle(debugPoints, element.drawStart.x.round(),
            element.drawStart.y.round(), 5, 0xFFFFFF00);
        img.drawCircle(debugPoints, element.drawEnd.x.round(),
            element.drawEnd.y.round(), 5, 0xFFFFFF00);

        //label line
        img.drawLine(
            debugPoints,
            element.drawStart.x.round(),
            element.drawStart.y.round(),
            element.drawEnd.x.round(),
            element.drawEnd.y.round(),
            0xFFFFFF00,
            thickness: 5);

        ///
        /// PAINT ON debugLabel(debug_label.jpg)
        ///

        // draw the label with random color
        img.drawLine(
            debugLabel,
            element.drawStart.x.round(),
            element.drawStart.y.round(),
            element.drawEnd.x.round(),
            element.drawEnd.y.round(),
            _randomColor(),
            thickness: element.drawWidth);
      });
      File(join(dir.path, "debug_landmark.jpg"))
          .writeAsBytesSync(img.encodeJpg(debugPoints));
      File(join(dir.path, "debug_label.jpg"))
          .writeAsBytesSync(img.encodeJpg(debugLabel));

      return true;
    }());

    //get creating time (also as the package's filename)
    int createTime = DateTime.now().millisecondsSinceEpoch;

    //generate thumbnail
    Uint8List thumbnailJpgRawData =
        await imageProcess.getThumbnail(imageJpgRawData);

    //create package object
    PenPowerNotePackage npkg = PenPowerNotePackage.create(
        imageJpgRaw: imageJpgRawData,
        thumbnailJpgRaw: thumbnailJpgRawData,
        labels: labels,
        createTime: createTime,
        imageSize: imageProcess.inputImageSize,
        basePath: dir.path);

    return npkg;
  }

  Offset _getWidgetOffset() {
    Offset siblingPos =
        (_siblingKey.currentContext!.findRenderObject() as RenderBox)
            .localToGlobal(Offset.zero);
    Offset canvasPos =
        (_canvasKey.currentContext!.findRenderObject() as RenderBox)
            .localToGlobal(Offset.zero);

    return siblingPos - canvasPos;
  }

  int _randomColor() {
    Random random = Random();
    return 0xFF << 24 |
        random.nextInt(255) << 16 |
        random.nextInt(255) << 8 |
        random.nextInt(255);
  }
}

class HighlightDrawing extends CustomPainter {
  DrawingStack<List<DrawingPixel>> drawStack;
  List<DrawingPixel> drawingList;
  //DrawingStack<List<DrawingPixel>> oldDrawStack = DrawingStack();
  //List<DrawingPixel> oldDrawingList;

  HighlightDrawing({required this.drawStack, required this.drawingList});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint();

    DrawingStack<List<DrawingPixel>> paintStack = drawStack.clone();
    List<DrawingPixel>? gesture = paintStack.pop();

    while (gesture != null) {
      paint.strokeWidth = gesture[0].brushWidth.toDouble();
      paint.color = gesture[0].color;

      drawGesture(canvas, paint, gesture);
      gesture = paintStack.pop();
    }
    if (drawingList.isNotEmpty) {
      paint.strokeWidth = drawingList[0].brushWidth.toDouble();
      paint.color = drawingList[0].color;
      drawGesture(canvas, paint, drawingList);
    }

    //renew
    //oldDrawStack = drawStack;
    //oldDrawingList = drawingList;
  }

  void drawGesture(Canvas canvas, Paint paint, List<DrawingPixel> gesture) {
    for (int i = 0; i < gesture.length - 1; ++i) {
      canvas.drawLine(gesture[i].position, gesture[i + 1].position, paint);
    }
  }

  @override
  bool shouldRepaint(HighlightDrawing other) {
    //always repaint when get notification
    return true;

    /*
    return this.oldDrawStack.isEmpty ||
        (this.drawStack.length != this.oldDrawStack.length)||
        ()this.drawingList.length != this.oldDrawingList.length);
    */
  }
}

class MarkerWidthSliderChangeNotifier extends ChangeNotifier {
  int _value = 10;

  double get value => _value.toDouble();

  set value(double value) {
    _value = value.round();
    notifyListeners();
  }
}

class HighlightMarkerDisplay extends CustomPainter {
  late Color _color;
  late int _markerWidth;

  HighlightMarkerDisplay({required Color color, required int markerWidth}) {
    _color = color;
    _markerWidth = markerWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    Offset p1 = Offset((size.width / 2) - 2, size.height / 2);
    Offset p2 = Offset((size.width / 2) + 2, size.height / 2);

    Paint paint = Paint()
      ..color = _color
      ..strokeWidth = _markerWidth.toDouble();

    canvas.drawLine(p1, p2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

///
/// Step 3
///
class NotebookViewChangeNotifier extends ChangeNotifier {
  final void Function() _removeLastPage;
  FocusNode noteTitleFocusNode = FocusNode();
  FocusNode noteDescFocusNode = FocusNode();

  NotebookViewChangeNotifier(this._removeLastPage) {
    noteTitleFocusNode.addListener(this.onFocusChanged);
    noteDescFocusNode.addListener(this.onFocusChanged);
  }

  void onFocusChanged() {
    if (!noteTitleFocusNode.hasPrimaryFocus ||
        !noteDescFocusNode.hasPrimaryFocus) {
      notifyListeners();
    }
  }

  String noteTitle = "new note";
  String noteDesc = "";

  get titleIsEmpty => noteTitle.isEmpty;

  void noteTitleOnchanged(String title) {
    noteTitle = title;
  }

  void noteTitleOnSubmitted(String title) {
    noteTitle = title;
    noteDescFocusNode.requestFocus();
  }

  void noteDescOnchangedAndSubmitted(String desc) {
    noteDesc = desc;
  }

  Future<void> finishButtonOnPressed(
      BuildContext context, PenPowerUser user) async {
    PenPowerDatabase db = PenPowerDatabase();

    //store into the database
    await db.open();

    //get note package
    PenPowerNotePackage npkg =
        Provider.of<HighlightViewChangeNotifier>(context, listen: false)
            .results;

    //did user want to creat a new notebook
    bool createNewNotebook =
        Provider.of<NotebookDropdownChangeNotifier>(context, listen: false)
            .isCreateNewNotebook;

    if (createNewNotebook) {
      //if user create a new Notebook
      PenPowerNotebook newNotebook =
          Provider.of<NotebookDropdownChangeNotifier>(context, listen: false)
              .createNewNotebook;

      await db.insertNotebook(newNotebook);
    }

    PenPowerNotebook notebook =
        Provider.of<NotebookDropdownChangeNotifier>(context, listen: false)
            .notebook;

    String title =
        Provider.of<NotebookViewChangeNotifier>(context, listen: false)
            .noteTitle;

    String description =
        Provider.of<NotebookViewChangeNotifier>(context, listen: false)
            .noteDesc;

    //save package and thumbnail
    npkg.save();

    PenPowerNote newNote = PenPowerNote(
        noteId: npkg.createTime,
        userId: user.userId,
        notebookId: notebook.notebookId,
        npkgPath: npkg.npkgPath,
        thumbnailPath: npkg.thumbnailPath,
        imageWidth: npkg.imageSize.width.round(),
        imageHeight: npkg.imageSize.height.round(),
        title: title,
        description: description);

    //write into the database
    await db.insertNote(newNote);

    //release resource
    //db.close();

    //close this page
    _removeLastPage();
  }

  void leave() => _removeLastPage();
}

class NotebookDropdownChangeNotifier extends ChangeNotifier {
  late List<PenPowerNotebook> notebookList;
  late PenPowerNotebook _notebook;
  late final PenPowerNotebook createNewNotebook;

  FocusNode notebookTitleFocusNode = FocusNode();
  FocusNode notebookDescFocusNode = FocusNode();

  NotebookDropdownChangeNotifier(
      List<PenPowerNotebook>? existNotebookList, PenPowerUser user) {
    createNewNotebook = PenPowerNotebook.empty(user.userId);
    if (existNotebookList != null) {
      notebookList = existNotebookList;
      notebookList.add(createNewNotebook);
    } else {
      notebookList = [createNewNotebook];
    }
    _notebook = notebookList[0];
    notebookTitleFocusNode.addListener(this.onFocusChanged);
    notebookDescFocusNode.addListener(this.onFocusChanged);
  }

  void onFocusChanged() {
    if (!notebookTitleFocusNode.hasPrimaryFocus ||
        !notebookDescFocusNode.hasPrimaryFocus) {
      notifyListeners();
    }
  }

  List<DropdownMenuItem> toMenuItem() {
    return notebookList.map((notebook) {
      if (notebook == createNewNotebook)
        return DropdownMenuItem(value: notebook, child: Text("+ New Notebook"));
      else
        return DropdownMenuItem(value: notebook, child: Text(notebook.title));
    }).toList();
  }

  PenPowerNotebook get notebook => _notebook;
  set notebook(PenPowerNotebook notebook) {
    _notebook = notebook;
    notifyListeners();
  }

  void notebookTitleOnchanged(String title) {
    createNewNotebook.title = title;
  }

  void notebookTitleOnSubmitted(String title) {
    createNewNotebook.title = title;
    notebookDescFocusNode.requestFocus();
  }

  void notebookDescOnchangedAndSubmitted(String desc) {
    createNewNotebook.description = desc;
  }

  void checkTitleLength() => notifyListeners();

  bool get isCreateNewNotebook => _notebook == createNewNotebook;
  bool get titleIsEmpty => createNewNotebook.title.length == 0;
}
