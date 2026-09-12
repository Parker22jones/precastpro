import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precastpro/export/submittal_pdf.dart';
import 'package:precastpro/logic/flow_tree.dart';
import 'package:precastpro/main.dart';
import 'package:precastpro/models/casting_catalog.dart';
import 'package:precastpro/models/job_spec.dart';
import 'package:precastpro/models/pipe_penetration.dart';
import 'package:precastpro/models/pipe_product.dart';
import 'package:precastpro/painters/elevation_painter.dart';
import 'package:precastpro/state/app_state.dart';
import 'package:precastpro/state/design_state.dart';
import 'package:precastpro/ui/app_shell.dart';
import 'package:precastpro/ui/calendar_page.dart';
import 'package:precastpro/ui/drawings_panel.dart';
import 'package:precastpro/ui/jobs_page.dart';

Future<void> pumpAt(
  WidgetTester tester,
  Size size,
  AppState state, {
  bool openJob = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  if (openJob) state.openJob(state.activeJob.id);
  await tester.pumpWidget(PrecastProApp(state: state));
  await tester.pumpAndSettle();
}

Future<void> openModule(WidgetTester tester, Module module, {bool wide = true}) async {
  if (!wide) {
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(Key('nav-${module.name}')));
  await tester.pumpAndSettle();
}

void main() {
  group('job hierarchy', () {
    test('seeded store carries jobs with number and contractor metadata', () {
      final app = AppState();
      expect(app.jobs.length, greaterThan(1));
      for (final job in app.jobs) {
        expect(job.number, isNotEmpty);
        expect(job.contractor, isNotEmpty);
        expect(app.structuresForJob(job.id), isNotEmpty);
      }
    });

    test('search matches name, number and contractor and ignores case', () {
      final app = AppState();
      final job = app.jobs.first;

      expect(app.searchJobs('').length, app.jobs.length);
      expect(app.searchJobs(job.name.toLowerCase()), contains(job));
      expect(app.searchJobs(job.number), contains(job));
      expect(app.searchJobs(job.contractor.substring(0, 5).toUpperCase()), contains(job));
      expect(app.searchJobs('zzzz-no-match'), isEmpty);
    });

    test('structures list A-Z by their unique structure name', () {
      final app = AppState();
      final job = app.jobs.first;
      final marks = app.alphabeticalStructures(job.id).map((s) => s.mark).toList();
      final sorted = [...marks]..sort();
      expect(marks, sorted);
    });

    test('flow tree nests upstream structures under their downstream parent', () {
      final app = AppState();
      final job = app.jobs.firstWhere((j) => j.id == 'job-riverbend');
      final tree = app.flowTree(job.id);

      expect(tree.map((n) => n.mark), contains('MH-1'));
      final root = tree.firstWhere((n) => n.mark == 'MH-1');
      expect(root.children.map((c) => c.mark), contains('MH-2'));
      expect(root.size, app.structuresForJob(job.id).length);
    });

    test('selecting a job or structure moves the active design', () {
      final app = AppState();
      final job = app.jobs.last;
      app.selectJob(job.id);
      expect(app.activeJob.id, job.id);
      expect(app.design.jobId, job.id);

      final target = app.alphabeticalStructures(job.id).last;
      app.selectStructureRecord(target);
      expect(app.design, same(target.design));
      expect(app.activeStructure, same(target));
    });
  });

  group('flow tree builder', () {
    List<FlowNode<String>> build(Map<String, String?> links) => buildFlowTree<String>(
      links.keys.toList(),
      markOf: (m) => m,
      downstreamOf: (m) => links[m],
    );

    test('linear chain nests one level per link', () {
      final tree = build({'A': null, 'B': 'A', 'C': 'B'});
      expect(tree.length, 1);
      expect(tree.single.children.single.mark, 'B');
      expect(tree.single.children.single.children.single.mark, 'C');
    });

    test('missing parents and cycles are kept as roots, never dropped', () {
      final cyclic = build({'A': 'B', 'B': 'A', 'C': 'ghost'});
      final marks = <String>[];
      void walk(FlowNode<String> n) {
        marks.add(n.mark);
        n.children.forEach(walk);
      }

      cyclic.forEach(walk);
      expect(marks.toSet(), {'A', 'B', 'C'});
    });
  });

  group('priority and calendar', () {
    test('structures order by priority, unranked last', () {
      final app = AppState();
      final job = app.jobs.first;
      final ordered = app.prioritizedStructures(job.id);
      final ranks = ordered
          .map((s) => s.design.priority == 0 ? 1 << 20 : s.design.priority)
          .toList();
      for (var i = 1; i < ranks.length; i++) {
        expect(ranks[i], greaterThanOrEqualTo(ranks[i - 1]));
      }
    });

    test('reordering rewrites the numeric ranks', () {
      final app = AppState();
      final job = app.jobs.first;
      final before = app.prioritizedStructures(job.id);
      if (before.length < 2) return;
      final last = before.last;

      app.reorderPriority(job.id, before.length - 1, 0);

      final after = app.prioritizedStructures(job.id);
      expect(after.first, same(last));
      expect(after.first.design.priority, 1);
    });

    test('casting line aggregates across jobs for a single date', () {
      final app = AppState();
      final day = DateTime(2030, 5, 6);
      final a = app.structures.first;
      final b = app.structures.last;
      app.scheduleStructure(a, day);
      app.scheduleStructure(b, day);

      final line = app.castingLineFor(day);
      expect(line, containsAll(<Object>[a, b]));
      expect(app.castingLineFor(day.add(const Duration(days: 1))), isNot(contains(a)));
    });

    test('drafting an unpoured structure moves it into the run', () {
      final app = AppState();
      final target = app.unpouredBacklog().first;
      final day = DateTime(2031, 2, 3);

      app.scheduleStructure(target, day);

      expect(target.pourDate, day);
      expect(app.castingLineFor(day), contains(target));
    });
  });

  group('industrial catalogs', () {
    test('EJ catalog carries the four requested castings', () {
      final ids = kEjCastings.map((c) => c.id).toList();
      expect(ids, containsAll(<String>['EJ 1860', 'EJ 5140-1', 'EJ 1337Z/1338A', 'EJ BJWSA']));
      for (final casting in kEjCastings) {
        expect(casting.sku, isNotEmpty);
        expect(casting.weightLbs, greaterThan(0));
      }
    });

    test('pipe catalog carries the requested quick-selectors', () {
      final labels = kPipeProducts.map((p) => p.label).join(' | ');
      for (final expected in const [
        'RCP Wall B',
        'PVC SDR 26',
        'ADS N-12',
        'SaniTite HP',
        'ADS PP',
        'Slot Box',
      ]) {
        expect(labels, contains(expected));
      }
    });

    test('applying a product drives O.D. and hole size from the nominal size', () {
      final pipe = PipePenetration(
        name: 'A',
        outsideDiameterIn: 12,
        invertElevationFt: 0,
        horizontalAngleDeg: 90,
      );
      final rcp = kPipeProducts.firstWhere((p) => p.id == 'RCP-B');

      pipe.applyProduct(rcp, 24);

      expect(pipe.nominalSizeIn, 24);
      expect(pipe.outsideDiameterIn, rcp.outsideDiameterFor(24));
      expect(pipe.holeSizeIn, pipe.outsideDiameterIn + pipe.psx.holeAllowanceIn);
    });

    test('Press-Seal PSX swaps mortar for a rubber sleeve specification', () {
      final pipe = PipePenetration(
        name: 'A',
        outsideDiameterIn: 24,
        invertElevationFt: 0,
        horizontalAngleDeg: 90,
      );
      expect(pipe.sealSpec, contains('Mortar'));

      pipe.applyPsx(PsxConnector.directDrive);

      expect(pipe.boot, BootType.pressSeal);
      expect(pipe.sealSpec, contains('sleeve'));
      expect(pipe.sealSpec, contains('no mortar'));
      expect(pipe.holeSizeIn, pipe.outsideDiameterIn + PsxConnector.directDrive.holeAllowanceIn);
      expect(PsxConnector.directDrive.sku, 'PSX-DD');
      expect(PsxConnector.nyloDrive.sku, 'PSX-ND');
    });

    test('a PSX sleeve replaces the boot line in the component takeoff', () {
      final design = DesignState();
      design.updatePipe(0, (p) => p.applyPsx(PsxConnector.nyloDrive));
      final skus = design.buildComponents().map((c) => c.stockSku).toSet();
      expect(skus, contains('PSX-ND'));
    });

    test('selecting a casting drives the top component and payload weight', () {
      final design = DesignState(castingId: 'EJ 1860');
      final components = design.buildComponents();
      expect(components.map((c) => c.stockSku), contains(castingById('EJ 1860').sku));
      expect(design.payloadWeightLbs, greaterThan(0));
    });
  });

  group('select precast submittal', () {
    testWidgets('package prints multiple pages with tracking and calc data', (tester) async {
      final design = DesignState();
      late Uint8List bytes;

      await tester.runAsync(() async {
        final elevationPng = await renderPainterToPng(
          buildElevationPainter(design),
          const Size(320, 440),
          pixelRatio: 1,
        );
        final planPng = await renderPainterToPng(
          buildPlanPainter(design),
          const Size(320, 320),
          pixelRatio: 1,
        );
        bytes = await buildSubmittalPdf(
          SubmittalData(
            jobName: design.jobName,
            jobNumber: 'J-2418',
            contractor: 'Halloran Underground LLC',
            structureMark: design.structureMark,
            customer: design.customer,
            structureTypeLabel: design.structureType.label,
            castDate: design.castDate,
            sumpDepthIn: design.sumpDepthIn,
            rimElevationFt: design.rimElevationFt,
            invertElevationFt: design.invertElevationFt,
            size: design.size,
            castingLabel: design.casting.label,
            castingWeightLbs: design.casting.weightLbs,
            conicalTop: design.conicalTop,
            stack: design.stack,
            pipes: design.pipes,
            validation: design.validation,
            elevationPng: elevationPng,
            planPng: planPng,
            generatedAt: DateTime(2026, 3, 4),
          ),
        );
      });

      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      // Three sheets: title/calc, CAD blueprints, takeoff.
      final raw = String.fromCharCodes(bytes);
      final pageCount = RegExp(r'/Type\s*/Page[^s]').allMatches(raw).length;
      expect(pageCount, greaterThanOrEqualTo(3));
    });

    test('tracking metadata and payload targets derive from the structure', () {
      final design = DesignState();
      final data = SubmittalData(
        jobName: design.jobName,
        jobNumber: 'J-2418',
        structureMark: 'MH-7',
        rimElevationFt: design.rimElevationFt,
        invertElevationFt: design.invertElevationFt,
        size: design.size,
        castingWeightLbs: 420,
        conicalTop: design.conicalTop,
        stack: design.stack,
        pipes: design.pipes,
        validation: design.validation,
        elevationPng: Uint8List(0),
        planPng: Uint8List(0),
        generatedAt: DateTime(2026, 3, 4),
      );

      expect(data.submittalNumber, 'SP-J-2418-MH-7-20260304');
      expect(data.topOfCastingFt, design.rimElevationFt);
      expect(data.payloadWeightLbs, design.stack.totalWeightLbs + 420);
    });
  });

  group('jobs and calendar screens', () {
    testWidgets('the app opens on the job browser and hides structure data', (tester) async {
      final app = AppState();
      await pumpAt(tester, const Size(1600, 1100), app, openJob: false);

      expect(find.byType(JobsPage), findsOneWidget);
      expect(find.byKey(const Key('job-row-job-northgate')), findsOneWidget);
      // No wizard, no structures, no other job's data until a job is opened.
      expect(find.byKey(const Key('field-structure-mark')), findsNothing);
      expect(find.byKey(const Key('nav-phase1')), findsNothing);

      await tester.enterText(find.byKey(const Key('field-job-search')), 'Weston');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('job-row-job-riverbend')), findsNothing);
      expect(find.byKey(const Key('job-row-job-northgate')), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-open-job-job-northgate')));
      await tester.pumpAndSettle();
      expect(app.isJobOpen, isTrue);
      expect(app.activeJob.id, 'job-northgate');

      // The sidebar tree lists only this job's structures.
      expect(find.byKey(const Key('tree-CB-2')), findsOneWidget);
      expect(find.byKey(const Key('tree-MH-1')), findsNothing);

      await tester.tap(find.byKey(const Key('tree-CB-2')));
      await tester.pumpAndSettle();
      expect(app.design.structureMark, 'CB-2');
      expect(find.byKey(const Key('field-structure-mark')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('closing a job returns to the browser', (tester) async {
      final app = AppState();
      await pumpAt(tester, const Size(1600, 1100), app);

      await tester.tap(find.byKey(const Key('btn-close-job')));
      await tester.pumpAndSettle();
      expect(app.isJobOpen, isFalse);
      expect(find.byType(JobsPage), findsOneWidget);
      expect(find.byKey(const Key('nav-phase1')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('job overview lists A-Z and flow order for the open job', (tester) async {
      final app = AppState();
      app.openJob('job-riverbend');
      await pumpAt(tester, const Size(1600, 1100), app);
      await openModule(tester, Module.jobs);

      expect(find.byType(JobOverviewPage), findsOneWidget);
      expect(find.byKey(const Key('alpha-MH-1')), findsOneWidget);
      expect(find.byKey(const Key('alpha-CB-1')), findsNothing);

      await tester.tap(find.byKey(const Key('flow-MH-3')).first);
      await tester.pumpAndSettle();
      expect(app.design.structureMark, 'MH-3');
      expect(tester.takeException(), isNull);
    });

    testWidgets('calendar drafts a backlog structure into tomorrow', (tester) async {
      final app = AppState();
      await pumpAt(tester, const Size(1600, 1100), app);
      await openModule(tester, Module.calendar);

      expect(find.byType(CalendarPage), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn-cal-tomorrow')));
      await tester.pumpAndSettle();

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final day = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      final target = app
          .unpouredBacklog(jobId: app.activeJob.id)
          .firstWhere((r) => r.pourDate != day);

      await tester.ensureVisible(find.byKey(Key('draft-${target.mark}')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('draft-${target.mark}')).first);
      await tester.pumpAndSettle();

      expect(target.pourDate, day);
      expect(app.castingLineFor(day), contains(target));
      expect(tester.takeException(), isNull);
    });

    testWidgets('jobs and calendar stay clean at iPhone width', (tester) async {
      await pumpAt(tester, const Size(390, 844), AppState(), openJob: false);
      expect(find.byType(JobsPage), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('btn-open-job-job-riverbend')));
      await tester.pumpAndSettle();
      await openModule(tester, Module.jobs, wide: false);
      expect(find.byType(JobOverviewPage), findsOneWidget);
      expect(tester.takeException(), isNull);

      await openModule(tester, Module.calendar, wide: false);
      expect(find.byType(CalendarPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
