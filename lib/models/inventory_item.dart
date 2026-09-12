/// Category buckets shown on the inventory page.
enum StockCategory { casting, concrete, accessory }

extension StockCategoryLabel on StockCategory {
  String get label => switch (this) {
    StockCategory.casting => 'Castings',
    StockCategory.concrete => 'Concrete Stock',
    StockCategory.accessory => 'Accessories',
  };
}

/// A raw stock item or casting held in the yard.
class InventoryItem {
  InventoryItem({
    required this.sku,
    required this.description,
    required this.category,
    required this.onHand,
    required this.minThreshold,
  });

  final String sku;
  final String description;
  final StockCategory category;
  int onHand;
  int minThreshold;

  bool get isLowStock => onHand <= minThreshold;
  int get shortfall => isLowStock ? minThreshold - onHand + 1 : 0;
}

/// Opening stock for a fresh yard.
List<InventoryItem> defaultInventory() => [
  InventoryItem(
    sku: 'RING-24',
    description: '24" Iron Grade Ring',
    category: StockCategory.casting,
    onHand: 40,
    minThreshold: 10,
  ),
  InventoryItem(
    sku: 'LID-24',
    description: '24" Iron Frame & Lid',
    category: StockCategory.casting,
    onHand: 24,
    minThreshold: 8,
  ),
  InventoryItem(
    sku: 'STEP-MA',
    description: 'Polypropylene Manhole Step',
    category: StockCategory.accessory,
    onHand: 180,
    minThreshold: 60,
  ),
  InventoryItem(
    sku: 'BOOT-ALOK',
    description: 'A-Lok Pipe Boot',
    category: StockCategory.accessory,
    onHand: 30,
    minThreshold: 12,
  ),
  InventoryItem(
    sku: 'BOOT-PSX',
    description: 'Press-Seal PSX Boot',
    category: StockCategory.accessory,
    onHand: 22,
    minThreshold: 10,
  ),
  InventoryItem(
    sku: 'BOOT-KOR',
    description: 'Kor-N-Seal Boot',
    category: StockCategory.accessory,
    onHand: 16,
    minThreshold: 8,
  ),
  InventoryItem(
    sku: 'BOOT-CIP',
    description: 'Cast-In-Place Sleeve',
    category: StockCategory.accessory,
    onHand: 18,
    minThreshold: 6,
  ),
  InventoryItem(
    sku: 'BOOT-GROUT',
    description: 'Non-Shrink Grout Kit',
    category: StockCategory.accessory,
    onHand: 25,
    minThreshold: 8,
  ),
  InventoryItem(
    sku: 'B48',
    description: '48" Base Section (8" floor)',
    category: StockCategory.concrete,
    onHand: 6,
    minThreshold: 2,
  ),
  InventoryItem(
    sku: 'B60',
    description: '60" Base Section (8" floor)',
    category: StockCategory.concrete,
    onHand: 4,
    minThreshold: 2,
  ),
  InventoryItem(
    sku: 'R48',
    description: '48" Risers (all heights)',
    category: StockCategory.concrete,
    onHand: 20,
    minThreshold: 6,
  ),
  InventoryItem(
    sku: 'R60',
    description: '60" Risers (all heights)',
    category: StockCategory.concrete,
    onHand: 12,
    minThreshold: 4,
  ),
  InventoryItem(
    sku: 'FT48',
    description: '48" Flat Top Slab',
    category: StockCategory.concrete,
    onHand: 5,
    minThreshold: 2,
  ),
  InventoryItem(
    sku: 'FT60',
    description: '60" Flat Top Slab',
    category: StockCategory.concrete,
    onHand: 4,
    minThreshold: 2,
  ),
  InventoryItem(
    sku: 'CT48',
    description: '48" Conical Top',
    category: StockCategory.concrete,
    onHand: 7,
    minThreshold: 2,
  ),
  InventoryItem(
    sku: 'CT60',
    description: '60" Conical Top',
    category: StockCategory.concrete,
    onHand: 3,
    minThreshold: 2,
  ),
  InventoryItem(
    sku: 'GR',
    description: 'Concrete Grade Rings (all heights)',
    category: StockCategory.concrete,
    onHand: 30,
    minThreshold: 10,
  ),
];
