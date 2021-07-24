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
import 'package:pen_power/Utils/StringL10N.dart';
import 'package:pen_power/Views/NoteDialog.dart';
import 'package:pen_power/Utils/Types.dart';

class NotebookChangeNotifier extends ChangeNotifier {
  List<PenPowerNote> _noteList;
  NotebookChangeNotifier(this._noteList);

  List<PenPowerNote> get noteList => _noteList;

  void removeNote(BuildContext context, int noteId) {
    int index = _noteList.indexWhere((element) => element.noteId == noteId);
    if (index == -1)
      throw Exception(StrL10N.of(context).error_note_id_not_found(noteId));

    _noteList.removeAt(index);
    notifyListeners();
  }

  void gridItemOnTap(BuildContext context, PenPowerNote note) {
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) => NoteDialog(note)).then((noteId) {
      if (noteId != null) removeNote(context, noteId);
    });
  }
}
