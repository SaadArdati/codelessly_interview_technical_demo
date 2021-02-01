import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'main.dart';

/// This is to continuously keep track of the size and optionally the id of the
/// ElementWidget. This happens when we resize the ElementHolders, you want
/// to constrain it's child ElementWidget too, or vice versa.
typedef ElementBuilder = Widget Function(
    int id, Size size, BuildContext context);

/// This is to keep track of the child ElementWidget resizing. This data is then
/// stored in main.dart's childSizes array.
typedef OnChildResize = void Function(Size childSize);

/// This is not in main.dart because only ElementHolders and ElementWidgets
/// use this information. This is only used to determine if the user
/// started pressing the drag handler or the resize handler of an ElementWidget
/// in edit mode.
enum InteractionState { NONE, DRAGGING, RESIZING }

/// The resizable Row elements, within are resizable ElementWidgets containing
/// the different shapes and sizes, built through ElementBuilder.
class ElementHolder extends StatefulWidget {
  final int id;
  final Size size;
  final ElementBuilder elementBuilder;
  final StreamController<bool> editStateController;
  final OnChildResize onChildResize;

  const ElementHolder({
    Key? key,
    required this.id,
    required this.size,
    required this.elementBuilder,
    required this.editStateController,
    required this.onChildResize,
  }) : super(key: key);

  @override
  _ElementHolderState createState() => _ElementHolderState();
}

class _ElementHolderState extends State<ElementHolder> {
  InteractionState _interactionState = InteractionState.NONE;
  Offset elementAlignment = Offset.zero;
  late Size elementSize;
  double widthLeft = 0.0;
  final GlobalKey _dragKey = GlobalKey();
  final GlobalKey _resizeKey = GlobalKey();

  @override
  void initState() {
    /// Provide an initial default size to the ElementWidget inside this
    /// ElementHolder. We're cutting it in half for visually clarity.
    elementSize = Size(widget.size.width / 2.0, widget.size.height / 2.0);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).highlightColor.withOpacity(0.5),
      width: widget.size.width,
      height: widget.size.height,
      child: GestureDetector(
        /// What we do here is decide what the user is trying to do in Edit mode.
        /// To decide the InteractionState, if it's resizing the ElementWidget
        /// or dragging.
        onPanStart: (details) {
          /// Here we check if the cursor clicked on the resize handle
          /// We do a comparison through global positioning.
          var resizeBox =
              _resizeKey.currentContext?.findRenderObject() as RenderBox;
          var resizePos = resizeBox.localToGlobal(Offset.zero);
          var resizeBoxSize = resizeBox.size;
          var resizePosCenter = Offset(resizePos.dx + resizeBoxSize.width / 2.0,
              resizePos.dy + resizeBoxSize.height / 2.0);
          if ((details.globalPosition.dx - resizePosCenter.dx).abs() <=
                  resizeBoxSize.width / 2.0 &&
              (details.globalPosition.dy - resizePosCenter.dy).abs() <=
                  resizeBoxSize.height / 2.0) {
            setState(() {
              _interactionState = InteractionState.RESIZING;
            });
          } else {
            /// This is the exact same logic, but for the drag handle.
            var dragBox =
                _dragKey.currentContext?.findRenderObject() as RenderBox;
            var dragPos = dragBox.localToGlobal(Offset.zero);
            var dragBoxSize = dragBox.size;
            var dragPosCenter = Offset(dragPos.dx + dragBoxSize.width / 2.0,
                dragPos.dy + dragBoxSize.height / 2.0);
            if ((details.globalPosition.dx - dragPosCenter.dx).abs() <=
                    dragBoxSize.width / 2.0 &&
                (details.globalPosition.dy - dragPosCenter.dy).abs() <=
                    dragBoxSize.height / 2.0) {
              setState(() {
                _interactionState = InteractionState.DRAGGING;
              });
            } else {
              setState(() {
                _interactionState = InteractionState.NONE;
              });
            }
          }
        },
        onPanUpdate: (details) {
          if (_interactionState == InteractionState.RESIZING) {
            /// RESIZE LOGIC
            var thisBox = context.findRenderObject() as RenderBox;
            setState(() {
              elementSize = Size(
                  min(thisBox.size.width,
                      max(16.0, elementSize.width + details.delta.dx * 2.0)),
                  min(thisBox.size.height,
                      max(16.0, elementSize.height + details.delta.dy * 2.0)));
            });
          } else if (_interactionState == InteractionState.DRAGGING) {
            /// DRAG LOGIC.
            var x = ((details.localPosition.dx / widget.size.width) * 2.0) - 1;
            var y = ((details.localPosition.dy / widget.size.height) * 2.0) - 1;

            setState(() {
              elementAlignment = Offset(max(-1, min(1, x)), max(-1, min(1, y)));
            });
          }

          widget.onChildResize(elementSize);
        },

        /// Reset state.
        onPanEnd: (details) {
          setState(() {
            _interactionState = InteractionState.NONE;
          });
        },
        child: Stack(children: [
          /// Align the resize handle to the bottom right corner of the
          /// ElementWidget.
          Align(
              alignment: Alignment(elementAlignment.dx, elementAlignment.dy),
              child: Stack(
                children: [
                  widget.elementBuilder(widget.id, elementSize, context),
                  Positioned(
                      bottom: 0,
                      right: 0,
                      child: StreamBuilder<bool>(
                          stream: widget.editStateController.stream,
                          builder: (context, snapshot) {
                            if (!(snapshot.data ?? false))
                              return const SizedBox();
                            return HandleDot(
                                color: Colors.white, key: _resizeKey);
                          })),
                ],
              )),

          /// Align the handle dot relative to this ElementHolder.
          Align(
            alignment: Alignment(elementAlignment.dx, elementAlignment.dy),
            child: StreamBuilder<bool>(
                stream: widget.editStateController.stream,
                builder: (context, snapshot) {
                  if (!(snapshot.data ?? false)) return const SizedBox();
                  return HandleDot(
                      color: Colors.green.withOpacity(0.5), key: _dragKey);
                }),
          ),
        ]),
      ),
    );
  }
}

