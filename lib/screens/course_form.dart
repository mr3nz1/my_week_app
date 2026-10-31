import 'package:flutter/material.dart';

import '../backend/backend.dart';
import '../models/course.dart';
import '../models/week_stats.dart';

/// Add a course, or edit one when [course] is given.
class CourseForm extends StatefulWidget {
  const CourseForm({
    super.key,
    required this.repository,
    required this.stats,
    this.course,
  });

  final CourseRepository repository;

  /// The current week, used to warn about clashes before saving.
  final WeekStats stats;
  final Course? course;

  @override
  State<CourseForm> createState() => _CourseFormState();
}

class _CourseFormState extends State<CourseForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.course?.name);
  late int _day = widget.course?.day ?? DateTime.now().weekday;
  late int _start = widget.course?.start ?? 8 * 60;
  late int _end = widget.course?.end ?? 10 * 60;
  bool _busy = false;

  bool get _editing => widget.course != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Course get _draft => Course(
    id: widget.course?.id ?? '',
    name: _name.text.trim(),
    day: _day,
    start: _start,
    end: _end,
  );

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    setState(() {
      final minutes = picked.hour * 60 + picked.minute;
      if (start) {
        // Keep the same length when the start moves, if it still fits the day.
        final length = _end - _start;
        _start = minutes;
        if (length > 0 && minutes + length <= 24 * 60) _end = minutes + length;
      } else {
        _end = minutes;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _end <= _start) {
      setState(() {}); // shows the time error
      return;
    }
    setState(() => _busy = true);
    try {
      if (_editing) {
        await widget.repository.update(_draft);
      } else {
        await widget.repository.add(_draft);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeError = _end <= _start ? 'The end must be after the start' : null;
    final clashes = timeError == null
        ? widget.stats.clashesWith(_draft)
        : const <Course>[];

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit course' : 'New course')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              autofocus: !_editing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Course name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter the course name' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _day,
              decoration: const InputDecoration(
                labelText: 'Day',
                border: OutlineInputBorder(),
              ),
              items: [
                for (var d = 1; d <= 7; d++)
                  DropdownMenuItem(value: d, child: Text(dayNames[d - 1])),
              ],
              onChanged: (d) => setState(() => _day = d!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    label: 'Starts',
                    minutes: _start,
                    onPressed: () => _pickTime(start: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeButton(
                    label: 'Ends',
                    minutes: _end,
                    onPressed: () => _pickTime(start: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (timeError != null)
              Text(timeError, style: TextStyle(color: theme.colorScheme.error))
            else
              Text('Length: ${formatDuration(_end - _start)}'),
            if (clashes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.warning_amber),
                  title: const Text('This clashes with'),
                  subtitle: Text(
                    clashes
                        .map(
                          (c) =>
                              '${c.name} (${formatTime(c.start)} – ${formatTime(c.end)})',
                        )
                        .join('\n'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_editing ? 'Save changes' : 'Add course'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.minutes,
    required this.onPressed,
  });

  final String label;
  final int minutes;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(
            formatTime(minutes),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}
