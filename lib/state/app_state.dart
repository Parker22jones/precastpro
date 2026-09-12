import 'package:flutter/foundation.dart';

import '../logic/flow_tree.dart';
import '../models/component_status.dart';
import '../models/inventory_item.dart';
import '../models/job.dart';
import '../models/job_spec.dart';
import '../models/pipe_penetration.dart';
import '../models/pipe_product.dart';
import '../models/precast_piece.dart';
import 'design_state.dart';

/// A structure that has been released from engineering into the yard: its
/// design plus the physical components tracked through the lifecycle.
class StructureRecord {
  StructureRecord({required this.design, required this.components});

  final DesignState design;
  final List<StructureComponent> components;

  String get mark => design.structureMark;
  String get jobName => design.jobName;
  String get jobId => design.jobId;

  /// Scheduled pour date, normalized to midnight for calendar grouping.
  DateTime get pourDate =>
      DateTime(design.castDate.year, design.castDate.month, design.castDate.day);

  bool get isPoured => components.isNotEmpty && components.every((c) => c.status != ComponentStatus.pendingPour);
  double get totalWeightLbs => components.fold(0.0, (s, c) => s + c.weightLbs);

  /// Concrete only - castings, boots and steps are pulled from stock rather
  /// than poured, so they do not count against the day's yardage.
  double get concreteWeightLbs => design.stack.totalWeightLbs;

  /// Concrete this structure takes out of the batch plant, in cubic yards.
  double get pourVolumeCuYd => concreteWeightLbs / (kConcreteDensityPcf * 27.0);

  int countWithStatus(ComponentStatus status) => components.where((c) => c.status == status).length;

  /// Furthest-behind component status, i.e. what the structure as a whole is
  /// waiting on.
  ComponentStatus get rollupStatus => components.isEmpty
      ? ComponentStatus.pendingPour
      : components.map((c) => c.status).reduce((a, b) => a.index <= b.index ? a : b);
}

/// An in-app reminder raised by the inventory engine.
class StockNotification {
  StockNotification({required this.sku, required this.message, required this.raisedAt});

  final String sku;
  final String message;
  final DateTime raisedAt;
  bool read = false;
}

/// Top-level store: every job's structures, the yard inventory, and the
/// reactive link between them.
class AppState extends ChangeNotifier {
  AppState({List<StructureRecord>? structures, List<InventoryItem>? inventory, List<Job>? jobs})
    : _inventory = inventory ?? defaultInventory(),
      _structures = structures ?? [],
      _jobs = jobs ?? [] {
    if (_structures.isEmpty) _seed();
    if (_jobs.isEmpty) _jobs.addAll(_jobsFromStructures());
    _activeJobId = _jobs.first.id;
    for (final record in _structures) {
      record.design.addListener(notifyListeners);
    }
  }

  @override
  void dispose() {
    for (final record in _structures) {
      record.design.removeListener(notifyListeners);
    }
    super.dispose();
  }

  final List<StructureRecord> _structures;
  final List<InventoryItem> _inventory;
  final List<Job> _jobs;
  final List<StockNotification> _notifications = [];
  int _activeIndex = 0;
  String _activeJobId = '';
  bool _jobOpen = false;

  List<StructureRecord> get structures => List.unmodifiable(_structures);
  List<Job> get jobs => List.unmodifiable(_jobs);
  List<InventoryItem> get inventory => List.unmodifiable(_inventory);
  List<StockNotification> get notifications => List.unmodifiable(_notifications);
  List<StockNotification> get unreadNotifications =>
      _notifications.where((n) => !n.read).toList(growable: false);
  List<InventoryItem> get lowStockItems =>
      _inventory.where((i) => i.isLowStock).toList(growable: false);

  int get activeIndex => _activeIndex;
  StructureRecord get activeStructure => _structures[_activeIndex];

  Job get activeJob => jobById(_activeJobId) ?? _jobs.first;

  /// True once a job has been explicitly opened from the job browser. Until
  /// then the application shows nothing but the job list, and while it is set
  /// every view is scoped to [activeJob].
  bool get isJobOpen => _jobOpen;

