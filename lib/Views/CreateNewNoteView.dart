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

import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';
import 'package:intl/intl.dart';

import 'package:pen_power/Providers/CreateNewNoteProvider.dart';
import 'package:pen_power/Utils/StringL10N.dart';
import 'package:pen_power/Utils/Database.dart';
import 'package:pen_power/Utils/Types.dart';

class CreateNewNotePage extends Page {
  late final void Function() _removeLastPage;
  CreateNewNotePage(this._removeLastPage);
  @override
  Route createRoute(BuildContext context) {
    return MaterialPageRoute(
        settings: this,
        builder: (context) {
          return MultiProvider(
              providers: [
                ChangeNotifierProvider<StepperChangeNotifier>(
                    create: (contex) => StepperChangeNotifier(_removeLastPage)),
                ChangeNotifierProvider<InputViewChangeNotifier>(
                    create: (context) => InputViewChangeNotifier()),
                ChangeNotifierProvider<HighlightViewChangeNotifier>(
                    create: (context) => HighlightViewChangeNotifier()),
                ChangeNotifierProvider<NotebookViewChangeNotifier>(
                    create: (context) =>
                        NotebookViewChangeNotifier(_removeLastPage))
              ],
              builder: (context, child) {
                return SafeArea(
                    child: Scaffold(
                        body: WillPopScope(
                            onWillPop: () async {
                              Provider.of<StepperChangeNotifier>(context,
                                      listen: false)
                                  .cancel();
                              return false;
                            },
                            child: CreateNewNoteStepper())));
              });
        });
  }
}

class CreateNewNoteStepper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    //print("CreateNewNoteStepper builded");

    return Selector<StepperChangeNotifier, int>(
        selector: (context, notifier) => notifier.currentStep,
        shouldRebuild: (preStep, nextStep) => preStep != nextStep,
        builder: (context, currentStep, child) => Stepper(
              type: StepperType.horizontal,
              physics: currentStep == 1
                  ? NeverScrollableScrollPhysics()
                  : ClampingScrollPhysics(),
              currentStep: currentStep,
              onStepTapped: (step) =>
                  Provider.of<StepperChangeNotifier>(context, listen: false)
                      .tapped(step),
              onStepContinue:
                  Provider.of<StepperChangeNotifier>(context, listen: false)
                      .continued,
              onStepCancel:
                  Provider.of<StepperChangeNotifier>(context, listen: false)
                      .cancel,
              controlsBuilder: _stepperControlBuilder,
              steps: [
                setInputStep(context, currentStep),
                highlightSelectStep(context, currentStep),
                notebookSelectStep(context, currentStep)
              ],
            ));
  }

  Widget _stepperControlBuilder(context, {onStepCancel, onStepContinue}) {
    return Selector<StepperChangeNotifier, int>(
        selector: (context, notifier) => notifier.currentStep,
        builder: (context, currentStep, child) =>
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: onStepCancel,
                  child: (currentStep == 0)
                      ? Text(StrL10N.of(context).btn_cancel.toLowerCase())
                      : Text(StrL10N.of(context).btn_previous.toLowerCase())),
              if (currentStep != 2)
                Selector<StepperChangeNotifier, bool>(
                    selector: (context, notifier) => notifier.nextButtonEnable,
                    builder: (context, enable, child) => ElevatedButton(
                        onPressed: (enable) ? onStepContinue : null,
                        child: Text(StrL10N.of(context).btn_next.toUpperCase(),
                            style: TextStyle(color: Colors.white)))),
            ]));
  }

  Step setInputStep(BuildContext context, int currentStep) {
    return Step(
        title: Text(StrL10N.of(context).new_bar_input),
        isActive: currentStep >= 0,
        state: currentStep >= 1 ? StepState.complete : StepState.disabled,
        content: InputStepView());
  }

  Step highlightSelectStep(BuildContext context, int currentStep) {
    return Step(
        title: Text(StrL10N.of(context).new_bar_draw),
        isActive: currentStep >= 1,
        state: currentStep >= 2 ? StepState.complete : StepState.disabled,
        content: HighlightSelectStepView());
  }

  Step notebookSelectStep(BuildContext context, int currentStep) {
    return Step(
        title: Text(StrL10N.of(context).new_bar_save),
        isActive: currentStep >= 2,
        state: currentStep >= 3 ? StepState.complete : StepState.disabled,
        content: NotebookSelectStepView());
  }
}

class OutlinedImageView extends StatelessWidget {
  final Widget? child;
  final Key? key;
  final String? showWarningText;
  final bool showProgressIndicator;
  final bool showWarning;

