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

import 'package:dots_indicator/dots_indicator.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'package:pen_power/Providers/TutorialDialogProvider.dart';
import 'package:pen_power/Utils/StringL10N.dart';

class TutorialDialog extends StatelessWidget {
  final bool isFirstTimeUse;
  final String target;
  TutorialDialog(this.isFirstTimeUse, this.target);

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
            child: ChangeNotifierProvider<TutorialDialogChangeNotifier>(
                create: (context) => TutorialDialogChangeNotifier(
                    target, isFirstTimeUse ? 6 : 3),
                builder: (context, child) {
                  return Container(
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
                      child: AspectRatio(
                          aspectRatio: 0.7,
                          child: ClipRRect(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(15)),
                              child: Stack(
                                  alignment: AlignmentDirectional.topEnd,
                                  children: [
                                    mainView(context),
                                    if (!isFirstTimeUse)
                                      IconButton(
                                          icon: Icon(Icons.close_rounded),
                                          onPressed: () =>
                                              Navigator.of(context).pop())
                                  ]))));
                })));
  }

  Widget mainView(BuildContext context) {
    return Consumer<TutorialDialogChangeNotifier>(
        builder: (context, notifier, child) => Column(children: [
              Expanded(
                  flex: 10,
                  child: PageView(
                    onPageChanged: notifier.onPageChanged,
                    controller: notifier.pageController,
                    children: [
                      _tutorialStep(
                          context,
                          StrL10N.of(context).tutorial_capture,
                          Icons.photo_camera_outlined),
                      _tutorialStep(context, StrL10N.of(context).tutorial_draw,
                          Icons.gesture_outlined),
                      _tutorialStep(context, StrL10N.of(context).tutorial_study,
                          Icons.school_outlined),
                      if (isFirstTimeUse) _iprsPage(context, notifier),
                      if (isFirstTimeUse) _userName(context, notifier),
                      if (isFirstTimeUse)
                        _tutorialStep(
                            context,
                            StrL10N.of(context).tutorial_done,
                            Icons.done_all_rounded)
                    ],
                  )),
              (!notifier.isLastPage)
                  ? Spacer(flex: 1)
                  : Expanded(
                      flex: 1,
                      child: ElevatedButton(
                          child: Text(StrL10N.of(context).btn_exit,
                              style: TextStyle(color: Colors.white)),
                          onPressed: () =>
                              notifier.exitButtonOnPressed(context))),
              Expanded(
                  flex: 1,
                  child: DotsIndicator(
                      dotsCount: notifier.maxPage,
                      position: notifier.currentPage.toDouble()))
            ]));
  }

  Widget _tutorialStep(BuildContext context, String title, IconData icon) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
          width: MediaQuery.of(context).size.width / 3,
          child: FittedBox(
              child: Icon(icon, color: Theme.of(context).primaryColor))),
      SizedBox(height: 10),
      SizedBox(
          width: MediaQuery.of(context).size.width / 3,
          child: FittedBox(child: Text(title))),
    ]);
  }

  Widget _iprsPage(
      BuildContext context, TutorialDialogChangeNotifier notifier) {
    if (!isFirstTimeUse) throw Exception("This page is not for you");
    return Container(
        padding: EdgeInsetsDirectional.all(10),
        child: Column(children: [
          Text(StrL10N.of(context).tutorial_iprs_title,
              textAlign: TextAlign.center),
          Text(StrL10N.of(context).tutorial_iprs_content,
              textAlign: TextAlign.center),
          Spacer(),
          TextField(
            textInputAction: TextInputAction.done,
            controller: TextEditingController()
              ..text = notifier.agreeIPRS
              ..selection = TextSelection.fromPosition(
                  TextPosition(offset: notifier.agreeIPRS.length)),
            decoration: InputDecoration(
                border: UnderlineInputBorder(),
                labelText: StrL10N.of(context).input_iprs_title,
                hintText: StrL10N.of(context)
                    .input_iprs_hint(notifier.agreeIPRSTarget),
                errorText: notifier.isUserTyped
                    ? null
                    : StrL10N.of(context)
                        .input_iprs_warning(notifier.agreeIPRSTarget)),
            onChanged: notifier.irpsOnChanged,
            onSubmitted: notifier.irpsOnSubmitted,
          ),
          Spacer(),
          ElevatedButton(
              onPressed: () => SystemNavigator.pop(),
              child: Text(StrL10N.of(context).btn_iprs_disagree,
                  style: TextStyle(color: Colors.white)))
        ]));
  }

  Widget _userName(
      BuildContext context, TutorialDialogChangeNotifier notifier) {
    if (!isFirstTimeUse) throw Exception("This page is not for you");
    return Container(
        padding: EdgeInsetsDirectional.all(10),
        child: Column(children: [
          Text(StrL10N.of(context).tutorial_new_user_title),
          Spacer(),
          TextField(
              focusNode: notifier.nameFocusNode,
              controller: TextEditingController()
                ..text = notifier.userName
                ..selection = TextSelection.fromPosition(
                    TextPosition(offset: notifier.userName.length)),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: StrL10N.of(context).input_name + " *",
                  errorText: notifier.isUserNameEmpty
                      ? StrL10N.of(context).input_name_warning
                      : null),
              onChanged: notifier.nameOnChanged,
              onSubmitted: notifier.nameOnSubmitted),
          Spacer(),
        ]));
  }
}
