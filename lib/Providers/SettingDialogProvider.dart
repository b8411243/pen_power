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
import 'package:pen_power/Utils/Types.dart';

class SettingChangeNotifier extends ChangeNotifier {
  FocusNode userNameFocusNode = FocusNode();
  PenPowerUser user;

  SettingChangeNotifier(this.user) {
    userNameFocusNode.addListener(this.onFocusChange);
  }

  bool get isNameEmpty => user.name.isEmpty;

  void onFocusChange() {
    if (!userNameFocusNode.hasPrimaryFocus) {
      notifyListeners();
    }
  }

  void nameTextOnChangedAndSumitted(String name) {
    user.name = name;
  }

  void submitButtonOnPressed(BuildContext context) async {
    PenPowerDatabase db = PenPowerDatabase();
    await db.open();
    await db.updateUserName(user.name);
    Navigator.of(context).pop(user.name);
  }

  void cancelButtonOnPressed(BuildContext context) {
    Navigator.of(context).pop(null);
  }
}