  OutlinedImageView(
      {this.key,
      this.showProgressIndicator = false,
      this.showWarning = false,
      this.showWarningText,
      this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        AspectRatio(
            aspectRatio: 1,
            child: Container(
                key: key,
                width: double.infinity,
                padding: EdgeInsetsDirectional.all(5),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).primaryColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: child)),
        if (showProgressIndicator)
          Container(width: 50, height: 50, child: CircularProgressIndicator()),
        if (showWarning)
          Container(
              decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).primaryColor),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white),
              padding: EdgeInsetsDirectional.all(5),
              child: Column(children: [
                Icon(Icons.warning_amber_rounded,
                    size: 50, color: Colors.yellow),
                (showWarningText == null)
                    ? Text("Something went wrong!!\nbut I don't know why")
                    : Text(showWarningText!, textAlign: TextAlign.center)
              ]))
      ],
    );
  }
}

///
/// Step 1
///
class InputStepView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    //print("InputStepView builded");
    return Column(children: [
      Consumer<InputViewChangeNotifier>(
        builder: (context, inputNotifier, child) => OutlinedImageView(
            showProgressIndicator: inputNotifier.isShowProgressIndicator,
            showWarning: inputNotifier.isShowWarning,
            showWarningText: inputNotifier.warningMessage,
            child: inputNotifier.isEmpty
                ? null
                : Image.memory(inputNotifier.image)),
      ),
      Row(children: [
        Expanded(flex: 9, child: PickingImageView(true)),
        Spacer(flex: 2),
        Expanded(flex: 9, child: PickingImageView(false)),
      ])
    ]);
  }
}

class PickingImageView extends StatelessWidget {
  final bool _isFromCamera;
  PickingImageView(this._isFromCamera);
  @override
  Widget build(BuildContext context) {
    return Consumer<InputViewChangeNotifier>(
        builder: (context, inputNotifier, child) => ElevatedButton(
            onPressed: (inputNotifier.isShowProgressIndicator)
                ? null
                : () => inputNotifier
                    .inputButtonOnPressed(context, _isFromCamera)
                    .then((isSuccess) => _setNextButton(context, isSuccess)),
            child: (_isFromCamera)
                ? Text(StrL10N.of(context).btn_from_camera,
                    style: TextStyle(color: Colors.white))
                : Text(StrL10N.of(context).btn_from_gallery,
                    style: TextStyle(color: Colors.white))));
  }

  void _setNextButton(BuildContext context, bool enable) {
    Provider.of<StepperChangeNotifier>(context, listen: false)
        .nextButtonEnable = enable;
  }
}

///
/// Step 2
///
class HighlightSelectStepView extends StatelessWidget {
  final GlobalKey _imageKey = GlobalKey();
  final GlobalKey _canvasKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    //print("HighlightSelectStepView builded");
    //cleanup canvas
    Provider.of<HighlightViewChangeNotifier>(context, listen: false)
        .initCanvas();

    return Column(children: [
      CanvasView(_imageKey, _canvasKey),
      SettingView(),
      SubmitView()
    ]);
  }
}

class CanvasView extends StatelessWidget {
  final GlobalKey _imageKey;
  final GlobalKey _canvasKey;

  CanvasView(this._imageKey, this._canvasKey);

  @override
  Widget build(BuildContext context) {
    return Consumer<HighlightViewChangeNotifier>(
        builder: (context, highlightNotifier, child) {
      //set keys
      highlightNotifier.setKeys(_imageKey, _canvasKey);
      return OutlinedImageView(
          showProgressIndicator: highlightNotifier.isShowProgressIndicator,
          showWarning: highlightNotifier.isShowWarning,
          showWarningText: highlightNotifier.warningMessage,
          child: Listener(
              behavior: HitTestBehavior.deferToChild,
              onPointerDown: (event) {
                _disableNextButton(context);
                highlightNotifier.onPointerDownEvent(event);
              },
              onPointerMove: highlightNotifier.onPointerMoveEvent,
              onPointerUp: highlightNotifier.onPointerUpEvent,
              child: Stack(alignment: AlignmentDirectional.center, children: [
                Selector<InputViewChangeNotifier, Uint8List>(
                    selector: (context, inputNotifier) => inputNotifier.image,
                    builder: (context, imageJpgRaw, child) =>
                        Image.memory(imageJpgRaw, key: _imageKey)),
                RepaintBoundary(
                    key: _canvasKey,
                    child: CustomPaint(
                        size: Size.infinite,
                        painter: HighlightDrawing(
                            drawStack: highlightNotifier.drawStack,
                            drawingList: highlightNotifier.drawingList)))
              ])));
    });
  }

