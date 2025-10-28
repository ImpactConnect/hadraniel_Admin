import 'dart:async';
import 'dart:collection';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

/// Smart caching service with LRU eviction, TTL, and intelligent prefetching
class SmartCacheService {
  static final SmartCacheService _instance = SmartCacheService._internal();
  factory SmartCacheService() => _instance;
  SmartCacheService._internal();

  // Cache storage with LRU eviction
  final Map<String, _CacheEntry> _cache = LinkedHashMap();

  // Cache configuration
  static const int DEFAULT_MAX_SIZE = 1000;
  static const Duration DEFAULT_TTL = Duration(minutes: 30);
  static const Duration PREFETCH_INTERVAL = Duration(minutes: 5);

  // Cache statistics
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  // Prefetch timer
  Timer? _prefetchTimer;

  // Cache configuration
  int _maxSize = DEFAULT_MAX_SIZE;
  Duration _defaultTtl = DEFAULT_TTL;

  /// Initialize cache service
  void initialize({
    int maxSize = DEFAULT_MAX_SIZE,
    Duration defaultTtl = DEFAULT_TTL,
    bool enablePrefetch = true,
  }) {
    _maxSize = maxSize;
    _defaultTtl = defaultTtl;

    if (enablePrefetch) {
      _startPrefetchTimer();
    }

    print(
        'Smart cache initialized: maxSize=$maxSize, ttl=${defaultTtl.inMinutes}min');
  }

  /// Get value from cache or fetch from database
  Future<T?> get<T>(
    String key,
    Future<T?> Function() fetcher, {
    Duration? ttl,
    bool useCache = true,
  }) async {
    if (!useCache) {
      return await fetcher();
    }

    // Check cache first
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      _hits++;
      // Move to end (LRU)
      _cache.remove(key);
      _cache[key] = entry;
      return entry.value as T?;
    }

    // Cache miss - fetch from database
    _misses++;
    final value = await fetcher();

    if (value != null) {
      await _put(key, value, ttl ?? _defaultTtl);
    }

