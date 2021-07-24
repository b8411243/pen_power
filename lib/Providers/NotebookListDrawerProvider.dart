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

import 'package:package_info/package_info.dart';
import 'package:flutter/material.dart';

import 'package:pen_power/Views/TutorialDailog.dart';
import 'package:pen_power/Views/SettingDialog.dart';
import 'package:pen_power/Utils/StringL10N.dart';
import 'package:pen_power/Utils/Types.dart';

class NotebookListDrawerChangeNotifier extends ChangeNotifier {
  late int notebookLength, noteLength;
  late PenPowerUser _user;

  NotebookListDrawerChangeNotifier();

  PenPowerUser get user => _user;
  set userName(String name) {
    _user.name = name;
    notifyListeners();
  }

  set showWelcome(int showWelcome) {
    _user.showWelcome = showWelcome;
    notifyListeners();
  }

  setData(int notebookLen, int noteLen, PenPowerUser user) {
    notebookLength = notebookLen;
    noteLength = noteLen;
    _user = user;
  }

  void showAllNotesOnTap(BuildContext context,
      void Function(PenPowerPages, {int notebookId, int noteId}) addPage) {
    Navigator.of(context).pop();
    addPage(PenPowerPages.NOTEBOOK_VIEW, notebookId: -1);
  }

  void tutorialOnTap(BuildContext context) {
    Navigator.of(context).pop();
    showDialog(
        context: context, builder: (context) => TutorialDialog(false, ""));
  }

  void settingOnTap(BuildContext context) {
    Navigator.of(context).pop();
    showDialog(context: context, builder: (context) => SettingDialog(_user))
        .then((newName) {
      if (newName != null) this.userName = newName;
    });
  }

  void aboutOnTap(BuildContext context) async {
    Navigator.of(context).pop();
    PackageInfo info = await PackageInfo.fromPlatform();

    showAboutDialog(
        context: context,
        applicationName: StrL10N.of(context).app_title,
        applicationIcon: Image.asset(
          "assets/icon/pen_power_icon_transparent_large.png",
          width: MediaQuery.of(context).size.width / 6,
        ),
        applicationVersion: info.version,
        applicationLegalese: StrL10N.of(context).app_legalese,
        children: [
          SizedBox(height: 10),
          Center(
              child: Text(StrL10N.of(context).app_author_title,
                  textAlign: TextAlign.center)),
          SizedBox(height: 5),
          Center(
            child: Text(StrL10N.of(context).app_author_name,
                textAlign: TextAlign.center),
          ),
          SizedBox(height: 10),
          Center(
              child: Text(StrL10N.of(context).app_translate_title,
                  textAlign: TextAlign.center)),
          SizedBox(height: 5),
          Center(
            child: Text(StrL10N.of(context).app_translate_name,
                textAlign: TextAlign.center),
          )
        ]);
  }

  void notebookLengthOnTap(BuildContext context) {
    Navigator.of(context).pop();
  }
}