  void _disableNextButton(BuildContext context) {
    Provider.of<StepperChangeNotifier>(context, listen: false)
        .nextButtonEnable = false;
  }
}

class SettingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<HighlightViewChangeNotifier>(
        builder: (context, highlightNotifier, child) {
      return Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            IconButton(
                icon: Icon(Icons.undo_rounded),
                onPressed: !highlightNotifier.undoable
                    ? null
                    : () {
                        _disableNextButton(context);
                        highlightNotifier.undo();
                      }),
            IconButton(
                icon: Icon(Icons.redo_rounded),
                onPressed: !highlightNotifier.redoable
                    ? null
                    : () {
                        _disableNextButton(context);
                        highlightNotifier.redo();
                      })
          ]),
          IconButton(
              icon: Icon(Icons.delete_outline_rounded),
              onPressed: !highlightNotifier.cleanable
                  ? null
                  : () {
                      _disableNextButton(context);
                      highlightNotifier.deleteAll();
                    })
        ]),
        ChangeNotifierProvider<MarkerWidthSliderChangeNotifier>(
            create: (context) => MarkerWidthSliderChangeNotifier(),
            builder: (context, child) =>
                Consumer<MarkerWidthSliderChangeNotifier>(
                    builder: (context, widthNotifier, child) =>
                        SliderWithDisplayWindow(
                            markerWidth: highlightNotifier.width.round(),
                            color: highlightNotifier.color,
                            min: 1,
                            max: 30,
                            value: widthNotifier.value,
                            sliderOnChanged: (newValue) {
                              widthNotifier.value = newValue;
                              highlightNotifier.markerWidth = newValue.round();
                            },
                            displayWindowOnTap: () =>
                                highlightNotifier.colorPickerDialog(context))))
      ]);
    });
  }

  void _disableNextButton(BuildContext context) {
    Provider.of<StepperChangeNotifier>(context, listen: false)
        .nextButtonEnable = false;
  }
}

class SliderWithDisplayWindow extends StatelessWidget {
  final double min;
  final double max;
  final double value;
  final Function(double value)? sliderOnChanged;
  final int markerWidth;
  final Color color;
  final Function()? displayWindowOnTap;

  SliderWithDisplayWindow(
      {required this.markerWidth,
      required this.color,
      required this.min,
      required this.max,
      required this.value,
      this.displayWindowOnTap,
      this.sliderOnChanged});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      InkWell(
          onTap: displayWindowOnTap,
          child: Container(
              height: 40,
              width: 40,
              padding: EdgeInsetsDirectional.only(top: 5, bottom: 5),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).primaryColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomPaint(
                  size: Size.infinite,
                  painter: HighlightMarkerDisplay(
                      markerWidth: markerWidth, color: color)))),
      Slider(
          value: value,
          min: min,
          max: max,
          label: value.round().toString(),
          onChanged: sliderOnChanged)
    ]);
  }
}

class SubmitView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<HighlightViewChangeNotifier>(
        builder: (context, highlightNotifier, child) => SizedBox(
            width: double.infinity,
            child: Selector<InputViewChangeNotifier, Uint8List>(
                selector: (context, inputNotifier) => inputNotifier.image,
                builder: (context, imageJpgRaw, child) => ElevatedButton(
                    onPressed: !highlightNotifier.submitEnable ||
                            highlightNotifier.isProcessed
                        ? null
                        : () => highlightNotifier
                            .submitButtonOnPressed(context, imageJpgRaw)
                            .then((isSuccess) => (isSuccess)
                                ? _enableNextButton(context)
                                : null),
                    child: (highlightNotifier.isProcessed)
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                Icon(Icons.check_rounded, color: Colors.green),
                                Text(StrL10N.of(context).btn_success,
                                    style: TextStyle(color: Colors.green))
                              ])
                        : Text(StrL10N.of(context).btn_analyze,
                            style: TextStyle(color: Colors.white))))));
  }

  void _enableNextButton(BuildContext context) {
    Provider.of<StepperChangeNotifier>(context, listen: false)
        .nextButtonEnable = true;
  }
}

