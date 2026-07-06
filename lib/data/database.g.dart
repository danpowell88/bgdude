// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CgmReadingsTable extends CgmReadings
    with TableInfo<$CgmReadingsTable, CgmRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CgmReadingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<DateTime> time = GeneratedColumn<DateTime>(
      'time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _mgdlMeta = const VerificationMeta('mgdl');
  @override
  late final GeneratedColumn<double> mgdl = GeneratedColumn<double>(
      'mgdl', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _trendMeta = const VerificationMeta('trend');
  @override
  late final GeneratedColumn<int> trend = GeneratedColumn<int>(
      'trend', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(7));
  static const VerificationMeta _sensorWarmupMeta =
      const VerificationMeta('sensorWarmup');
  @override
  late final GeneratedColumn<bool> sensorWarmup = GeneratedColumn<bool>(
      'sensor_warmup', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("sensor_warmup" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _compressionLowMeta =
      const VerificationMeta('compressionLow');
  @override
  late final GeneratedColumn<bool> compressionLow = GeneratedColumn<bool>(
      'compression_low', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("compression_low" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isCalibrationMeta =
      const VerificationMeta('isCalibration');
  @override
  late final GeneratedColumn<bool> isCalibration = GeneratedColumn<bool>(
      'is_calibration', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_calibration" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('sensor'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        time,
        mgdl,
        trend,
        sensorWarmup,
        compressionLow,
        isCalibration,
        source
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cgm_readings';
  @override
  VerificationContext validateIntegrity(Insertable<CgmRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('mgdl')) {
      context.handle(
          _mgdlMeta, mgdl.isAcceptableOrUnknown(data['mgdl']!, _mgdlMeta));
    } else if (isInserting) {
      context.missing(_mgdlMeta);
    }
    if (data.containsKey('trend')) {
      context.handle(
          _trendMeta, trend.isAcceptableOrUnknown(data['trend']!, _trendMeta));
    }
    if (data.containsKey('sensor_warmup')) {
      context.handle(
          _sensorWarmupMeta,
          sensorWarmup.isAcceptableOrUnknown(
              data['sensor_warmup']!, _sensorWarmupMeta));
    }
    if (data.containsKey('compression_low')) {
      context.handle(
          _compressionLowMeta,
          compressionLow.isAcceptableOrUnknown(
              data['compression_low']!, _compressionLowMeta));
    }
    if (data.containsKey('is_calibration')) {
      context.handle(
          _isCalibrationMeta,
          isCalibration.isAcceptableOrUnknown(
              data['is_calibration']!, _isCalibrationMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {time},
      ];
  @override
  CgmRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CgmRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}time'])!,
      mgdl: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}mgdl'])!,
      trend: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trend'])!,
      sensorWarmup: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}sensor_warmup'])!,
      compressionLow: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}compression_low'])!,
      isCalibration: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_calibration'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
    );
  }

  @override
  $CgmReadingsTable createAlias(String alias) {
    return $CgmReadingsTable(attachedDatabase, alias);
  }
}

class CgmRow extends DataClass implements Insertable<CgmRow> {
  final int id;
  final DateTime time;
  final double mgdl;
  final int trend;
  final bool sensorWarmup;
  final bool compressionLow;

  /// A calibration finger-prick (excluded from metrics/training) — schema v3 (TASK-9).
  final bool isCalibration;

  /// 'sensor' | 'meter'. Sensor rows own their time slot; meter rows never overwrite them.
  final String source;
  const CgmRow(
      {required this.id,
      required this.time,
      required this.mgdl,
      required this.trend,
      required this.sensorWarmup,
      required this.compressionLow,
      required this.isCalibration,
      required this.source});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['time'] = Variable<DateTime>(time);
    map['mgdl'] = Variable<double>(mgdl);
    map['trend'] = Variable<int>(trend);
    map['sensor_warmup'] = Variable<bool>(sensorWarmup);
    map['compression_low'] = Variable<bool>(compressionLow);
    map['is_calibration'] = Variable<bool>(isCalibration);
    map['source'] = Variable<String>(source);
    return map;
  }

  CgmReadingsCompanion toCompanion(bool nullToAbsent) {
    return CgmReadingsCompanion(
      id: Value(id),
      time: Value(time),
      mgdl: Value(mgdl),
      trend: Value(trend),
      sensorWarmup: Value(sensorWarmup),
      compressionLow: Value(compressionLow),
      isCalibration: Value(isCalibration),
      source: Value(source),
    );
  }

  factory CgmRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CgmRow(
      id: serializer.fromJson<int>(json['id']),
      time: serializer.fromJson<DateTime>(json['time']),
      mgdl: serializer.fromJson<double>(json['mgdl']),
      trend: serializer.fromJson<int>(json['trend']),
      sensorWarmup: serializer.fromJson<bool>(json['sensorWarmup']),
      compressionLow: serializer.fromJson<bool>(json['compressionLow']),
      isCalibration: serializer.fromJson<bool>(json['isCalibration']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'time': serializer.toJson<DateTime>(time),
      'mgdl': serializer.toJson<double>(mgdl),
      'trend': serializer.toJson<int>(trend),
      'sensorWarmup': serializer.toJson<bool>(sensorWarmup),
      'compressionLow': serializer.toJson<bool>(compressionLow),
      'isCalibration': serializer.toJson<bool>(isCalibration),
      'source': serializer.toJson<String>(source),
    };
  }

  CgmRow copyWith(
          {int? id,
          DateTime? time,
          double? mgdl,
          int? trend,
          bool? sensorWarmup,
          bool? compressionLow,
          bool? isCalibration,
          String? source}) =>
      CgmRow(
        id: id ?? this.id,
        time: time ?? this.time,
        mgdl: mgdl ?? this.mgdl,
        trend: trend ?? this.trend,
        sensorWarmup: sensorWarmup ?? this.sensorWarmup,
        compressionLow: compressionLow ?? this.compressionLow,
        isCalibration: isCalibration ?? this.isCalibration,
        source: source ?? this.source,
      );
  CgmRow copyWithCompanion(CgmReadingsCompanion data) {
    return CgmRow(
      id: data.id.present ? data.id.value : this.id,
      time: data.time.present ? data.time.value : this.time,
      mgdl: data.mgdl.present ? data.mgdl.value : this.mgdl,
      trend: data.trend.present ? data.trend.value : this.trend,
      sensorWarmup: data.sensorWarmup.present
          ? data.sensorWarmup.value
          : this.sensorWarmup,
      compressionLow: data.compressionLow.present
          ? data.compressionLow.value
          : this.compressionLow,
      isCalibration: data.isCalibration.present
          ? data.isCalibration.value
          : this.isCalibration,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CgmRow(')
          ..write('id: $id, ')
          ..write('time: $time, ')
          ..write('mgdl: $mgdl, ')
          ..write('trend: $trend, ')
          ..write('sensorWarmup: $sensorWarmup, ')
          ..write('compressionLow: $compressionLow, ')
          ..write('isCalibration: $isCalibration, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, time, mgdl, trend, sensorWarmup,
      compressionLow, isCalibration, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CgmRow &&
          other.id == this.id &&
          other.time == this.time &&
          other.mgdl == this.mgdl &&
          other.trend == this.trend &&
          other.sensorWarmup == this.sensorWarmup &&
          other.compressionLow == this.compressionLow &&
          other.isCalibration == this.isCalibration &&
          other.source == this.source);
}

class CgmReadingsCompanion extends UpdateCompanion<CgmRow> {
  final Value<int> id;
  final Value<DateTime> time;
  final Value<double> mgdl;
  final Value<int> trend;
  final Value<bool> sensorWarmup;
  final Value<bool> compressionLow;
  final Value<bool> isCalibration;
  final Value<String> source;
  const CgmReadingsCompanion({
    this.id = const Value.absent(),
    this.time = const Value.absent(),
    this.mgdl = const Value.absent(),
    this.trend = const Value.absent(),
    this.sensorWarmup = const Value.absent(),
    this.compressionLow = const Value.absent(),
    this.isCalibration = const Value.absent(),
    this.source = const Value.absent(),
  });
  CgmReadingsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime time,
    required double mgdl,
    this.trend = const Value.absent(),
    this.sensorWarmup = const Value.absent(),
    this.compressionLow = const Value.absent(),
    this.isCalibration = const Value.absent(),
    this.source = const Value.absent(),
  })  : time = Value(time),
        mgdl = Value(mgdl);
  static Insertable<CgmRow> custom({
    Expression<int>? id,
    Expression<DateTime>? time,
    Expression<double>? mgdl,
    Expression<int>? trend,
    Expression<bool>? sensorWarmup,
    Expression<bool>? compressionLow,
    Expression<bool>? isCalibration,
    Expression<String>? source,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (time != null) 'time': time,
      if (mgdl != null) 'mgdl': mgdl,
      if (trend != null) 'trend': trend,
      if (sensorWarmup != null) 'sensor_warmup': sensorWarmup,
      if (compressionLow != null) 'compression_low': compressionLow,
      if (isCalibration != null) 'is_calibration': isCalibration,
      if (source != null) 'source': source,
    });
  }

  CgmReadingsCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? time,
      Value<double>? mgdl,
      Value<int>? trend,
      Value<bool>? sensorWarmup,
      Value<bool>? compressionLow,
      Value<bool>? isCalibration,
      Value<String>? source}) {
    return CgmReadingsCompanion(
      id: id ?? this.id,
      time: time ?? this.time,
      mgdl: mgdl ?? this.mgdl,
      trend: trend ?? this.trend,
      sensorWarmup: sensorWarmup ?? this.sensorWarmup,
      compressionLow: compressionLow ?? this.compressionLow,
      isCalibration: isCalibration ?? this.isCalibration,
      source: source ?? this.source,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (time.present) {
      map['time'] = Variable<DateTime>(time.value);
    }
    if (mgdl.present) {
      map['mgdl'] = Variable<double>(mgdl.value);
    }
    if (trend.present) {
      map['trend'] = Variable<int>(trend.value);
    }
    if (sensorWarmup.present) {
      map['sensor_warmup'] = Variable<bool>(sensorWarmup.value);
    }
    if (compressionLow.present) {
      map['compression_low'] = Variable<bool>(compressionLow.value);
    }
    if (isCalibration.present) {
      map['is_calibration'] = Variable<bool>(isCalibration.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CgmReadingsCompanion(')
          ..write('id: $id, ')
          ..write('time: $time, ')
          ..write('mgdl: $mgdl, ')
          ..write('trend: $trend, ')
          ..write('sensorWarmup: $sensorWarmup, ')
          ..write('compressionLow: $compressionLow, ')
          ..write('isCalibration: $isCalibration, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }
}

class $BolusEventsTable extends BolusEvents
    with TableInfo<$BolusEventsTable, BolusRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BolusEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<DateTime> time = GeneratedColumn<DateTime>(
      'time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _unitsMeta = const VerificationMeta('units');
  @override
  late final GeneratedColumn<double> units = GeneratedColumn<double>(
      'units', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _carbsGramsMeta =
      const VerificationMeta('carbsGrams');
  @override
  late final GeneratedColumn<double> carbsGrams = GeneratedColumn<double>(
      'carbs_grams', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isExtendedMeta =
      const VerificationMeta('isExtended');
  @override
  late final GeneratedColumn<bool> isExtended = GeneratedColumn<bool>(
      'is_extended', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_extended" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _durationMinutesMeta =
      const VerificationMeta('durationMinutes');
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
      'duration_minutes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isAutomaticMeta =
      const VerificationMeta('isAutomatic');
  @override
  late final GeneratedColumn<bool> isAutomatic = GeneratedColumn<bool>(
      'is_automatic', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_automatic" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, time, units, carbsGrams, isExtended, durationMinutes, isAutomatic];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bolus_events';
  @override
  VerificationContext validateIntegrity(Insertable<BolusRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('units')) {
      context.handle(
          _unitsMeta, units.isAcceptableOrUnknown(data['units']!, _unitsMeta));
    } else if (isInserting) {
      context.missing(_unitsMeta);
    }
    if (data.containsKey('carbs_grams')) {
      context.handle(
          _carbsGramsMeta,
          carbsGrams.isAcceptableOrUnknown(
              data['carbs_grams']!, _carbsGramsMeta));
    }
    if (data.containsKey('is_extended')) {
      context.handle(
          _isExtendedMeta,
          isExtended.isAcceptableOrUnknown(
              data['is_extended']!, _isExtendedMeta));
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
          _durationMinutesMeta,
          durationMinutes.isAcceptableOrUnknown(
              data['duration_minutes']!, _durationMinutesMeta));
    }
    if (data.containsKey('is_automatic')) {
      context.handle(
          _isAutomaticMeta,
          isAutomatic.isAcceptableOrUnknown(
              data['is_automatic']!, _isAutomaticMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BolusRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BolusRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}time'])!,
      units: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}units'])!,
      carbsGrams: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}carbs_grams'])!,
      isExtended: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_extended'])!,
      durationMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_minutes'])!,
      isAutomatic: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_automatic'])!,
    );
  }

  @override
  $BolusEventsTable createAlias(String alias) {
    return $BolusEventsTable(attachedDatabase, alias);
  }
}

class BolusRow extends DataClass implements Insertable<BolusRow> {
  final int id;
  final DateTime time;
  final double units;
  final double carbsGrams;
  final bool isExtended;
  final int durationMinutes;
  final bool isAutomatic;
  const BolusRow(
      {required this.id,
      required this.time,
      required this.units,
      required this.carbsGrams,
      required this.isExtended,
      required this.durationMinutes,
      required this.isAutomatic});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['time'] = Variable<DateTime>(time);
    map['units'] = Variable<double>(units);
    map['carbs_grams'] = Variable<double>(carbsGrams);
    map['is_extended'] = Variable<bool>(isExtended);
    map['duration_minutes'] = Variable<int>(durationMinutes);
    map['is_automatic'] = Variable<bool>(isAutomatic);
    return map;
  }

  BolusEventsCompanion toCompanion(bool nullToAbsent) {
    return BolusEventsCompanion(
      id: Value(id),
      time: Value(time),
      units: Value(units),
      carbsGrams: Value(carbsGrams),
      isExtended: Value(isExtended),
      durationMinutes: Value(durationMinutes),
      isAutomatic: Value(isAutomatic),
    );
  }

  factory BolusRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BolusRow(
      id: serializer.fromJson<int>(json['id']),
      time: serializer.fromJson<DateTime>(json['time']),
      units: serializer.fromJson<double>(json['units']),
      carbsGrams: serializer.fromJson<double>(json['carbsGrams']),
      isExtended: serializer.fromJson<bool>(json['isExtended']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
      isAutomatic: serializer.fromJson<bool>(json['isAutomatic']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'time': serializer.toJson<DateTime>(time),
      'units': serializer.toJson<double>(units),
      'carbsGrams': serializer.toJson<double>(carbsGrams),
      'isExtended': serializer.toJson<bool>(isExtended),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
      'isAutomatic': serializer.toJson<bool>(isAutomatic),
    };
  }

  BolusRow copyWith(
          {int? id,
          DateTime? time,
          double? units,
          double? carbsGrams,
          bool? isExtended,
          int? durationMinutes,
          bool? isAutomatic}) =>
      BolusRow(
        id: id ?? this.id,
        time: time ?? this.time,
        units: units ?? this.units,
        carbsGrams: carbsGrams ?? this.carbsGrams,
        isExtended: isExtended ?? this.isExtended,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        isAutomatic: isAutomatic ?? this.isAutomatic,
      );
  BolusRow copyWithCompanion(BolusEventsCompanion data) {
    return BolusRow(
      id: data.id.present ? data.id.value : this.id,
      time: data.time.present ? data.time.value : this.time,
      units: data.units.present ? data.units.value : this.units,
      carbsGrams:
          data.carbsGrams.present ? data.carbsGrams.value : this.carbsGrams,
      isExtended:
          data.isExtended.present ? data.isExtended.value : this.isExtended,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      isAutomatic:
          data.isAutomatic.present ? data.isAutomatic.value : this.isAutomatic,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BolusRow(')
          ..write('id: $id, ')
          ..write('time: $time, ')
          ..write('units: $units, ')
          ..write('carbsGrams: $carbsGrams, ')
          ..write('isExtended: $isExtended, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('isAutomatic: $isAutomatic')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, time, units, carbsGrams, isExtended, durationMinutes, isAutomatic);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BolusRow &&
          other.id == this.id &&
          other.time == this.time &&
          other.units == this.units &&
          other.carbsGrams == this.carbsGrams &&
          other.isExtended == this.isExtended &&
          other.durationMinutes == this.durationMinutes &&
          other.isAutomatic == this.isAutomatic);
}

class BolusEventsCompanion extends UpdateCompanion<BolusRow> {
  final Value<int> id;
  final Value<DateTime> time;
  final Value<double> units;
  final Value<double> carbsGrams;
  final Value<bool> isExtended;
  final Value<int> durationMinutes;
  final Value<bool> isAutomatic;
  const BolusEventsCompanion({
    this.id = const Value.absent(),
    this.time = const Value.absent(),
    this.units = const Value.absent(),
    this.carbsGrams = const Value.absent(),
    this.isExtended = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.isAutomatic = const Value.absent(),
  });
  BolusEventsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime time,
    required double units,
    this.carbsGrams = const Value.absent(),
    this.isExtended = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.isAutomatic = const Value.absent(),
  })  : time = Value(time),
        units = Value(units);
  static Insertable<BolusRow> custom({
    Expression<int>? id,
    Expression<DateTime>? time,
    Expression<double>? units,
    Expression<double>? carbsGrams,
    Expression<bool>? isExtended,
    Expression<int>? durationMinutes,
    Expression<bool>? isAutomatic,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (time != null) 'time': time,
      if (units != null) 'units': units,
      if (carbsGrams != null) 'carbs_grams': carbsGrams,
      if (isExtended != null) 'is_extended': isExtended,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (isAutomatic != null) 'is_automatic': isAutomatic,
    });
  }

  BolusEventsCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? time,
      Value<double>? units,
      Value<double>? carbsGrams,
      Value<bool>? isExtended,
      Value<int>? durationMinutes,
      Value<bool>? isAutomatic}) {
    return BolusEventsCompanion(
      id: id ?? this.id,
      time: time ?? this.time,
      units: units ?? this.units,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      isExtended: isExtended ?? this.isExtended,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isAutomatic: isAutomatic ?? this.isAutomatic,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (time.present) {
      map['time'] = Variable<DateTime>(time.value);
    }
    if (units.present) {
      map['units'] = Variable<double>(units.value);
    }
    if (carbsGrams.present) {
      map['carbs_grams'] = Variable<double>(carbsGrams.value);
    }
    if (isExtended.present) {
      map['is_extended'] = Variable<bool>(isExtended.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (isAutomatic.present) {
      map['is_automatic'] = Variable<bool>(isAutomatic.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BolusEventsCompanion(')
          ..write('id: $id, ')
          ..write('time: $time, ')
          ..write('units: $units, ')
          ..write('carbsGrams: $carbsGrams, ')
          ..write('isExtended: $isExtended, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('isAutomatic: $isAutomatic')
          ..write(')'))
        .toString();
  }
}

class $BasalSegmentsTable extends BasalSegments
    with TableInfo<$BasalSegmentsTable, BasalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BasalSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _startMeta = const VerificationMeta('start');
  @override
  late final GeneratedColumn<DateTime> start = GeneratedColumn<DateTime>(
      'start', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endMeta = const VerificationMeta('end');
  @override
  late final GeneratedColumn<DateTime> end = GeneratedColumn<DateTime>(
      'end', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _unitsPerHourMeta =
      const VerificationMeta('unitsPerHour');
  @override
  late final GeneratedColumn<double> unitsPerHour = GeneratedColumn<double>(
      'units_per_hour', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, start, end, unitsPerHour];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'basal_segments';
  @override
  VerificationContext validateIntegrity(Insertable<BasalRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('start')) {
      context.handle(
          _startMeta, start.isAcceptableOrUnknown(data['start']!, _startMeta));
    } else if (isInserting) {
      context.missing(_startMeta);
    }
    if (data.containsKey('end')) {
      context.handle(
          _endMeta, end.isAcceptableOrUnknown(data['end']!, _endMeta));
    } else if (isInserting) {
      context.missing(_endMeta);
    }
    if (data.containsKey('units_per_hour')) {
      context.handle(
          _unitsPerHourMeta,
          unitsPerHour.isAcceptableOrUnknown(
              data['units_per_hour']!, _unitsPerHourMeta));
    } else if (isInserting) {
      context.missing(_unitsPerHourMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BasalRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BasalRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      start: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start'])!,
      end: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end'])!,
      unitsPerHour: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}units_per_hour'])!,
    );
  }

  @override
  $BasalSegmentsTable createAlias(String alias) {
    return $BasalSegmentsTable(attachedDatabase, alias);
  }
}

class BasalRow extends DataClass implements Insertable<BasalRow> {
  final int id;
  final DateTime start;
  final DateTime end;
  final double unitsPerHour;
  const BasalRow(
      {required this.id,
      required this.start,
      required this.end,
      required this.unitsPerHour});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['start'] = Variable<DateTime>(start);
    map['end'] = Variable<DateTime>(end);
    map['units_per_hour'] = Variable<double>(unitsPerHour);
    return map;
  }

  BasalSegmentsCompanion toCompanion(bool nullToAbsent) {
    return BasalSegmentsCompanion(
      id: Value(id),
      start: Value(start),
      end: Value(end),
      unitsPerHour: Value(unitsPerHour),
    );
  }

  factory BasalRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BasalRow(
      id: serializer.fromJson<int>(json['id']),
      start: serializer.fromJson<DateTime>(json['start']),
      end: serializer.fromJson<DateTime>(json['end']),
      unitsPerHour: serializer.fromJson<double>(json['unitsPerHour']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'start': serializer.toJson<DateTime>(start),
      'end': serializer.toJson<DateTime>(end),
      'unitsPerHour': serializer.toJson<double>(unitsPerHour),
    };
  }

  BasalRow copyWith(
          {int? id, DateTime? start, DateTime? end, double? unitsPerHour}) =>
      BasalRow(
        id: id ?? this.id,
        start: start ?? this.start,
        end: end ?? this.end,
        unitsPerHour: unitsPerHour ?? this.unitsPerHour,
      );
  BasalRow copyWithCompanion(BasalSegmentsCompanion data) {
    return BasalRow(
      id: data.id.present ? data.id.value : this.id,
      start: data.start.present ? data.start.value : this.start,
      end: data.end.present ? data.end.value : this.end,
      unitsPerHour: data.unitsPerHour.present
          ? data.unitsPerHour.value
          : this.unitsPerHour,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BasalRow(')
          ..write('id: $id, ')
          ..write('start: $start, ')
          ..write('end: $end, ')
          ..write('unitsPerHour: $unitsPerHour')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, start, end, unitsPerHour);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BasalRow &&
          other.id == this.id &&
          other.start == this.start &&
          other.end == this.end &&
          other.unitsPerHour == this.unitsPerHour);
}

class BasalSegmentsCompanion extends UpdateCompanion<BasalRow> {
  final Value<int> id;
  final Value<DateTime> start;
  final Value<DateTime> end;
  final Value<double> unitsPerHour;
  const BasalSegmentsCompanion({
    this.id = const Value.absent(),
    this.start = const Value.absent(),
    this.end = const Value.absent(),
    this.unitsPerHour = const Value.absent(),
  });
  BasalSegmentsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime start,
    required DateTime end,
    required double unitsPerHour,
  })  : start = Value(start),
        end = Value(end),
        unitsPerHour = Value(unitsPerHour);
  static Insertable<BasalRow> custom({
    Expression<int>? id,
    Expression<DateTime>? start,
    Expression<DateTime>? end,
    Expression<double>? unitsPerHour,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (start != null) 'start': start,
      if (end != null) 'end': end,
      if (unitsPerHour != null) 'units_per_hour': unitsPerHour,
    });
  }

  BasalSegmentsCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? start,
      Value<DateTime>? end,
      Value<double>? unitsPerHour}) {
    return BasalSegmentsCompanion(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      unitsPerHour: unitsPerHour ?? this.unitsPerHour,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (start.present) {
      map['start'] = Variable<DateTime>(start.value);
    }
    if (end.present) {
      map['end'] = Variable<DateTime>(end.value);
    }
    if (unitsPerHour.present) {
      map['units_per_hour'] = Variable<double>(unitsPerHour.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BasalSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('start: $start, ')
          ..write('end: $end, ')
          ..write('unitsPerHour: $unitsPerHour')
          ..write(')'))
        .toString();
  }
}

class $CarbEntriesTable extends CarbEntries
    with TableInfo<$CarbEntriesTable, CarbRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CarbEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<DateTime> time = GeneratedColumn<DateTime>(
      'time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _gramsMeta = const VerificationMeta('grams');
  @override
  late final GeneratedColumn<double> grams = GeneratedColumn<double>(
      'grams', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _absorptionMinutesMeta =
      const VerificationMeta('absorptionMinutes');
  @override
  late final GeneratedColumn<int> absorptionMinutes = GeneratedColumn<int>(
      'absorption_minutes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(180));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('user'));
  @override
  List<GeneratedColumn> get $columns =>
      [id, time, grams, absorptionMinutes, source];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'carb_entries';
  @override
  VerificationContext validateIntegrity(Insertable<CarbRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('grams')) {
      context.handle(
          _gramsMeta, grams.isAcceptableOrUnknown(data['grams']!, _gramsMeta));
    } else if (isInserting) {
      context.missing(_gramsMeta);
    }
    if (data.containsKey('absorption_minutes')) {
      context.handle(
          _absorptionMinutesMeta,
          absorptionMinutes.isAcceptableOrUnknown(
              data['absorption_minutes']!, _absorptionMinutesMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CarbRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CarbRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}time'])!,
      grams: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}grams'])!,
      absorptionMinutes: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}absorption_minutes'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
    );
  }

  @override
  $CarbEntriesTable createAlias(String alias) {
    return $CarbEntriesTable(attachedDatabase, alias);
  }
}

class CarbRow extends DataClass implements Insertable<CarbRow> {
  final int id;
  final DateTime time;
  final double grams;
  final int absorptionMinutes;
  final String source;
  const CarbRow(
      {required this.id,
      required this.time,
      required this.grams,
      required this.absorptionMinutes,
      required this.source});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['time'] = Variable<DateTime>(time);
    map['grams'] = Variable<double>(grams);
    map['absorption_minutes'] = Variable<int>(absorptionMinutes);
    map['source'] = Variable<String>(source);
    return map;
  }

  CarbEntriesCompanion toCompanion(bool nullToAbsent) {
    return CarbEntriesCompanion(
      id: Value(id),
      time: Value(time),
      grams: Value(grams),
      absorptionMinutes: Value(absorptionMinutes),
      source: Value(source),
    );
  }

  factory CarbRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CarbRow(
      id: serializer.fromJson<int>(json['id']),
      time: serializer.fromJson<DateTime>(json['time']),
      grams: serializer.fromJson<double>(json['grams']),
      absorptionMinutes: serializer.fromJson<int>(json['absorptionMinutes']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'time': serializer.toJson<DateTime>(time),
      'grams': serializer.toJson<double>(grams),
      'absorptionMinutes': serializer.toJson<int>(absorptionMinutes),
      'source': serializer.toJson<String>(source),
    };
  }

  CarbRow copyWith(
          {int? id,
          DateTime? time,
          double? grams,
          int? absorptionMinutes,
          String? source}) =>
      CarbRow(
        id: id ?? this.id,
        time: time ?? this.time,
        grams: grams ?? this.grams,
        absorptionMinutes: absorptionMinutes ?? this.absorptionMinutes,
        source: source ?? this.source,
      );
  CarbRow copyWithCompanion(CarbEntriesCompanion data) {
    return CarbRow(
      id: data.id.present ? data.id.value : this.id,
      time: data.time.present ? data.time.value : this.time,
      grams: data.grams.present ? data.grams.value : this.grams,
      absorptionMinutes: data.absorptionMinutes.present
          ? data.absorptionMinutes.value
          : this.absorptionMinutes,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CarbRow(')
          ..write('id: $id, ')
          ..write('time: $time, ')
          ..write('grams: $grams, ')
          ..write('absorptionMinutes: $absorptionMinutes, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, time, grams, absorptionMinutes, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CarbRow &&
          other.id == this.id &&
          other.time == this.time &&
          other.grams == this.grams &&
          other.absorptionMinutes == this.absorptionMinutes &&
          other.source == this.source);
}

class CarbEntriesCompanion extends UpdateCompanion<CarbRow> {
  final Value<int> id;
  final Value<DateTime> time;
  final Value<double> grams;
  final Value<int> absorptionMinutes;
  final Value<String> source;
  const CarbEntriesCompanion({
    this.id = const Value.absent(),
    this.time = const Value.absent(),
    this.grams = const Value.absent(),
    this.absorptionMinutes = const Value.absent(),
    this.source = const Value.absent(),
  });
  CarbEntriesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime time,
    required double grams,
    this.absorptionMinutes = const Value.absent(),
    this.source = const Value.absent(),
  })  : time = Value(time),
        grams = Value(grams);
  static Insertable<CarbRow> custom({
    Expression<int>? id,
    Expression<DateTime>? time,
    Expression<double>? grams,
    Expression<int>? absorptionMinutes,
    Expression<String>? source,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (time != null) 'time': time,
      if (grams != null) 'grams': grams,
      if (absorptionMinutes != null) 'absorption_minutes': absorptionMinutes,
      if (source != null) 'source': source,
    });
  }

  CarbEntriesCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? time,
      Value<double>? grams,
      Value<int>? absorptionMinutes,
      Value<String>? source}) {
    return CarbEntriesCompanion(
      id: id ?? this.id,
      time: time ?? this.time,
      grams: grams ?? this.grams,
      absorptionMinutes: absorptionMinutes ?? this.absorptionMinutes,
      source: source ?? this.source,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (time.present) {
      map['time'] = Variable<DateTime>(time.value);
    }
    if (grams.present) {
      map['grams'] = Variable<double>(grams.value);
    }
    if (absorptionMinutes.present) {
      map['absorption_minutes'] = Variable<int>(absorptionMinutes.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CarbEntriesCompanion(')
          ..write('id: $id, ')
          ..write('time: $time, ')
          ..write('grams: $grams, ')
          ..write('absorptionMinutes: $absorptionMinutes, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }
}

class $HealthSamplesTable extends HealthSamples
    with TableInfo<$HealthSamplesTable, HealthRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HealthSamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<DateTime> time = GeneratedColumn<DateTime>(
      'time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
      'value', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _metaMeta = const VerificationMeta('meta');
  @override
  late final GeneratedColumn<String> meta = GeneratedColumn<String>(
      'meta', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  @override
  List<GeneratedColumn> get $columns => [id, time, type, value, meta];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'health_samples';
  @override
  VerificationContext validateIntegrity(Insertable<HealthRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('meta')) {
      context.handle(
          _metaMeta, meta.isAcceptableOrUnknown(data['meta']!, _metaMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HealthRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HealthRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}time'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}value'])!,
      meta: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}meta'])!,
    );
  }

  @override
  $HealthSamplesTable createAlias(String alias) {
    return $HealthSamplesTable(attachedDatabase, alias);
  }
}

class HealthRow extends DataClass implements Insertable<HealthRow> {
  final int id;
  final DateTime time;
  final String type;
  final double value;
  final String meta;
  const HealthRow(
      {required this.id,
      required this.time,
      required this.type,
      required this.value,
      required this.meta});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['time'] = Variable<DateTime>(time);
    map['type'] = Variable<String>(type);
    map['value'] = Variable<double>(value);
    map['meta'] = Variable<String>(meta);
    return map;
  }

  HealthSamplesCompanion toCompanion(bool nullToAbsent) {
    return HealthSamplesCompanion(
      id: Value(id),
      time: Value(time),
      type: Value(type),
      value: Value(value),
      meta: Value(meta),
    );
  }

  factory HealthRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HealthRow(
      id: serializer.fromJson<int>(json['id']),
      time: serializer.fromJson<DateTime>(json['time']),
      type: serializer.fromJson<String>(json['type']),
      value: serializer.fromJson<double>(json['value']),
      meta: serializer.fromJson<String>(json['meta']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'time': serializer.toJson<DateTime>(time),
      'type': serializer.toJson<String>(type),
      'value': serializer.toJson<double>(value),
      'meta': serializer.toJson<String>(meta),
    };
  }

  HealthRow copyWith(
          {int? id,
          DateTime? time,
          String? type,
          double? value,
          String? meta}) =>
      HealthRow(
        id: id ?? this.id,
        time: time ?? this.time,
        type: type ?? this.type,
        value: value ?? this.value,
        meta: meta ?? this.meta,
      );
  HealthRow copyWithCompanion(HealthSamplesCompanion data) {
    return HealthRow(
      id: data.id.present ? data.id.value : this.id,
      time: data.time.present ? data.time.value : this.time,
      type: data.type.present ? data.type.value : this.type,
      value: data.value.present ? data.value.value : this.value,
      meta: data.meta.present ? data.meta.value : this.meta,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HealthRow(')
          ..write('id: $id, ')
          ..write('time: $time, ')
          ..write('type: $type, ')
          ..write('value: $value, ')
          ..write('meta: $meta')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, time, type, value, meta);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HealthRow &&
          other.id == this.id &&
          other.time == this.time &&
          other.type == this.type &&
          other.value == this.value &&
          other.meta == this.meta);
}

class HealthSamplesCompanion extends UpdateCompanion<HealthRow> {
  final Value<int> id;
  final Value<DateTime> time;
  final Value<String> type;
  final Value<double> value;
  final Value<String> meta;
  const HealthSamplesCompanion({
    this.id = const Value.absent(),
    this.time = const Value.absent(),
    this.type = const Value.absent(),
    this.value = const Value.absent(),
    this.meta = const Value.absent(),
  });
  HealthSamplesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime time,
    required String type,
    required double value,
    this.meta = const Value.absent(),
  })  : time = Value(time),
        type = Value(type),
        value = Value(value);
  static Insertable<HealthRow> custom({
    Expression<int>? id,
    Expression<DateTime>? time,
    Expression<String>? type,
    Expression<double>? value,
    Expression<String>? meta,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (time != null) 'time': time,
      if (type != null) 'type': type,
      if (value != null) 'value': value,
      if (meta != null) 'meta': meta,
    });
  }

  HealthSamplesCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? time,
      Value<String>? type,
      Value<double>? value,
      Value<String>? meta}) {
    return HealthSamplesCompanion(
      id: id ?? this.id,
      time: time ?? this.time,
      type: type ?? this.type,
      value: value ?? this.value,
      meta: meta ?? this.meta,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (time.present) {
      map['time'] = Variable<DateTime>(time.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (meta.present) {
      map['meta'] = Variable<String>(meta.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HealthSamplesCompanion(')
          ..write('id: $id, ')
          ..write('time: $time, ')
          ..write('type: $type, ')
          ..write('value: $value, ')
          ..write('meta: $meta')
          ..write(')'))
        .toString();
  }
}

class $AnnotationsTable extends Annotations
    with TableInfo<$AnnotationsTable, AnnotationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnnotationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
      'kind', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _startMeta = const VerificationMeta('start');
  @override
  late final GeneratedColumn<DateTime> start = GeneratedColumn<DateTime>(
      'start', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endMeta = const VerificationMeta('end');
  @override
  late final GeneratedColumn<DateTime> end = GeneratedColumn<DateTime>(
      'end', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _carbsGramsMeta =
      const VerificationMeta('carbsGrams');
  @override
  late final GeneratedColumn<double> carbsGrams = GeneratedColumn<double>(
      'carbs_grams', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _confidenceMeta =
      const VerificationMeta('confidence');
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
      'confidence', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  @override
  List<GeneratedColumn> get $columns =>
      [id, kind, start, end, carbsGrams, note, confidence];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'annotations';
  @override
  VerificationContext validateIntegrity(Insertable<AnnotationRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('start')) {
      context.handle(
          _startMeta, start.isAcceptableOrUnknown(data['start']!, _startMeta));
    } else if (isInserting) {
      context.missing(_startMeta);
    }
    if (data.containsKey('end')) {
      context.handle(
          _endMeta, end.isAcceptableOrUnknown(data['end']!, _endMeta));
    } else if (isInserting) {
      context.missing(_endMeta);
    }
    if (data.containsKey('carbs_grams')) {
      context.handle(
          _carbsGramsMeta,
          carbsGrams.isAcceptableOrUnknown(
              data['carbs_grams']!, _carbsGramsMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('confidence')) {
      context.handle(
          _confidenceMeta,
          confidence.isAcceptableOrUnknown(
              data['confidence']!, _confidenceMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnnotationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnnotationRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}kind'])!,
      start: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start'])!,
      end: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end'])!,
      carbsGrams: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}carbs_grams'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note'])!,
      confidence: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}confidence'])!,
    );
  }

  @override
  $AnnotationsTable createAlias(String alias) {
    return $AnnotationsTable(attachedDatabase, alias);
  }
}

class AnnotationRow extends DataClass implements Insertable<AnnotationRow> {
  final String id;
  final int kind;
  final DateTime start;
  final DateTime end;
  final double carbsGrams;
  final String note;
  final double confidence;
  const AnnotationRow(
      {required this.id,
      required this.kind,
      required this.start,
      required this.end,
      required this.carbsGrams,
      required this.note,
      required this.confidence});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<int>(kind);
    map['start'] = Variable<DateTime>(start);
    map['end'] = Variable<DateTime>(end);
    map['carbs_grams'] = Variable<double>(carbsGrams);
    map['note'] = Variable<String>(note);
    map['confidence'] = Variable<double>(confidence);
    return map;
  }

  AnnotationsCompanion toCompanion(bool nullToAbsent) {
    return AnnotationsCompanion(
      id: Value(id),
      kind: Value(kind),
      start: Value(start),
      end: Value(end),
      carbsGrams: Value(carbsGrams),
      note: Value(note),
      confidence: Value(confidence),
    );
  }

  factory AnnotationRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnnotationRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<int>(json['kind']),
      start: serializer.fromJson<DateTime>(json['start']),
      end: serializer.fromJson<DateTime>(json['end']),
      carbsGrams: serializer.fromJson<double>(json['carbsGrams']),
      note: serializer.fromJson<String>(json['note']),
      confidence: serializer.fromJson<double>(json['confidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<int>(kind),
      'start': serializer.toJson<DateTime>(start),
      'end': serializer.toJson<DateTime>(end),
      'carbsGrams': serializer.toJson<double>(carbsGrams),
      'note': serializer.toJson<String>(note),
      'confidence': serializer.toJson<double>(confidence),
    };
  }

  AnnotationRow copyWith(
          {String? id,
          int? kind,
          DateTime? start,
          DateTime? end,
          double? carbsGrams,
          String? note,
          double? confidence}) =>
      AnnotationRow(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        start: start ?? this.start,
        end: end ?? this.end,
        carbsGrams: carbsGrams ?? this.carbsGrams,
        note: note ?? this.note,
        confidence: confidence ?? this.confidence,
      );
  AnnotationRow copyWithCompanion(AnnotationsCompanion data) {
    return AnnotationRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      start: data.start.present ? data.start.value : this.start,
      end: data.end.present ? data.end.value : this.end,
      carbsGrams:
          data.carbsGrams.present ? data.carbsGrams.value : this.carbsGrams,
      note: data.note.present ? data.note.value : this.note,
      confidence:
          data.confidence.present ? data.confidence.value : this.confidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('start: $start, ')
          ..write('end: $end, ')
          ..write('carbsGrams: $carbsGrams, ')
          ..write('note: $note, ')
          ..write('confidence: $confidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, start, end, carbsGrams, note, confidence);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnnotationRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.start == this.start &&
          other.end == this.end &&
          other.carbsGrams == this.carbsGrams &&
          other.note == this.note &&
          other.confidence == this.confidence);
}

class AnnotationsCompanion extends UpdateCompanion<AnnotationRow> {
  final Value<String> id;
  final Value<int> kind;
  final Value<DateTime> start;
  final Value<DateTime> end;
  final Value<double> carbsGrams;
  final Value<String> note;
  final Value<double> confidence;
  final Value<int> rowid;
  const AnnotationsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.start = const Value.absent(),
    this.end = const Value.absent(),
    this.carbsGrams = const Value.absent(),
    this.note = const Value.absent(),
    this.confidence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnnotationsCompanion.insert({
    required String id,
    required int kind,
    required DateTime start,
    required DateTime end,
    this.carbsGrams = const Value.absent(),
    this.note = const Value.absent(),
    this.confidence = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        kind = Value(kind),
        start = Value(start),
        end = Value(end);
  static Insertable<AnnotationRow> custom({
    Expression<String>? id,
    Expression<int>? kind,
    Expression<DateTime>? start,
    Expression<DateTime>? end,
    Expression<double>? carbsGrams,
    Expression<String>? note,
    Expression<double>? confidence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (start != null) 'start': start,
      if (end != null) 'end': end,
      if (carbsGrams != null) 'carbs_grams': carbsGrams,
      if (note != null) 'note': note,
      if (confidence != null) 'confidence': confidence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnnotationsCompanion copyWith(
      {Value<String>? id,
      Value<int>? kind,
      Value<DateTime>? start,
      Value<DateTime>? end,
      Value<double>? carbsGrams,
      Value<String>? note,
      Value<double>? confidence,
      Value<int>? rowid}) {
    return AnnotationsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      start: start ?? this.start,
      end: end ?? this.end,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      note: note ?? this.note,
      confidence: confidence ?? this.confidence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (start.present) {
      map['start'] = Variable<DateTime>(start.value);
    }
    if (end.present) {
      map['end'] = Variable<DateTime>(end.value);
    }
    if (carbsGrams.present) {
      map['carbs_grams'] = Variable<double>(carbsGrams.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('start: $start, ')
          ..write('end: $end, ')
          ..write('carbsGrams: $carbsGrams, ')
          ..write('note: $note, ')
          ..write('confidence: $confidence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PredictionsTable extends Predictions
    with TableInfo<$PredictionsTable, PredictionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PredictionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _madeAtMeta = const VerificationMeta('madeAt');
  @override
  late final GeneratedColumn<DateTime> madeAt = GeneratedColumn<DateTime>(
      'made_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _horizonMinutesMeta =
      const VerificationMeta('horizonMinutes');
  @override
  late final GeneratedColumn<int> horizonMinutes = GeneratedColumn<int>(
      'horizon_minutes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _predictedMgdlMeta =
      const VerificationMeta('predictedMgdl');
  @override
  late final GeneratedColumn<double> predictedMgdl = GeneratedColumn<double>(
      'predicted_mgdl', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _lowerMgdlMeta =
      const VerificationMeta('lowerMgdl');
  @override
  late final GeneratedColumn<double> lowerMgdl = GeneratedColumn<double>(
      'lower_mgdl', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _upperMgdlMeta =
      const VerificationMeta('upperMgdl');
  @override
  late final GeneratedColumn<double> upperMgdl = GeneratedColumn<double>(
      'upper_mgdl', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _actualMgdlMeta =
      const VerificationMeta('actualMgdl');
  @override
  late final GeneratedColumn<double> actualMgdl = GeneratedColumn<double>(
      'actual_mgdl', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _modelIdMeta =
      const VerificationMeta('modelId');
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
      'model_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('deterministic'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        madeAt,
        horizonMinutes,
        predictedMgdl,
        lowerMgdl,
        upperMgdl,
        actualMgdl,
        modelId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'predictions';
  @override
  VerificationContext validateIntegrity(Insertable<PredictionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('made_at')) {
      context.handle(_madeAtMeta,
          madeAt.isAcceptableOrUnknown(data['made_at']!, _madeAtMeta));
    } else if (isInserting) {
      context.missing(_madeAtMeta);
    }
    if (data.containsKey('horizon_minutes')) {
      context.handle(
          _horizonMinutesMeta,
          horizonMinutes.isAcceptableOrUnknown(
              data['horizon_minutes']!, _horizonMinutesMeta));
    } else if (isInserting) {
      context.missing(_horizonMinutesMeta);
    }
    if (data.containsKey('predicted_mgdl')) {
      context.handle(
          _predictedMgdlMeta,
          predictedMgdl.isAcceptableOrUnknown(
              data['predicted_mgdl']!, _predictedMgdlMeta));
    } else if (isInserting) {
      context.missing(_predictedMgdlMeta);
    }
    if (data.containsKey('lower_mgdl')) {
      context.handle(_lowerMgdlMeta,
          lowerMgdl.isAcceptableOrUnknown(data['lower_mgdl']!, _lowerMgdlMeta));
    } else if (isInserting) {
      context.missing(_lowerMgdlMeta);
    }
    if (data.containsKey('upper_mgdl')) {
      context.handle(_upperMgdlMeta,
          upperMgdl.isAcceptableOrUnknown(data['upper_mgdl']!, _upperMgdlMeta));
    } else if (isInserting) {
      context.missing(_upperMgdlMeta);
    }
    if (data.containsKey('actual_mgdl')) {
      context.handle(
          _actualMgdlMeta,
          actualMgdl.isAcceptableOrUnknown(
              data['actual_mgdl']!, _actualMgdlMeta));
    }
    if (data.containsKey('model_id')) {
      context.handle(_modelIdMeta,
          modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PredictionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PredictionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      madeAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}made_at'])!,
      horizonMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}horizon_minutes'])!,
      predictedMgdl: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}predicted_mgdl'])!,
      lowerMgdl: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lower_mgdl'])!,
      upperMgdl: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}upper_mgdl'])!,
      actualMgdl: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}actual_mgdl']),
      modelId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model_id'])!,
    );
  }

  @override
  $PredictionsTable createAlias(String alias) {
    return $PredictionsTable(attachedDatabase, alias);
  }
}

class PredictionRow extends DataClass implements Insertable<PredictionRow> {
  final int id;
  final DateTime madeAt;
  final int horizonMinutes;
  final double predictedMgdl;
  final double lowerMgdl;
  final double upperMgdl;
  final double? actualMgdl;
  final String modelId;
  const PredictionRow(
      {required this.id,
      required this.madeAt,
      required this.horizonMinutes,
      required this.predictedMgdl,
      required this.lowerMgdl,
      required this.upperMgdl,
      this.actualMgdl,
      required this.modelId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['made_at'] = Variable<DateTime>(madeAt);
    map['horizon_minutes'] = Variable<int>(horizonMinutes);
    map['predicted_mgdl'] = Variable<double>(predictedMgdl);
    map['lower_mgdl'] = Variable<double>(lowerMgdl);
    map['upper_mgdl'] = Variable<double>(upperMgdl);
    if (!nullToAbsent || actualMgdl != null) {
      map['actual_mgdl'] = Variable<double>(actualMgdl);
    }
    map['model_id'] = Variable<String>(modelId);
    return map;
  }

  PredictionsCompanion toCompanion(bool nullToAbsent) {
    return PredictionsCompanion(
      id: Value(id),
      madeAt: Value(madeAt),
      horizonMinutes: Value(horizonMinutes),
      predictedMgdl: Value(predictedMgdl),
      lowerMgdl: Value(lowerMgdl),
      upperMgdl: Value(upperMgdl),
      actualMgdl: actualMgdl == null && nullToAbsent
          ? const Value.absent()
          : Value(actualMgdl),
      modelId: Value(modelId),
    );
  }

  factory PredictionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PredictionRow(
      id: serializer.fromJson<int>(json['id']),
      madeAt: serializer.fromJson<DateTime>(json['madeAt']),
      horizonMinutes: serializer.fromJson<int>(json['horizonMinutes']),
      predictedMgdl: serializer.fromJson<double>(json['predictedMgdl']),
      lowerMgdl: serializer.fromJson<double>(json['lowerMgdl']),
      upperMgdl: serializer.fromJson<double>(json['upperMgdl']),
      actualMgdl: serializer.fromJson<double?>(json['actualMgdl']),
      modelId: serializer.fromJson<String>(json['modelId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'madeAt': serializer.toJson<DateTime>(madeAt),
      'horizonMinutes': serializer.toJson<int>(horizonMinutes),
      'predictedMgdl': serializer.toJson<double>(predictedMgdl),
      'lowerMgdl': serializer.toJson<double>(lowerMgdl),
      'upperMgdl': serializer.toJson<double>(upperMgdl),
      'actualMgdl': serializer.toJson<double?>(actualMgdl),
      'modelId': serializer.toJson<String>(modelId),
    };
  }

  PredictionRow copyWith(
          {int? id,
          DateTime? madeAt,
          int? horizonMinutes,
          double? predictedMgdl,
          double? lowerMgdl,
          double? upperMgdl,
          Value<double?> actualMgdl = const Value.absent(),
          String? modelId}) =>
      PredictionRow(
        id: id ?? this.id,
        madeAt: madeAt ?? this.madeAt,
        horizonMinutes: horizonMinutes ?? this.horizonMinutes,
        predictedMgdl: predictedMgdl ?? this.predictedMgdl,
        lowerMgdl: lowerMgdl ?? this.lowerMgdl,
        upperMgdl: upperMgdl ?? this.upperMgdl,
        actualMgdl: actualMgdl.present ? actualMgdl.value : this.actualMgdl,
        modelId: modelId ?? this.modelId,
      );
  PredictionRow copyWithCompanion(PredictionsCompanion data) {
    return PredictionRow(
      id: data.id.present ? data.id.value : this.id,
      madeAt: data.madeAt.present ? data.madeAt.value : this.madeAt,
      horizonMinutes: data.horizonMinutes.present
          ? data.horizonMinutes.value
          : this.horizonMinutes,
      predictedMgdl: data.predictedMgdl.present
          ? data.predictedMgdl.value
          : this.predictedMgdl,
      lowerMgdl: data.lowerMgdl.present ? data.lowerMgdl.value : this.lowerMgdl,
      upperMgdl: data.upperMgdl.present ? data.upperMgdl.value : this.upperMgdl,
      actualMgdl:
          data.actualMgdl.present ? data.actualMgdl.value : this.actualMgdl,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PredictionRow(')
          ..write('id: $id, ')
          ..write('madeAt: $madeAt, ')
          ..write('horizonMinutes: $horizonMinutes, ')
          ..write('predictedMgdl: $predictedMgdl, ')
          ..write('lowerMgdl: $lowerMgdl, ')
          ..write('upperMgdl: $upperMgdl, ')
          ..write('actualMgdl: $actualMgdl, ')
          ..write('modelId: $modelId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, madeAt, horizonMinutes, predictedMgdl,
      lowerMgdl, upperMgdl, actualMgdl, modelId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PredictionRow &&
          other.id == this.id &&
          other.madeAt == this.madeAt &&
          other.horizonMinutes == this.horizonMinutes &&
          other.predictedMgdl == this.predictedMgdl &&
          other.lowerMgdl == this.lowerMgdl &&
          other.upperMgdl == this.upperMgdl &&
          other.actualMgdl == this.actualMgdl &&
          other.modelId == this.modelId);
}

class PredictionsCompanion extends UpdateCompanion<PredictionRow> {
  final Value<int> id;
  final Value<DateTime> madeAt;
  final Value<int> horizonMinutes;
  final Value<double> predictedMgdl;
  final Value<double> lowerMgdl;
  final Value<double> upperMgdl;
  final Value<double?> actualMgdl;
  final Value<String> modelId;
  const PredictionsCompanion({
    this.id = const Value.absent(),
    this.madeAt = const Value.absent(),
    this.horizonMinutes = const Value.absent(),
    this.predictedMgdl = const Value.absent(),
    this.lowerMgdl = const Value.absent(),
    this.upperMgdl = const Value.absent(),
    this.actualMgdl = const Value.absent(),
    this.modelId = const Value.absent(),
  });
  PredictionsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime madeAt,
    required int horizonMinutes,
    required double predictedMgdl,
    required double lowerMgdl,
    required double upperMgdl,
    this.actualMgdl = const Value.absent(),
    this.modelId = const Value.absent(),
  })  : madeAt = Value(madeAt),
        horizonMinutes = Value(horizonMinutes),
        predictedMgdl = Value(predictedMgdl),
        lowerMgdl = Value(lowerMgdl),
        upperMgdl = Value(upperMgdl);
  static Insertable<PredictionRow> custom({
    Expression<int>? id,
    Expression<DateTime>? madeAt,
    Expression<int>? horizonMinutes,
    Expression<double>? predictedMgdl,
    Expression<double>? lowerMgdl,
    Expression<double>? upperMgdl,
    Expression<double>? actualMgdl,
    Expression<String>? modelId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (madeAt != null) 'made_at': madeAt,
      if (horizonMinutes != null) 'horizon_minutes': horizonMinutes,
      if (predictedMgdl != null) 'predicted_mgdl': predictedMgdl,
      if (lowerMgdl != null) 'lower_mgdl': lowerMgdl,
      if (upperMgdl != null) 'upper_mgdl': upperMgdl,
      if (actualMgdl != null) 'actual_mgdl': actualMgdl,
      if (modelId != null) 'model_id': modelId,
    });
  }

  PredictionsCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? madeAt,
      Value<int>? horizonMinutes,
      Value<double>? predictedMgdl,
      Value<double>? lowerMgdl,
      Value<double>? upperMgdl,
      Value<double?>? actualMgdl,
      Value<String>? modelId}) {
    return PredictionsCompanion(
      id: id ?? this.id,
      madeAt: madeAt ?? this.madeAt,
      horizonMinutes: horizonMinutes ?? this.horizonMinutes,
      predictedMgdl: predictedMgdl ?? this.predictedMgdl,
      lowerMgdl: lowerMgdl ?? this.lowerMgdl,
      upperMgdl: upperMgdl ?? this.upperMgdl,
      actualMgdl: actualMgdl ?? this.actualMgdl,
      modelId: modelId ?? this.modelId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (madeAt.present) {
      map['made_at'] = Variable<DateTime>(madeAt.value);
    }
    if (horizonMinutes.present) {
      map['horizon_minutes'] = Variable<int>(horizonMinutes.value);
    }
    if (predictedMgdl.present) {
      map['predicted_mgdl'] = Variable<double>(predictedMgdl.value);
    }
    if (lowerMgdl.present) {
      map['lower_mgdl'] = Variable<double>(lowerMgdl.value);
    }
    if (upperMgdl.present) {
      map['upper_mgdl'] = Variable<double>(upperMgdl.value);
    }
    if (actualMgdl.present) {
      map['actual_mgdl'] = Variable<double>(actualMgdl.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PredictionsCompanion(')
          ..write('id: $id, ')
          ..write('madeAt: $madeAt, ')
          ..write('horizonMinutes: $horizonMinutes, ')
          ..write('predictedMgdl: $predictedMgdl, ')
          ..write('lowerMgdl: $lowerMgdl, ')
          ..write('upperMgdl: $upperMgdl, ')
          ..write('actualMgdl: $actualMgdl, ')
          ..write('modelId: $modelId')
          ..write(')'))
        .toString();
  }
}

class $ModelRunsTable extends ModelRuns
    with TableInfo<$ModelRunsTable, ModelRunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
      'stage', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _trainedOnDaysMeta =
      const VerificationMeta('trainedOnDays');
  @override
  late final GeneratedColumn<int> trainedOnDays = GeneratedColumn<int>(
      'trained_on_days', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _metricsJsonMeta =
      const VerificationMeta('metricsJson');
  @override
  late final GeneratedColumn<String> metricsJson = GeneratedColumn<String>(
      'metrics_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _weightsJsonMeta =
      const VerificationMeta('weightsJson');
  @override
  late final GeneratedColumn<String> weightsJson = GeneratedColumn<String>(
      'weights_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  @override
  List<GeneratedColumn> get $columns =>
      [id, stage, createdAt, trainedOnDays, metricsJson, weightsJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'model_runs';
  @override
  VerificationContext validateIntegrity(Insertable<ModelRunRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
          _stageMeta, stage.isAcceptableOrUnknown(data['stage']!, _stageMeta));
    } else if (isInserting) {
      context.missing(_stageMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('trained_on_days')) {
      context.handle(
          _trainedOnDaysMeta,
          trainedOnDays.isAcceptableOrUnknown(
              data['trained_on_days']!, _trainedOnDaysMeta));
    } else if (isInserting) {
      context.missing(_trainedOnDaysMeta);
    }
    if (data.containsKey('metrics_json')) {
      context.handle(
          _metricsJsonMeta,
          metricsJson.isAcceptableOrUnknown(
              data['metrics_json']!, _metricsJsonMeta));
    }
    if (data.containsKey('weights_json')) {
      context.handle(
          _weightsJsonMeta,
          weightsJson.isAcceptableOrUnknown(
              data['weights_json']!, _weightsJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModelRunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModelRunRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      stage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stage'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      trainedOnDays: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trained_on_days'])!,
      metricsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metrics_json'])!,
      weightsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}weights_json'])!,
    );
  }

  @override
  $ModelRunsTable createAlias(String alias) {
    return $ModelRunsTable(attachedDatabase, alias);
  }
}

class ModelRunRow extends DataClass implements Insertable<ModelRunRow> {
  final String id;
  final String stage;
  final DateTime createdAt;
  final int trainedOnDays;
  final String metricsJson;
  final String weightsJson;
  const ModelRunRow(
      {required this.id,
      required this.stage,
      required this.createdAt,
      required this.trainedOnDays,
      required this.metricsJson,
      required this.weightsJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['stage'] = Variable<String>(stage);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['trained_on_days'] = Variable<int>(trainedOnDays);
    map['metrics_json'] = Variable<String>(metricsJson);
    map['weights_json'] = Variable<String>(weightsJson);
    return map;
  }

  ModelRunsCompanion toCompanion(bool nullToAbsent) {
    return ModelRunsCompanion(
      id: Value(id),
      stage: Value(stage),
      createdAt: Value(createdAt),
      trainedOnDays: Value(trainedOnDays),
      metricsJson: Value(metricsJson),
      weightsJson: Value(weightsJson),
    );
  }

  factory ModelRunRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModelRunRow(
      id: serializer.fromJson<String>(json['id']),
      stage: serializer.fromJson<String>(json['stage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      trainedOnDays: serializer.fromJson<int>(json['trainedOnDays']),
      metricsJson: serializer.fromJson<String>(json['metricsJson']),
      weightsJson: serializer.fromJson<String>(json['weightsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'stage': serializer.toJson<String>(stage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'trainedOnDays': serializer.toJson<int>(trainedOnDays),
      'metricsJson': serializer.toJson<String>(metricsJson),
      'weightsJson': serializer.toJson<String>(weightsJson),
    };
  }

  ModelRunRow copyWith(
          {String? id,
          String? stage,
          DateTime? createdAt,
          int? trainedOnDays,
          String? metricsJson,
          String? weightsJson}) =>
      ModelRunRow(
        id: id ?? this.id,
        stage: stage ?? this.stage,
        createdAt: createdAt ?? this.createdAt,
        trainedOnDays: trainedOnDays ?? this.trainedOnDays,
        metricsJson: metricsJson ?? this.metricsJson,
        weightsJson: weightsJson ?? this.weightsJson,
      );
  ModelRunRow copyWithCompanion(ModelRunsCompanion data) {
    return ModelRunRow(
      id: data.id.present ? data.id.value : this.id,
      stage: data.stage.present ? data.stage.value : this.stage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      trainedOnDays: data.trainedOnDays.present
          ? data.trainedOnDays.value
          : this.trainedOnDays,
      metricsJson:
          data.metricsJson.present ? data.metricsJson.value : this.metricsJson,
      weightsJson:
          data.weightsJson.present ? data.weightsJson.value : this.weightsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModelRunRow(')
          ..write('id: $id, ')
          ..write('stage: $stage, ')
          ..write('createdAt: $createdAt, ')
          ..write('trainedOnDays: $trainedOnDays, ')
          ..write('metricsJson: $metricsJson, ')
          ..write('weightsJson: $weightsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, stage, createdAt, trainedOnDays, metricsJson, weightsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelRunRow &&
          other.id == this.id &&
          other.stage == this.stage &&
          other.createdAt == this.createdAt &&
          other.trainedOnDays == this.trainedOnDays &&
          other.metricsJson == this.metricsJson &&
          other.weightsJson == this.weightsJson);
}

class ModelRunsCompanion extends UpdateCompanion<ModelRunRow> {
  final Value<String> id;
  final Value<String> stage;
  final Value<DateTime> createdAt;
  final Value<int> trainedOnDays;
  final Value<String> metricsJson;
  final Value<String> weightsJson;
  final Value<int> rowid;
  const ModelRunsCompanion({
    this.id = const Value.absent(),
    this.stage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.trainedOnDays = const Value.absent(),
    this.metricsJson = const Value.absent(),
    this.weightsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelRunsCompanion.insert({
    required String id,
    required String stage,
    required DateTime createdAt,
    required int trainedOnDays,
    this.metricsJson = const Value.absent(),
    this.weightsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        stage = Value(stage),
        createdAt = Value(createdAt),
        trainedOnDays = Value(trainedOnDays);
  static Insertable<ModelRunRow> custom({
    Expression<String>? id,
    Expression<String>? stage,
    Expression<DateTime>? createdAt,
    Expression<int>? trainedOnDays,
    Expression<String>? metricsJson,
    Expression<String>? weightsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (stage != null) 'stage': stage,
      if (createdAt != null) 'created_at': createdAt,
      if (trainedOnDays != null) 'trained_on_days': trainedOnDays,
      if (metricsJson != null) 'metrics_json': metricsJson,
      if (weightsJson != null) 'weights_json': weightsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelRunsCompanion copyWith(
      {Value<String>? id,
      Value<String>? stage,
      Value<DateTime>? createdAt,
      Value<int>? trainedOnDays,
      Value<String>? metricsJson,
      Value<String>? weightsJson,
      Value<int>? rowid}) {
    return ModelRunsCompanion(
      id: id ?? this.id,
      stage: stage ?? this.stage,
      createdAt: createdAt ?? this.createdAt,
      trainedOnDays: trainedOnDays ?? this.trainedOnDays,
      metricsJson: metricsJson ?? this.metricsJson,
      weightsJson: weightsJson ?? this.weightsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (trainedOnDays.present) {
      map['trained_on_days'] = Variable<int>(trainedOnDays.value);
    }
    if (metricsJson.present) {
      map['metrics_json'] = Variable<String>(metricsJson.value);
    }
    if (weightsJson.present) {
      map['weights_json'] = Variable<String>(weightsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelRunsCompanion(')
          ..write('id: $id, ')
          ..write('stage: $stage, ')
          ..write('createdAt: $createdAt, ')
          ..write('trainedOnDays: $trainedOnDays, ')
          ..write('metricsJson: $metricsJson, ')
          ..write('weightsJson: $weightsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedMealsTable extends SavedMeals
    with TableInfo<$SavedMealsTable, SavedMealRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedMealsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
      'emoji', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('🍽️'));
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('other'));
  static const VerificationMeta _carbsGramsMeta =
      const VerificationMeta('carbsGrams');
  @override
  late final GeneratedColumn<double> carbsGrams = GeneratedColumn<double>(
      'carbs_grams', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _fatProteinHeavyMeta =
      const VerificationMeta('fatProteinHeavy');
  @override
  late final GeneratedColumn<bool> fatProteinHeavy = GeneratedColumn<bool>(
      'fat_protein_heavy', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("fat_protein_heavy" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _absorptionMinutesMeta =
      const VerificationMeta('absorptionMinutes');
  @override
  late final GeneratedColumn<int> absorptionMinutes = GeneratedColumn<int>(
      'absorption_minutes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(180));
  static const VerificationMeta _peakOffsetMinutesMeta =
      const VerificationMeta('peakOffsetMinutes');
  @override
  late final GeneratedColumn<int> peakOffsetMinutes = GeneratedColumn<int>(
      'peak_offset_minutes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(90));
  static const VerificationMeta _outcomesJsonMeta =
      const VerificationMeta('outcomesJson');
  @override
  late final GeneratedColumn<String> outcomesJson = GeneratedColumn<String>(
      'outcomes_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        emoji,
        category,
        carbsGrams,
        fatProteinHeavy,
        absorptionMinutes,
        peakOffsetMinutes,
        outcomesJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_meals';
  @override
  VerificationContext validateIntegrity(Insertable<SavedMealRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
          _emojiMeta, emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('carbs_grams')) {
      context.handle(
          _carbsGramsMeta,
          carbsGrams.isAcceptableOrUnknown(
              data['carbs_grams']!, _carbsGramsMeta));
    } else if (isInserting) {
      context.missing(_carbsGramsMeta);
    }
    if (data.containsKey('fat_protein_heavy')) {
      context.handle(
          _fatProteinHeavyMeta,
          fatProteinHeavy.isAcceptableOrUnknown(
              data['fat_protein_heavy']!, _fatProteinHeavyMeta));
    }
    if (data.containsKey('absorption_minutes')) {
      context.handle(
          _absorptionMinutesMeta,
          absorptionMinutes.isAcceptableOrUnknown(
              data['absorption_minutes']!, _absorptionMinutesMeta));
    }
    if (data.containsKey('peak_offset_minutes')) {
      context.handle(
          _peakOffsetMinutesMeta,
          peakOffsetMinutes.isAcceptableOrUnknown(
              data['peak_offset_minutes']!, _peakOffsetMinutesMeta));
    }
    if (data.containsKey('outcomes_json')) {
      context.handle(
          _outcomesJsonMeta,
          outcomesJson.isAcceptableOrUnknown(
              data['outcomes_json']!, _outcomesJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedMealRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedMealRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      emoji: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}emoji'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      carbsGrams: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}carbs_grams'])!,
      fatProteinHeavy: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}fat_protein_heavy'])!,
      absorptionMinutes: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}absorption_minutes'])!,
      peakOffsetMinutes: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}peak_offset_minutes'])!,
      outcomesJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}outcomes_json'])!,
    );
  }

  @override
  $SavedMealsTable createAlias(String alias) {
    return $SavedMealsTable(attachedDatabase, alias);
  }
}

class SavedMealRow extends DataClass implements Insertable<SavedMealRow> {
  final String id;
  final String name;
  final String emoji;
  final String category;
  final double carbsGrams;
  final bool fatProteinHeavy;
  final int absorptionMinutes;
  final int peakOffsetMinutes;

  /// JSON array of MealOutcome.toJson() maps (bounded to 20 by the domain layer).
  final String outcomesJson;
  const SavedMealRow(
      {required this.id,
      required this.name,
      required this.emoji,
      required this.category,
      required this.carbsGrams,
      required this.fatProteinHeavy,
      required this.absorptionMinutes,
      required this.peakOffsetMinutes,
      required this.outcomesJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['emoji'] = Variable<String>(emoji);
    map['category'] = Variable<String>(category);
    map['carbs_grams'] = Variable<double>(carbsGrams);
    map['fat_protein_heavy'] = Variable<bool>(fatProteinHeavy);
    map['absorption_minutes'] = Variable<int>(absorptionMinutes);
    map['peak_offset_minutes'] = Variable<int>(peakOffsetMinutes);
    map['outcomes_json'] = Variable<String>(outcomesJson);
    return map;
  }

  SavedMealsCompanion toCompanion(bool nullToAbsent) {
    return SavedMealsCompanion(
      id: Value(id),
      name: Value(name),
      emoji: Value(emoji),
      category: Value(category),
      carbsGrams: Value(carbsGrams),
      fatProteinHeavy: Value(fatProteinHeavy),
      absorptionMinutes: Value(absorptionMinutes),
      peakOffsetMinutes: Value(peakOffsetMinutes),
      outcomesJson: Value(outcomesJson),
    );
  }

  factory SavedMealRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedMealRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      emoji: serializer.fromJson<String>(json['emoji']),
      category: serializer.fromJson<String>(json['category']),
      carbsGrams: serializer.fromJson<double>(json['carbsGrams']),
      fatProteinHeavy: serializer.fromJson<bool>(json['fatProteinHeavy']),
      absorptionMinutes: serializer.fromJson<int>(json['absorptionMinutes']),
      peakOffsetMinutes: serializer.fromJson<int>(json['peakOffsetMinutes']),
      outcomesJson: serializer.fromJson<String>(json['outcomesJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'emoji': serializer.toJson<String>(emoji),
      'category': serializer.toJson<String>(category),
      'carbsGrams': serializer.toJson<double>(carbsGrams),
      'fatProteinHeavy': serializer.toJson<bool>(fatProteinHeavy),
      'absorptionMinutes': serializer.toJson<int>(absorptionMinutes),
      'peakOffsetMinutes': serializer.toJson<int>(peakOffsetMinutes),
      'outcomesJson': serializer.toJson<String>(outcomesJson),
    };
  }

  SavedMealRow copyWith(
          {String? id,
          String? name,
          String? emoji,
          String? category,
          double? carbsGrams,
          bool? fatProteinHeavy,
          int? absorptionMinutes,
          int? peakOffsetMinutes,
          String? outcomesJson}) =>
      SavedMealRow(
        id: id ?? this.id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        category: category ?? this.category,
        carbsGrams: carbsGrams ?? this.carbsGrams,
        fatProteinHeavy: fatProteinHeavy ?? this.fatProteinHeavy,
        absorptionMinutes: absorptionMinutes ?? this.absorptionMinutes,
        peakOffsetMinutes: peakOffsetMinutes ?? this.peakOffsetMinutes,
        outcomesJson: outcomesJson ?? this.outcomesJson,
      );
  SavedMealRow copyWithCompanion(SavedMealsCompanion data) {
    return SavedMealRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      category: data.category.present ? data.category.value : this.category,
      carbsGrams:
          data.carbsGrams.present ? data.carbsGrams.value : this.carbsGrams,
      fatProteinHeavy: data.fatProteinHeavy.present
          ? data.fatProteinHeavy.value
          : this.fatProteinHeavy,
      absorptionMinutes: data.absorptionMinutes.present
          ? data.absorptionMinutes.value
          : this.absorptionMinutes,
      peakOffsetMinutes: data.peakOffsetMinutes.present
          ? data.peakOffsetMinutes.value
          : this.peakOffsetMinutes,
      outcomesJson: data.outcomesJson.present
          ? data.outcomesJson.value
          : this.outcomesJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedMealRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('category: $category, ')
          ..write('carbsGrams: $carbsGrams, ')
          ..write('fatProteinHeavy: $fatProteinHeavy, ')
          ..write('absorptionMinutes: $absorptionMinutes, ')
          ..write('peakOffsetMinutes: $peakOffsetMinutes, ')
          ..write('outcomesJson: $outcomesJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, emoji, category, carbsGrams,
      fatProteinHeavy, absorptionMinutes, peakOffsetMinutes, outcomesJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedMealRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.emoji == this.emoji &&
          other.category == this.category &&
          other.carbsGrams == this.carbsGrams &&
          other.fatProteinHeavy == this.fatProteinHeavy &&
          other.absorptionMinutes == this.absorptionMinutes &&
          other.peakOffsetMinutes == this.peakOffsetMinutes &&
          other.outcomesJson == this.outcomesJson);
}

class SavedMealsCompanion extends UpdateCompanion<SavedMealRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> emoji;
  final Value<String> category;
  final Value<double> carbsGrams;
  final Value<bool> fatProteinHeavy;
  final Value<int> absorptionMinutes;
  final Value<int> peakOffsetMinutes;
  final Value<String> outcomesJson;
  final Value<int> rowid;
  const SavedMealsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.emoji = const Value.absent(),
    this.category = const Value.absent(),
    this.carbsGrams = const Value.absent(),
    this.fatProteinHeavy = const Value.absent(),
    this.absorptionMinutes = const Value.absent(),
    this.peakOffsetMinutes = const Value.absent(),
    this.outcomesJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedMealsCompanion.insert({
    required String id,
    required String name,
    this.emoji = const Value.absent(),
    this.category = const Value.absent(),
    required double carbsGrams,
    this.fatProteinHeavy = const Value.absent(),
    this.absorptionMinutes = const Value.absent(),
    this.peakOffsetMinutes = const Value.absent(),
    this.outcomesJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        carbsGrams = Value(carbsGrams);
  static Insertable<SavedMealRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? emoji,
    Expression<String>? category,
    Expression<double>? carbsGrams,
    Expression<bool>? fatProteinHeavy,
    Expression<int>? absorptionMinutes,
    Expression<int>? peakOffsetMinutes,
    Expression<String>? outcomesJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (emoji != null) 'emoji': emoji,
      if (category != null) 'category': category,
      if (carbsGrams != null) 'carbs_grams': carbsGrams,
      if (fatProteinHeavy != null) 'fat_protein_heavy': fatProteinHeavy,
      if (absorptionMinutes != null) 'absorption_minutes': absorptionMinutes,
      if (peakOffsetMinutes != null) 'peak_offset_minutes': peakOffsetMinutes,
      if (outcomesJson != null) 'outcomes_json': outcomesJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedMealsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? emoji,
      Value<String>? category,
      Value<double>? carbsGrams,
      Value<bool>? fatProteinHeavy,
      Value<int>? absorptionMinutes,
      Value<int>? peakOffsetMinutes,
      Value<String>? outcomesJson,
      Value<int>? rowid}) {
    return SavedMealsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      category: category ?? this.category,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatProteinHeavy: fatProteinHeavy ?? this.fatProteinHeavy,
      absorptionMinutes: absorptionMinutes ?? this.absorptionMinutes,
      peakOffsetMinutes: peakOffsetMinutes ?? this.peakOffsetMinutes,
      outcomesJson: outcomesJson ?? this.outcomesJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (carbsGrams.present) {
      map['carbs_grams'] = Variable<double>(carbsGrams.value);
    }
    if (fatProteinHeavy.present) {
      map['fat_protein_heavy'] = Variable<bool>(fatProteinHeavy.value);
    }
    if (absorptionMinutes.present) {
      map['absorption_minutes'] = Variable<int>(absorptionMinutes.value);
    }
    if (peakOffsetMinutes.present) {
      map['peak_offset_minutes'] = Variable<int>(peakOffsetMinutes.value);
    }
    if (outcomesJson.present) {
      map['outcomes_json'] = Variable<String>(outcomesJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedMealsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('category: $category, ')
          ..write('carbsGrams: $carbsGrams, ')
          ..write('fatProteinHeavy: $fatProteinHeavy, ')
          ..write('absorptionMinutes: $absorptionMinutes, ')
          ..write('peakOffsetMinutes: $peakOffsetMinutes, ')
          ..write('outcomesJson: $outcomesJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppKvTable extends AppKv with TableInfo<$AppKvTable, AppKvRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppKvTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_kv';
  @override
  VerificationContext validateIntegrity(Insertable<AppKvRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppKvRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppKvRow(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $AppKvTable createAlias(String alias) {
    return $AppKvTable(attachedDatabase, alias);
  }
}

class AppKvRow extends DataClass implements Insertable<AppKvRow> {
  final String key;
  final String value;
  const AppKvRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppKvCompanion toCompanion(bool nullToAbsent) {
    return AppKvCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory AppKvRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppKvRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppKvRow copyWith({String? key, String? value}) => AppKvRow(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  AppKvRow copyWithCompanion(AppKvCompanion data) {
    return AppKvRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppKvRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppKvRow && other.key == this.key && other.value == this.value);
}

class AppKvCompanion extends UpdateCompanion<AppKvRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppKvCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppKvCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppKvRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppKvCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return AppKvCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppKvCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CgmReadingsTable cgmReadings = $CgmReadingsTable(this);
  late final $BolusEventsTable bolusEvents = $BolusEventsTable(this);
  late final $BasalSegmentsTable basalSegments = $BasalSegmentsTable(this);
  late final $CarbEntriesTable carbEntries = $CarbEntriesTable(this);
  late final $HealthSamplesTable healthSamples = $HealthSamplesTable(this);
  late final $AnnotationsTable annotations = $AnnotationsTable(this);
  late final $PredictionsTable predictions = $PredictionsTable(this);
  late final $ModelRunsTable modelRuns = $ModelRunsTable(this);
  late final $SavedMealsTable savedMeals = $SavedMealsTable(this);
  late final $AppKvTable appKv = $AppKvTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        cgmReadings,
        bolusEvents,
        basalSegments,
        carbEntries,
        healthSamples,
        annotations,
        predictions,
        modelRuns,
        savedMeals,
        appKv
      ];
}

typedef $$CgmReadingsTableCreateCompanionBuilder = CgmReadingsCompanion
    Function({
  Value<int> id,
  required DateTime time,
  required double mgdl,
  Value<int> trend,
  Value<bool> sensorWarmup,
  Value<bool> compressionLow,
  Value<bool> isCalibration,
  Value<String> source,
});
typedef $$CgmReadingsTableUpdateCompanionBuilder = CgmReadingsCompanion
    Function({
  Value<int> id,
  Value<DateTime> time,
  Value<double> mgdl,
  Value<int> trend,
  Value<bool> sensorWarmup,
  Value<bool> compressionLow,
  Value<bool> isCalibration,
  Value<String> source,
});

class $$CgmReadingsTableFilterComposer
    extends Composer<_$AppDatabase, $CgmReadingsTable> {
  $$CgmReadingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get mgdl => $composableBuilder(
      column: $table.mgdl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get trend => $composableBuilder(
      column: $table.trend, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get sensorWarmup => $composableBuilder(
      column: $table.sensorWarmup, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get compressionLow => $composableBuilder(
      column: $table.compressionLow,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCalibration => $composableBuilder(
      column: $table.isCalibration, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));
}

class $$CgmReadingsTableOrderingComposer
    extends Composer<_$AppDatabase, $CgmReadingsTable> {
  $$CgmReadingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get mgdl => $composableBuilder(
      column: $table.mgdl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get trend => $composableBuilder(
      column: $table.trend, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get sensorWarmup => $composableBuilder(
      column: $table.sensorWarmup,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get compressionLow => $composableBuilder(
      column: $table.compressionLow,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCalibration => $composableBuilder(
      column: $table.isCalibration,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));
}

class $$CgmReadingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CgmReadingsTable> {
  $$CgmReadingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<double> get mgdl =>
      $composableBuilder(column: $table.mgdl, builder: (column) => column);

  GeneratedColumn<int> get trend =>
      $composableBuilder(column: $table.trend, builder: (column) => column);

  GeneratedColumn<bool> get sensorWarmup => $composableBuilder(
      column: $table.sensorWarmup, builder: (column) => column);

  GeneratedColumn<bool> get compressionLow => $composableBuilder(
      column: $table.compressionLow, builder: (column) => column);

  GeneratedColumn<bool> get isCalibration => $composableBuilder(
      column: $table.isCalibration, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$CgmReadingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CgmReadingsTable,
    CgmRow,
    $$CgmReadingsTableFilterComposer,
    $$CgmReadingsTableOrderingComposer,
    $$CgmReadingsTableAnnotationComposer,
    $$CgmReadingsTableCreateCompanionBuilder,
    $$CgmReadingsTableUpdateCompanionBuilder,
    (CgmRow, BaseReferences<_$AppDatabase, $CgmReadingsTable, CgmRow>),
    CgmRow,
    PrefetchHooks Function()> {
  $$CgmReadingsTableTableManager(_$AppDatabase db, $CgmReadingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CgmReadingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CgmReadingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CgmReadingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> time = const Value.absent(),
            Value<double> mgdl = const Value.absent(),
            Value<int> trend = const Value.absent(),
            Value<bool> sensorWarmup = const Value.absent(),
            Value<bool> compressionLow = const Value.absent(),
            Value<bool> isCalibration = const Value.absent(),
            Value<String> source = const Value.absent(),
          }) =>
              CgmReadingsCompanion(
            id: id,
            time: time,
            mgdl: mgdl,
            trend: trend,
            sensorWarmup: sensorWarmup,
            compressionLow: compressionLow,
            isCalibration: isCalibration,
            source: source,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime time,
            required double mgdl,
            Value<int> trend = const Value.absent(),
            Value<bool> sensorWarmup = const Value.absent(),
            Value<bool> compressionLow = const Value.absent(),
            Value<bool> isCalibration = const Value.absent(),
            Value<String> source = const Value.absent(),
          }) =>
              CgmReadingsCompanion.insert(
            id: id,
            time: time,
            mgdl: mgdl,
            trend: trend,
            sensorWarmup: sensorWarmup,
            compressionLow: compressionLow,
            isCalibration: isCalibration,
            source: source,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CgmReadingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CgmReadingsTable,
    CgmRow,
    $$CgmReadingsTableFilterComposer,
    $$CgmReadingsTableOrderingComposer,
    $$CgmReadingsTableAnnotationComposer,
    $$CgmReadingsTableCreateCompanionBuilder,
    $$CgmReadingsTableUpdateCompanionBuilder,
    (CgmRow, BaseReferences<_$AppDatabase, $CgmReadingsTable, CgmRow>),
    CgmRow,
    PrefetchHooks Function()>;
typedef $$BolusEventsTableCreateCompanionBuilder = BolusEventsCompanion
    Function({
  Value<int> id,
  required DateTime time,
  required double units,
  Value<double> carbsGrams,
  Value<bool> isExtended,
  Value<int> durationMinutes,
  Value<bool> isAutomatic,
});
typedef $$BolusEventsTableUpdateCompanionBuilder = BolusEventsCompanion
    Function({
  Value<int> id,
  Value<DateTime> time,
  Value<double> units,
  Value<double> carbsGrams,
  Value<bool> isExtended,
  Value<int> durationMinutes,
  Value<bool> isAutomatic,
});

class $$BolusEventsTableFilterComposer
    extends Composer<_$AppDatabase, $BolusEventsTable> {
  $$BolusEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get units => $composableBuilder(
      column: $table.units, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get carbsGrams => $composableBuilder(
      column: $table.carbsGrams, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isExtended => $composableBuilder(
      column: $table.isExtended, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMinutes => $composableBuilder(
      column: $table.durationMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isAutomatic => $composableBuilder(
      column: $table.isAutomatic, builder: (column) => ColumnFilters(column));
}

class $$BolusEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $BolusEventsTable> {
  $$BolusEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get units => $composableBuilder(
      column: $table.units, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get carbsGrams => $composableBuilder(
      column: $table.carbsGrams, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isExtended => $composableBuilder(
      column: $table.isExtended, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
      column: $table.durationMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isAutomatic => $composableBuilder(
      column: $table.isAutomatic, builder: (column) => ColumnOrderings(column));
}

class $$BolusEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BolusEventsTable> {
  $$BolusEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<double> get units =>
      $composableBuilder(column: $table.units, builder: (column) => column);

  GeneratedColumn<double> get carbsGrams => $composableBuilder(
      column: $table.carbsGrams, builder: (column) => column);

  GeneratedColumn<bool> get isExtended => $composableBuilder(
      column: $table.isExtended, builder: (column) => column);

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
      column: $table.durationMinutes, builder: (column) => column);

  GeneratedColumn<bool> get isAutomatic => $composableBuilder(
      column: $table.isAutomatic, builder: (column) => column);
}

class $$BolusEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BolusEventsTable,
    BolusRow,
    $$BolusEventsTableFilterComposer,
    $$BolusEventsTableOrderingComposer,
    $$BolusEventsTableAnnotationComposer,
    $$BolusEventsTableCreateCompanionBuilder,
    $$BolusEventsTableUpdateCompanionBuilder,
    (BolusRow, BaseReferences<_$AppDatabase, $BolusEventsTable, BolusRow>),
    BolusRow,
    PrefetchHooks Function()> {
  $$BolusEventsTableTableManager(_$AppDatabase db, $BolusEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BolusEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BolusEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BolusEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> time = const Value.absent(),
            Value<double> units = const Value.absent(),
            Value<double> carbsGrams = const Value.absent(),
            Value<bool> isExtended = const Value.absent(),
            Value<int> durationMinutes = const Value.absent(),
            Value<bool> isAutomatic = const Value.absent(),
          }) =>
              BolusEventsCompanion(
            id: id,
            time: time,
            units: units,
            carbsGrams: carbsGrams,
            isExtended: isExtended,
            durationMinutes: durationMinutes,
            isAutomatic: isAutomatic,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime time,
            required double units,
            Value<double> carbsGrams = const Value.absent(),
            Value<bool> isExtended = const Value.absent(),
            Value<int> durationMinutes = const Value.absent(),
            Value<bool> isAutomatic = const Value.absent(),
          }) =>
              BolusEventsCompanion.insert(
            id: id,
            time: time,
            units: units,
            carbsGrams: carbsGrams,
            isExtended: isExtended,
            durationMinutes: durationMinutes,
            isAutomatic: isAutomatic,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BolusEventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BolusEventsTable,
    BolusRow,
    $$BolusEventsTableFilterComposer,
    $$BolusEventsTableOrderingComposer,
    $$BolusEventsTableAnnotationComposer,
    $$BolusEventsTableCreateCompanionBuilder,
    $$BolusEventsTableUpdateCompanionBuilder,
    (BolusRow, BaseReferences<_$AppDatabase, $BolusEventsTable, BolusRow>),
    BolusRow,
    PrefetchHooks Function()>;
typedef $$BasalSegmentsTableCreateCompanionBuilder = BasalSegmentsCompanion
    Function({
  Value<int> id,
  required DateTime start,
  required DateTime end,
  required double unitsPerHour,
});
typedef $$BasalSegmentsTableUpdateCompanionBuilder = BasalSegmentsCompanion
    Function({
  Value<int> id,
  Value<DateTime> start,
  Value<DateTime> end,
  Value<double> unitsPerHour,
});

class $$BasalSegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $BasalSegmentsTable> {
  $$BasalSegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get start => $composableBuilder(
      column: $table.start, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get end => $composableBuilder(
      column: $table.end, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get unitsPerHour => $composableBuilder(
      column: $table.unitsPerHour, builder: (column) => ColumnFilters(column));
}

class $$BasalSegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $BasalSegmentsTable> {
  $$BasalSegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get start => $composableBuilder(
      column: $table.start, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get end => $composableBuilder(
      column: $table.end, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get unitsPerHour => $composableBuilder(
      column: $table.unitsPerHour,
      builder: (column) => ColumnOrderings(column));
}

class $$BasalSegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BasalSegmentsTable> {
  $$BasalSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get start =>
      $composableBuilder(column: $table.start, builder: (column) => column);

  GeneratedColumn<DateTime> get end =>
      $composableBuilder(column: $table.end, builder: (column) => column);

  GeneratedColumn<double> get unitsPerHour => $composableBuilder(
      column: $table.unitsPerHour, builder: (column) => column);
}

class $$BasalSegmentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BasalSegmentsTable,
    BasalRow,
    $$BasalSegmentsTableFilterComposer,
    $$BasalSegmentsTableOrderingComposer,
    $$BasalSegmentsTableAnnotationComposer,
    $$BasalSegmentsTableCreateCompanionBuilder,
    $$BasalSegmentsTableUpdateCompanionBuilder,
    (BasalRow, BaseReferences<_$AppDatabase, $BasalSegmentsTable, BasalRow>),
    BasalRow,
    PrefetchHooks Function()> {
  $$BasalSegmentsTableTableManager(_$AppDatabase db, $BasalSegmentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BasalSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BasalSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BasalSegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> start = const Value.absent(),
            Value<DateTime> end = const Value.absent(),
            Value<double> unitsPerHour = const Value.absent(),
          }) =>
              BasalSegmentsCompanion(
            id: id,
            start: start,
            end: end,
            unitsPerHour: unitsPerHour,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime start,
            required DateTime end,
            required double unitsPerHour,
          }) =>
              BasalSegmentsCompanion.insert(
            id: id,
            start: start,
            end: end,
            unitsPerHour: unitsPerHour,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BasalSegmentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BasalSegmentsTable,
    BasalRow,
    $$BasalSegmentsTableFilterComposer,
    $$BasalSegmentsTableOrderingComposer,
    $$BasalSegmentsTableAnnotationComposer,
    $$BasalSegmentsTableCreateCompanionBuilder,
    $$BasalSegmentsTableUpdateCompanionBuilder,
    (BasalRow, BaseReferences<_$AppDatabase, $BasalSegmentsTable, BasalRow>),
    BasalRow,
    PrefetchHooks Function()>;
typedef $$CarbEntriesTableCreateCompanionBuilder = CarbEntriesCompanion
    Function({
  Value<int> id,
  required DateTime time,
  required double grams,
  Value<int> absorptionMinutes,
  Value<String> source,
});
typedef $$CarbEntriesTableUpdateCompanionBuilder = CarbEntriesCompanion
    Function({
  Value<int> id,
  Value<DateTime> time,
  Value<double> grams,
  Value<int> absorptionMinutes,
  Value<String> source,
});

class $$CarbEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CarbEntriesTable> {
  $$CarbEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get grams => $composableBuilder(
      column: $table.grams, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get absorptionMinutes => $composableBuilder(
      column: $table.absorptionMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));
}

class $$CarbEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CarbEntriesTable> {
  $$CarbEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get grams => $composableBuilder(
      column: $table.grams, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get absorptionMinutes => $composableBuilder(
      column: $table.absorptionMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));
}

class $$CarbEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CarbEntriesTable> {
  $$CarbEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<double> get grams =>
      $composableBuilder(column: $table.grams, builder: (column) => column);

  GeneratedColumn<int> get absorptionMinutes => $composableBuilder(
      column: $table.absorptionMinutes, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$CarbEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CarbEntriesTable,
    CarbRow,
    $$CarbEntriesTableFilterComposer,
    $$CarbEntriesTableOrderingComposer,
    $$CarbEntriesTableAnnotationComposer,
    $$CarbEntriesTableCreateCompanionBuilder,
    $$CarbEntriesTableUpdateCompanionBuilder,
    (CarbRow, BaseReferences<_$AppDatabase, $CarbEntriesTable, CarbRow>),
    CarbRow,
    PrefetchHooks Function()> {
  $$CarbEntriesTableTableManager(_$AppDatabase db, $CarbEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CarbEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CarbEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CarbEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> time = const Value.absent(),
            Value<double> grams = const Value.absent(),
            Value<int> absorptionMinutes = const Value.absent(),
            Value<String> source = const Value.absent(),
          }) =>
              CarbEntriesCompanion(
            id: id,
            time: time,
            grams: grams,
            absorptionMinutes: absorptionMinutes,
            source: source,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime time,
            required double grams,
            Value<int> absorptionMinutes = const Value.absent(),
            Value<String> source = const Value.absent(),
          }) =>
              CarbEntriesCompanion.insert(
            id: id,
            time: time,
            grams: grams,
            absorptionMinutes: absorptionMinutes,
            source: source,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CarbEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CarbEntriesTable,
    CarbRow,
    $$CarbEntriesTableFilterComposer,
    $$CarbEntriesTableOrderingComposer,
    $$CarbEntriesTableAnnotationComposer,
    $$CarbEntriesTableCreateCompanionBuilder,
    $$CarbEntriesTableUpdateCompanionBuilder,
    (CarbRow, BaseReferences<_$AppDatabase, $CarbEntriesTable, CarbRow>),
    CarbRow,
    PrefetchHooks Function()>;
typedef $$HealthSamplesTableCreateCompanionBuilder = HealthSamplesCompanion
    Function({
  Value<int> id,
  required DateTime time,
  required String type,
  required double value,
  Value<String> meta,
});
typedef $$HealthSamplesTableUpdateCompanionBuilder = HealthSamplesCompanion
    Function({
  Value<int> id,
  Value<DateTime> time,
  Value<String> type,
  Value<double> value,
  Value<String> meta,
});

class $$HealthSamplesTableFilterComposer
    extends Composer<_$AppDatabase, $HealthSamplesTable> {
  $$HealthSamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get meta => $composableBuilder(
      column: $table.meta, builder: (column) => ColumnFilters(column));
}

class $$HealthSamplesTableOrderingComposer
    extends Composer<_$AppDatabase, $HealthSamplesTable> {
  $$HealthSamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get meta => $composableBuilder(
      column: $table.meta, builder: (column) => ColumnOrderings(column));
}

class $$HealthSamplesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HealthSamplesTable> {
  $$HealthSamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get meta =>
      $composableBuilder(column: $table.meta, builder: (column) => column);
}

class $$HealthSamplesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HealthSamplesTable,
    HealthRow,
    $$HealthSamplesTableFilterComposer,
    $$HealthSamplesTableOrderingComposer,
    $$HealthSamplesTableAnnotationComposer,
    $$HealthSamplesTableCreateCompanionBuilder,
    $$HealthSamplesTableUpdateCompanionBuilder,
    (HealthRow, BaseReferences<_$AppDatabase, $HealthSamplesTable, HealthRow>),
    HealthRow,
    PrefetchHooks Function()> {
  $$HealthSamplesTableTableManager(_$AppDatabase db, $HealthSamplesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HealthSamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HealthSamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HealthSamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> time = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<double> value = const Value.absent(),
            Value<String> meta = const Value.absent(),
          }) =>
              HealthSamplesCompanion(
            id: id,
            time: time,
            type: type,
            value: value,
            meta: meta,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime time,
            required String type,
            required double value,
            Value<String> meta = const Value.absent(),
          }) =>
              HealthSamplesCompanion.insert(
            id: id,
            time: time,
            type: type,
            value: value,
            meta: meta,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HealthSamplesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HealthSamplesTable,
    HealthRow,
    $$HealthSamplesTableFilterComposer,
    $$HealthSamplesTableOrderingComposer,
    $$HealthSamplesTableAnnotationComposer,
    $$HealthSamplesTableCreateCompanionBuilder,
    $$HealthSamplesTableUpdateCompanionBuilder,
    (HealthRow, BaseReferences<_$AppDatabase, $HealthSamplesTable, HealthRow>),
    HealthRow,
    PrefetchHooks Function()>;
typedef $$AnnotationsTableCreateCompanionBuilder = AnnotationsCompanion
    Function({
  required String id,
  required int kind,
  required DateTime start,
  required DateTime end,
  Value<double> carbsGrams,
  Value<String> note,
  Value<double> confidence,
  Value<int> rowid,
});
typedef $$AnnotationsTableUpdateCompanionBuilder = AnnotationsCompanion
    Function({
  Value<String> id,
  Value<int> kind,
  Value<DateTime> start,
  Value<DateTime> end,
  Value<double> carbsGrams,
  Value<String> note,
  Value<double> confidence,
  Value<int> rowid,
});

class $$AnnotationsTableFilterComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get start => $composableBuilder(
      column: $table.start, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get end => $composableBuilder(
      column: $table.end, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get carbsGrams => $composableBuilder(
      column: $table.carbsGrams, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get confidence => $composableBuilder(
      column: $table.confidence, builder: (column) => ColumnFilters(column));
}

class $$AnnotationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get start => $composableBuilder(
      column: $table.start, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get end => $composableBuilder(
      column: $table.end, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get carbsGrams => $composableBuilder(
      column: $table.carbsGrams, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get confidence => $composableBuilder(
      column: $table.confidence, builder: (column) => ColumnOrderings(column));
}

class $$AnnotationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<DateTime> get start =>
      $composableBuilder(column: $table.start, builder: (column) => column);

  GeneratedColumn<DateTime> get end =>
      $composableBuilder(column: $table.end, builder: (column) => column);

  GeneratedColumn<double> get carbsGrams => $composableBuilder(
      column: $table.carbsGrams, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
      column: $table.confidence, builder: (column) => column);
}

class $$AnnotationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AnnotationsTable,
    AnnotationRow,
    $$AnnotationsTableFilterComposer,
    $$AnnotationsTableOrderingComposer,
    $$AnnotationsTableAnnotationComposer,
    $$AnnotationsTableCreateCompanionBuilder,
    $$AnnotationsTableUpdateCompanionBuilder,
    (
      AnnotationRow,
      BaseReferences<_$AppDatabase, $AnnotationsTable, AnnotationRow>
    ),
    AnnotationRow,
    PrefetchHooks Function()> {
  $$AnnotationsTableTableManager(_$AppDatabase db, $AnnotationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnnotationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnnotationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnnotationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> kind = const Value.absent(),
            Value<DateTime> start = const Value.absent(),
            Value<DateTime> end = const Value.absent(),
            Value<double> carbsGrams = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<double> confidence = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnotationsCompanion(
            id: id,
            kind: kind,
            start: start,
            end: end,
            carbsGrams: carbsGrams,
            note: note,
            confidence: confidence,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required int kind,
            required DateTime start,
            required DateTime end,
            Value<double> carbsGrams = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<double> confidence = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnotationsCompanion.insert(
            id: id,
            kind: kind,
            start: start,
            end: end,
            carbsGrams: carbsGrams,
            note: note,
            confidence: confidence,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AnnotationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AnnotationsTable,
    AnnotationRow,
    $$AnnotationsTableFilterComposer,
    $$AnnotationsTableOrderingComposer,
    $$AnnotationsTableAnnotationComposer,
    $$AnnotationsTableCreateCompanionBuilder,
    $$AnnotationsTableUpdateCompanionBuilder,
    (
      AnnotationRow,
      BaseReferences<_$AppDatabase, $AnnotationsTable, AnnotationRow>
    ),
    AnnotationRow,
    PrefetchHooks Function()>;
typedef $$PredictionsTableCreateCompanionBuilder = PredictionsCompanion
    Function({
  Value<int> id,
  required DateTime madeAt,
  required int horizonMinutes,
  required double predictedMgdl,
  required double lowerMgdl,
  required double upperMgdl,
  Value<double?> actualMgdl,
  Value<String> modelId,
});
typedef $$PredictionsTableUpdateCompanionBuilder = PredictionsCompanion
    Function({
  Value<int> id,
  Value<DateTime> madeAt,
  Value<int> horizonMinutes,
  Value<double> predictedMgdl,
  Value<double> lowerMgdl,
  Value<double> upperMgdl,
  Value<double?> actualMgdl,
  Value<String> modelId,
});

class $$PredictionsTableFilterComposer
    extends Composer<_$AppDatabase, $PredictionsTable> {
  $$PredictionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get madeAt => $composableBuilder(
      column: $table.madeAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get horizonMinutes => $composableBuilder(
      column: $table.horizonMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get predictedMgdl => $composableBuilder(
      column: $table.predictedMgdl, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lowerMgdl => $composableBuilder(
      column: $table.lowerMgdl, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get upperMgdl => $composableBuilder(
      column: $table.upperMgdl, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get actualMgdl => $composableBuilder(
      column: $table.actualMgdl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get modelId => $composableBuilder(
      column: $table.modelId, builder: (column) => ColumnFilters(column));
}

class $$PredictionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PredictionsTable> {
  $$PredictionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get madeAt => $composableBuilder(
      column: $table.madeAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get horizonMinutes => $composableBuilder(
      column: $table.horizonMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get predictedMgdl => $composableBuilder(
      column: $table.predictedMgdl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lowerMgdl => $composableBuilder(
      column: $table.lowerMgdl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get upperMgdl => $composableBuilder(
      column: $table.upperMgdl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get actualMgdl => $composableBuilder(
      column: $table.actualMgdl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get modelId => $composableBuilder(
      column: $table.modelId, builder: (column) => ColumnOrderings(column));
}

class $$PredictionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PredictionsTable> {
  $$PredictionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get madeAt =>
      $composableBuilder(column: $table.madeAt, builder: (column) => column);

  GeneratedColumn<int> get horizonMinutes => $composableBuilder(
      column: $table.horizonMinutes, builder: (column) => column);

  GeneratedColumn<double> get predictedMgdl => $composableBuilder(
      column: $table.predictedMgdl, builder: (column) => column);

  GeneratedColumn<double> get lowerMgdl =>
      $composableBuilder(column: $table.lowerMgdl, builder: (column) => column);

  GeneratedColumn<double> get upperMgdl =>
      $composableBuilder(column: $table.upperMgdl, builder: (column) => column);

  GeneratedColumn<double> get actualMgdl => $composableBuilder(
      column: $table.actualMgdl, builder: (column) => column);

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);
}

class $$PredictionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PredictionsTable,
    PredictionRow,
    $$PredictionsTableFilterComposer,
    $$PredictionsTableOrderingComposer,
    $$PredictionsTableAnnotationComposer,
    $$PredictionsTableCreateCompanionBuilder,
    $$PredictionsTableUpdateCompanionBuilder,
    (
      PredictionRow,
      BaseReferences<_$AppDatabase, $PredictionsTable, PredictionRow>
    ),
    PredictionRow,
    PrefetchHooks Function()> {
  $$PredictionsTableTableManager(_$AppDatabase db, $PredictionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PredictionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PredictionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PredictionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> madeAt = const Value.absent(),
            Value<int> horizonMinutes = const Value.absent(),
            Value<double> predictedMgdl = const Value.absent(),
            Value<double> lowerMgdl = const Value.absent(),
            Value<double> upperMgdl = const Value.absent(),
            Value<double?> actualMgdl = const Value.absent(),
            Value<String> modelId = const Value.absent(),
          }) =>
              PredictionsCompanion(
            id: id,
            madeAt: madeAt,
            horizonMinutes: horizonMinutes,
            predictedMgdl: predictedMgdl,
            lowerMgdl: lowerMgdl,
            upperMgdl: upperMgdl,
            actualMgdl: actualMgdl,
            modelId: modelId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime madeAt,
            required int horizonMinutes,
            required double predictedMgdl,
            required double lowerMgdl,
            required double upperMgdl,
            Value<double?> actualMgdl = const Value.absent(),
            Value<String> modelId = const Value.absent(),
          }) =>
              PredictionsCompanion.insert(
            id: id,
            madeAt: madeAt,
            horizonMinutes: horizonMinutes,
            predictedMgdl: predictedMgdl,
            lowerMgdl: lowerMgdl,
            upperMgdl: upperMgdl,
            actualMgdl: actualMgdl,
            modelId: modelId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PredictionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PredictionsTable,
    PredictionRow,
    $$PredictionsTableFilterComposer,
    $$PredictionsTableOrderingComposer,
    $$PredictionsTableAnnotationComposer,
    $$PredictionsTableCreateCompanionBuilder,
    $$PredictionsTableUpdateCompanionBuilder,
    (
      PredictionRow,
      BaseReferences<_$AppDatabase, $PredictionsTable, PredictionRow>
    ),
    PredictionRow,
    PrefetchHooks Function()>;
typedef $$ModelRunsTableCreateCompanionBuilder = ModelRunsCompanion Function({
  required String id,
  required String stage,
  required DateTime createdAt,
  required int trainedOnDays,
  Value<String> metricsJson,
  Value<String> weightsJson,
  Value<int> rowid,
});
typedef $$ModelRunsTableUpdateCompanionBuilder = ModelRunsCompanion Function({
  Value<String> id,
  Value<String> stage,
  Value<DateTime> createdAt,
  Value<int> trainedOnDays,
  Value<String> metricsJson,
  Value<String> weightsJson,
  Value<int> rowid,
});

class $$ModelRunsTableFilterComposer
    extends Composer<_$AppDatabase, $ModelRunsTable> {
  $$ModelRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stage => $composableBuilder(
      column: $table.stage, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get trainedOnDays => $composableBuilder(
      column: $table.trainedOnDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metricsJson => $composableBuilder(
      column: $table.metricsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get weightsJson => $composableBuilder(
      column: $table.weightsJson, builder: (column) => ColumnFilters(column));
}

class $$ModelRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $ModelRunsTable> {
  $$ModelRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stage => $composableBuilder(
      column: $table.stage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get trainedOnDays => $composableBuilder(
      column: $table.trainedOnDays,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metricsJson => $composableBuilder(
      column: $table.metricsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get weightsJson => $composableBuilder(
      column: $table.weightsJson, builder: (column) => ColumnOrderings(column));
}

class $$ModelRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModelRunsTable> {
  $$ModelRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get trainedOnDays => $composableBuilder(
      column: $table.trainedOnDays, builder: (column) => column);

  GeneratedColumn<String> get metricsJson => $composableBuilder(
      column: $table.metricsJson, builder: (column) => column);

  GeneratedColumn<String> get weightsJson => $composableBuilder(
      column: $table.weightsJson, builder: (column) => column);
}

class $$ModelRunsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ModelRunsTable,
    ModelRunRow,
    $$ModelRunsTableFilterComposer,
    $$ModelRunsTableOrderingComposer,
    $$ModelRunsTableAnnotationComposer,
    $$ModelRunsTableCreateCompanionBuilder,
    $$ModelRunsTableUpdateCompanionBuilder,
    (ModelRunRow, BaseReferences<_$AppDatabase, $ModelRunsTable, ModelRunRow>),
    ModelRunRow,
    PrefetchHooks Function()> {
  $$ModelRunsTableTableManager(_$AppDatabase db, $ModelRunsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> stage = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> trainedOnDays = const Value.absent(),
            Value<String> metricsJson = const Value.absent(),
            Value<String> weightsJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ModelRunsCompanion(
            id: id,
            stage: stage,
            createdAt: createdAt,
            trainedOnDays: trainedOnDays,
            metricsJson: metricsJson,
            weightsJson: weightsJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String stage,
            required DateTime createdAt,
            required int trainedOnDays,
            Value<String> metricsJson = const Value.absent(),
            Value<String> weightsJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ModelRunsCompanion.insert(
            id: id,
            stage: stage,
            createdAt: createdAt,
            trainedOnDays: trainedOnDays,
            metricsJson: metricsJson,
            weightsJson: weightsJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ModelRunsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ModelRunsTable,
    ModelRunRow,
    $$ModelRunsTableFilterComposer,
    $$ModelRunsTableOrderingComposer,
    $$ModelRunsTableAnnotationComposer,
    $$ModelRunsTableCreateCompanionBuilder,
    $$ModelRunsTableUpdateCompanionBuilder,
    (ModelRunRow, BaseReferences<_$AppDatabase, $ModelRunsTable, ModelRunRow>),
    ModelRunRow,
    PrefetchHooks Function()>;
typedef $$SavedMealsTableCreateCompanionBuilder = SavedMealsCompanion Function({
  required String id,
  required String name,
  Value<String> emoji,
  Value<String> category,
  required double carbsGrams,
  Value<bool> fatProteinHeavy,
  Value<int> absorptionMinutes,
  Value<int> peakOffsetMinutes,
  Value<String> outcomesJson,
  Value<int> rowid,
});
typedef $$SavedMealsTableUpdateCompanionBuilder = SavedMealsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> emoji,
  Value<String> category,
  Value<double> carbsGrams,
  Value<bool> fatProteinHeavy,
  Value<int> absorptionMinutes,
  Value<int> peakOffsetMinutes,
  Value<String> outcomesJson,
  Value<int> rowid,
});

class $$SavedMealsTableFilterComposer
    extends Composer<_$AppDatabase, $SavedMealsTable> {
  $$SavedMealsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get emoji => $composableBuilder(
      column: $table.emoji, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get carbsGrams => $composableBuilder(
      column: $table.carbsGrams, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get fatProteinHeavy => $composableBuilder(
      column: $table.fatProteinHeavy,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get absorptionMinutes => $composableBuilder(
      column: $table.absorptionMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get peakOffsetMinutes => $composableBuilder(
      column: $table.peakOffsetMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get outcomesJson => $composableBuilder(
      column: $table.outcomesJson, builder: (column) => ColumnFilters(column));
}

class $$SavedMealsTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedMealsTable> {
  $$SavedMealsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get emoji => $composableBuilder(
      column: $table.emoji, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get carbsGrams => $composableBuilder(
      column: $table.carbsGrams, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get fatProteinHeavy => $composableBuilder(
      column: $table.fatProteinHeavy,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get absorptionMinutes => $composableBuilder(
      column: $table.absorptionMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get peakOffsetMinutes => $composableBuilder(
      column: $table.peakOffsetMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get outcomesJson => $composableBuilder(
      column: $table.outcomesJson,
      builder: (column) => ColumnOrderings(column));
}

class $$SavedMealsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedMealsTable> {
  $$SavedMealsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<double> get carbsGrams => $composableBuilder(
      column: $table.carbsGrams, builder: (column) => column);

  GeneratedColumn<bool> get fatProteinHeavy => $composableBuilder(
      column: $table.fatProteinHeavy, builder: (column) => column);

  GeneratedColumn<int> get absorptionMinutes => $composableBuilder(
      column: $table.absorptionMinutes, builder: (column) => column);

  GeneratedColumn<int> get peakOffsetMinutes => $composableBuilder(
      column: $table.peakOffsetMinutes, builder: (column) => column);

  GeneratedColumn<String> get outcomesJson => $composableBuilder(
      column: $table.outcomesJson, builder: (column) => column);
}

class $$SavedMealsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SavedMealsTable,
    SavedMealRow,
    $$SavedMealsTableFilterComposer,
    $$SavedMealsTableOrderingComposer,
    $$SavedMealsTableAnnotationComposer,
    $$SavedMealsTableCreateCompanionBuilder,
    $$SavedMealsTableUpdateCompanionBuilder,
    (
      SavedMealRow,
      BaseReferences<_$AppDatabase, $SavedMealsTable, SavedMealRow>
    ),
    SavedMealRow,
    PrefetchHooks Function()> {
  $$SavedMealsTableTableManager(_$AppDatabase db, $SavedMealsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedMealsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedMealsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedMealsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> emoji = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<double> carbsGrams = const Value.absent(),
            Value<bool> fatProteinHeavy = const Value.absent(),
            Value<int> absorptionMinutes = const Value.absent(),
            Value<int> peakOffsetMinutes = const Value.absent(),
            Value<String> outcomesJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SavedMealsCompanion(
            id: id,
            name: name,
            emoji: emoji,
            category: category,
            carbsGrams: carbsGrams,
            fatProteinHeavy: fatProteinHeavy,
            absorptionMinutes: absorptionMinutes,
            peakOffsetMinutes: peakOffsetMinutes,
            outcomesJson: outcomesJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String> emoji = const Value.absent(),
            Value<String> category = const Value.absent(),
            required double carbsGrams,
            Value<bool> fatProteinHeavy = const Value.absent(),
            Value<int> absorptionMinutes = const Value.absent(),
            Value<int> peakOffsetMinutes = const Value.absent(),
            Value<String> outcomesJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SavedMealsCompanion.insert(
            id: id,
            name: name,
            emoji: emoji,
            category: category,
            carbsGrams: carbsGrams,
            fatProteinHeavy: fatProteinHeavy,
            absorptionMinutes: absorptionMinutes,
            peakOffsetMinutes: peakOffsetMinutes,
            outcomesJson: outcomesJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SavedMealsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SavedMealsTable,
    SavedMealRow,
    $$SavedMealsTableFilterComposer,
    $$SavedMealsTableOrderingComposer,
    $$SavedMealsTableAnnotationComposer,
    $$SavedMealsTableCreateCompanionBuilder,
    $$SavedMealsTableUpdateCompanionBuilder,
    (
      SavedMealRow,
      BaseReferences<_$AppDatabase, $SavedMealsTable, SavedMealRow>
    ),
    SavedMealRow,
    PrefetchHooks Function()>;
typedef $$AppKvTableCreateCompanionBuilder = AppKvCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppKvTableUpdateCompanionBuilder = AppKvCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppKvTableFilterComposer extends Composer<_$AppDatabase, $AppKvTable> {
  $$AppKvTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppKvTableOrderingComposer
    extends Composer<_$AppDatabase, $AppKvTable> {
  $$AppKvTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppKvTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppKvTable> {
  $$AppKvTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppKvTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppKvTable,
    AppKvRow,
    $$AppKvTableFilterComposer,
    $$AppKvTableOrderingComposer,
    $$AppKvTableAnnotationComposer,
    $$AppKvTableCreateCompanionBuilder,
    $$AppKvTableUpdateCompanionBuilder,
    (AppKvRow, BaseReferences<_$AppDatabase, $AppKvTable, AppKvRow>),
    AppKvRow,
    PrefetchHooks Function()> {
  $$AppKvTableTableManager(_$AppDatabase db, $AppKvTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppKvTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppKvTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppKvTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppKvCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppKvCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppKvTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppKvTable,
    AppKvRow,
    $$AppKvTableFilterComposer,
    $$AppKvTableOrderingComposer,
    $$AppKvTableAnnotationComposer,
    $$AppKvTableCreateCompanionBuilder,
    $$AppKvTableUpdateCompanionBuilder,
    (AppKvRow, BaseReferences<_$AppDatabase, $AppKvTable, AppKvRow>),
    AppKvRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CgmReadingsTableTableManager get cgmReadings =>
      $$CgmReadingsTableTableManager(_db, _db.cgmReadings);
  $$BolusEventsTableTableManager get bolusEvents =>
      $$BolusEventsTableTableManager(_db, _db.bolusEvents);
  $$BasalSegmentsTableTableManager get basalSegments =>
      $$BasalSegmentsTableTableManager(_db, _db.basalSegments);
  $$CarbEntriesTableTableManager get carbEntries =>
      $$CarbEntriesTableTableManager(_db, _db.carbEntries);
  $$HealthSamplesTableTableManager get healthSamples =>
      $$HealthSamplesTableTableManager(_db, _db.healthSamples);
  $$AnnotationsTableTableManager get annotations =>
      $$AnnotationsTableTableManager(_db, _db.annotations);
  $$PredictionsTableTableManager get predictions =>
      $$PredictionsTableTableManager(_db, _db.predictions);
  $$ModelRunsTableTableManager get modelRuns =>
      $$ModelRunsTableTableManager(_db, _db.modelRuns);
  $$SavedMealsTableTableManager get savedMeals =>
      $$SavedMealsTableTableManager(_db, _db.savedMeals);
  $$AppKvTableTableManager get appKv =>
      $$AppKvTableTableManager(_db, _db.appKv);
}
