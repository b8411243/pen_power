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

import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import 'package:pen_power/Utils/Types.dart';

///
///         HEADER
///
/// 0   File Name           [100]
/// 100 File mode (octal)   [8]
/// 108 UID (octal)         [8]
/// 116 GID (octal)         [8]
/// 124 File size (octal)   [12]
/// 136 Time (octal)        [12]
/// 148 Checksum (octal)    [8]
/// 156 File Type           [1]
/// 157 Linked File         [100]
/// 257 "ustar" + NUL       [6]
/// 263 "00"(version)       [2]
/// 265 User name           [32]
/// 297 Group name          [32]
/// 329 Major number        [8]
/// 337 Minor number        [8]
/// 345 Filename prefix     [155]
/// 500 Empty               [12]

class Packaging {
  Uint8List packageFiles(
      {required List<Uint8List> rawFiles,
      required List<String> fileNames,
      required String folderName,
      required int createTime}) {
    if (rawFiles.length != fileNames.length)
      throw Exception("rawFiles.length != fileNames.length");

    BytesBuilder builder = BytesBuilder();

    //add folder
    builder.add(_createHeader(
        name: folderName + "/",
        size: 0,
        createTime: createTime,
        mode: "755",
        type: "5"));

    //add files
    for (int index = 0; index < rawFiles.length; ++index) {
      builder.add(_file(
          rawFiles[index], folderName + "/" + fileNames[index], createTime));
    }

    //EOF
    builder.add(Uint8List(1024));

    return builder.toBytes();
  }

  Map<String, Uint8List> depackageFiles(String pkgPath) {
    try {
      Uint8List pkgRawData = File(pkgPath).readAsBytesSync();

      //skip byte 0-511 which is folder
      int readerIndex = 512;

      Map<String, Uint8List> files = Map<String, Uint8List>();

      while (readerIndex < pkgRawData.length) {
        Map<String, String> header =
            _readHeader(pkgRawData.sublist(readerIndex, readerIndex + 512));

        int fileSize = int.parse(header["fileSize"]!, radix: 8);
        String fileName = basename(header["fileName"]!);

        readerIndex += 512;

        files[fileName] =
            pkgRawData.sublist(readerIndex, readerIndex + fileSize);

        readerIndex += 512 * ((fileSize / 512).ceil());

        if (_isEOF(pkgRawData.sublist(readerIndex, readerIndex + 512))) break;
      }
      return files;
    } catch (error) {
      throw Exception(error);
    }
  }

  Uint8List _createHeader(
      {required String name,
      required int size,
      required int createTime,
      String mode = "644",
      String type = "0",
      String userName = "user",
      String groupName = "penpower"}) {
    //guarantee that header size == 512
    Uint8List header = Uint8List(512);

    //file name
    header.setAll(0, Uint8List.fromList(ascii.encode(name)));

    //file mode
    header.setAll(
        100, Uint8List.fromList(ascii.encode(mode.padLeft(6, '0') + " ")));

    //uid & gid (set as 000000)
    header.setAll(108, Uint8List.fromList(ascii.encode("000000 ")));
    header.setAll(116, Uint8List.fromList(ascii.encode("000000 ")));

    //file size
    header.setAll(
        124,
        Uint8List.fromList(
            ascii.encode(size.toRadixString(8).padLeft(11, "0") + " ")));

    //time
    int unixTime = (createTime / 1000).round();
    header.setAll(
        136, Uint8List.fromList(ascii.encode(unixTime.toRadixString(8) + " ")));

    //Checksum (set as space(0x20) temporarily)
    header.setAll(148, Uint8List.fromList(ascii.encode("".padLeft(8, " "))));

    //file type
    header[156] = ascii.encode(type)[0];

    //linked file (empty)
    //UStar indicator
    header.setAll(257, Uint8List.fromList(ascii.encode("ustar")));

    //UStar version
    header.setAll(263, Uint8List.fromList(ascii.encode("00")));

    //user name
    header.setAll(265, Uint8List.fromList(ascii.encode(userName)));

    //group name
    header.setAll(297, Uint8List.fromList(ascii.encode(groupName)));

    //device major & minor number
    header.setAll(329, Uint8List.fromList(ascii.encode("000000 ")));
    header.setAll(337, Uint8List.fromList(ascii.encode("000000 ")));

    //calculate checksum & set
    Uint8List checksum = _checksum(header);
    header.setAll(148, checksum);

    return header;
  }

  Uint8List _file(Uint8List fileData, String fileName, int createTime) {
    BytesBuilder builder = BytesBuilder();

    int size = fileData.length;
    //header
    builder
        .add(_createHeader(name: fileName, size: size, createTime: createTime));
    //content
    builder.add(fileData);
    //rounded up to 512 bytes
    builder.add(Uint8List(512 - (size % 512)));

    return builder.toBytes();
  }

  Uint8List _checksum(Uint8List header) {
    int sum = 0;
    header.forEach((byte) {
      sum += byte;
    });

    return Uint8List.fromList(
        ascii.encode(sum.toRadixString(8).padLeft(6, '0')));
  }