///
/// Step 3
///
class NotebookSelectStepView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    //print("notebookSelectView builded");
    return FutureBuilder<Tuple2<List<PenPowerUser>, List<PenPowerNotebook>>>(
        future: _loadData(),
        builder: (BuildContext context,
            AsyncSnapshot<Tuple2<List<PenPowerUser>, List<PenPowerNotebook>>>
                snapshot) {
          if (snapshot.hasData) {
            return ChangeNotifierProvider<NotebookDropdownChangeNotifier>(
                create: (context) => NotebookDropdownChangeNotifier(
                    snapshot.data!.item2, snapshot.data!.item1[0]),
                builder: (context, child) => Column(children: [
                      UsernameDisplayView.hasData(snapshot.data!.item1),
                      NotebookDropdownButtonView.hasData(
                          snapshot.data!.item1, snapshot.data!.item2),
                      NoteDataView.hasData(snapshot.data!.item1)
                    ]));
          } else if (snapshot.hasError) {
            return Column(children: [
              UsernameDisplayView.hasError(),
              NotebookDropdownButtonView.hasError(),
            ]);
          } else {
            return Column(children: [
              UsernameDisplayView.loading(),
              NotebookDropdownButtonView.loading(),
              NoteDataView.hasError()
            ]);
          }
        });
  }

  Future<Tuple2<List<PenPowerUser>, List<PenPowerNotebook>>> _loadData() async {
    PenPowerDatabase db = PenPowerDatabase();
    await db.open();
    Tuple2<List<PenPowerUser>, List<PenPowerNotebook>> data =
        Tuple2(await db.allUsers, await db.allNotebooks);
    //db.close();
    return data;
  }
}

class UsernameDisplayView extends StatelessWidget {
  final List<PenPowerUser>? users;
  final bool hasError;
  UsernameDisplayView.loading()
      : users = null,
        hasError = false;
  UsernameDisplayView.hasError()
      : users = null,
        hasError = true;
  UsernameDisplayView.hasData(this.users) : hasError = false;
  @override
  Widget build(BuildContext context) {
    if (users == null) {
      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(StrL10N.of(context).new_title_user),
        hasError
            ? Text(StrL10N.of(context).new_load_error)
            : Text(StrL10N.of(context).new_load_loading)
      ]);
    } else {
      return Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(StrL10N.of(context).new_title_user),
          Text(users![0].name)
        ]),
        SizedBox(height: 5),
        Selector<HighlightViewChangeNotifier, int>(
            selector: (context, notifier) => notifier.results.createTime,
            builder: (context, time, child) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(StrL10N.of(context).new_title_create_time),
                      Text(DateFormat("yyyy-MM-dd HH:mm:ss")
                          .format(DateTime.fromMillisecondsSinceEpoch(time)))
                    ]))
      ]);
    }
  }
}

class NotebookDropdownButtonView extends StatelessWidget {
  final List<PenPowerUser>? users;
  final List<PenPowerNotebook>? notebooks;
  final bool hasError;
  NotebookDropdownButtonView.loading()
      : users = null,
        notebooks = null,
        hasError = false;
  NotebookDropdownButtonView.hasError()
      : users = null,
        notebooks = null,
        hasError = true;
  NotebookDropdownButtonView.hasData(this.users, this.notebooks)
      : hasError = false;

  @override
  Widget build(BuildContext context) {
    if (users != null && notebooks != null) {
      return Consumer<NotebookDropdownChangeNotifier>(
          builder: (context, dropdownNotifier, child) => Column(children: [
                DropdownButtonWithTitle(
                    title: StrL10N.of(context).new_title_notebook,
                    value: dropdownNotifier.notebook,
                    items: dropdownNotifier.toMenuItem(),
                    onChanged: (selectedNotebook) =>
                        dropdownNotifier.notebook = selectedNotebook),
                if (dropdownNotifier.isCreateNewNotebook)
                  NewNotebookView(dropdownNotifier)
              ]));
    } else if (users == null && notebooks == null) {
      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(StrL10N.of(context).new_title_notebook),
        hasError
            ? Text(StrL10N.of(context).new_load_error)
            : Text(StrL10N.of(context).new_load_loading)
      ]);
    } else {
      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(StrL10N.of(context).new_title_notebook),
        Text(StrL10N.of(context).new_load_error)
      ]);
    }
  }
}

class DropdownButtonWithTitle extends StatelessWidget {
  final String title;
  final List<DropdownMenuItem<dynamic>>? items;
  final dynamic value;
  final void Function(dynamic)? onChanged;

  DropdownButtonWithTitle(
      {required this.title,
      required this.items,
      required this.value,
      required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title),
      DropdownButton(value: value, items: items, onChanged: onChanged)
    ]);
  }
}

class NewNotebookView extends StatelessWidget {
  final NotebookDropdownChangeNotifier dropdownNotifier;

