import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../theme/theme.dart';
import '../widgets/settings_bottom_sheet.dart';
import 'note_editor_screen.dart';
import 'trash_screen.dart';

// ──────────────────────────────────────────────
//  HomeScreen
// ──────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Allow body + FAB to render behind the transparent gesture bar
      extendBody: true,
      // ── AppBar ────────────────────────────────
      appBar: _buildAppBar(context),
      // ── Drawer ────────────────────────────────
      drawer: _buildDrawer(context),
      // ── Body ──────────────────────────────────
      body: _currentIndex == 0 ? const _HomeBody() : const TrashScreen(),
      // ── FAB ───────────────────────────────────
      floatingActionButton: _currentIndex == 0 ? _buildFAB(context) : null,
    );
  }

  // ── AppBar factory ────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      // Left – hamburger menu
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Symbols.menu, color: AppColors.textPrimary, size: 24),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'Menu',
        ),
      ),
      // Center – title
      title: Text(
        'Ormaflow',
        style: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: 0.2,
        ),
      ),
      // Right – settings
      actions: [
        IconButton(
          icon: const Icon(
            Symbols.settings,
            color: AppColors.textPrimary,
            size: 24,
          ),
          onPressed: () => showSettingsSheet(context),
          tooltip: 'Settings',
        ),
      ],
    );
  }

  // ── FAB factory ───────────────────────────────

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NoteEditorScreen(),
          ),
        );
      },
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Icon(Symbols.add, size: 28, weight: 600),
    );
  }

  // ── Drawer factory ────────────────────────────

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      elevation: 0,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.surface,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Ormaflow',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          _buildDrawerItem(
            icon: Symbols.home,
            title: 'Home',
            index: 0,
            context: context,
          ),
          _buildDrawerItem(
            icon: Symbols.delete,
            title: 'Trash',
            index: 1,
            context: context,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required int index,
    required BuildContext context,
  }) {
    final isSelected = _currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: isSelected,
        selectedTileColor: AppColors.accent.withAlpha(25), // Mild green tint
        leading: Icon(
          icon,
          color: isSelected ? AppColors.accent : AppColors.textSecondary,
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: isSelected ? AppColors.accent : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
          Navigator.pop(context); // Close drawer
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  _HomeBody  – scrollable content area
// ──────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SizedBox(height: 8),
          _HeroCard(),
          SizedBox(height: 16),
          _TaskListCard(),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  _HeroCard  – "Tasks for Today" + pending badge
// ──────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final pending = context.watch<TaskProvider>().pendingCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tasks for Today',
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 10),
          _PendingBadge(count: pending),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  _PendingBadge  – small green pill chip
// ──────────────────────────────────────────────

class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count pending',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          shadows: [
            Shadow(
              color: Colors.black.withAlpha(40),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  _TaskListCard  – all tasks in one #2D2D2D box
// ──────────────────────────────────────────────

class _TaskListCard extends StatelessWidget {
  const _TaskListCard();

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>().tasks;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        // Material INSIDE the clip: InkWell splash is now rendered on this
        // material, so it is clipped by the RRect and never bleeds square
        // corners on the first/last rows.
        child: Material(
          color: AppColors.surface,
          child: Column(
            children: [
              for (int i = 0; i < tasks.length; i++) ...[
                _TaskRow(task: tasks[i]),
                if (i < tasks.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.divider,
                    indent: 0,
                    endIndent: 0,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  _TaskRow  – single task item inside the card
//
//  Interaction model (Libadwaita style):
//   • Tap anywhere on the row  → "Launch Note" (primary action)
//   • Tap the trailing circle  → toggle isCompleted ONLY
//
//  The trailing GestureDetector uses HitTestBehavior.opaque so it
//  absorbs the pointer event before the outer InkWell sees it,
//  keeping the two actions completely isolated.
// ──────────────────────────────────────────────

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final Task task;

  void _showNoteDetails(BuildContext context, Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(task: task),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        context.read<TaskProvider>().moveToTrash(task.id);
      },
      background: Container(
        color: AppColors.background, // Match the window background to look like a cutout
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFE04F5F).withAlpha(35), // Soft coral/red tint
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Symbols.delete,
            color: Color(0xFFE04F5F),
            size: 22,
          ),
        ),
      ),
      child: InkWell(
        // Primary action: open / launch the note
        onTap: () => _showNoteDetails(context, task),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Task details (left / main area) ──────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row — includes type icon prefix for Voice/Image
                  _TaskTitleRow(task: task),
                  const SizedBox(height: 3),
                  // Subtitle: time • type label
                  _TaskSubtitle(task: task),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // ── Trailing checkbox (isolated tap zone) ─
            GestureDetector(
              // opaque: absorbs this touch so the outer InkWell never fires
              behavior: HitTestBehavior.opaque,
              onTap: () => context.read<TaskProvider>().toggleTask(task.id),
              child: Padding(
                // Generous hit-target padding around the small circle
                padding: const EdgeInsets.all(4),
                child: _CircleCheck(isCompleted: task.isCompleted),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  _CircleCheck  – flat modern toggle (Libadwaita 1.5+ style)
//
//  Unchecked: thin muted ring, transparent fill
//  Checked  : solid accent fill + white checkmark
//  Animation: AnimatedContainer smoothly interpolates colour & border
// ──────────────────────────────────────────────

class _CircleCheck extends StatelessWidget {
  const _CircleCheck({required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted ? AppColors.accent : Colors.transparent,
        border: Border.all(
          // Muted ring when idle; accent ring disappears into fill when done
          color: isCompleted ? AppColors.accent : const Color(0xFF56555E),
          width: 1.75,
        ),
      ),
      child: isCompleted
          ? const Center(
              child: Icon(
                Symbols.check,
                size: 15,
                weight: 700,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}

// ──────────────────────────────────────────────
//  _TaskTitleRow  – title + optional type icon prefix
// ──────────────────────────────────────────────

class _TaskTitleRow extends StatelessWidget {
  const _TaskTitleRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final bool hasPrefix = task.type != TaskType.manual;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasPrefix) ...[
          Icon(task.type.icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 5),
        ],
        Expanded(
          child: Text(
            task.title,
            style: GoogleFonts.inter(
              color: task.isCompleted
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 15,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
//  _TaskSubtitle  – "09:00 AM • Manual"
// ──────────────────────────────────────────────

class _TaskSubtitle extends StatelessWidget {
  const _TaskSubtitle({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          task.time,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 6),
        // Small dot separator
        Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: AppColors.textSecondary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          task.type.label,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