class ElementWidget extends StatefulWidget {
  final int id;
  final Size size;
  final StreamController<bool>? editStateController;
  final Shape shape;
  final Color color;

  const ElementWidget({
    Key? key,
    this.editStateController,
    required this.id,
    required this.size,
    required this.shape,
    required this.color,
  }) : super(key: key);

  @override
  _ElementWidgetState createState() => _ElementWidgetState();
}

class _ElementWidgetState extends State<ElementWidget> {
  /// Convenience method.
  Widget createShape(Color color) {
    return Material(
        color: Colors.transparent,
        child: Container(
          width: widget.size.width,
          height: widget.size.height,
          decoration: BoxDecoration(
              color: widget.shape == Shape.CIRCLE_OUTLINE ||
                      widget.shape == Shape.SQUARE_OUTLINE
                  ? Colors.transparent
                  : color,
              border: widget.shape == Shape.CIRCLE_OUTLINE ||
                      widget.shape == Shape.SQUARE_OUTLINE
                  ? Border.all(color: color, width: 4)
                  : null,
              borderRadius: widget.shape == Shape.CIRCLE ||
                      widget.shape == Shape.CIRCLE_OUTLINE
                  ? BorderRadius.circular(100)
                  : null,
              shape: widget.shape == Shape.CIRCLE ||
                      widget.shape == Shape.CIRCLE_OUTLINE
                  ? BoxShape.rectangle
                  : BoxShape.rectangle),
          child: widget.id == -1 ? null : Center(child: Text('${widget.id}')),
        ));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.editStateController == null) {
      /// Used to display the Shape row you can select elements to drag to our
      /// infamous Row.
      /// Kind of a dirty implementation to depend on null.
      return Draggable(
        data: [widget.id, widget.shape.index],
        feedback: createShape(widget.color),
        child: createShape(widget.color),
        childWhenDragging: createShape(widget.color.withOpacity(0.5)),
      );
    } else {
      return StreamBuilder<bool>(
          stream: widget.editStateController?.stream,
          builder: (context, snapshot) {
            /// Disable draggability if we're in edit mode.
            if (!(snapshot.data ?? false)) {
              return Draggable<List<int>>(
                data: [widget.id, widget.shape.index],
                feedback: createShape(widget.color),
                child: createShape(widget.color),
                childWhenDragging: createShape(widget.color.withOpacity(0.5)),
              );
            } else {
              return createShape(widget.color);
            }
          });
    }
  }
}

class HandleDot extends StatelessWidget {
  final Color color;

  const HandleDot({
    Key? key,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black38, width: 3)),
    );
  }
}