  NewNotebookView(this.dropdownNotifier);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(height: 3),
      TextField(
          focusNode: dropdownNotifier.notebookTitleFocusNode,
          controller: TextEditingController()
            ..text = dropdownNotifier.createNewNotebook.title
            ..selection = TextSelection.fromPosition(TextPosition(
                offset: dropdownNotifier.createNewNotebook.title.length)),
          decoration: InputDecoration(
              icon: Icon(Icons.title_rounded),
              border: OutlineInputBorder(),
              labelText: StrL10N.of(context).input_notebook_title + " *",
              errorText: dropdownNotifier.titleIsEmpty
                  ? StrL10N.of(context).input_notebook_title_warning
                  : null),
          textInputAction: TextInputAction.next,
          onChanged: dropdownNotifier.notebookTitleOnchanged,
          onSubmitted: dropdownNotifier.notebookTitleOnSubmitted),
      SizedBox(height: 5),
      TextField(
          focusNode: dropdownNotifier.notebookDescFocusNode,
          controller: TextEditingController()
            ..text = dropdownNotifier.createNewNotebook.description
            ..selection = TextSelection.fromPosition(TextPosition(
                offset: dropdownNotifier.createNewNotebook.description.length)),
          decoration: InputDecoration(
              icon: Icon(Icons.description_rounded),
              border: OutlineInputBorder(),
              labelText: StrL10N.of(context).input_notebook_desc),
          //textInputAction: TextInputAction.next,
          onChanged: dropdownNotifier.notebookDescOnchangedAndSubmitted,
          onSubmitted: dropdownNotifier.notebookDescOnchangedAndSubmitted),
      SizedBox(height: 3)
    ]);
  }
}

class NoteDataView extends StatelessWidget {
  final List<PenPowerUser>? users;
  final bool hasError;
  NoteDataView.hasData(this.users) : hasError = false;
  NoteDataView.hasError()
      : hasError = true,
        users = null;

  @override
  Widget build(BuildContext context) {
    if (!hasError) {
      return Consumer<NotebookViewChangeNotifier>(
          builder: (context, notebookNotifier, child) => Column(children: [
                SizedBox(height: 20),
                TextField(
                    controller: TextEditingController()
                      ..text = notebookNotifier.noteTitle
                      ..selection = TextSelection.fromPosition(TextPosition(
                          offset: notebookNotifier.noteTitle.length)),
                    focusNode: notebookNotifier.noteTitleFocusNode,
                    decoration: InputDecoration(
                        icon: Icon(Icons.title_rounded),
                        border: OutlineInputBorder(),
                        labelText: StrL10N.of(context).input_note_title + " *",
                        errorText: notebookNotifier.titleIsEmpty
                            ? StrL10N.of(context).input_note_title_warning
                            : null),
                    onChanged: notebookNotifier.noteTitleOnchanged,
                    onSubmitted: notebookNotifier.noteTitleOnSubmitted),
                SizedBox(height: 5),
                TextField(
                    controller: TextEditingController()
                      ..text = notebookNotifier.noteDesc
                      ..selection = TextSelection.fromPosition(TextPosition(
                          offset: notebookNotifier.noteDesc.length)),
                    focusNode: notebookNotifier.noteDescFocusNode,
                    decoration: InputDecoration(
                        icon: Icon(Icons.description_rounded),
                        border: OutlineInputBorder(),
                        labelText: StrL10N.of(context).input_note_desc),
                    //textInputAction: TextInputAction.done,
                    onChanged: notebookNotifier.noteDescOnchangedAndSubmitted,
                    onSubmitted:
                        notebookNotifier.noteDescOnchangedAndSubmitted),
                SizedBox(height: 5),
                Consumer<NotebookDropdownChangeNotifier>(
                    builder: (context, dropdownNotifier, child) => SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            child: Text(StrL10N.of(context).btn_finish,
                                style: TextStyle(color: Colors.white)),
                            onPressed: (dropdownNotifier.isCreateNewNotebook &&
                                        dropdownNotifier.titleIsEmpty) ||
                                    notebookNotifier.titleIsEmpty
                                ? null
                                : () => notebookNotifier.finishButtonOnPressed(
                                    context, users![0]))))
              ]));
    } else {
      return Consumer<NotebookViewChangeNotifier>(
          builder: (context, notifier, child) =>
              ElevatedButton(onPressed: () => notifier.leave(), child: child),
          child: Text(StrL10N.of(context).btn_exit,
              style: TextStyle(color: Colors.white)));
    }
  }
}
