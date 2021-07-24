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

import 'package:flutter/material.dart';

import 'package:pen_power/Views/NotebookListView.dart';
import 'package:pen_power/Utils/Database.dart';
import 'package:pen_power/Utils/Package.dart';
import 'package:pen_power/Utils/Types.dart';

class NotebookListChangeNotifier extends ChangeNotifier {
  late List<PenPowerNotebook> _notebookList;
  late List<PenPowerNote> _noteList;
  late List<String> _thumbnailList;

  NotebookListChangeNotifier();

  List<String> get thumbnailList => _thumbnailList;
  List<PenPowerNotebook> get notebookList => _notebookList;

  void setData(List<PenPowerNotebook> notebookList, List<String> thumbnailList,
      List<PenPowerNote> noteList) {
    _notebookList = notebookList;
    _thumbnailList = thumbnailList;
    _noteList = noteList;
  }

  void editOnTap(BuildContext context, int index) async {
    Navigator.of(context).pop();
    PenPowerNotebook? newNotebook = await showDialog(
        context: context,
        builder: (context) => NotebookEditDialog(_notebookList[index]));
    if (newNotebook != null) {
      _notebookList[index] = newNotebook;
      notifyListeners();
    }
  }

  void deleteOnTap(BuildContext context, int index) async {
    Navigator.of(context).pop();
    bool? isUserDelete = await showDialog(
        context: context, builder: (context) => NotebookDeleteDialog());

    if (isUserDelete != null && isUserDelete) {
      await _deleteProgress(index);
      _notebookList.removeAt(index);
      _thumbnailList.removeAt(index);
      notifyListeners();
    }
  }

  Future<void> _deleteProgress(int index) async {
    PenPowerNotebook notebook = _notebookList[index];
    PenPowerDatabase db = PenPowerDatabase();
    await db.open();

    //delete notes
    List<PenPowerNote> noteList = await db.getNoteListByNotebook(notebook);
    noteList.forEach((removeNote) async {
      _noteList.removeWhere((note) => note == removeNote);
      PenPowerNotePackage.delete(removeNote);
      await db.deleteNoteByNote(removeNote);
    });

    await db.deleteNotebookByNotebook(notebook);
  }
}

class NotebookEditChangeNotifier extends ChangeNotifier {
  FocusNode titleFocusNode = FocusNode();
  FocusNode descFocusNode = FocusNode();
  PenPowerNotebook notebook;
  NotebookEditChangeNotifier(this.notebook) {
    titleFocusNode.addListener(this.onFocusChange);
    descFocusNode.addListener(this.onFocusChange);
  }

  bool get isTitleEmpty => notebook.title.isEmpty;

  void onFocusChange() {
    if (!titleFocusNode.hasPrimaryFocus || !descFocusNode.hasPrimaryFocus) {
      notifyListeners();
    }
  }

  void titleTextOnChanged(String title) {
    notebook.title = title;
  }

  void titleTextOnSubmitted(String title) {
    notebook.title = title;
    descFocusNode.requestFocus();
  }

  void descTextOnChangedAndSumitted(String desc) {
    notebook.description = desc;
  }

  void submitButtonOnPressed(BuildContext context) async {
    PenPowerDatabase db = PenPowerDatabase();
    await db.open();
    await db.updateNotebook(notebook);
    Navigator.of(context).pop(notebook);
  }

  void cancelButtonOnPressed(BuildContext context) {
    Navigator.of(context).pop(null);
  }
}
