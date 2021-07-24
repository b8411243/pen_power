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

import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'package:pen_power/Providers/NoteDialogProvider.dart';
import 'package:pen_power/Utils/ImageProcess.dart';
import 'package:pen_power/Utils/StringL10N.dart';
import 'package:pen_power/Utils/Types.dart';

class NoteDialog extends StatelessWidget {
  final NoteDialogChangeNotifier noteDialogChangeNotifier;
  final ScrollController _controller = ScrollController();

  NoteDialog(PenPowerNote note)
      : noteDialogChangeNotifier = NoteDialogChangeNotifier(note);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: ChangeNotifierProvider<NoteDialogChangeNotifier>(
                create: (context) => noteDialogChangeNotifier,
                builder: (context, child) => Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black,
                                offset: Offset(0, 10),
                                blurRadius: 10)
                          ]),
                      child: Selector<NoteDialogChangeNotifier, bool>(
                          selector: (context, notifier) =>
                              notifier.isEditingText,
                          builder: (context, isEditing, child) => ClipRRect(
                              borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(15),
                                  topRight: Radius.circular(15)),
                              child: SingleChildScrollView(
                                  controller: _controller,
                                  physics: (isEditing)
                                      ? null
                                      : NeverScrollableScrollPhysics(),
                                  child: Column(children: [
                                    mainView(context),
                                    footerView()
                                  ])))),
                    ))));
  }

  Widget mainView(BuildContext context) {
    return Stack(alignment: AlignmentDirectional.topEnd, children: [
      Consumer<NoteDialogChangeNotifier>(
          builder: (context, notifier, child) => SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                child: NoteView(
                    labels: notifier.npkg.labels,
                    showedLabel: notifier.showedList,
                    imageJpgRaw: notifier.npkg.imageJpgRaw,
                    onTap: notifier.noteViewOnTap),
              )),
      IconButton(
          icon: Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(null))
    ]);
  }

  Widget footerView() {
    return Container(
        padding: EdgeInsetsDirectional.all(5),
        child: Consumer<NoteDialogChangeNotifier>(
            builder: (context, notifier, child) =>
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                            icon: Icon(Icons.edit_rounded),
                            onPressed: notifier.isEditingText
                                ? null
                                : () => notifier.editButtonOnPressed(context)),
                        IconButton(
                            icon: Icon(notifier.hideAllIcon
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded),
                            onPressed: notifier.visibilityButtonOnPressed),
                        PopupMenuButton(itemBuilder: (context) {
                          return [
                            PopupMenuItem(
                                child: ListTile(
                              title:
                                  Text(StrL10N.of(context).note_move_to_title),
                              trailing: Icon(Icons.drive_file_move_rounded),
                              onTap: () =>
                                  notifier.moveToButtonOnPressed(context),
                            )),
                            PopupMenuItem(
                                child: ListTile(
                              title: Text(StrL10N.of(context).btn_delete),
                              trailing: Icon(Icons.delete_rounded),
                              onTap: () =>
                                  notifier.deleteButtonOnPressed(context),
                            )),
                          ];
                        }),
                      ]),

                  //title
                  _editableTitle(context, notifier),
                  SizedBox(height: 5),

                  //description
                  _editableDesc(context, notifier),
                ])));
  }

  Widget _editableTitle(
      BuildContext context, NoteDialogChangeNotifier notifier) {
    if (notifier.isEditingText) {
      return TextField(
          controller: TextEditingController()
            ..text = notifier.note.title
            ..selection = TextSelection.fromPosition(
                TextPosition(offset: notifier.note.title.length)),
          focusNode: notifier.titleFocusNode,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
              border: UnderlineInputBorder(),
              labelText: StrL10N.of(context).input_note_title + " *",
              errorText: notifier.isTitleEmpty
                  ? StrL10N.of(context).input_note_title_warning
                  : null),
          onChanged: notifier.titleTextOnChanged,
          onSubmitted: notifier.titleTextOnSubmitted);
    } else {
      return Text(notifier.note.title,
          style: TextStyle(fontWeight: FontWeight.bold));
    }
  }

  Widget _editableDesc(
      BuildContext context, NoteDialogChangeNotifier notifier) {
    if (notifier.isEditingText) {
      return TextField(
          focusNode: notifier.descFocusNode,
          controller: TextEditingController()
            ..text = notifier.note.description
            ..selection = TextSelection.fromPosition(
                TextPosition(offset: notifier.note.description.length)),
          textInputAction: notifier.isTitleEmpty
              ? TextInputAction.next
              : TextInputAction.done,
          decoration: InputDecoration(
              border: UnderlineInputBorder(),
              labelText: StrL10N.of(context).input_note_desc),
          onChanged: notifier.descTextOnChanged,
          onSubmitted: notifier.descTextOnSubmitted);
    } else {
      return Text(notifier.note.description,
          style: TextStyle(fontWeight: FontWeight.w200));
    }
  }
}

