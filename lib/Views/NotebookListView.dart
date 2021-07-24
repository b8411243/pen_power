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
import 'package:intl/intl.dart';

import 'package:pen_power/Providers/NotebookListDrawerProvider.dart';
import 'package:pen_power/Providers/NotebookListProvider.dart';
import 'package:pen_power/Views/NotebookListDrawerView.dart';
import 'package:pen_power/Views/DatabaseLoadingView.dart';
import 'package:pen_power/Views/TutorialDailog.dart';
import 'package:pen_power/Utils/StringL10N.dart';
import 'package:pen_power/Utils/Database.dart';
import 'package:pen_power/Utils/Types.dart';

class NotebookListPage extends Page {
  final Function(PenPowerPages, {int notebookId, int noteId}) _addPage;

  NotebookListPage(this._addPage);

  @override
  Route createRoute(BuildContext context) {
    return MaterialPageRoute(
        settings: this,
        builder: (context) => SafeArea(
                child: MultiProvider(
                    providers: [
                  ChangeNotifierProvider<NotebookListChangeNotifier>(
                      create: (context) => NotebookListChangeNotifier()),
                  ChangeNotifierProvider<NotebookListDrawerChangeNotifier>(
                      create: (context) => NotebookListDrawerChangeNotifier())
                ],
                    child: FutureBuilder(
                        future: _loadData(),
                        builder: (BuildContext context,
                            AsyncSnapshot<Tuple4> snapshot) {
                          if (snapshot.hasData)
                            return hasDataView(context, snapshot.data!);
                          else if (snapshot.hasError)
                            return Scaffold(
                                body: DatabaseLoadingView.hasError(context));
                          else
                            return Scaffold(
                                body: DatabaseLoadingView.loading(context));
                        }))));
  }

  Widget hasDataView(BuildContext context, Tuple4 data) {
    Provider.of<NotebookListChangeNotifier>(context)
        .setData(data.item1, data.item2, data.item3);
    Provider.of<NotebookListDrawerChangeNotifier>(context).setData(
        (data.item1 as List).length, (data.item3 as List).length, data.item4);

    return Scaffold(
        appBar: AppBar(
          title: Text(StrL10N.of(context).notebook_page_title),
          backgroundColor: Colors.white,
        ),
        drawer: NotebookListViewDrawer(_addPage),
        body: NotebookListView(_addPage),
        floatingActionButton: FloatingActionButton(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            child: Icon(Icons.add),
            onPressed: () => _addPage(PenPowerPages.CREATE)));
  }

  Future<
      Tuple4<List<PenPowerNotebook>, List<String>, List<PenPowerNote>,
          PenPowerUser>> _loadData() async {
    PenPowerDatabase db = PenPowerDatabase();
    await db.open();
    List<PenPowerNotebook> notebookList = await db.allNotebooks;
    List<PenPowerNote> noteList = await db.allNotes;
    PenPowerUser user = await db.firstUser;
    List<String> thumbnailPathList = [];

    for (PenPowerNotebook notebook in notebookList) {
      List<PenPowerNote> nList = await db.getNoteListByNotebook(notebook);
      if (nList.length == 0) {
        thumbnailPathList.add("");
      } else {
        thumbnailPathList.add(nList.last.thumbnailPath);
      }
    }
    return Tuple4(notebookList, thumbnailPathList, noteList, user);
  }
}

