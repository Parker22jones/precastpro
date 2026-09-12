/// Phase 1 job/spec identity of a structure.
enum StructureType { sanitaryManhole, stormManhole, catchBasin, junctionBox, wetWell }

extension StructureTypeLabel on StructureType {
  String get label => switch (this) {
        StructureType.sanitaryManhole => 'Sanitary Manhole',
        StructureType.stormManhole => 'Storm Manhole',
        StructureType.catchBasin => 'Catch Basin',
        StructureType.junctionBox => 'Junction Box',
        StructureType.wetWell => 'Wet Well',
      };
}

/// Boot / pipe connector styles offered on the production sheet.
enum BootType { aLok, pressSeal, korNSeal, castInPlace, groutedIn }

extension BootTypeLabel on BootType {
  String get label => switch (this) {
        BootType.aLok => 'A-Lok',
        BootType.pressSeal => 'Press-Seal',
        BootType.korNSeal => 'Kor-N-Seal',
        BootType.castInPlace => 'Cast-In-Place',
        BootType.groutedIn => 'Grouted In',
      };

  /// Stock SKU consumed when the structure ships.
  String get sku => switch (this) {
        BootType.aLok => 'BOOT-ALOK',
        BootType.pressSeal => 'BOOT-PSX',
        BootType.korNSeal => 'BOOT-KOR',
        BootType.castInPlace => 'BOOT-CIP',
        BootType.groutedIn => 'BOOT-GROUT',
      };
}

/// Pipe materials available in the pipe schedule grid.
enum PipeMaterial { pvc, rcp, dip, hdpe, cmp }

extension PipeMaterialLabel on PipeMaterial {
  String get label => switch (this) {
        PipeMaterial.pvc => 'PVC',
        PipeMaterial.rcp => 'RCP',
        PipeMaterial.dip => 'DIP',
        PipeMaterial.hdpe => 'HDPE',
        PipeMaterial.cmp => 'CMP',
      };
}