  /// Structures belonging to the open job - the only ones any job-scoped
  /// screen is allowed to show.
  List<StructureRecord> get activeJobStructures => structuresForJob(_activeJobId);

  /// Enters a job's database: selects it, lands on its first structure and
  /// unlocks the job-scoped screens.
  void openJob(String jobId) {
    if (jobById(jobId) == null) return;
    if (jobId != _activeJobId) {
      _activeJobId = jobId;
      final structures = alphabeticalStructures(jobId);
      if (structures.isNotEmpty) _activeIndex = _structures.indexOf(structures.first);
    }
    _jobOpen = true;
    notifyListeners();
  }

  /// Leaves the job database and returns to the job browser.
  void closeJob() {
    if (!_jobOpen) return;
    _jobOpen = false;
    notifyListeners();
  }

  Job? jobById(String id) {
    for (final job in _jobs) {
      if (job.id == id) return job;
    }
    return null;
  }

  /// Jobs matching the instant-search query on the Jobs screen.
  List<Job> searchJobs(String query) =>
      _jobs.where((j) => j.matches(query)).toList(growable: false);

  List<StructureRecord> structuresForJob(String jobId) =>
      _structures.where((s) => s.jobId == jobId).toList(growable: false);

  /// Structures of a job strictly A-to-Z by their unique structure names.
  List<StructureRecord> alphabeticalStructures(String jobId) =>
      structuresForJob(jobId)..sort((a, b) => a.mark.compareTo(b.mark));

  /// Drainage order: outfall roots with upstream branches nested inside.
  List<FlowNode<StructureRecord>> flowTree(String jobId) => buildFlowTree<StructureRecord>(
    structuresForJob(jobId),
    markOf: (s) => s.mark,
    downstreamOf: (s) => s.design.downstreamMark,
  );

  /// Job structures ordered by shop priority; unranked items fall to the end.
  List<StructureRecord> prioritizedStructures(String jobId) {
    final list = structuresForJob(jobId).toList();
    list.sort((a, b) {
      final pa = a.design.priority == 0 ? 1 << 20 : a.design.priority;
      final pb = b.design.priority == 0 ? 1 << 20 : b.design.priority;
      return pa == pb ? a.mark.compareTo(b.mark) : pa.compareTo(pb);
    });
    return list;
  }

  /// Applies a new ranking order, renumbering priorities from 1.
  void setPriorityOrder(List<StructureRecord> ordered) {
    for (var i = 0; i < ordered.length; i++) {
      ordered[i].design.priority = i + 1;
    }
    notifyListeners();
  }

  void reorderPriority(String jobId, int oldIndex, int newIndex) {
    final ordered = prioritizedStructures(jobId);
    if (oldIndex < 0 || oldIndex >= ordered.length) return;
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final record = ordered.removeAt(oldIndex);
    ordered.insert(target.clamp(0, ordered.length), record);
    setPriorityOrder(ordered);
  }

  /// Every structure scheduled to be poured on [day], most urgent first.
  /// Pass [jobId] to keep the line inside one job's database.
  List<StructureRecord> castingLineFor(DateTime day, {String? jobId}) {
    final date = DateTime(day.year, day.month, day.day);
    final list = _structures
        .where((s) => s.pourDate == date && (jobId == null || s.jobId == jobId))
        .toList();
    list.sort((a, b) {
      final pa = a.design.priority == 0 ? 1 << 20 : a.design.priority;
      final pb = b.design.priority == 0 ? 1 << 20 : b.design.priority;
      return pa == pb ? a.mark.compareTo(b.mark) : pa.compareTo(pb);
    });
    return list;
  }

  /// Concrete scheduled for [day], in pounds.
  double concreteWeightLbsFor(DateTime day, {String? jobId}) =>
      castingLineFor(day, jobId: jobId).fold(0.0, (sum, r) => sum + r.concreteWeightLbs);

  /// Concrete scheduled for [day], in cubic yards - what the plant manager
  /// books against the batch plant.
  double pourVolumeCuYdFor(DateTime day, {String? jobId}) =>
      concreteWeightLbsFor(day, jobId: jobId) / (kConcreteDensityPcf * 27.0);

  /// Yardage the plant can batch in one shift.
  static const double dailyPourCapacityCuYd = 40.0;