class NoteView extends LeafRenderObjectWidget {
  final void Function(Offset position, double ratio) onTap;
  final List<PenPowerLabel> labels;
  final List<bool> showedLabel;
  final Uint8List imageJpgRaw;
  NoteView(
      {required this.labels,
      required this.showedLabel,
      required this.imageJpgRaw,
      required this.onTap});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return NoteViewRenderBox(labels, showedLabel, imageJpgRaw, onTap);
  }

  @override
  updateRenderObject(
      BuildContext context, covariant RenderObject renderObject) {
    NoteViewRenderBox noteViewRenderBox = renderObject as NoteViewRenderBox;
    noteViewRenderBox
      ..labels = labels
      ..showedLabel = showedLabel
      ..imageJpgRaw = imageJpgRaw
      ..onTap = onTap;
  }
}

class NoteViewRenderBox extends RenderBox {
  ui.Image? _image;
  Offset? _oldPosition;
  late double _ratio;

  void Function(Offset position, double ratio) _onTap;
  List<PenPowerLabel> _labels;
  List<bool> _showedLabel;
  Uint8List _imageJpgRaw;

  NoteViewRenderBox(
      this._labels, this._showedLabel, this._imageJpgRaw, this._onTap);

  set onTap(void Function(Offset position, double ratio) func) => _onTap = func;
  set labels(List<PenPowerLabel> lb) => _labels = lb;
  set imageJpgRaw(Uint8List raw) => _imageJpgRaw = raw;
  set showedLabel(List<bool> list) {
    _showedLabel = list;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  bool hitTestSelf(Offset position) {
    if (_oldPosition != null && _oldPosition == position) {
      return false;
    }
    _onTap(position, _ratio);
    _oldPosition = position;
    return false;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    double _width = constraints.biggest.width;
    Size _imageSize = ImageProcess.jpegImageSize(_imageJpgRaw);
    _ratio = _width / _imageSize.width;

    return _imageSize * _ratio;
  }

  @override
  void paint(PaintingContext context, Offset offset) async {
    if (_image == null) {
      await _loadImage(constraints.biggest.width);
    }

    context.canvas.drawImage(_image!, offset, Paint());

    Paint paint = Paint();
    for (int i = 0; i < _labels.length; ++i) {
      if (_showedLabel[i]) {
        paint.color = Color(0x7FFFFF00);
      } else {
        paint.color = Colors.black;
      }

      paint.strokeWidth = _labels[i].drawWidth * _ratio;

      Offset start = Offset(_labels[i].drawStart.x, _labels[i].drawStart.y);
      Offset end = offset + Offset(_labels[i].drawEnd.x, _labels[i].drawEnd.y);

      context.canvas
          .drawLine(offset + start * _ratio, offset + end * _ratio, paint);
    }
  }

  Future<void> _loadImage(double width) async {
    ui.Codec codec = await ui.instantiateImageCodec(_imageJpgRaw,
        targetWidth: width.round());
    ui.FrameInfo frameInfo = await codec.getNextFrame();
    _image = frameInfo.image;
    markNeedsLayout();
  }
}

class NoteMoveToDialog extends StatelessWidget {
  final List<PenPowerNotebook> notebookList;
  NoteMoveToDialog(this.notebookList);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MoveDropChangeNotifier>(
        create: (context) => MoveDropChangeNotifier(this.notebookList),
        builder: (context, child) => Consumer<MoveDropChangeNotifier>(
                builder: (context, notifier, child) {
              return AlertDialog(
                title: Text(StrL10N.of(context).note_move_to_title),
                content: Container(
                    child: DropdownButton(
                  value: notifier.selectNotebook,
                  items: notifier.notebookList
                      .map((notebook) => DropdownMenuItem(
                            child: Text(notebook.title),
                            value: notebook,
                          ))
                      .toList(),
                  onChanged: (PenPowerNotebook? notebook) {
                    if (notebook != null) notifier.selectNotebook = notebook;
                  },
                )),
                actions: [
                  TextButton(
                      child: Text(StrL10N.of(context).btn_cancel.toLowerCase()),
                      onPressed: () {
                        Navigator.of(context).pop();
                      }),
                  ElevatedButton(
                      child: Text(StrL10N.of(context).btn_move_it,
                          style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Navigator.of(context)
                            .pop(notifier.selectNotebook.notebookId);
                      }),
                ],
              );
            }));
  }
}

class NoteDeleteDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        Icon(Icons.warning_rounded, color: Colors.yellow),
        Text(StrL10N.of(context).note_delete_title)
      ]),
      content: Text(StrL10N.of(context).note_delete_content),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 0,
      backgroundColor: Colors.white,
      actions: [
        TextButton(
            child: Text(StrL10N.of(context).btn_sure),
            onPressed: () async {
              Navigator.of(context).pop(true);
            }),
        ElevatedButton(
            child: Text(StrL10N.of(context).btn_cancel.toUpperCase(),
                style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.of(context).pop(false);
            }),
      ],
    );
  }
}
