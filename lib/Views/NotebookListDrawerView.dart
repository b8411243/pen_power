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

import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'package:pen_power/Providers/NotebookListDrawerProvider.dart';
import 'package:pen_power/Utils/StringL10N.dart';
import 'package:pen_power/Utils/Types.dart';

class NotebookListViewDrawer extends StatelessWidget {
  final Function(PenPowerPages, {int notebookId, int noteId}) _addPage;
  NotebookListViewDrawer(this._addPage);
  @override
  Widget build(BuildContext context) {
    return Consumer<NotebookListDrawerChangeNotifier>(
        builder: (context, drawerNotifier, child) => Container(
            width: MediaQuery.of(context).size.width * 0.6,
            child: Drawer(
                child: ListView(children: [
              _header(context, drawerNotifier),
              ListTile(
                  leading: Icon(Icons.grid_view_rounded),
                  title: Text(StrL10N.of(context).drawer_show_all_note),
                  onTap: () =>
                      drawerNotifier.showAllNotesOnTap(context, _addPage)),
              ListTile(
                  leading: Icon(Icons.lightbulb_rounded),
                  title: Text(StrL10N.of(context).drawer_tutorial),
                  onTap: () => drawerNotifier.tutorialOnTap(context)),
              ListTile(
                  leading: Icon(Icons.settings_rounded),
                  title: Text(StrL10N.of(context).drawer_setting),
                  onTap: () => drawerNotifier.settingOnTap(context)),
              ListTile(
                  leading: Icon(Icons.info_rounded),
                  title: Text(StrL10N.of(context).drawer_about),
                  onTap: () => drawerNotifier.aboutOnTap(context)),
            ]))));
  }

  Widget _header(
      BuildContext context, NotebookListDrawerChangeNotifier drawerNotifier) {
    return DrawerHeader(
        child: Container(
            decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).primaryColor),
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Expanded(
                  child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: Theme.of(context).primaryColor))),
                      child: Container(
                          padding: EdgeInsetsDirectional.only(start: 5, end: 5),
                          child: FittedBox(
                              alignment: AlignmentDirectional.bottomCenter,
                              fit: BoxFit.contain,
                              child: Text(drawerNotifier.user.name))))),
              Expanded(child: _dataStatisticWidget(context, drawerNotifier))
            ])));
  }

  Widget _dataStatisticWidget(
      BuildContext context, NotebookListDrawerChangeNotifier drawerNotifier) {
    return Row(children: [
      Expanded(
          child: _singleDataWidget(drawerNotifier.notebookLength,
              StrL10N.of(context).notebook_page_title, Colors.pink,
              onTap: () => drawerNotifier.notebookLengthOnTap(context))),
      Expanded(
          child: Container(
        decoration: BoxDecoration(
            border: Border(
                left: BorderSide(color: Theme.of(context).primaryColor))),
        child: _singleDataWidget(drawerNotifier.noteLength,
            StrL10N.of(context).note_page_title, Colors.teal,
            onTap: () => drawerNotifier.showAllNotesOnTap(context, _addPage)),
      )),
    ]);
  }

  Widget _singleDataWidget(int value, String title, Color color,
      {required void Function() onTap}) {
    return InkWell(
        onTap: onTap,
        child: Column(children: [
          Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: color, width: 3))),
                child: FittedBox(child: Text(" " + value.toString() + " ")),
              )),
          Expanded(
            flex: 1,
            child: Container(
                padding: EdgeInsetsDirectional.all(2),
                child: FittedBox(
                    child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w400),
                ))),
          )
        ]));
  }
}