  Map<String, String> _readHeader(Uint8List headerRawData) {
    Map<String, String> header = Map<String, String>();
    // 0   File Name           [100]
    header["fileName"] = _readItem(headerRawData.sublist(0, 100));
    // 100 File mode (octal)   [8]
    header["fileMode"] = _readItem(headerRawData.sublist(100, 108));
    // 108 UID (octal)         [8]
    header["uid"] = _readItem(headerRawData.sublist(108, 116));
    // 116 GID (octal)         [8]
    header["gid"] = _readItem(headerRawData.sublist(116, 124));
    // 124 File size (octal)   [12]
    header["fileSize"] = _readItem(headerRawData.sublist(124, 136));
    // 136 Time (octal)        [12]
    header["time"] = _readItem(headerRawData.sublist(136, 148));
    // 148 Checksum (octal)    [8]
    header["checksum"] = _readItem(headerRawData.sublist(148, 156));
    // 156 File Type           [1]
    header["fileType"] = _readItem(headerRawData.sublist(156, 157));
    // 157 Linked File         [100]
    //header["linkedFile"] = _readItem(headerRawData.sublist(157, 257));
    // 257 "ustar" + NUL       [6]
    //header["ustar"] = _readItem(headerRawData.sublist(0, 100));
    // 263 "00"(version)       [2]
    //header["version"] = _readItem(headerRawData.sublist(0, 100));
    // 265 User name           [32]
    header["userName"] = _readItem(headerRawData.sublist(265, 297));
    // 297 Group name          [32]
    header["groupName"] = _readItem(headerRawData.sublist(297, 329));
    // 329 Major number        [8]
    header["majorNumber"] = _readItem(headerRawData.sublist(329, 337));
    // 337 Minor number        [8]
    header["minorNumber"] = _readItem(headerRawData.sublist(337, 345));

    return header;
  }

  String _readItem(Uint8List rawData) {
    int dataEndIndex = rawData.length;
    for (int i = 0; i < rawData.length; ++i) {
      if (rawData[i] < 0x21) {
        dataEndIndex = i;
        break;
      }
    }
    return ascii.decode(rawData.sublist(0, dataEndIndex));
  }

  bool _isEOF(Uint8List rawData) {
    for (int i = 0; i < rawData.length; ++i) if (rawData[i] != 0) return false;
    return true;
  }
}

class PenPowerNotePackage extends Packaging {
  late Uint8List imageJpgRaw;
  late Uint8List thumbnailJpgRaw;
  late List<PenPowerLabel> labels;
  late int createTime;
  late Size imageSize;
  late String basePath;
  late String thumbnailDirPath;

  String get npkgPath => join(basePath, (createTime.toString() + ".npkg"));
  String get thumbnailPath =>
      join(thumbnailDirPath, "thumbnail_" + createTime.toString() + ".jpg");

  PenPowerNotePackage.create(
      {required this.imageJpgRaw,
      required this.thumbnailJpgRaw,
      required this.labels,
      required this.createTime,
      required this.imageSize,
      required this.basePath})
      : thumbnailDirPath = join(basePath, "thumbnail");

  void save() {
    try {
      //packege it
      Uint8List packagedFile = packageFiles(
          rawFiles: [imageJpgRaw, _list2jsonFile()],
          fileNames: ["image.jpg", "labels.json"],
          folderName: createTime.toString(),
          createTime: createTime);
      //write file
      File(join(basePath, (createTime.toString() + ".npkg")))
          .writeAsBytesSync(packagedFile);
    } on Exception catch (e) {
      throw Exception(e);
    }

    //write thumbnail
    Directory dir = Directory(thumbnailDirPath);
    dir.exists().then((isExists) {
      if (!isExists) {
        //directory not exist -> create it and save thumbnail
        dir.create().then((value) {
          File(join(thumbnailDirPath,
                  "thumbnail_" + createTime.toString() + ".jpg"))
              .writeAsBytesSync(thumbnailJpgRaw);
        });
      } else {
        //directory exists -> save thumbnail
        File(join(thumbnailDirPath,
                "thumbnail_" + createTime.toString() + ".jpg"))
            .writeAsBytesSync(thumbnailJpgRaw);
      }
    });
  }

  Uint8List _list2jsonFile() {
    //convert List<PenPowerLabel> to json formatted String
    String jsonLabels =
        json.encode({"labels": labels.map((label) => label.toMap()).toList()});

    //encode String as Uint8List
    BytesBuilder builder = BytesBuilder();
    builder.add(ascii.encode(jsonLabels));
    return builder.toBytes();
  }

  PenPowerNotePackage.read(PenPowerNote note) {
    basePath = dirname(note.npkgPath);
    createTime = int.parse(basenameWithoutExtension(note.npkgPath));
    thumbnailDirPath = dirname(note.thumbnailPath);
    thumbnailJpgRaw = File(note.thumbnailPath).readAsBytesSync();
    imageSize = Size(note.imageWidth.toDouble(), note.imageHeight.toDouble());

    //read *.npkg file
    Map<String, Uint8List> files = depackageFiles(note.npkgPath);
    imageJpgRaw = files["image.jpg"]!;
    labels = _jsonFile2List(files["labels.json"]!);
  }

  List<PenPowerLabel> _jsonFile2List(Uint8List jsonFileRaw) {
    String jsonString = ascii.decode(jsonFileRaw);
    Map<String, dynamic> jsonMap = json.decode(jsonString);

    return (jsonMap["labels"] as List)
        .map((label) => PenPowerLabel.fromMap(label))
        .toList();
  }

  static void delete(PenPowerNote note) async {
    try {
      await File(note.npkgPath).delete();
      await File(note.thumbnailPath).delete();
    } catch (error) {
      throw Exception(error);
    }
  }
}