    return value;
  }

  /// Put value in cache
  Future<void> _put(String key, dynamic value, Duration ttl) async {
    // Remove existing entry
    _cache.remove(key);

    // Add new entry
    _cache[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );

    // Evict if necessary
    await _evictIfNecessary();
  }

  /// Manually put value in cache
  Future<void> put(String key, dynamic value, {Duration? ttl}) async {
    await _put(key, value, ttl ?? _defaultTtl);
  }

  /// Remove value from cache
  void remove(String key) {
    _cache.remove(key);
  }

  /// Clear entire cache
  void clear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    print('Cache cleared');
  }

  /// Evict expired and excess entries
  Future<void> _evictIfNecessary() async {
    // Remove expired entries
    final now = DateTime.now();
    _cache.removeWhere((key, entry) {
      if (entry.isExpired) {
        _evictions++;
        return true;
      }
      return false;
    });

    // Remove oldest entries if over size limit (LRU)
    while (_cache.length > _maxSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
      _evictions++;
    }
  }

  /// Get cached products with intelligent fetching
  Future<List<Map<String, dynamic>>> getProducts({
    String? categoryId,
    bool syncedOnly = false,
    int limit = 100,
  }) async {
    final cacheKey = 'products_${categoryId ?? 'all'}_${syncedOnly}_$limit';

    return await get<List<Map<String, dynamic>>>(
          cacheKey,
          () async {
            final db = await DatabaseHelper().database;

            String whereClause = '';
            List<dynamic> whereArgs = [];

            if (categoryId != null || syncedOnly) {
              final conditions = <String>[];

              if (categoryId != null) {
                conditions.add('category_id = ?');
                whereArgs.add(categoryId);
              }

              if (syncedOnly) {
                conditions.add('is_synced = 1');
              }

              whereClause = 'WHERE ${conditions.join(' AND ')}';
            }

            final result = await db.rawQuery('''
          SELECT id, name, price, stock_quantity, category_id, is_synced
          FROM products 
          $whereClause
          ORDER BY name
          LIMIT $limit
        ''', whereArgs);

            return result;
          },
          ttl: Duration(minutes: 15), // Products change less frequently
        ) ??
        [];
  }

  /// Get cached product by ID
  Future<Map<String, dynamic>?> getProduct(String productId) async {
    return await get<Map<String, dynamic>>(
      'product_$productId',
      () async {
        final db = await DatabaseHelper().database;
        final result = await db.query(
          'products',
          where: 'id = ?',
          whereArgs: [productId],
        );
        return result.isNotEmpty ? result.first : null;
      },
      ttl: Duration(minutes: 30),
    );
  }

  /// Get cached customers with search support
  Future<List<Map<String, dynamic>>> getCustomers({
    String? searchTerm,
    String? outletId,
    int limit = 50,
  }) async {
    final cacheKey =
        'customers_${searchTerm ?? 'all'}_${outletId ?? 'all'}_$limit';

    return await get<List<Map<String, dynamic>>>(
          cacheKey,
          () async {
            final db = await DatabaseHelper().database;

            String whereClause = '';
            List<dynamic> whereArgs = [];

            if (searchTerm != null || outletId != null) {
              final conditions = <String>[];

              if (searchTerm != null) {
                conditions.add('(name LIKE ? OR phone LIKE ?)');
                whereArgs.addAll(['%$searchTerm%', '%$searchTerm%']);
              }

              if (outletId != null) {
                conditions.add('outlet_id = ?');
                whereArgs.add(outletId);
              }

              whereClause = 'WHERE ${conditions.join(' AND ')}';
            }

            final result = await db.rawQuery('''
          SELECT id, name, phone, outlet_id, is_synced
          FROM customers 
          $whereClause
          ORDER BY name
          LIMIT $limit
        ''', whereArgs);

            return result;
          },
          ttl: Duration(minutes: 20),
        ) ??
        [];
  }

  /// Get cached sales with date range
  Future<List<Map<String, dynamic>>> getSales({
    DateTime? startDate,
    DateTime? endDate,
    String? customerId,
    int limit = 100,
  }) async {
    final startStr = startDate?.toIso8601String() ?? 'null';
    final endStr = endDate?.toIso8601String() ?? 'null';
    final cacheKey =
        'sales_${startStr}_${endStr}_${customerId ?? 'all'}_$limit';

    return await get<List<Map<String, dynamic>>>(
          cacheKey,
          () async {
            final db = await DatabaseHelper().database;

            String whereClause = '';
            List<dynamic> whereArgs = [];

            final conditions = <String>[];

            if (startDate != null) {
              conditions.add('created_at >= ?');
              whereArgs.add(startDate.toIso8601String());
            }

            if (endDate != null) {
              conditions.add('created_at <= ?');
              whereArgs.add(endDate.toIso8601String());
            }

            if (customerId != null) {
              conditions.add('customer_id = ?');
              whereArgs.add(customerId);
            }

            if (conditions.isNotEmpty) {
              whereClause = 'WHERE ${conditions.join(' AND ')}';
            }

            final result = await db.rawQuery('''
          SELECT s.*, c.name as customer_name
          FROM sales s
          LEFT JOIN customers c ON s.customer_id = c.id
          $whereClause
          ORDER BY s.created_at DESC
          LIMIT $limit
        ''', whereArgs);

            return result;
          },
          ttl: Duration(minutes: 10), // Sales data changes more frequently
        ) ??
        [];
  }

  /// Get cached sale items for a sale
  Future<List<Map<String, dynamic>>> getSaleItems(String saleId) async {
    return await get<List<Map<String, dynamic>>>(
          'sale_items_$saleId',
          () async {
            final db = await DatabaseHelper().database;
            final result = await db.rawQuery('''
          SELECT si.*, p.name as product_name, p.price as unit_price
          FROM sale_items si
          JOIN products p ON si.product_id = p.id
          WHERE si.sale_id = ?
          ORDER BY si.created_at
        ''', [saleId]);

            return result;
          },
          ttl: Duration(hours: 1), // Sale items rarely change once created
        ) ??
        [];
  }

  /// Get cached stock balances
  Future<List<Map<String, dynamic>>> getStockBalances({
    String? productId,
    String? outletId,
    int limit = 100,
  }) async {
    final cacheKey =
        'stock_balances_${productId ?? 'all'}_${outletId ?? 'all'}_$limit';

    return await get<List<Map<String, dynamic>>>(
          cacheKey,
          () async {
            final db = await DatabaseHelper().database;

            String whereClause = '';
            List<dynamic> whereArgs = [];

            if (productId != null || outletId != null) {
              final conditions = <String>[];

              if (productId != null) {
                conditions.add('product_id = ?');
                whereArgs.add(productId);
              }

              if (outletId != null) {
                conditions.add('outlet_id = ?');
                whereArgs.add(outletId);
              }

              whereClause = 'WHERE ${conditions.join(' AND ')}';
            }

            final result = await db.rawQuery('''
          SELECT sb.*, p.name as product_name, o.name as outlet_name
          FROM stock_balances sb
          LEFT JOIN products p ON sb.product_id = p.id
          LEFT JOIN outlets o ON sb.outlet_id = o.id
          $whereClause
          ORDER BY sb.updated_at DESC
          LIMIT $limit
        ''', whereArgs);

            return result;
          },
          ttl: Duration(minutes: 5), // Stock changes frequently
        ) ??
        [];
  }

  /// Invalidate cache entries by pattern
  void invalidatePattern(String pattern) {
    final keysToRemove = <String>[];

    for (var key in _cache.keys) {
      if (key.contains(pattern)) {
        keysToRemove.add(key);
      }
    }

    for (var key in keysToRemove) {
      _cache.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      print(
          'Invalidated ${keysToRemove.length} cache entries matching pattern: $pattern');
    }
  }

  /// Invalidate cache when data changes
  void invalidateOnDataChange(String tableName, String? recordId) {
    switch (tableName.toLowerCase()) {
      case 'products':
        invalidatePattern('products_');
        if (recordId != null) {
          remove('product_$recordId');
        }
        break;
      case 'customers':
        invalidatePattern('customers_');
        break;
      case 'sales':
        invalidatePattern('sales_');
        break;
      case 'sale_items':
        invalidatePattern('sale_items_');
        break;
      case 'stock_balances':
        invalidatePattern('stock_balances_');
        break;
    }
  }

  /// Start prefetch timer for commonly accessed data
  void _startPrefetchTimer() {
    _prefetchTimer?.cancel();
    _prefetchTimer = Timer.periodic(PREFETCH_INTERVAL, (_) {
      _prefetchCommonData();
    });
  }

  /// Prefetch commonly accessed data
  Future<void> _prefetchCommonData() async {
    try {
      print('Prefetching common data...');

      // Prefetch recent products
      await getProducts(limit: 50);

      // Prefetch recent customers
      await getCustomers(limit: 30);

      // Prefetch today's sales
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      await getSales(
        startDate: startOfDay,
        endDate: today,
        limit: 50,
      );

      print('Prefetch completed');
    } catch (e) {
      print('Prefetch failed: $e');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final totalRequests = _hits + _misses;
    final hitRate = totalRequests > 0 ? (_hits / totalRequests * 100) : 0;

    return {
      'size': _cache.length,
      'max_size': _maxSize,
      'hits': _hits,
      'misses': _misses,
      'evictions': _evictions,
      'hit_rate_percent': hitRate.toStringAsFixed(2),
      'total_requests': totalRequests,
      'memory_usage_estimate_kb': _cache.length * 2, // Rough estimate
    };
  }

  /// Warm up cache with essential data
  Future<void> warmUp() async {
    print('Warming up cache...');

    try {
      // Load essential data
      await Future.wait([
        getProducts(limit: 100),
        getCustomers(limit: 50),
        getStockBalances(limit: 50),
      ]);

      print('Cache warm-up completed');
    } catch (e) {
      print('Cache warm-up failed: $e');
    }
  }

  /// Dispose cache service
  void dispose() {
    _prefetchTimer?.cancel();
    _cache.clear();
    print('Smart cache service disposed');
  }
}

/// Cache entry with expiration
class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;

  _CacheEntry({
    required this.value,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Cache-aware database operations mixin
mixin CacheAwareDatabaseOperations {
  final SmartCacheService _cache = SmartCacheService();

  /// Insert with cache invalidation
  Future<int> insertWithCache(
    Database db,
    String table,
    Map<String, dynamic> values,
  ) async {
    final result = await db.insert(table, values);
    _cache.invalidateOnDataChange(table, values['id']?.toString());
    return result;
  }

  /// Update with cache invalidation
  Future<int> updateWithCache(
    Database db,
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final result =
        await db.update(table, values, where: where, whereArgs: whereArgs);
    _cache.invalidateOnDataChange(table, values['id']?.toString());
    return result;
  }

  /// Delete with cache invalidation
  Future<int> deleteWithCache(
    Database db,
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final result = await db.delete(table, where: where, whereArgs: whereArgs);
    _cache.invalidateOnDataChange(table, null);
    return result;
  }
}
