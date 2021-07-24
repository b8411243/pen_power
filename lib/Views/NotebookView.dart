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

import 'dart:io';

import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';

import 'package:pen_power/Providers/NotebookProvider.dart';
import 'package:pen_power/Views/DatabaseLoadingView.dart';
import 'package:pen_power/Utils/StringL10N.dart';
import 'package:pen_power/Utils/Database.dart';
import 'package:pen_power/Utils/Types.dart';

class NotebookPage extends Page {
  final int notebookId;
  final void Function() _removeLastPage;
  NotebookPage(this.notebookId, this._removeLastPage);
  @override
  Route createRoute(BuildContext context) {
    return MaterialPageRoute(
        settings: this,
        builder: (context) {
          return SafeArea(
              child: FutureBuilder(
                  future: _loadNotes(context),
                  builder: (BuildContext context,
                      AsyncSnapshot<Tuple2<List<PenPowerNote>, String>>
                          snapshot) {
                    if (snapshot.hasData) {
                      return ChangeNotifierProvider<NotebookChangeNotifier>(
                          create: (context) =>
                              NotebookChangeNotifier(snapshot.data!.item1),
                          builder: (context, child) => Scaffold(
                              appBar: AppBar(
                                title: Text(snapshot.data!.item2),
                                backgroundColor: Colors.white,
                                leading: IconButton(
                                  icon: Icon(Icons.arrow_back_rounded),
                                  onPressed: _removeLastPage,
                                ),
                              ),
                              body: NotebookView()));
                    } else if (snapshot.hasError) {
                      return Scaffold(
                          body: DatabaseLoadingView.hasError(context));
                    } else {
                      return Scaffold(
                          body: DatabaseLoadingView.loading(context));
                    }
                  }));
        });
  }

  Future<Tuple2<List<PenPowerNote>, String>> _loadNotes(
      BuildContext context) async {
    PenPowerDatabase db = PenPowerDatabase();
    await db.open();
    if (notebookId == -1) {
      List<PenPowerNote> noteList = await db.allNotes;

      return Tuple2(noteList, StrL10N.of(context).note_page_title_all);
    } else {
      List<PenPowerNote> noteList = await db.getNoteList(notebookId);
      String notebookTitle = (await db.getNotebook(notebookId)).title;
      return Tuple2(noteList, notebookTitle);
    }
  }
}

class NotebookView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<NotebookChangeNotifier>(
        builder: (context, notifier, child) {
      if (notifier.noteList.length > 0) {
        return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, childAspectRatio: 1),
            itemCount: notifier.noteList.length,
            itemBuilder: (context, index) {
              PenPowerNote note = notifier.noteList[index];
              return InkWell(
                onTap: () => notifier.gridItemOnTap(context, note),
                child: GridTile(child: Image.file(File(note.thumbnailPath))),
              );
            });
      } else {
        return Center(child: Text(StrL10N.of(context).notebook_empty));
      }
    });
  }
}
