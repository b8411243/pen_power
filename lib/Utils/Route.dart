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

import 'package:pen_power/Views/CreateNewNoteView.dart';
import 'package:pen_power/Views/NotebookListView.dart';
import 'package:pen_power/Views/NotebookView.dart';
import 'package:pen_power/Views/UnknowView.dart';
import 'package:pen_power/Utils/Types.dart';

class PenPowerRoutePath {
  PenPowerPages _pageStatus = PenPowerPages.NOTEBOOK_LIST;
  int notebookId = 0;
  int noteId = 0;

  PenPowerRoutePath.fromPage(PenPowerPages page,
      {this.notebookId = 0, this.noteId = 0})
      : _pageStatus = page;

  PenPowerRoutePath.unknown() : _pageStatus = PenPowerPages.UNKNOWN;
  PenPowerRoutePath.createNote() : _pageStatus = PenPowerPages.CREATE;
  PenPowerRoutePath.notebookList() : _pageStatus = PenPowerPages.NOTEBOOK_LIST;
  PenPowerRoutePath.notebookView(this.notebookId)
      : _pageStatus = PenPowerPages.NOTEBOOK_VIEW;

  set setStatus(PenPowerPages status) {
    _pageStatus = status;
  }

  PenPowerPages get status => _pageStatus;
}

class PenPowerInfoParser extends RouteInformationParser<PenPowerRoutePath> {
  @override
  Future<PenPowerRoutePath> parseRouteInformation(
      RouteInformation routeInformation) async {
    String location = routeInformation.location ?? "";
    if (location == "") return PenPowerRoutePath.unknown();

    final uri = Uri.parse(location);

    //Handel '/'
    if (uri.pathSegments.length == 0) {
      return PenPowerRoutePath.notebookList();
    }

    if (uri.pathSegments[0] == "create") {
      //Handle '/create'
      return PenPowerRoutePath.createNote();
    } else {
      //Handle '/${notebookId}'
      return PenPowerRoutePath.notebookView(int.parse(uri.pathSegments[0]));
    }
  }

  @override
  RouteInformation restoreRouteInformation(PenPowerRoutePath path) {
    switch (path.status) {
      case PenPowerPages.CREATE:
        return RouteInformation(location: '/create');
      case PenPowerPages.NOTEBOOK_LIST:
        return RouteInformation(location: '/');
      case PenPowerPages.NOTEBOOK_VIEW:
        return RouteInformation(location: '/${path.notebookId}');
      default:
        return RouteInformation(location: '/unkown');
    }
  }
}

class PenPowerRouterDelegate extends RouterDelegate<PenPowerRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<PenPowerRoutePath> {
  late final GlobalKey<NavigatorState> navigatorKey;

  late List<PenPowerRoutePath> _routePatList;

  PenPowerRouterDelegate() {
    navigatorKey = GlobalKey<NavigatorState>();
    _routePatList = [PenPowerRoutePath.notebookList()];
  }

  PenPowerRoutePath get currentConfiguration {
    return _routePatList.last;
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
        key: navigatorKey, pages: _toPageList(), onPopPage: _onPopPage);
  }

  @override
  Future<void> setInitialRoutePath(PenPowerRoutePath path) async {
    return;
  }

  @override
  Future<void> setNewRoutePath(PenPowerRoutePath path) async {
    _routePatList.add(path);
  }

  List<Page> _toPageList() {
    return _routePatList.map((routePath) => _toPage(routePath)).toList();
  }

  Page _toPage(PenPowerRoutePath routePath) {
    switch (routePath.status) {
      case PenPowerPages.CREATE:
        return CreateNewNotePage(removeLastPage);
      case PenPowerPages.NOTEBOOK_LIST:
        return NotebookListPage(addPage);
      case PenPowerPages.NOTEBOOK_VIEW:
        return NotebookPage(routePath.notebookId, removeLastPage);
      case PenPowerPages.UNKNOWN:
      default:
        return UnknowPage();
    }
  }

  bool _onPopPage(route, result) {
    if (!route.didPop(result)) return false;
    _routePatList.removeLast();
    notifyListeners();
    return true;
  }

  void addPage(PenPowerPages page, {int notebookId = 0, int noteId = 0}) {
    if (notebookId != 0 && noteId != 0)
      throw Exception("notebook id and note id can't set at the same time");

    _routePatList.add(PenPowerRoutePath.fromPage(page,
        notebookId: notebookId, noteId: noteId));
    notifyListeners();
  }

  void removeLastPage() {
    _routePatList.removeLast();
    notifyListeners();
  }
}
