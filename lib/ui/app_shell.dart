import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'app_scope.dart';
import 'drawings_panel.dart';
import 'inventory_page.dart';
import 'logistics_page.dart';
import 'mh_theme.dart';
import 'phases/phase_elevations.dart';
import 'phases/phase_job_info.dart';
import 'phases/phase_pipe_schedule.dart';
import 'phases/phase_structural.dart';
import 'phases/phase_takeoff.dart';

/// Width at or above which the desktop side-by-side layout is used.
const double kWideLayoutBreakpoint = 900;

/// Sidebar destinations: the five engineering phases plus the operations
/// modules that share the same store.
enum Module {
  phase1('1', 'Job Info & Spec', Icons.description_outlined),
  phase2('2', 'Elevations & Sizing', Icons.straighten),
  phase3('3', 'Pipe Schedule', Icons.grid_on),
  phase4('4', 'Structural Details', Icons.settings_input_component),
  phase5('5', 'Takeoff & Production', Icons.fact_check_outlined),
  logistics('', 'Logistics Dashboard', Icons.local_shipping_outlined),
  inventory('', 'Inventory Management', Icons.inventory_2_outlined);

  const Module(this.step, this.title, this.icon);

  final String step;
  final String title;
  final IconData icon;

  bool get isPhase => step.isNotEmpty;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  Module _module = Module.phase1;
  int _seenNotifications = 0;
  AppState? _app;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (!identical(app, _app)) {
      _app?.removeListener(_onStateChanged);
      _app = app..addListener(_onStateChanged);
      _seenNotifications = app.notifications.length;
    }
  }

  @override
  void dispose() {
    _app?.removeListener(_onStateChanged);
    super.dispose();
  }

  /// In-app reminder whenever the inventory engine raises a new alert.
  void _onStateChanged() {
    final app = _app;
    if (app == null || !mounted) return;
    final count = app.notifications.length;
    if (count > _seenNotifications) {
      final latest = app.notifications.last;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('low-stock-snackbar'),
          backgroundColor: Mh.warn,
          duration: const Duration(seconds: 6),
          content: Text('LOW STOCK: ${latest.message}',
              style: const TextStyle(color: Color(0xFF3A2A00), fontWeight: FontWeight.w700)),
          action: SnackBarAction(
            label: 'INVENTORY',
            textColor: const Color(0xFF3A2A00),
            onPressed: () => setState(() => _module = Module.inventory),
          ),
        ),
      );
    }
    _seenNotifications = count;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= kWideLayoutBreakpoint;
      final content = _content(app, wide);

      return Scaffold(
        appBar: _TopBar(
          app: app,
          module: _module,
          compact: !wide,
          onOpenInventory: () => setState(() => _module = Module.inventory),
        ),
        drawer: wide
            ? null
            : Drawer(
                width: 258,
                child: _Sidebar(
                  module: _module,
                  onSelect: (m) {
                    Navigator.of(context).pop();
                    setState(() => _module = m);
                  },
                ),
              ),
        body: SafeArea(
          child: wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    width: 228,
                    child: _Sidebar(module: _module, onSelect: (m) => setState(() => _module = m)),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ])
              : content,
        ),
      );
    });
  }

  Widget _content(AppState app, bool wide) {
    final page = switch (_module) {
      Module.phase1 => const PhaseJobInfo(),
      Module.phase2 => const PhaseElevations(),
      Module.phase3 => const PhasePipeSchedule(),
      Module.phase4 => const PhaseStructural(),
      Module.phase5 => const PhaseTakeoff(),
      Module.logistics => const LogisticsPage(),
      Module.inventory => const InventoryPage(),
    };

    if (!_module.isPhase) return page;

    final drawings = DrawingsPanel(design: app.design, stacked: !wide);

    if (wide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(flex: 5, child: Column(children: [Expanded(child: page), _PhaseNav(
          module: _module,
          onSelect: (m) => setState(() => _module = m),
        )])),
        const VerticalDivider(width: 1),
        Expanded(flex: 4, child: drawings),
      ]);
    }

    // Narrow: data and drawings as swipeable tabs.
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        const ColoredBox(
          color: Mh.chromeLight,
          child: SizedBox(
            width: double.infinity,
            height: 34,
            child: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Color(0xFFB8C6D4),
              indicatorColor: Colors.white,
              labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              tabs: [Tab(text: 'DATA'), Tab(text: 'DRAWINGS')],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(children: [
            Column(children: [
              Expanded(child: page),
              _PhaseNav(module: _module, onSelect: (m) => setState(() => _module = m)),
            ]),
            drawings,
          ]),
        ),
      ]),
    );
  }
}

/// Back / next strip under the wizard content.
class _PhaseNav extends StatelessWidget {
  const _PhaseNav({required this.module, required this.onSelect});

  final Module module;
  final ValueChanged<Module> onSelect;

