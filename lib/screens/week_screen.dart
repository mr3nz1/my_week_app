import 'package:flutter/material.dart';

import '../backend/backend.dart';
import '../models/course.dart';
import '../models/week_stats.dart';
import 'course_form.dart';

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key, required this.backend, required this.user});

  final Backend backend;
  final AppUser user;

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  late final CourseRepository _repo = widget.backend.coursesFor(
    widget.user.uid,
  );
  // Created once, so rebuilding the screen does not restart the stream.
  late final Stream<List<Course>> _courses = _repo.watchCourses();

  WeekStats _latest = WeekStats(const []);

  void _openForm({Course? course}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CourseForm(repository: _repo, course: course, stats: _latest),
      ),
    );
  }

  Future<void> _delete(Course course) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this course?'),
        content: Text(
          '${course.name}\n${dayNames[course.day - 1]}, ${formatTime(course.start)} – ${formatTime(course.end)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.delete(course.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${course.name} deleted'),
          // A SnackBar with an action stays until dismissed by default.
          persist: false,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _repo.restore(course),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Week'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () {
              ScaffoldMessenger.of(context).clearSnackBars();
              widget.backend.auth.signOut();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add course'),
      ),
      body: StreamBuilder<List<Course>>(
        stream: _courses,
        builder: (context, snapshot) {
          // Error state: for example, the security rules refused.
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.error_outline,
              text: 'Could not load your courses.\n${snapshot.error}',
            );
          }
          // Loading state: nothing has arrived yet.
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = _latest = WeekStats(snapshot.data!);
          // Empty state.
          if (stats.courses.isEmpty) {
            return const _Message(
              icon: Icons.event_available,
              text:
                  'Your week is empty.\nTap "Add course" to add your first course.',
            );
          }
          return _WeekList(
            stats: stats,
            backend: widget.backend,
            user: widget.user,
            onTap: (c) => _openForm(course: c),
            onLongPress: _delete,
          );
        },
      ),
    );
  }
}

class _WeekList extends StatelessWidget {
  const _WeekList({
    required this.stats,
    required this.backend,
    required this.user,
    required this.onTap,
    required this.onLongPress,
  });

  final WeekStats stats;
  final Backend backend;
  final AppUser user;
  final void Function(Course) onTap;
  final void Function(Course) onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _Summary(stats: stats, backend: backend, user: user),
        if (stats.clashes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(
                Icons.warning_amber,
                color: theme.colorScheme.onErrorContainer,
              ),
              title: Text(
                stats.clashes.length == 1
                    ? '1 clash in your week'
                    : '${stats.clashes.length} clashes in your week',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
              subtitle: Text(
                stats.clashes
                    .map(
                      (p) =>
                          '${p.$1.name} and ${p.$2.name} (${dayNames[p.$1.day - 1]})',
                    )
                    .join('\n'),
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ),
        ],
        for (final day in stats.activeDays) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 4),
            child: Row(
              children: [
                Text(dayNames[day - 1], style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(
                  formatDuration(stats.minutesOn(day)),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          for (final course in stats.byDay[day]!)
            _CourseTile(
              course: course,
              clashesWith: stats.clashesWith(course),
              onTap: () => onTap(course),
              onLongPress: () => onLongPress(course),
            ),
        ],
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            'Tap a course to edit it, long-press to delete it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.stats,
    required this.backend,
    required this.user,
  });

  final WeekStats stats;
  final Backend backend;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busiest = stats.busiestDay;
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This week', style: theme.textTheme.labelLarge),
            Text(
              formatDuration(stats.totalMinutes),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${stats.courses.length} ${stats.courses.length == 1 ? 'course' : 'courses'}'
              ' on ${stats.activeDays.length} ${stats.activeDays.length == 1 ? 'day' : 'days'}'
              '${busiest == null ? '' : ' · busiest: ${dayNames[busiest - 1]}'}',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  backend.isCloud ? Icons.cloud_done : Icons.phone_android,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${user.email ?? ''} · ${backend.label}',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({
    required this.course,
    required this.clashesWith,
    required this.onTap,
    required this.onLongPress,
  });

  final Course course;
  final List<Course> clashesWith;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clash = clashesWith.isNotEmpty;
    return Card(
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: Text(
          '${formatTime(course.start)}\n${formatTime(course.end)}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        title: Text(course.name),
        subtitle: Text(
          clash
              ? 'Clashes with ${clashesWith.map((c) => c.name).join(', ')}'
              : formatDuration(course.minutes),
        ),
        subtitleTextStyle: clash
            ? theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              )
            : null,
        trailing: clash
            ? Icon(Icons.warning_amber, color: theme.colorScheme.error)
            : null,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
