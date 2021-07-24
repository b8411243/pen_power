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

import 'package:pen_power/Views/NoteDialog.dart';
import 'package:pen_power/Utils/Database.dart';
import 'package:pen_power/Utils/Package.dart';
import 'package:pen_power/Utils/Types.dart';

class NoteDialogChangeNotifier extends ChangeNotifier {
  late List<bool> showedList;
  PenPowerNotePackage npkg;
  PenPowerNote _note;
  bool _isEditingText = false;
  FocusNode titleFocusNode = FocusNode();
  FocusNode descFocusNode = FocusNode();

  NoteDialogChangeNotifier(this._note)
      : npkg = PenPowerNotePackage.read(_note) {
    showedList = List.filled(npkg.labels.length, true);
    titleFocusNode.addListener(this.onFocusChanged);
    descFocusNode.addListener(this.onFocusChanged);
  }

  bool get hideAllIcon {
    //show the "hide all(Visibility Off)" icon only when all of element is TRUE
    //else show the "show all(Visibility)" icon
    bool labelVisible = true;
    showedList.forEach((element) => labelVisible = labelVisible & element);
    return labelVisible;
  }

  void onFocusChanged() async {
    if (!titleFocusNode.hasPrimaryFocus || !descFocusNode.hasPrimaryFocus) {
      notifyListeners();
    } else if (!titleFocusNode.hasPrimaryFocus &&
        !descFocusNode.hasPrimaryFocus) {
      if (!isTitleEmpty) {
        editingTextEnd();
      }
    }
  }

  bool get isEditingText => _isEditingText;

  void editingTextEnd() async {
    _isEditingText = false;

    //update database
    PenPowerDatabase db = PenPowerDatabase();
    await db.open();
    await db.updateNote(_note);

    notifyListeners();
  }

  PenPowerNote get note => _note;

  bool get isTitleEmpty => _note.title.isEmpty;

  void titleTextOnChanged(String title) {
    _note.title = title;
  }

  void titleTextOnSubmitted(String title) {
    _note.title = title;
    descFocusNode.requestFocus();
  }

  void descTextOnChanged(String desc) {
    _note.description = desc;
  }

  void descTextOnSubmitted(String desc) {
    if (isTitleEmpty) {
      titleFocusNode.requestFocus();
    } else {
      _note.description = desc;
      editingTextEnd();
    }
  }

  void noteViewOnTap(Offset position, double ratio) {
    if (_isEditingText) return;
    for (int i = 0; i < npkg.labels.length; ++i) {
      Offset scaledPosition = position * (1 / ratio);
      Point<double> point = Point<double>(scaledPosition.dx, scaledPosition.dy);
      if (npkg.labels[i].isInBound(point)) {
        showedList[i] = !showedList[i];
        notifyListeners();
      }
    }
  }

  void editButtonOnPressed(BuildContext context) {
    _isEditingText = true;
    notifyListeners();
  }

  void visibilityButtonOnPressed() {
    if (hideAllIcon) {
      showedList.fillRange(0, showedList.length, false);
    } else {
      showedList.fillRange(0, showedList.length, true);
    }
    notifyListeners();
  }

  void moveToButtonOnPressed(BuildContext context) async {
    //pop the menu
    Navigator.of(context).pop();

    PenPowerDatabase db = PenPowerDatabase();
    await db.open();
    List<PenPowerNotebook> notebookList = await db.allNotebooks;
    int? moveToNotebookId = await showDialog(
        context: context, builder: (context) => NoteMoveToDialog(notebookList));

    if (moveToNotebookId != null) {
      if (_note.notebookId != moveToNotebookId) {
        _note.notebookId = moveToNotebookId;
        await db.updateNote(_note);
        Navigator.of(context).pop(_note.noteId);
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  void deleteButtonOnPressed(BuildContext context) async {
    //pop the menu
    Navigator.of(context).pop();

    bool? isUserDeleteNote = await showDialog(
        context: context, builder: (context) => NoteDeleteDialog());

    if (isUserDeleteNote != null && isUserDeleteNote) {
      PenPowerNotePackage.delete(_note);
      PenPowerDatabase db = PenPowerDatabase();
      await db.open();
      await db.deleteNoteByNote(note);
      //return notebook view & notice it that it needs to renew the list
      if (isUserDeleteNote) Navigator.of(context).pop(_note.noteId);
    }
  }
}

class MoveDropChangeNotifier extends ChangeNotifier {
  List<PenPowerNotebook> notebookList;
  PenPowerNotebook _selectNotebook;

  MoveDropChangeNotifier(this.notebookList) : _selectNotebook = notebookList[0];

  PenPowerNotebook get selectNotebook => _selectNotebook;
  set selectNotebook(PenPowerNotebook newNotebook) {
    _selectNotebook = newNotebook;
    notifyListeners();
  }
}