  @override
  Widget build(BuildContext context) {
    final phases = Module.values.where((m) => m.isPhase).toList();
    final index = phases.indexOf(module);
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: Mh.headerFill,
        border: Border(top: BorderSide(color: Mh.gridLine)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(children: [
        OutlinedButton(
          key: const Key('btn-phase-back'),
          onPressed: index <= 0 ? null : () => onSelect(phases[index - 1]),
          child: const Text('< BACK'),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text('PHASE ${module.step} OF ${phases.length} - ${module.title.toUpperCase()}',
              style: Mh.header),
        ),
        FilledButton(
          key: const Key('btn-phase-next'),
          onPressed: index >= phases.length - 1 ? null : () => onSelect(phases[index + 1]),
          child: const Text('NEXT >'),
        ),
      ]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.module, required this.onSelect});

  final Module module;
  final ValueChanged<Module> onSelect;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final phases = Module.values.where((m) => m.isPhase).toList();
    final ops = Module.values.where((m) => !m.isPhase).toList();
    final lowCount = app.lowStockItems.length;

    return Container(
      color: Mh.chrome,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: Mh.chromeLight,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('PRECASTPRO',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2)),
              Text('${app.design.jobName} / ${app.design.structureMark}',
                  style: const TextStyle(color: Color(0xFF9FB4C8), fontSize: 10.5)),
            ]),
          ),
          const _SidebarHeading('Engineering Wizard'),
          for (final m in phases)
            _SidebarTile(
              module: m,
              selected: m == module,
              onTap: () => onSelect(m),
              leadingText: m.step,
            ),
          const _SidebarHeading('Operations'),
          for (final m in ops)
            _SidebarTile(
              module: m,
              selected: m == module,
              onTap: () => onSelect(m),
              badge: m == Module.inventory && lowCount > 0 ? '$lowCount' : null,
            ),
        ],
      ),
    );
  }
}

class _SidebarHeading extends StatelessWidget {
  const _SidebarHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              color: Color(0xFF7D93A6),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0)),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.module,
    required this.selected,
    required this.onTap,
    this.leadingText,
    this.badge,
  });

  final Module module;
  final bool selected;
  final VoidCallback onTap;
  final String? leadingText;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('nav-${module.name}'),
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? Mh.accent : Colors.transparent,
          border: const Border(bottom: BorderSide(color: Color(0xFF223243))),
        ),
        child: Row(children: [
          if (leadingText != null)
            Container(
              width: 17,
              height: 17,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.white : const Color(0xFF35485E),
                shape: BoxShape.rectangle,
              ),
              child: Text(leadingText!,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: selected ? Mh.accent : Colors.white)),
            )
          else
            Icon(module.icon, size: 16, color: selected ? Colors.white : const Color(0xFFB8C6D4)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(module.title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : const Color(0xFFD4DEE7))),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              color: Mh.warn,
              child: Text(badge!,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF3A2A00))),
            ),
        ]),
      ),
    );
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.app,
    required this.module,
    required this.compact,
    required this.onOpenInventory,
  });

  final AppState app;
  final Module module;
  final bool compact;
  final VoidCallback onOpenInventory;

  @override
  Size get preferredSize => const Size.fromHeight(38);

  @override
  Widget build(BuildContext context) {
    final low = app.lowStockItems;
    final unread = app.unreadNotifications.length;

    return AppBar(
      toolbarHeight: 38,
      backgroundColor: Mh.chrome,
      foregroundColor: Colors.white,
      titleSpacing: 8,
      title: Text(
        compact ? module.title : '${app.design.jobName}  /  ${app.design.structureMark}',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (low.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            child: InkWell(
              key: const Key('badge-low-stock'),
              onTap: onOpenInventory,
              child: Container(
                color: Mh.warn,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                child: Text('LOW STOCK ALERT (${low.length})',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF3A2A00))),
              ),
            ),
          ),
        IconButton(
          key: const Key('btn-notifications'),
          tooltip: 'Reminders',
          onPressed: () => _showNotifications(context),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_none, size: 19),
          ),
        ),
      ],
    );
  }

  void _showNotifications(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('Inventory Reminders', style: TextStyle(fontSize: 15)),
        content: SizedBox(
          width: 420,
          child: app.notifications.isEmpty
              ? const Text('No reminders.', style: Mh.cell)
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final n in app.notifications.reversed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.warning_amber_rounded, size: 16, color: Mh.warn),
                          const SizedBox(width: 6),
                          Expanded(child: Text(n.message, style: Mh.cell)),
                        ]),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              app.markNotificationsRead();
              Navigator.of(context).pop();
            },
            child: const Text('MARK ALL READ'),
          ),
        ],
      ),
    );
  }
}

/// Exposed for tests: whether the desktop layout applies at [width].
bool isWideLayout(double width) => width >= kWideLayoutBreakpoint;

/// True on platforms where the submittal is shared rather than printed.
bool get isWebTarget => kIsWeb;
