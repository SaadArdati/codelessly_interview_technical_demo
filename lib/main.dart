import 'dart:async';
import 'dart:math';

import 'package:codelessly_interview/row_box.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

void main() {
  runApp(App());
}

enum Shape { SQUARE, SQUARE_OUTLINE, CIRCLE, CIRCLE_OUTLINE }

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Codelessly Interview',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: MainPage());
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final Size defaultSize = const Size(75, 75);

  final List<ElementBuilder> elements = [];
  final List<double> widthPadding = [];
  final List<Size> childSizes = [];

  /// This is made into a controller because only the ElementWidgets need it,
  /// and they are in a separate Widget class. This makes the implementation
  /// significantly cleaner.
  late StreamController<bool> editStateController;

  /// We don't need a StreamController because we don't need to notify or receive
  /// this piece of data anywhere outside of this widget.
  ///
  /// This is because this widget contains the logic on how to handle constraints
  /// between normal mode and fixed mode.
  ///
  /// No other widget needs to know this information other than the ListTileSwitcher.
  bool fixedMode = false;

  bool useFractions = false;

  @override
  void initState() {
    editStateController = StreamController<bool>.broadcast();
    editStateController.add(false);
    super.initState();
  }

  @override
  void dispose() {
    editStateController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
      child: Column(
        children: [
          Row(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width / 3.0),
                child: StreamBuilder<bool>(
                    stream: editStateController.stream,
                    builder: (context, snapshot) {
                      return SwitchListTile(
                          title: Text('Edit Mode'),
                          subtitle: Text(
                              'Will enable you to change the position and size of each element'),
                          value: snapshot.data ?? false,
                          onChanged: (newValue) {
                            editStateController.add(newValue);
                          });
                    }),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width / 3.0),
                child: SwitchListTile(
                    title: Text('Fix Width'),
                    subtitle: Text(
                        'If this is enabled, the row will no longer be expandable, '
                        "rather fixed to the width it's at currently."
                        'Elements will also no longer squish.'),
                    value: fixedMode,
                    onChanged: (newValue) {
                      setState(() {
                        fixedMode = newValue;

                        /// RESET
                        if (useFractions) {
                          useFractions = false;
                          final screenWidth = MediaQuery.of(context).size.width;
                          var endPadding = defaultSize.width + 6 + 16;
                          for (int i = 0; i < widthPadding.length; i++) {
                            widthPadding[i] = max(
                                16, widthPadding[i] * screenWidth - endPadding);
                          }
                        }
                      });
                    }),
              ),
              if (fixedMode)
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width / 3.0),
                  child: SwitchListTile(
                      title: Text('Use Fractions'),
                      subtitle: Text(
                          'If this is enabled, the grey boxes will use fractions instead of pixel constraints.'),
                      value: useFractions,
                      onChanged: (newValue) {
                        setState(() {
                          useFractions = newValue;
                          if (useFractions) {
                            final length = widthPadding.length;
                            for (int i = 0; i < widthPadding.length; i++) {
                              widthPadding[i] = 1 / length;
                            }
                          } else {
                            /// RESET
                            final screenWidth =
                                MediaQuery.of(context).size.width;
                            for (int i = 0; i < widthPadding.length; i++) {
                              widthPadding[i] = max(
                                  16,
                                  widthPadding[i] * screenWidth -
                                      (12 * elements.length));
                            }
                          }
                        });
                      }),
                ),
            ],
          ),

          /// Loop through the Shapes enum and add all the shape options here.
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Shapes'),
              ),
              ...Shape.values
                  .map((shape) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElementWidget(
                            id: -1,
                            size: defaultSize,
                            shape: shape,
                            color: Theme.of(context).primaryColor),
                      ))
                  .toList(),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(children: [
              /// This is a row that contains all the elements
              /// and the DragTarget to add more.
              ...elements
                  .map((elementBuilder) => Row(
                        children: [
                          /// This DragTarget exists to allow swapping of
                          /// elements Shapes.
                          DragTarget<List<int>>(
                            onAccept: (details) {
                              /// This is where the swapping logic happens.
                              /// Just replacing the element from the list.
                              setState(() {
                                int index = elements.indexOf(elementBuilder);
                                elements[index] = (id, size, context) =>
                                    ElementWidget(
                                      editStateController: editStateController,
                                      id: id,
                                      size: size,
                                      color: Theme.of(context).primaryColor,
                                      shape: Shape.values[details[1]],
                                    );
                              });
                            },
                            builder: (BuildContext context,
                                List<List<int>?> candidateData,
                                List<dynamic> rejectedData) {
                              var index = elements.indexOf(elementBuilder);
                              var endPadding = defaultSize.width + 6 + 16;

                              /// This is where the padding/sizing is handled.
                              var size = Size(
                                  widthPadding[index] *
                                      (useFractions
                                          ? MediaQuery.of(context).size.width -
                                              endPadding -
                                              (12 * elements.length)
                                          : 1),
                                  defaultSize.height);

                              /// When NOT swapping, this is what we render in each
                              /// Row child.
                              return ElementHolder(
                                id: elements.indexOf(elementBuilder),

                                size: size,
                                elementBuilder: elementBuilder,
                                editStateController: editStateController,

                                /// This keeps track of the child sizes so we
                                /// can calculate constraints.
                                onChildResize: (Size childSize) {
                                  setState(() {
                                    var index =
                                        elements.indexOf(elementBuilder);
                                    childSizes[index] = childSize;
                                  });
                                },
                              );
                            },
                          ),
                          GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              setState(() {
                                var index = elements.indexOf(elementBuilder);

                                /// Fixed mode means we need to resize neighbor
                                /// elements rather than just simply modifying
                                /// this element's size. This is to preserve
                                /// Row width.
                                if (fixedMode) {
                                  /// Prevent movement of the last handle to keep Row width fixed.
                                  if (index >= elements.length - 1) return;

                                  var amount = details.delta.dx.abs();

                                  /// We loop in different directions if going
                                  /// backwards or forwards.
                                  if (details.delta.dx < 0) {
                                    for (int i = index; i >= 0; i--) {
                                      var elementWidth = widthPadding[i];
                                      var childWidth = childSizes[i].width;

                                      if (useFractions) {
                                        var endPadding =
                                            defaultSize.width + 6 + 16;
                                        var scrnWidth =
                                            MediaQuery.of(context).size.width -
                                                endPadding -
                                                (12 * elements.length);
                                        var amountFraction = amount / scrnWidth;
                                        var childFraction =
                                            childWidth / scrnWidth;

                                        /// It's already stored as a fraction.
                                        var elementFraction = elementWidth;
                                        var spaceLeftFraction =
                                            elementFraction - childFraction;

                                        if (spaceLeftFraction > 0) {
                                          var amountLeft = spaceLeftFraction -
                                              amountFraction;
                                          if (amountLeft > 0) {
                                            widthPadding[i] -= amountFraction;
                                            widthPadding[index + 1] +=
                                                amountFraction;
                                            break;
                                          }
                                        }
                                      } else {
                                        var spaceLeft =
                                            elementWidth - childWidth;
                                        if (spaceLeft > 0) {
                                          var amountLeft = spaceLeft - amount;
                                          if (amountLeft > 0) {
                                            widthPadding[i] -= amount;
                                            widthPadding[index + 1] += amount;
                                            break;
                                          }
                                        }
                                      }
                                    }
                                  } else {
                                    for (int i = index + 1;
                                        i < elements.length;
                                        i++) {
                                      var elementWidth = widthPadding[i];
                                      var childWidth = childSizes[i].width;

                                      if (useFractions) {
                                        var endPadding =
                                            defaultSize.width + 6 + 16;
                                        var scrnWidth =
                                            MediaQuery.of(context).size.width -
                                                endPadding -
                                                (12 * elements.length);
                                        var amountFraction = amount / scrnWidth;
                                        var childFraction =
                                            childWidth / scrnWidth;

                                        /// It's already stored as a fraction.
                                        var elementFraction = elementWidth;
                                        var spaceLeftFraction =
                                            elementFraction - childFraction;
                                        if (spaceLeftFraction > 0) {
                                          var amountLeft = spaceLeftFraction -
                                              amountFraction;
                                          if (amountLeft > 0) {
                                            widthPadding[i] -= amountFraction;
                                            widthPadding[index] +=
                                                amountFraction;
                                            break;
                                          }
                                        }
                                      } else {
                                        var spaceLeft =
                                            elementWidth - childWidth;
                                        if (spaceLeft > 0) {
                                          var amountLeft = spaceLeft - amount;
                                          if (amountLeft > 0) {
                                            widthPadding[i] -= amount;
                                            widthPadding[index] += amount;
                                            break;
                                          }
                                        }
                                      }
                                    }
                                  }
                                } else {
                                  /// Not fixed mode. Every element box can
                                  /// grow/shrink as it pleases independently.
                                  ///
                                  /// No restriction on Row width.
                                  widthPadding[index] = max(16,
                                      widthPadding[index] + details.delta.dx);
                                }
                              });
                            },
                            child: InkWell(
                              onTap: () {
                                /// Could use just an InkResponse here but this
                                /// was more convenient to show feedback when
                                /// selecting a box handle to drag around.
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Container(
                                    color: Colors.black26,
                                    width: 4,

                                    /// Add height so the separation is clearer
                                    height: defaultSize.height * 1.2),
                              ),
                            ),
                          ),
                        ],
                      ))
                  .toList(),

              /// Drag shapes from the Shapes row to this DragTarget to
              /// add them to the row of elements.
              DragTarget<List<int>>(
                  onAccept: (details) {
                    setState(() {
                      /// Create a new element.
                      elements.add((id, size, context) => ElementWidget(
                            editStateController: editStateController,
                            id: id,
                            size: size,
                            color: Theme.of(context).primaryColor,
                            shape: Shape.values[details[1]],
                          ));

                      /// Give it default data.
                      widthPadding.add(defaultSize.width);
                      childSizes.add(Size(
                          defaultSize.width / 2.0, defaultSize.height / 2.0));
                    });
                  },
                  builder: (BuildContext context,
                          List<List<int>?> candidateData,
                          List<dynamic> rejectedData) =>
                      DottedBorder(
                        strokeWidth: 3,
                        dashPattern: [5, 5],
                        borderType: BorderType.RRect,
                        color: Theme.of(context).accentColor,
                        child: Container(
                          width: defaultSize.width,
                          height: defaultSize.height,
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.15),
                          child: Center(
                            child: Icon(
                              Icons.add,
                              size: 40,
                              color: Theme.of(context).accentColor,
                            ),
                          ),
                        ),
                      ))
            ]),
          ),

          /// Divider
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Divider(
              color: Theme.of(context).hintColor.withOpacity(0.25),
              thickness: 2,
            ),
          ),

          /// Delete elements by dragging them over this DragTarget
          /// Or click the IconButton directly to clear all elements.
          DragTarget<List<int>>(
            onAccept: (details) {
              setState(() {
                elements.removeAt(details[0]);
                widthPadding.removeAt(details[0]);
                childSizes.removeAt(details[0]);

                if (useFractions) {
                  /// Reset paddings to width if usingFractions.
                  final length = widthPadding.length;
                  for (int i = 0; i < widthPadding.length; i++) {
                    widthPadding[i] = 1 / length;
                  }
                }
              });
            },
            onWillAccept: (details) => details == null || details[0] >= 0,
            builder: (BuildContext context, List<List<int>?> candidateData,
                List<dynamic> rejectedData) {
              return Container(
                color:
                    candidateData.isEmpty ? Colors.transparent : Colors.yellow,
                child: Center(
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        elements.clear();
                        widthPadding.clear();
                        childSizes.clear();
                      });
                    },
                    icon: Icon(
                      Icons.delete,
                      color: candidateData.isEmpty
                          ? Theme.of(context).disabledColor
                          : Theme.of(context).errorColor,
                    ),
                  ),
                ),
              );
            },
          )
        ],
      ),
    ));
  }
}
