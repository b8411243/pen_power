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

import 'package:device_info/device_info.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart';

import 'package:pen_power/Utils/Types.dart';

class PenPowerDatabase {
  late final Database database;
  final String _nameDB = "penpowerDatabase.db";
  final int _versionDB = 1;

  PenPowerDatabase() {
    WidgetsFlutterBinding.ensureInitialized();
  }

  Future<void> open() async {
    bool firstUse = false;
    database = await openDatabase(join(await getDatabasesPath(), _nameDB),
        onCreate: (db, version) {
      //create user table
      db.execute("CREATE TABLE user(user_id TEXT PRIMARY KEY,"
          "name TEXT NOT NULL,"
          "latest_color INTEGER NOT NULL,"
          "latest_width INTEGER NOT NULL,"
          "show_welcome INTEGER NOT NULL"
          ")");
      //create notebook table
      db.execute("CREATE TABLE notebook(notebook_id INTEGER PRIMARY KEY,"
          "user_id INTEGER NOT NULL,"
          "title TEXT NOT NULL,"
          "description TEXT)");
      //create note table
      db.execute("CREATE TABLE note(note_id INTEGER PRIMARY KEY,"
          "notebook_id INT,"
          "user_id INT,"
          "npkg_path TEXT NOT NULL,"
          "thumbnail_path TEXT NOT NULL,"
          "image_width INTEGER NOT NULL,"
          "image_height INTEGER NOT NULL,"
          "title TEXT NOT NULL,"
          "description TEXT)");

      //create default data
      firstUse = true;
    }, version: _versionDB);

    if (firstUse) await initDatabase();
  }

  Future<void> initDatabase() async {
    final DeviceInfoPlugin deviceInfoPlugin = new DeviceInfoPlugin();
    String deviceId = DateTime.now().millisecondsSinceEpoch.toString();
    if (Platform.isAndroid) {
      AndroidDeviceInfo build = await deviceInfoPlugin.androidInfo;
      deviceId = build.androidId;
    } else if (Platform.isIOS) {
      IosDeviceInfo build = await deviceInfoPlugin.iosInfo;
      deviceId = build.identifierForVendor;
    }

    await database.insert("user", {
      "user_id": deviceId,
      "name": "new user",
      "latest_color": 0x7FFFFF00,
      "latest_width": 10,
      "show_welcome": 1
    });
    await database.insert("notebook", {
      "notebook_id": DateTime.now().millisecondsSinceEpoch,
      "user_id": deviceId,
      "title": "default",
      "description": ""
    });
  }

  void close() => database.close();

  Future<List<PenPowerUser>> get allUsers async {
    //SELECT * FROM user
    List<Map<String, dynamic>> maps = await database.query("user");
    List<PenPowerUser> userList = [];
    maps.forEach((map) {
      userList.add(PenPowerUser.fromMap(map));
    });
    return userList;
  }

  Future<List<PenPowerNotebook>> get allNotebooks async {
    //SELECT * FROM notebook
    List<Map<String, dynamic>> maps = await database.query("notebook");
    List<PenPowerNotebook> notebookList = [];
    maps.forEach((map) {
      notebookList.add(PenPowerNotebook.fromMap(map));
    });
    return notebookList;
  }

  Future<List<PenPowerNote>> get allNotes async {
    //SELECT * FROM note
    List<Map<String, dynamic>> maps = await database.query("note");

    List<PenPowerNote> noteList = [];
    maps.forEach((map) {
      noteList.add(PenPowerNote.fromMap(map));
    });
    return noteList;
  }

  Future<PenPowerUser> get firstUser async {
    //SELECT * FROM user
    List<Map<String, dynamic>> maps = await database.query("user");
    return PenPowerUser.fromMap(maps[0]);
  }

  Future<List<PenPowerNote>> getNoteListByNotebook(
      PenPowerNotebook notebook) async {
    return await getNoteList(notebook.notebookId);
  }

  Future<List<PenPowerNotebook>> getNotebookList(PenPowerUser user) async {
    //SELECT * FROM notebook WHERE user_id=$user.userId
    List<Map<String, dynamic>> maps = await database
        .query("notebook", where: "user_id = ?", whereArgs: [user.userId]);
    List<PenPowerNotebook> notebookList = [];
    maps.forEach((map) {
      notebookList.add(PenPowerNotebook.fromMap(map));
    });
    return notebookList;
  }

  Future<PenPowerNotebook> getNotebook(int notebookId) async {
    //SELECT * FROM notebook WHERE notebook_id=$notebookId
    List<Map<String, dynamic>> maps = await database
        .query("notebook", where: "notebook_id = ?", whereArgs: [notebookId]);

    return PenPowerNotebook.fromMap(maps[0]);
  }

  Future<List<PenPowerNote>> getNoteList(int notebookId) async {
    //SELECT * FROM note WHERE notebook_id=$notebookId
    List<Map<String, dynamic>> maps = await database
        .query("note", where: "notebook_id = ?", whereArgs: [notebookId]);

    List<PenPowerNote> noteList = [];
    maps.forEach((map) {
      noteList.add(PenPowerNote.fromMap(map));
    });
    return noteList;
  }

  Future<PenPowerNote> getNote(int noteId) async {
    //SELECT * FROM note WHERE note_id=$noteId
    List<Map<String, dynamic>> maps =
        await database.query("note", where: "note_id = ?", whereArgs: [noteId]);
    return PenPowerNote.fromMap(maps[0]);
  }

  Future<void> insertNotebook(PenPowerNotebook notebook) async =>
      await database.insert("notebook", notebook.toMap());

  Future<void> insertNote(PenPowerNote note) async =>
      await database.insert("note", note.toMap());

  Future<void> updateUserName(String userName) async {
    PenPowerUser user = await this.firstUser;
    await database.update("user", {"name": userName, "show_welcome": 0},
        where: "user_id = ?", whereArgs: [user.userId]);
  }

  Future<void> updateNotebook(PenPowerNotebook notebook) async {
    await database.update("notebook", notebook.toUpdateMap(),
        where: "notebook_id = ?", whereArgs: [notebook.notebookId]);
  }

  Future<void> updateNote(PenPowerNote note) async {
    await database.update("note", note.toUpdateMap(),
        where: "note_id = ?", whereArgs: [note.noteId]);
  }

  Future<void> deleteNotebookByNotebook(PenPowerNotebook notebook) async {
    await deleteNotebook(notebook.notebookId);
  }

  Future<void> deleteNotebook(int notebookId) async {
    await database
        .delete("notebook", where: "notebook_id = ?", whereArgs: [notebookId]);
  }

  Future<void> deleteNoteByNote(PenPowerNote note) async {
    await deleteNote(note.noteId);
  }

  Future<void> deleteNote(int noteId) async {
    await database.delete("note", where: "note_id = ?", whereArgs: [noteId]);
  }
}