  bool isOverPourCapacity(DateTime day) =>
      pourVolumeCuYdFor(day) > dailyPourCapacityCuYd;

  static DateTime get tomorrow {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  /// Tomorrow's run - the view plant managers open first each afternoon.
  List<StructureRecord> get tomorrowCastingLine => castingLineFor(tomorrow);
  double get tomorrowPourVolumeCuYd => pourVolumeCuYdFor(tomorrow);

  /// Unpoured structures ranked by priority, for drafting into a run.
  List<StructureRecord> unpouredBacklog({String? jobId}) {
    final list = _structures
        .where((s) => !s.isPoured && (jobId == null || s.jobId == jobId))
        .toList();
    list.sort((a, b) {
      final pa = a.design.priority == 0 ? 1 << 20 : a.design.priority;
      final pb = b.design.priority == 0 ? 1 << 20 : b.design.priority;
      return pa == pb ? a.mark.compareTo(b.mark) : pa.compareTo(pb);
    });
    return list;
  }

  /// Drafts a structure into the manufacturing run on [day].
  void scheduleStructure(StructureRecord record, DateTime day) {
    record.design.castDate = DateTime(day.year, day.month, day.day);
    notifyListeners();
  }

  void selectJob(String jobId) {
    if (jobById(jobId) == null || jobId == _activeJobId) return;
    _activeJobId = jobId;
    final first = alphabeticalStructures(jobId);
    if (first.isNotEmpty) _activeIndex = _structures.indexOf(first.first);
    notifyListeners();
  }

  /// Opens a structure in the wizard from either navigation panel.
  void selectStructureRecord(StructureRecord record) {
    final index = _structures.indexOf(record);
    if (index < 0) return;
    _activeIndex = index;
    _activeJobId = record.jobId;
    notifyListeners();
  }

  void updateJob(Job job, {String? name, String? number, String? contractor, String? customer}) {
    if (name != null) job.name = name;
    if (number != null) job.number = number;
    if (contractor != null) job.contractor = contractor;
    if (customer != null) job.customer = customer;
    for (final record in structuresForJob(job.id)) {
      record.design.jobName = job.name;
      record.design.customer = job.customer;
    }
    notifyListeners();
  }

  Job addJob({String? name, String? number, String? contractor, String? customer}) {
    final n = _jobs.length + 1;
    final job = Job(
      id: 'job-$n-${DateTime.now().millisecondsSinceEpoch}',
      name: name ?? 'New Job ${n.toString().padLeft(2, '0')}',
      number: number ?? 'J-${(1000 + n)}',
      contractor: contractor ?? 'TBD',
      customer: customer ?? 'TBD',
    );
    _jobs.add(job);
    _activeJobId = job.id;
    _jobOpen = true;
    notifyListeners();
    return job;
  }

  /// The design currently open in the engineering wizard.
  DesignState get design => activeStructure.design;

  void selectStructure(int index) {
    if (index < 0 || index >= _structures.length || index == _activeIndex) return;
    _activeIndex = index;
    notifyListeners();
  }

  /// Re-issues the active structure's component list from the current design.
  /// Components already past "Pending Pour" keep their status where the id and
  /// piece still match, so a late design tweak does not wipe yard progress.
  void releaseActiveStructureToYard() {
    final record = activeStructure;
    final previous = {for (final c in record.components) c.id: c};
    final rebuilt = record.design.buildComponents();
    for (final component in rebuilt) {
      final old = previous[component.id];
      if (old != null && old.pieceId == component.pieceId) {
        component.status = old.status;
      }
    }
    record.components
      ..clear()
      ..addAll(rebuilt);
    notifyListeners();
  }

  void addStructure({String? jobId, String? jobName, String? mark, String? customer}) {
    final n = _structures.length + 1;
    final job = jobById(jobId ?? _activeJobId);
    final design = DesignState(
      jobId: job?.id ?? _activeJobId,
      jobName: jobName ?? job?.name ?? 'New Job ${n.toString().padLeft(2, '0')}',
      structureMark: mark ?? 'MH-$n',
      customer: customer ?? job?.customer ?? 'TBD',
    );
    design.addListener(notifyListeners);
    _structures.add(StructureRecord(design: design, components: design.buildComponents()));
    _activeIndex = _structures.length - 1;
    notifyListeners();
  }

  /// Advances (or rolls back) one component. Crossing into "Shipped" consumes
  /// the matching stock item; rolling back out of "Shipped" returns it.
  void setComponentStatus(
    StructureRecord record,
    StructureComponent component,
    ComponentStatus status,
  ) {
    final was = component.status;
    if (was == status) return;
    component.status = status;

    if (!was.hasLeftYard && status.hasLeftYard) {
      _consumeStock(component.stockSku);
    } else if (was.hasLeftYard && !status.hasLeftYard) {
      _returnStock(component.stockSku);
    }
    notifyListeners();
  }

  void advanceComponent(StructureRecord record, StructureComponent component) {
    final next = component.status.next;
    if (next != null) setComponentStatus(record, component, next);
  }

  /// Yard manager shortcut: ship (or un-ship) every component of a structure.
  void setStructureShipped(StructureRecord record, bool shipped) {
    for (final component in record.components) {
      if (shipped && !component.status.hasLeftYard) {
        setComponentStatus(record, component, ComponentStatus.shipped);
      } else if (!shipped && component.status.hasLeftYard) {
        setComponentStatus(record, component, ComponentStatus.inYard);
      }
    }
  }

  InventoryItem? itemForSku(String sku) {
    for (final item in _inventory) {
      if (item.sku == sku) return item;
    }
    return null;
  }

  void setThreshold(InventoryItem item, int threshold) {
    item.minThreshold = threshold < 0 ? 0 : threshold;
    _checkLowStock(item);
    notifyListeners();
  }

  void receiveStock(InventoryItem item, int quantity) {
    item.onHand += quantity;
    if (item.onHand < 0) item.onHand = 0;
    if (item.isLowStock) {
      _checkLowStock(item);
    } else {
      _notifications.removeWhere((n) => n.sku == item.sku);
    }
    notifyListeners();
  }

  void markNotificationsRead() {
    for (final n in _notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  void _consumeStock(String sku) {
    final item = itemForSku(sku);
    if (item == null) return;
    item.onHand = item.onHand > 0 ? item.onHand - 1 : 0;
    _checkLowStock(item);
  }

  void _returnStock(String sku) {
    final item = itemForSku(sku);
    if (item == null) return;
    item.onHand += 1;
    if (!item.isLowStock) _notifications.removeWhere((n) => n.sku == item.sku);
  }

  void _checkLowStock(InventoryItem item) {
    if (!item.isLowStock) return;
    if (_notifications.any((n) => n.sku == item.sku && !n.read)) return;
    _notifications.add(
      StockNotification(
        sku: item.sku,
        message:
            '${item.description} is at ${item.onHand} on hand '
            '(minimum ${item.minThreshold}). Reorder ${item.shortfall} or more.',
        raisedAt: DateTime.now(),
      ),
    );
  }

  /// Derives job headers for structures supplied without them (tests, imports).
  List<Job> _jobsFromStructures() {
    final out = <Job>[];
    for (final record in _structures) {
      if (out.any((j) => j.id == record.jobId)) continue;
      out.add(
        Job(
          id: record.jobId,
          name: record.jobName,
          number: record.jobId.toUpperCase(),
          contractor: 'TBD',
          customer: record.design.customer,
        ),
      );
    }
    if (out.isEmpty) {
      out.add(
        Job(id: 'job-1', name: 'Unassigned', number: 'J-0001', contractor: 'TBD', customer: 'TBD'),
      );
    }
    return out;
  }

  void _seed() {
    final today = DateTime.now();
    DateTime day(int offset) =>
        DateTime(today.year, today.month, today.day).add(Duration(days: offset));

    _jobs.addAll([
      Job(
        id: 'job-riverbend',
        name: 'Riverbend Interceptor',
        number: 'J-2418',
        contractor: 'Halloran Underground LLC',
        customer: 'City of Springfield',
      ),
      Job(
        id: 'job-northgate',
        name: 'Northgate Retail Pad',
        number: 'J-2512',
        contractor: 'Weston Site Development',
        customer: 'Northgate Developers',
      ),
    ]);

    final mh1 = DesignState(
      jobId: 'job-riverbend',
      jobName: 'Riverbend Interceptor',
      structureMark: 'MH-1',
      customer: 'City of Springfield',
      structureType: StructureType.sanitaryManhole,
      castDate: day(0),
      priority: 1,
      castingId: 'EJ BJWSA',
      rimElevationFt: 100.0,
      invertElevationFt: 88.5,
    );
    final mh2 = DesignState(
      jobId: 'job-riverbend',
      jobName: 'Riverbend Interceptor',
      structureMark: 'MH-2',
      customer: 'City of Springfield',
      downstreamMark: 'MH-1',
      castDate: day(1),
      priority: 2,
      structureType: StructureType.sanitaryManhole,
      rimElevationFt: 102.5,
      invertElevationFt: 89.0,
      structureDiameterIn: 60,
      conicalTop: false,
      pipes: [
        PipePenetration(
          name: 'IN-A',
          outsideDiameterIn: 18,
          invertElevationFt: 90.0,
          horizontalAngleDeg: 45,
          material: PipeMaterial.rcp,
        ),
        PipePenetration(
          name: 'OUT',
          outsideDiameterIn: 24,
          invertElevationFt: 89.0,
          horizontalAngleDeg: 225,
          material: PipeMaterial.rcp,
        ),
      ],
    );
    final mh3 = DesignState(
      jobId: 'job-riverbend',
      jobName: 'Riverbend Interceptor',
      structureMark: 'MH-3',
      customer: 'City of Springfield',
      downstreamMark: 'MH-2',
      castDate: day(3),
      priority: 3,
      structureType: StructureType.sanitaryManhole,
      rimElevationFt: 104.0,
      invertElevationFt: 91.0,
      pipes: [
        PipePenetration(
          name: 'OUT',
          outsideDiameterIn: 18,
          invertElevationFt: 91.0,
          horizontalAngleDeg: 180,
          material: PipeMaterial.rcp,
          productId: 'RCP-B',
          nominalSizeIn: 15,
          psx: PsxConnector.directDrive,
          boot: BootType.pressSeal,
        ),
      ],
    );
    final cb1 = DesignState(
      jobId: 'job-northgate',
      jobName: 'Northgate Retail Pad',
      structureMark: 'CB-1',
      customer: 'Northgate Developers',
      castDate: day(1),
      priority: 1,
      castingId: 'EJ 1860',
      structureType: StructureType.catchBasin,
      rimElevationFt: 96.0,
      invertElevationFt: 90.0,
      sumpDepthIn: 12,
      conicalTop: false,
      pipes: [
        PipePenetration(
          name: 'OUT',
          outsideDiameterIn: 15,
          invertElevationFt: 90.0,
          horizontalAngleDeg: 270,
          material: PipeMaterial.hdpe,
        ),
      ],
    );

    final cb2 = DesignState(
      jobId: 'job-northgate',
      jobName: 'Northgate Retail Pad',
      structureMark: 'CB-2',
      customer: 'Northgate Developers',
      downstreamMark: 'CB-1',
      castDate: day(-2),
      priority: 2,
      castingId: 'EJ 1337Z/1338A',
      structureType: StructureType.catchBasin,
      rimElevationFt: 97.5,
      invertElevationFt: 91.5,
      sumpDepthIn: 12,
      conicalTop: false,
      pipes: [
        PipePenetration(
          name: 'OUT',
          outsideDiameterIn: 15,
          invertElevationFt: 91.5,
          horizontalAngleDeg: 90,
          material: PipeMaterial.hdpe,
          productId: 'ADS-N12',
          nominalSizeIn: 12,
        ),
      ],
    );

    for (final design in [mh1, mh2, mh3, cb1, cb2]) {
      _structures.add(StructureRecord(design: design, components: design.buildComponents()));
    }

    // Give the yard a realistic starting spread of progress.
    final first = _structures.first.components;
    for (var i = 0; i < first.length; i++) {
      first[i].status = i < 3
          ? ComponentStatus.inYard
          : i < 6
          ? ComponentStatus.manufactured
          : ComponentStatus.pendingPour;
    }
  }
}
