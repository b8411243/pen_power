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

import 'package:pen_power/Utils/Database.dart';

class TutorialDialogChangeNotifier extends ChangeNotifier {
  // page view
  int _currentPage = 0;
  int maxPage;
  PageController _pageController = PageController(initialPage: 0);

  // username
  FocusNode nameFocusNode = FocusNode();
  String userName = "new user";

  // iprs check
  FocusNode iprsFocusNode = FocusNode();
  String agreeIPRS = "";
  final String agreeIPRSTarget;

  TutorialDialogChangeNotifier(this.agreeIPRSTarget, this.maxPage) {
    nameFocusNode.addListener(this.onFocusChanged);
    iprsFocusNode.addListener(this.onFocusChanged);
  }

  PageController get pageController => _pageController;
  int get currentPage => _currentPage;
  bool get isLastPage => _currentPage == maxPage - 1;
  set currentPage(int page) {
    _currentPage = page;
    notifyListeners();
  }

  void onPageChanged(int pageNumger) {
    if (pageNumger == 4) {
      //user swap to user name page (page 4)
      if (isUserTyped) {
        currentPage = pageNumger;
      } else {
        currentPage = 3;
        _pageController.jumpToPage(3);
      }
    } else if (pageNumger == 5) {
      if (!isUserNameEmpty) {
        //not empty and user is typed
        currentPage = pageNumger;
      } else {
        currentPage = 4;
        _pageController.jumpToPage(4);
      }
    } else {
      currentPage = pageNumger;
    }
  }

  void onFocusChanged() {
    if (!nameFocusNode.hasPrimaryFocus || !iprsFocusNode.hasPrimaryFocus) {
      notifyListeners();
    }
  }

  void irpsOnChanged(String str) {
    agreeIPRS = str;
  }

  void irpsOnSubmitted(String str) {
    agreeIPRS = str;
    notifyListeners();
  }

  void nameOnChanged(String str) {
    userName = str;
  }

  void nameOnSubmitted(String str) {
    userName = str;
    notifyListeners();
  }

  bool get isUserNameEmpty => userName.isEmpty;

  bool get isUserTyped {
    //remove spaces
    String targetString = agreeIPRSTarget.replaceAll(' ', '');
    String objectString = agreeIPRS.replaceAll(' ', '');

    if (objectString.length != targetString.length) return false;

    //turn all to upper case
    targetString = targetString.toUpperCase();
    objectString = objectString.toUpperCase();

    return objectString == targetString;
  }

  void autoNextPage() {
    _pageController.jumpToPage(4);
    currentPage = 4;
    notifyListeners();
  }

  void exitButtonOnPressed(BuildContext context) async {
    if (_currentPage == 2) {
      Navigator.of(context).pop();
    } else {
      //save to db
      PenPowerDatabase db = PenPowerDatabase();
      await db.open();
      await db.updateUserName(userName);
      Navigator.of(context).pop(userName);
    }
  }
}