class NotebookListView extends StatelessWidget {
  final Function(PenPowerPages, {int notebookId, int noteId}) _addPage;
  NotebookListView(this._addPage);
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance!
        .addPostFrameCallback((_) => showWelcomeDialog(context));
    return Consumer<NotebookListChangeNotifier>(
        builder: (context, notifier, child) => ListView.builder(
            itemCount: notifier.notebookList.length,
            itemBuilder: (context, notebookIndex) {
              String subtitle = DateFormat("yyyy-MM-dd HH:mm").format(
                  DateTime.fromMillisecondsSinceEpoch(
                      notifier.notebookList[notebookIndex].notebookId));
              return ListTile(
                  leading: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                          alignment: AlignmentDirectional.center,
                          child:
                              (notifier.thumbnailList[notebookIndex].length ==
                                      0)
                                  ? Icon(Icons.image_rounded)
                                  : ClipRRect(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(10)),
                                      child: Image.file(File(notifier
                                          .thumbnailList[notebookIndex]))))),
                  title: Text(notifier.notebookList[notebookIndex].title,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(subtitle),
                  trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                            PopupMenuItem(
                                value: 0,
                                child: ListTile(
                                  trailing: Icon(Icons.edit_rounded),
                                  title: Text(StrL10N.of(context).btn_edit),
                                  onTap: () => notifier.editOnTap(
                                      context, notebookIndex),
                                )),
                            PopupMenuItem(
                                value: 1,
                                child: ListTile(
                                  trailing: Icon(Icons.delete_forever_rounded),
                                  title: Text(StrL10N.of(context).btn_delete),
                                  onTap: () => notifier.deleteOnTap(
                                      context, notebookIndex),
                                )),
                          ]),
                  onTap: () => _addPage(PenPowerPages.NOTEBOOK_VIEW,
                      notebookId:
                          notifier.notebookList[notebookIndex].notebookId));
            }));
  }

  showWelcomeDialog(BuildContext context) async {
    int isShow =
        Provider.of<NotebookListDrawerChangeNotifier>(context, listen: false)
            .user
            .showWelcome;

    if (isShow != 1) return;

    String target = StrL10N.of(context).tutorial_iprs_agree;

    String? userName = await showDialog(
        context: context, builder: (context) => TutorialDialog(true, target));

    if (userName != null) {
      Provider.of<NotebookListDrawerChangeNotifier>(context, listen: false)
          .userName = userName;
      Provider.of<NotebookListDrawerChangeNotifier>(context, listen: false)
          .showWelcome = 0;
    } else {
      throw Exception("cannot get new user name");
    }
  }
}

class NotebookEditDialog extends StatelessWidget {
  final PenPowerNotebook notebook;
  NotebookEditDialog(this.notebook);
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: ChangeNotifierProvider<NotebookEditChangeNotifier>(
            create: (context) => NotebookEditChangeNotifier(notebook),
            builder: (context, child) => Consumer<NotebookEditChangeNotifier>(
                builder: (context, editNotifier, child) => AlertDialog(
                        title: Text(StrL10N.of(context).notebook_edit),
                        content: AspectRatio(
                            aspectRatio: 1.3,
                            child: Column(children: [
                              TextField(
                                  focusNode: editNotifier.titleFocusNode,
                                  controller: TextEditingController()
                                    ..text = editNotifier.notebook.title
                                    ..selection = TextSelection.fromPosition(
                                        TextPosition(
                                            offset: editNotifier
                                                .notebook.title.length)),
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                      border: UnderlineInputBorder(),
                                      labelText: StrL10N.of(context)
                                              .input_notebook_title +
                                          " *",
                                      errorText: editNotifier.isTitleEmpty
                                          ? StrL10N.of(context)
                                              .input_notebook_title_warning
                                          : null),
                                  onChanged: editNotifier.titleTextOnChanged,
                                  onSubmitted:
                                      editNotifier.titleTextOnSubmitted),
                              TextField(
                                focusNode: editNotifier.descFocusNode,
                                controller: TextEditingController()
                                  ..text = editNotifier.notebook.description
                                  ..selection = TextSelection.fromPosition(
                                      TextPosition(
                                          offset: editNotifier
                                              .notebook.description.length)),
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                    border: UnderlineInputBorder(),
                                    labelText: StrL10N.of(context)
                                        .input_notebook_desc),
                                onChanged:
                                    editNotifier.descTextOnChangedAndSumitted,
                                onSubmitted:
                                    editNotifier.descTextOnChangedAndSumitted,
                              )
                            ])),
                        actions: [
                          TextButton(
                              child: Text(StrL10N.of(context).btn_cancel),
                              onPressed: () =>
                                  editNotifier.cancelButtonOnPressed(context)),
                          ElevatedButton(
                              child: Text(StrL10N.of(context).btn_submit,
                                  style: TextStyle(color: Colors.white)),
                              onPressed: () =>
                                  editNotifier.submitButtonOnPressed(context))
                        ]))));
  }
}

class NotebookDeleteDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        Icon(Icons.warning_rounded, color: Colors.yellow),
        Text(StrL10N.of(context).notebook_delete_title)
      ]),
      content: Text(StrL10N.of(context).notebook_delete_content),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 0,
      backgroundColor: Colors.white,
      actions: [
        TextButton(
            child: Text(StrL10N.of(context).btn_sure),
            onPressed: () {
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
