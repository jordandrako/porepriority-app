import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:provider/provider.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/pages/list/task_edit.dart';
import 'package:vikunja_app/stores/list_store.dart';
import 'package:vikunja_app/utils/misc.dart';
import 'package:vikunja_app/theme/constants.dart';

enum DropLocation {above, below, none}

class TaskData {
  final Task task;
  final Size size;
  TaskData(this.task, this.size);
}

class BucketTaskCard extends StatefulWidget {
  final Task task;
  final int index;
  final DragUpdateCallback onDragUpdate;
  final void Function(Task, int) onAccept;

  const BucketTaskCard({
    Key key,
    @required this.task,
    @required this.index,
    @required this.onDragUpdate,
    @required this.onAccept,
  }) : assert(task != null),
       assert(index != null),
       assert(onDragUpdate != null),
       assert(onAccept != null),
       super(key: key);

  @override
  State<BucketTaskCard> createState() => _BucketTaskCardState();
}

class _BucketTaskCardState extends State<BucketTaskCard> with AutomaticKeepAliveClientMixin {
  Size _cardSize;
  bool _dragging = false;
  DropLocation _dropLocation = DropLocation.none;
  TaskData _dropData;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_cardSize == null) _updateCardSize(context);

    final taskState = Provider.of<ListProvider>(context);
    final bucket = taskState.buckets[taskState.buckets.indexWhere((b) => b.id == widget.task.bucketId)];
    // default chip height: 32
    const double chipHeight = 28;
    const chipConstraints = BoxConstraints(maxHeight: chipHeight);
    final theme = Theme.of(context);

    final numRow = Row(
      children: <Widget>[
        Text(
          '#${widget.task.id}',
          style: theme.textTheme.subtitle2.copyWith(
            color: Colors.grey,
          ),
        ),
      ],
    );
    if (widget.task.done) {
      numRow.children.insert(0, Container(
        constraints: chipConstraints,
        padding: EdgeInsets.only(right: 4),
        child: FittedBox(
          child: Chip(
            label: Text('Done'),
            labelStyle: theme.textTheme.labelLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.brightness == Brightness.dark
                  ? Colors.black : Colors.white,
            ),
            backgroundColor: vGreen,
          ),
        ),
      ));
    }

    final titleRow = Row(
      children: <Widget>[
        Expanded(
          child: Text(
            widget.task.title,
            style: theme.textTheme.titleMedium.copyWith(
              color: widget.task.textColor,
            ),
          ),
        ),
      ],
    );
    final duration = widget.task.dueDate.difference(DateTime.now());
    if (widget.task.dueDate.year > 2) {
      titleRow.children.add(Container(
        constraints: chipConstraints,
        padding: EdgeInsets.only(left: 4),
        child: FittedBox(
          child: Chip(
            avatar: Icon(
              Icons.calendar_month,
              color: duration.isNegative ? Colors.red : null,
            ),
            label: Text(durationToHumanReadable(duration)),
            labelStyle: theme.textTheme.labelLarge.copyWith(
              color: duration.isNegative ? Colors.red : null,
            ),
            backgroundColor: duration.isNegative ? Colors.red.withAlpha(20) : null,
          ),
        ),
      ));
    }

    final labelRow = Wrap(
      children: <Widget>[],
      spacing: 4,
      runSpacing: 4,
    );
    widget.task.labels?.sort((a, b) => a.title.compareTo(b.title));
    widget.task.labels?.asMap()?.forEach((i, label) {
      labelRow.children.add(Chip(
        label: Text(label.title),
        labelStyle: theme.textTheme.labelLarge.copyWith(
          color: label.textColor,
        ),
        backgroundColor: label.color,
      ));
    });
    if (widget.task.description.isNotEmpty) {
      final uncompletedTaskCount = '* [ ]'.allMatches(widget.task.description).length;
      final completedTaskCount = '* [x]'.allMatches(widget.task.description).length;
      final taskCount = uncompletedTaskCount + completedTaskCount;
      if (taskCount > 0) {
        final iconSize = (theme.textTheme.labelLarge.fontSize ?? 14) + 2;
        labelRow.children.add(Chip(
          avatar: Container(
            constraints: BoxConstraints(maxHeight: iconSize, maxWidth: iconSize),
            child: CircularProgressIndicator(
              value: uncompletedTaskCount == 0
                  ? 1 : uncompletedTaskCount.toDouble() / taskCount.toDouble(),
              backgroundColor: Colors.grey,
            )  ,
          ),
          label: Text(
              (uncompletedTaskCount == 0 ? '' : '$completedTaskCount of ')
                  + '$taskCount tasks'
          ),
        ));
      }
    }
    if (widget.task.attachments != null && widget.task.attachments.isNotEmpty) {
      labelRow.children.add(Chip(
        label: Transform.rotate(
          angle: -pi / 4.0,
          child: Icon(Icons.attachment),
        ),
      ));
    }
    if (widget.task.description.isNotEmpty) {
      labelRow.children.add(Chip(
        label: Icon(Icons.notes),
      ));
    }

    final rowConstraints = BoxConstraints(minHeight: chipHeight);
    final card = Card(
      color: widget.task.color,
      child: InkWell(
        child: Theme(
          data: Theme.of(context).copyWith(
            // Remove enforced margins
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  constraints: rowConstraints,
                  child: numRow,
                ),
                Container(
                  constraints: rowConstraints,
                  child: titleRow,
                ),
                Padding(
                  padding: labelRow.children.isNotEmpty
                      ? const EdgeInsets.only(top: 8) : EdgeInsets.zero,
                  child: labelRow,
                ),
              ],
            ),
          ),
        ),
        onTap: () {
          FocusScope.of(context).unfocus();
          Navigator.push<Task>(
            context,
            MaterialPageRoute(
              builder: (context) => TaskEditPage(
                task: widget.task,
                taskState: taskState,
              ),
            ),
          );
        },
      ),
    );

    return LongPressDraggable<TaskData>(
      data: TaskData(widget.task, _cardSize),
      maxSimultaneousDrags: taskState.taskDragging ? 0 : 1, // only one task can be dragged at a time
      onDragStarted: () {
        taskState.taskDragging = true;
        setState(() => _dragging = true);
      },
      onDragUpdate: widget.onDragUpdate,
      onDragEnd: (_) {
        taskState.taskDragging = false;
        setState(() => _dragging = false);
      },
      feedback: (_cardSize == null) ? SizedBox.shrink() : SizedBox.fromSize(
        size: _cardSize,
        child: Card(
          color: card.color,
          child: (card.child as InkWell).child,
          elevation: (card.elevation ?? 0) + 5,
        ),
      ),
      childWhenDragging: SizedBox.shrink(),
      child: () {
        if (_dragging || _cardSize == null) return card;

        final dropBoxSize = _dropData?.size ?? _cardSize;
        final dropBox = DottedBorder(
          color: Colors.white,
          child: SizedBox.fromSize(size: dropBoxSize),
        );
        final dropAbove = taskState.taskDragging && _dropLocation == DropLocation.above;
        final dropBelow = taskState.taskDragging && _dropLocation == DropLocation.below;
        final DragTargetLeave<TaskData> dragTargetOnLeave = (data) => setState(() {
          _dropLocation = DropLocation.none;
          _dropData = null;
        });
        final DragTargetAccept<TaskData> dragTargetOnAccept = (data) {
          final index = bucket.tasks.indexOf(widget.task);
          widget.onAccept(data.task, _dropLocation == DropLocation.above ? index : index + 1);
          setState(() {
            _dropLocation = DropLocation.none;
            _dropData = null;
          });
        };

        return SizedBox(
          width: _cardSize.width,
          height: _cardSize.height + (dropAbove || dropBelow ? dropBoxSize.height + 4: 0),
          child: Stack(
            children: <Widget>[
              Column(
                children: [
                  if (dropAbove) dropBox,
                  card,
                  if (dropBelow) dropBox,
                ],
              ),
              Column(
                children: <SizedBox>[
                  SizedBox(
                    height: (_cardSize.height / 2) + (dropAbove ? dropBoxSize.height : 0),
                    child: DragTarget<TaskData>(
                      onWillAccept: (data) {
                        setState(() {
                          _dropLocation = DropLocation.above;
                          _dropData = data;
                        });
                        return true;
                      },
                      onAccept: dragTargetOnAccept,
                      onLeave: dragTargetOnLeave,
                      builder: (_, __, ___) => SizedBox.expand(),
                    ),
                  ),
                  SizedBox(
                    height: (_cardSize.height / 2) + (dropBelow ? dropBoxSize.height : 0),
                    child: DragTarget<TaskData>(
                      onWillAccept: (data) {
                        setState(() {
                          _dropLocation = DropLocation.below;
                          _dropData = data;
                        });
                        return true;
                      },
                      onAccept: dragTargetOnAccept,
                      onLeave: dragTargetOnLeave,
                      builder: (_, __, ___) => SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }(),
    );
  }

  void _updateCardSize(BuildContext context) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {
        _cardSize = context.size;
      });
    });
  }

  @override
  bool get wantKeepAlive => _dragging;
}