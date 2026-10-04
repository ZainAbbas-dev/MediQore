// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $HouseholdsTable extends Households
    with TableInfo<$HouseholdsTable, LocalHousehold> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HouseholdsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _householdNumberMeta = const VerificationMeta(
    'householdNumber',
  );
  @override
  late final GeneratedColumn<String> householdNumber = GeneratedColumn<String>(
    'household_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _villageMeta = const VerificationMeta(
    'village',
  );
  @override
  late final GeneratedColumn<String> village = GeneratedColumn<String>(
    'village',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdOnDeviceMeta = const VerificationMeta(
    'createdOnDevice',
  );
  @override
  late final GeneratedColumn<DateTime> createdOnDevice =
      GeneratedColumn<DateTime>(
        'created_on_device',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _areaIdMeta = const VerificationMeta('areaId');
  @override
  late final GeneratedColumn<String> areaId = GeneratedColumn<String>(
    'area_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverSeq,
    householdNumber,
    address,
    village,
    latitude,
    longitude,
    createdOnDevice,
    deletedAt,
    areaId,
    createdBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'households';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalHousehold> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('household_number')) {
      context.handle(
        _householdNumberMeta,
        householdNumber.isAcceptableOrUnknown(
          data['household_number']!,
          _householdNumberMeta,
        ),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('village')) {
      context.handle(
        _villageMeta,
        village.isAcceptableOrUnknown(data['village']!, _villageMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('created_on_device')) {
      context.handle(
        _createdOnDeviceMeta,
        createdOnDevice.isAcceptableOrUnknown(
          data['created_on_device']!,
          _createdOnDeviceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdOnDeviceMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('area_id')) {
      context.handle(
        _areaIdMeta,
        areaId.isAcceptableOrUnknown(data['area_id']!, _areaIdMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalHousehold map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalHousehold(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      householdNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}household_number'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      village: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}village'],
      ),
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      createdOnDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_on_device'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      areaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}area_id'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
    );
  }

  @override
  $HouseholdsTable createAlias(String alias) {
    return $HouseholdsTable(attachedDatabase, alias);
  }
}

class LocalHousehold extends DataClass implements Insertable<LocalHousehold> {
  final String id;
  final int? serverSeq;
  final String? householdNumber;
  final String? address;
  final String? village;
  final double? latitude;
  final double? longitude;
  final DateTime createdOnDevice;
  final DateTime? deletedAt;
  final String? areaId;
  final String? createdBy;
  const LocalHousehold({
    required this.id,
    this.serverSeq,
    this.householdNumber,
    this.address,
    this.village,
    this.latitude,
    this.longitude,
    required this.createdOnDevice,
    this.deletedAt,
    this.areaId,
    this.createdBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    if (!nullToAbsent || householdNumber != null) {
      map['household_number'] = Variable<String>(householdNumber);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || village != null) {
      map['village'] = Variable<String>(village);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    map['created_on_device'] = Variable<DateTime>(createdOnDevice);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || areaId != null) {
      map['area_id'] = Variable<String>(areaId);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    return map;
  }

  HouseholdsCompanion toCompanion(bool nullToAbsent) {
    return HouseholdsCompanion(
      id: Value(id),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      householdNumber: householdNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(householdNumber),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      village: village == null && nullToAbsent
          ? const Value.absent()
          : Value(village),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      createdOnDevice: Value(createdOnDevice),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      areaId: areaId == null && nullToAbsent
          ? const Value.absent()
          : Value(areaId),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
    );
  }

  factory LocalHousehold.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalHousehold(
      id: serializer.fromJson<String>(json['id']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      householdNumber: serializer.fromJson<String?>(json['householdNumber']),
      address: serializer.fromJson<String?>(json['address']),
      village: serializer.fromJson<String?>(json['village']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      createdOnDevice: serializer.fromJson<DateTime>(json['createdOnDevice']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      areaId: serializer.fromJson<String?>(json['areaId']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'householdNumber': serializer.toJson<String?>(householdNumber),
      'address': serializer.toJson<String?>(address),
      'village': serializer.toJson<String?>(village),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'createdOnDevice': serializer.toJson<DateTime>(createdOnDevice),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'areaId': serializer.toJson<String?>(areaId),
      'createdBy': serializer.toJson<String?>(createdBy),
    };
  }

  LocalHousehold copyWith({
    String? id,
    Value<int?> serverSeq = const Value.absent(),
    Value<String?> householdNumber = const Value.absent(),
    Value<String?> address = const Value.absent(),
    Value<String?> village = const Value.absent(),
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    DateTime? createdOnDevice,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<String?> areaId = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
  }) => LocalHousehold(
    id: id ?? this.id,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    householdNumber: householdNumber.present
        ? householdNumber.value
        : this.householdNumber,
    address: address.present ? address.value : this.address,
    village: village.present ? village.value : this.village,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    createdOnDevice: createdOnDevice ?? this.createdOnDevice,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    areaId: areaId.present ? areaId.value : this.areaId,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
  );
  LocalHousehold copyWithCompanion(HouseholdsCompanion data) {
    return LocalHousehold(
      id: data.id.present ? data.id.value : this.id,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      householdNumber: data.householdNumber.present
          ? data.householdNumber.value
          : this.householdNumber,
      address: data.address.present ? data.address.value : this.address,
      village: data.village.present ? data.village.value : this.village,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      createdOnDevice: data.createdOnDevice.present
          ? data.createdOnDevice.value
          : this.createdOnDevice,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      areaId: data.areaId.present ? data.areaId.value : this.areaId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalHousehold(')
          ..write('id: $id, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('householdNumber: $householdNumber, ')
          ..write('address: $address, ')
          ..write('village: $village, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('createdOnDevice: $createdOnDevice, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('areaId: $areaId, ')
          ..write('createdBy: $createdBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverSeq,
    householdNumber,
    address,
    village,
    latitude,
    longitude,
    createdOnDevice,
    deletedAt,
    areaId,
    createdBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalHousehold &&
          other.id == this.id &&
          other.serverSeq == this.serverSeq &&
          other.householdNumber == this.householdNumber &&
          other.address == this.address &&
          other.village == this.village &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.createdOnDevice == this.createdOnDevice &&
          other.deletedAt == this.deletedAt &&
          other.areaId == this.areaId &&
          other.createdBy == this.createdBy);
}

class HouseholdsCompanion extends UpdateCompanion<LocalHousehold> {
  final Value<String> id;
  final Value<int?> serverSeq;
  final Value<String?> householdNumber;
  final Value<String?> address;
  final Value<String?> village;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<DateTime> createdOnDevice;
  final Value<DateTime?> deletedAt;
  final Value<String?> areaId;
  final Value<String?> createdBy;
  final Value<int> rowid;
  const HouseholdsCompanion({
    this.id = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.householdNumber = const Value.absent(),
    this.address = const Value.absent(),
    this.village = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.createdOnDevice = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.areaId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HouseholdsCompanion.insert({
    required String id,
    this.serverSeq = const Value.absent(),
    this.householdNumber = const Value.absent(),
    this.address = const Value.absent(),
    this.village = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    required DateTime createdOnDevice,
    this.deletedAt = const Value.absent(),
    this.areaId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdOnDevice = Value(createdOnDevice);
  static Insertable<LocalHousehold> custom({
    Expression<String>? id,
    Expression<int>? serverSeq,
    Expression<String>? householdNumber,
    Expression<String>? address,
    Expression<String>? village,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<DateTime>? createdOnDevice,
    Expression<DateTime>? deletedAt,
    Expression<String>? areaId,
    Expression<String>? createdBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (householdNumber != null) 'household_number': householdNumber,
      if (address != null) 'address': address,
      if (village != null) 'village': village,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (createdOnDevice != null) 'created_on_device': createdOnDevice,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (areaId != null) 'area_id': areaId,
      if (createdBy != null) 'created_by': createdBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HouseholdsCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverSeq,
    Value<String?>? householdNumber,
    Value<String?>? address,
    Value<String?>? village,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<DateTime>? createdOnDevice,
    Value<DateTime?>? deletedAt,
    Value<String?>? areaId,
    Value<String?>? createdBy,
    Value<int>? rowid,
  }) {
    return HouseholdsCompanion(
      id: id ?? this.id,
      serverSeq: serverSeq ?? this.serverSeq,
      householdNumber: householdNumber ?? this.householdNumber,
      address: address ?? this.address,
      village: village ?? this.village,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdOnDevice: createdOnDevice ?? this.createdOnDevice,
      deletedAt: deletedAt ?? this.deletedAt,
      areaId: areaId ?? this.areaId,
      createdBy: createdBy ?? this.createdBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (householdNumber.present) {
      map['household_number'] = Variable<String>(householdNumber.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (village.present) {
      map['village'] = Variable<String>(village.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (createdOnDevice.present) {
      map['created_on_device'] = Variable<DateTime>(createdOnDevice.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (areaId.present) {
      map['area_id'] = Variable<String>(areaId.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HouseholdsCompanion(')
          ..write('id: $id, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('householdNumber: $householdNumber, ')
          ..write('address: $address, ')
          ..write('village: $village, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('createdOnDevice: $createdOnDevice, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('areaId: $areaId, ')
          ..write('createdBy: $createdBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WomenTable extends Women with TableInfo<$WomenTable, LocalWoman> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WomenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _areaIdMeta = const VerificationMeta('areaId');
  @override
  late final GeneratedColumn<String> areaId = GeneratedColumn<String>(
    'area_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdOnDeviceMeta = const VerificationMeta(
    'createdOnDevice',
  );
  @override
  late final GeneratedColumn<DateTime> createdOnDevice =
      GeneratedColumn<DateTime>(
        'created_on_device',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _householdIdMeta = const VerificationMeta(
    'householdId',
  );
  @override
  late final GeneratedColumn<String> householdId = GeneratedColumn<String>(
    'household_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patientCodeMeta = const VerificationMeta(
    'patientCode',
  );
  @override
  late final GeneratedColumn<String> patientCode = GeneratedColumn<String>(
    'patient_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<int> age = GeneratedColumn<int>(
    'age',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _husbandNameMeta = const VerificationMeta(
    'husbandName',
  );
  @override
  late final GeneratedColumn<String> husbandName = GeneratedColumn<String>(
    'husband_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactNumberMeta = const VerificationMeta(
    'contactNumber',
  );
  @override
  late final GeneratedColumn<String> contactNumber = GeneratedColumn<String>(
    'contact_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverSeq,
    areaId,
    createdBy,
    createdOnDevice,
    deletedAt,
    householdId,
    patientCode,
    name,
    age,
    husbandName,
    contactNumber,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'women';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalWoman> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('area_id')) {
      context.handle(
        _areaIdMeta,
        areaId.isAcceptableOrUnknown(data['area_id']!, _areaIdMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('created_on_device')) {
      context.handle(
        _createdOnDeviceMeta,
        createdOnDevice.isAcceptableOrUnknown(
          data['created_on_device']!,
          _createdOnDeviceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdOnDeviceMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('household_id')) {
      context.handle(
        _householdIdMeta,
        householdId.isAcceptableOrUnknown(
          data['household_id']!,
          _householdIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_householdIdMeta);
    }
    if (data.containsKey('patient_code')) {
      context.handle(
        _patientCodeMeta,
        patientCode.isAcceptableOrUnknown(
          data['patient_code']!,
          _patientCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_patientCodeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('age')) {
      context.handle(
        _ageMeta,
        age.isAcceptableOrUnknown(data['age']!, _ageMeta),
      );
    }
    if (data.containsKey('husband_name')) {
      context.handle(
        _husbandNameMeta,
        husbandName.isAcceptableOrUnknown(
          data['husband_name']!,
          _husbandNameMeta,
        ),
      );
    }
    if (data.containsKey('contact_number')) {
      context.handle(
        _contactNumberMeta,
        contactNumber.isAcceptableOrUnknown(
          data['contact_number']!,
          _contactNumberMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalWoman map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalWoman(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      areaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}area_id'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      createdOnDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_on_device'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      householdId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}household_id'],
      )!,
      patientCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}patient_code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      age: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age'],
      ),
      husbandName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}husband_name'],
      ),
      contactNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_number'],
      ),
    );
  }

  @override
  $WomenTable createAlias(String alias) {
    return $WomenTable(attachedDatabase, alias);
  }
}

class LocalWoman extends DataClass implements Insertable<LocalWoman> {
  final String id;
  final int? serverSeq;
  final String? areaId;
  final String? createdBy;
  final DateTime createdOnDevice;
  final DateTime? deletedAt;

  /// No foreign key: a pulled woman can arrive before her household.
  final String householdId;
  final String patientCode;
  final String name;
  final int? age;
  final String? husbandName;
  final String? contactNumber;
  const LocalWoman({
    required this.id,
    this.serverSeq,
    this.areaId,
    this.createdBy,
    required this.createdOnDevice,
    this.deletedAt,
    required this.householdId,
    required this.patientCode,
    required this.name,
    this.age,
    this.husbandName,
    this.contactNumber,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    if (!nullToAbsent || areaId != null) {
      map['area_id'] = Variable<String>(areaId);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    map['created_on_device'] = Variable<DateTime>(createdOnDevice);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['household_id'] = Variable<String>(householdId);
    map['patient_code'] = Variable<String>(patientCode);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || age != null) {
      map['age'] = Variable<int>(age);
    }
    if (!nullToAbsent || husbandName != null) {
      map['husband_name'] = Variable<String>(husbandName);
    }
    if (!nullToAbsent || contactNumber != null) {
      map['contact_number'] = Variable<String>(contactNumber);
    }
    return map;
  }

  WomenCompanion toCompanion(bool nullToAbsent) {
    return WomenCompanion(
      id: Value(id),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      areaId: areaId == null && nullToAbsent
          ? const Value.absent()
          : Value(areaId),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      createdOnDevice: Value(createdOnDevice),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      householdId: Value(householdId),
      patientCode: Value(patientCode),
      name: Value(name),
      age: age == null && nullToAbsent ? const Value.absent() : Value(age),
      husbandName: husbandName == null && nullToAbsent
          ? const Value.absent()
          : Value(husbandName),
      contactNumber: contactNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(contactNumber),
    );
  }

  factory LocalWoman.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalWoman(
      id: serializer.fromJson<String>(json['id']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      areaId: serializer.fromJson<String?>(json['areaId']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      createdOnDevice: serializer.fromJson<DateTime>(json['createdOnDevice']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      householdId: serializer.fromJson<String>(json['householdId']),
      patientCode: serializer.fromJson<String>(json['patientCode']),
      name: serializer.fromJson<String>(json['name']),
      age: serializer.fromJson<int?>(json['age']),
      husbandName: serializer.fromJson<String?>(json['husbandName']),
      contactNumber: serializer.fromJson<String?>(json['contactNumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'areaId': serializer.toJson<String?>(areaId),
      'createdBy': serializer.toJson<String?>(createdBy),
      'createdOnDevice': serializer.toJson<DateTime>(createdOnDevice),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'householdId': serializer.toJson<String>(householdId),
      'patientCode': serializer.toJson<String>(patientCode),
      'name': serializer.toJson<String>(name),
      'age': serializer.toJson<int?>(age),
      'husbandName': serializer.toJson<String?>(husbandName),
      'contactNumber': serializer.toJson<String?>(contactNumber),
    };
  }

  LocalWoman copyWith({
    String? id,
    Value<int?> serverSeq = const Value.absent(),
    Value<String?> areaId = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
    DateTime? createdOnDevice,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? householdId,
    String? patientCode,
    String? name,
    Value<int?> age = const Value.absent(),
    Value<String?> husbandName = const Value.absent(),
    Value<String?> contactNumber = const Value.absent(),
  }) => LocalWoman(
    id: id ?? this.id,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    areaId: areaId.present ? areaId.value : this.areaId,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    createdOnDevice: createdOnDevice ?? this.createdOnDevice,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    householdId: householdId ?? this.householdId,
    patientCode: patientCode ?? this.patientCode,
    name: name ?? this.name,
    age: age.present ? age.value : this.age,
    husbandName: husbandName.present ? husbandName.value : this.husbandName,
    contactNumber: contactNumber.present
        ? contactNumber.value
        : this.contactNumber,
  );
  LocalWoman copyWithCompanion(WomenCompanion data) {
    return LocalWoman(
      id: data.id.present ? data.id.value : this.id,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      areaId: data.areaId.present ? data.areaId.value : this.areaId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdOnDevice: data.createdOnDevice.present
          ? data.createdOnDevice.value
          : this.createdOnDevice,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      householdId: data.householdId.present
          ? data.householdId.value
          : this.householdId,
      patientCode: data.patientCode.present
          ? data.patientCode.value
          : this.patientCode,
      name: data.name.present ? data.name.value : this.name,
      age: data.age.present ? data.age.value : this.age,
      husbandName: data.husbandName.present
          ? data.husbandName.value
          : this.husbandName,
      contactNumber: data.contactNumber.present
          ? data.contactNumber.value
          : this.contactNumber,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalWoman(')
          ..write('id: $id, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('areaId: $areaId, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdOnDevice: $createdOnDevice, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('householdId: $householdId, ')
          ..write('patientCode: $patientCode, ')
          ..write('name: $name, ')
          ..write('age: $age, ')
          ..write('husbandName: $husbandName, ')
          ..write('contactNumber: $contactNumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverSeq,
    areaId,
    createdBy,
    createdOnDevice,
    deletedAt,
    householdId,
    patientCode,
    name,
    age,
    husbandName,
    contactNumber,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalWoman &&
          other.id == this.id &&
          other.serverSeq == this.serverSeq &&
          other.areaId == this.areaId &&
          other.createdBy == this.createdBy &&
          other.createdOnDevice == this.createdOnDevice &&
          other.deletedAt == this.deletedAt &&
          other.householdId == this.householdId &&
          other.patientCode == this.patientCode &&
          other.name == this.name &&
          other.age == this.age &&
          other.husbandName == this.husbandName &&
          other.contactNumber == this.contactNumber);
}

class WomenCompanion extends UpdateCompanion<LocalWoman> {
  final Value<String> id;
  final Value<int?> serverSeq;
  final Value<String?> areaId;
  final Value<String?> createdBy;
  final Value<DateTime> createdOnDevice;
  final Value<DateTime?> deletedAt;
  final Value<String> householdId;
  final Value<String> patientCode;
  final Value<String> name;
  final Value<int?> age;
  final Value<String?> husbandName;
  final Value<String?> contactNumber;
  final Value<int> rowid;
  const WomenCompanion({
    this.id = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.areaId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdOnDevice = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.householdId = const Value.absent(),
    this.patientCode = const Value.absent(),
    this.name = const Value.absent(),
    this.age = const Value.absent(),
    this.husbandName = const Value.absent(),
    this.contactNumber = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WomenCompanion.insert({
    required String id,
    this.serverSeq = const Value.absent(),
    this.areaId = const Value.absent(),
    this.createdBy = const Value.absent(),
    required DateTime createdOnDevice,
    this.deletedAt = const Value.absent(),
    required String householdId,
    required String patientCode,
    required String name,
    this.age = const Value.absent(),
    this.husbandName = const Value.absent(),
    this.contactNumber = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdOnDevice = Value(createdOnDevice),
       householdId = Value(householdId),
       patientCode = Value(patientCode),
       name = Value(name);
  static Insertable<LocalWoman> custom({
    Expression<String>? id,
    Expression<int>? serverSeq,
    Expression<String>? areaId,
    Expression<String>? createdBy,
    Expression<DateTime>? createdOnDevice,
    Expression<DateTime>? deletedAt,
    Expression<String>? householdId,
    Expression<String>? patientCode,
    Expression<String>? name,
    Expression<int>? age,
    Expression<String>? husbandName,
    Expression<String>? contactNumber,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (areaId != null) 'area_id': areaId,
      if (createdBy != null) 'created_by': createdBy,
      if (createdOnDevice != null) 'created_on_device': createdOnDevice,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (householdId != null) 'household_id': householdId,
      if (patientCode != null) 'patient_code': patientCode,
      if (name != null) 'name': name,
      if (age != null) 'age': age,
      if (husbandName != null) 'husband_name': husbandName,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WomenCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverSeq,
    Value<String?>? areaId,
    Value<String?>? createdBy,
    Value<DateTime>? createdOnDevice,
    Value<DateTime?>? deletedAt,
    Value<String>? householdId,
    Value<String>? patientCode,
    Value<String>? name,
    Value<int?>? age,
    Value<String?>? husbandName,
    Value<String?>? contactNumber,
    Value<int>? rowid,
  }) {
    return WomenCompanion(
      id: id ?? this.id,
      serverSeq: serverSeq ?? this.serverSeq,
      areaId: areaId ?? this.areaId,
      createdBy: createdBy ?? this.createdBy,
      createdOnDevice: createdOnDevice ?? this.createdOnDevice,
      deletedAt: deletedAt ?? this.deletedAt,
      householdId: householdId ?? this.householdId,
      patientCode: patientCode ?? this.patientCode,
      name: name ?? this.name,
      age: age ?? this.age,
      husbandName: husbandName ?? this.husbandName,
      contactNumber: contactNumber ?? this.contactNumber,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (areaId.present) {
      map['area_id'] = Variable<String>(areaId.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdOnDevice.present) {
      map['created_on_device'] = Variable<DateTime>(createdOnDevice.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (householdId.present) {
      map['household_id'] = Variable<String>(householdId.value);
    }
    if (patientCode.present) {
      map['patient_code'] = Variable<String>(patientCode.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (age.present) {
      map['age'] = Variable<int>(age.value);
    }
    if (husbandName.present) {
      map['husband_name'] = Variable<String>(husbandName.value);
    }
    if (contactNumber.present) {
      map['contact_number'] = Variable<String>(contactNumber.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WomenCompanion(')
          ..write('id: $id, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('areaId: $areaId, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdOnDevice: $createdOnDevice, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('householdId: $householdId, ')
          ..write('patientCode: $patientCode, ')
          ..write('name: $name, ')
          ..write('age: $age, ')
          ..write('husbandName: $husbandName, ')
          ..write('contactNumber: $contactNumber, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PregnanciesTable extends Pregnancies
    with TableInfo<$PregnanciesTable, LocalPregnancy> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PregnanciesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _areaIdMeta = const VerificationMeta('areaId');
  @override
  late final GeneratedColumn<String> areaId = GeneratedColumn<String>(
    'area_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdOnDeviceMeta = const VerificationMeta(
    'createdOnDevice',
  );
  @override
  late final GeneratedColumn<DateTime> createdOnDevice =
      GeneratedColumn<DateTime>(
        'created_on_device',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _womanIdMeta = const VerificationMeta(
    'womanId',
  );
  @override
  late final GeneratedColumn<String> womanId = GeneratedColumn<String>(
    'woman_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _registeredOnMeta = const VerificationMeta(
    'registeredOn',
  );
  @override
  late final GeneratedColumn<String> registeredOn = GeneratedColumn<String>(
    'registered_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pregnancyMonthAtRegistrationMeta =
      const VerificationMeta('pregnancyMonthAtRegistration');
  @override
  late final GeneratedColumn<int> pregnancyMonthAtRegistration =
      GeneratedColumn<int>(
        'pregnancy_month_at_registration',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _closedOnMeta = const VerificationMeta(
    'closedOn',
  );
  @override
  late final GeneratedColumn<String> closedOn = GeneratedColumn<String>(
    'closed_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverSeq,
    areaId,
    createdBy,
    createdOnDevice,
    deletedAt,
    womanId,
    registeredOn,
    pregnancyMonthAtRegistration,
    status,
    closedOn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pregnancies';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalPregnancy> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('area_id')) {
      context.handle(
        _areaIdMeta,
        areaId.isAcceptableOrUnknown(data['area_id']!, _areaIdMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('created_on_device')) {
      context.handle(
        _createdOnDeviceMeta,
        createdOnDevice.isAcceptableOrUnknown(
          data['created_on_device']!,
          _createdOnDeviceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdOnDeviceMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('woman_id')) {
      context.handle(
        _womanIdMeta,
        womanId.isAcceptableOrUnknown(data['woman_id']!, _womanIdMeta),
      );
    } else if (isInserting) {
      context.missing(_womanIdMeta);
    }
    if (data.containsKey('registered_on')) {
      context.handle(
        _registeredOnMeta,
        registeredOn.isAcceptableOrUnknown(
          data['registered_on']!,
          _registeredOnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_registeredOnMeta);
    }
    if (data.containsKey('pregnancy_month_at_registration')) {
      context.handle(
        _pregnancyMonthAtRegistrationMeta,
        pregnancyMonthAtRegistration.isAcceptableOrUnknown(
          data['pregnancy_month_at_registration']!,
          _pregnancyMonthAtRegistrationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pregnancyMonthAtRegistrationMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('closed_on')) {
      context.handle(
        _closedOnMeta,
        closedOn.isAcceptableOrUnknown(data['closed_on']!, _closedOnMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalPregnancy map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPregnancy(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      areaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}area_id'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      createdOnDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_on_device'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      womanId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}woman_id'],
      )!,
      registeredOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}registered_on'],
      )!,
      pregnancyMonthAtRegistration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pregnancy_month_at_registration'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      closedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}closed_on'],
      ),
    );
  }

  @override
  $PregnanciesTable createAlias(String alias) {
    return $PregnanciesTable(attachedDatabase, alias);
  }
}

class LocalPregnancy extends DataClass implements Insertable<LocalPregnancy> {
  final String id;
  final int? serverSeq;
  final String? areaId;
  final String? createdBy;
  final DateTime createdOnDevice;
  final DateTime? deletedAt;
  final String womanId;

  /// A calendar date, YYYY-MM-DD, as the server stores it.
  final String registeredOn;
  final int pregnancyMonthAtRegistration;
  final String status;
  final String? closedOn;
  const LocalPregnancy({
    required this.id,
    this.serverSeq,
    this.areaId,
    this.createdBy,
    required this.createdOnDevice,
    this.deletedAt,
    required this.womanId,
    required this.registeredOn,
    required this.pregnancyMonthAtRegistration,
    required this.status,
    this.closedOn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    if (!nullToAbsent || areaId != null) {
      map['area_id'] = Variable<String>(areaId);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    map['created_on_device'] = Variable<DateTime>(createdOnDevice);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['woman_id'] = Variable<String>(womanId);
    map['registered_on'] = Variable<String>(registeredOn);
    map['pregnancy_month_at_registration'] = Variable<int>(
      pregnancyMonthAtRegistration,
    );
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || closedOn != null) {
      map['closed_on'] = Variable<String>(closedOn);
    }
    return map;
  }

  PregnanciesCompanion toCompanion(bool nullToAbsent) {
    return PregnanciesCompanion(
      id: Value(id),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      areaId: areaId == null && nullToAbsent
          ? const Value.absent()
          : Value(areaId),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      createdOnDevice: Value(createdOnDevice),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      womanId: Value(womanId),
      registeredOn: Value(registeredOn),
      pregnancyMonthAtRegistration: Value(pregnancyMonthAtRegistration),
      status: Value(status),
      closedOn: closedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(closedOn),
    );
  }

  factory LocalPregnancy.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPregnancy(
      id: serializer.fromJson<String>(json['id']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      areaId: serializer.fromJson<String?>(json['areaId']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      createdOnDevice: serializer.fromJson<DateTime>(json['createdOnDevice']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      womanId: serializer.fromJson<String>(json['womanId']),
      registeredOn: serializer.fromJson<String>(json['registeredOn']),
      pregnancyMonthAtRegistration: serializer.fromJson<int>(
        json['pregnancyMonthAtRegistration'],
      ),
      status: serializer.fromJson<String>(json['status']),
      closedOn: serializer.fromJson<String?>(json['closedOn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'areaId': serializer.toJson<String?>(areaId),
      'createdBy': serializer.toJson<String?>(createdBy),
      'createdOnDevice': serializer.toJson<DateTime>(createdOnDevice),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'womanId': serializer.toJson<String>(womanId),
      'registeredOn': serializer.toJson<String>(registeredOn),
      'pregnancyMonthAtRegistration': serializer.toJson<int>(
        pregnancyMonthAtRegistration,
      ),
      'status': serializer.toJson<String>(status),
      'closedOn': serializer.toJson<String?>(closedOn),
    };
  }

  LocalPregnancy copyWith({
    String? id,
    Value<int?> serverSeq = const Value.absent(),
    Value<String?> areaId = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
    DateTime? createdOnDevice,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? womanId,
    String? registeredOn,
    int? pregnancyMonthAtRegistration,
    String? status,
    Value<String?> closedOn = const Value.absent(),
  }) => LocalPregnancy(
    id: id ?? this.id,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    areaId: areaId.present ? areaId.value : this.areaId,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    createdOnDevice: createdOnDevice ?? this.createdOnDevice,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    womanId: womanId ?? this.womanId,
    registeredOn: registeredOn ?? this.registeredOn,
    pregnancyMonthAtRegistration:
        pregnancyMonthAtRegistration ?? this.pregnancyMonthAtRegistration,
    status: status ?? this.status,
    closedOn: closedOn.present ? closedOn.value : this.closedOn,
  );
  LocalPregnancy copyWithCompanion(PregnanciesCompanion data) {
    return LocalPregnancy(
      id: data.id.present ? data.id.value : this.id,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      areaId: data.areaId.present ? data.areaId.value : this.areaId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdOnDevice: data.createdOnDevice.present
          ? data.createdOnDevice.value
          : this.createdOnDevice,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      womanId: data.womanId.present ? data.womanId.value : this.womanId,
      registeredOn: data.registeredOn.present
          ? data.registeredOn.value
          : this.registeredOn,
      pregnancyMonthAtRegistration: data.pregnancyMonthAtRegistration.present
          ? data.pregnancyMonthAtRegistration.value
          : this.pregnancyMonthAtRegistration,
      status: data.status.present ? data.status.value : this.status,
      closedOn: data.closedOn.present ? data.closedOn.value : this.closedOn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPregnancy(')
          ..write('id: $id, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('areaId: $areaId, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdOnDevice: $createdOnDevice, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('womanId: $womanId, ')
          ..write('registeredOn: $registeredOn, ')
          ..write(
            'pregnancyMonthAtRegistration: $pregnancyMonthAtRegistration, ',
          )
          ..write('status: $status, ')
          ..write('closedOn: $closedOn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverSeq,
    areaId,
    createdBy,
    createdOnDevice,
    deletedAt,
    womanId,
    registeredOn,
    pregnancyMonthAtRegistration,
    status,
    closedOn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPregnancy &&
          other.id == this.id &&
          other.serverSeq == this.serverSeq &&
          other.areaId == this.areaId &&
          other.createdBy == this.createdBy &&
          other.createdOnDevice == this.createdOnDevice &&
          other.deletedAt == this.deletedAt &&
          other.womanId == this.womanId &&
          other.registeredOn == this.registeredOn &&
          other.pregnancyMonthAtRegistration ==
              this.pregnancyMonthAtRegistration &&
          other.status == this.status &&
          other.closedOn == this.closedOn);
}

class PregnanciesCompanion extends UpdateCompanion<LocalPregnancy> {
  final Value<String> id;
  final Value<int?> serverSeq;
  final Value<String?> areaId;
  final Value<String?> createdBy;
  final Value<DateTime> createdOnDevice;
  final Value<DateTime?> deletedAt;
  final Value<String> womanId;
  final Value<String> registeredOn;
  final Value<int> pregnancyMonthAtRegistration;
  final Value<String> status;
  final Value<String?> closedOn;
  final Value<int> rowid;
  const PregnanciesCompanion({
    this.id = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.areaId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdOnDevice = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.womanId = const Value.absent(),
    this.registeredOn = const Value.absent(),
    this.pregnancyMonthAtRegistration = const Value.absent(),
    this.status = const Value.absent(),
    this.closedOn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PregnanciesCompanion.insert({
    required String id,
    this.serverSeq = const Value.absent(),
    this.areaId = const Value.absent(),
    this.createdBy = const Value.absent(),
    required DateTime createdOnDevice,
    this.deletedAt = const Value.absent(),
    required String womanId,
    required String registeredOn,
    required int pregnancyMonthAtRegistration,
    this.status = const Value.absent(),
    this.closedOn = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdOnDevice = Value(createdOnDevice),
       womanId = Value(womanId),
       registeredOn = Value(registeredOn),
       pregnancyMonthAtRegistration = Value(pregnancyMonthAtRegistration);
  static Insertable<LocalPregnancy> custom({
    Expression<String>? id,
    Expression<int>? serverSeq,
    Expression<String>? areaId,
    Expression<String>? createdBy,
    Expression<DateTime>? createdOnDevice,
    Expression<DateTime>? deletedAt,
    Expression<String>? womanId,
    Expression<String>? registeredOn,
    Expression<int>? pregnancyMonthAtRegistration,
    Expression<String>? status,
    Expression<String>? closedOn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (areaId != null) 'area_id': areaId,
      if (createdBy != null) 'created_by': createdBy,
      if (createdOnDevice != null) 'created_on_device': createdOnDevice,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (womanId != null) 'woman_id': womanId,
      if (registeredOn != null) 'registered_on': registeredOn,
      if (pregnancyMonthAtRegistration != null)
        'pregnancy_month_at_registration': pregnancyMonthAtRegistration,
      if (status != null) 'status': status,
      if (closedOn != null) 'closed_on': closedOn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PregnanciesCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverSeq,
    Value<String?>? areaId,
    Value<String?>? createdBy,
    Value<DateTime>? createdOnDevice,
    Value<DateTime?>? deletedAt,
    Value<String>? womanId,
    Value<String>? registeredOn,
    Value<int>? pregnancyMonthAtRegistration,
    Value<String>? status,
    Value<String?>? closedOn,
    Value<int>? rowid,
  }) {
    return PregnanciesCompanion(
      id: id ?? this.id,
      serverSeq: serverSeq ?? this.serverSeq,
      areaId: areaId ?? this.areaId,
      createdBy: createdBy ?? this.createdBy,
      createdOnDevice: createdOnDevice ?? this.createdOnDevice,
      deletedAt: deletedAt ?? this.deletedAt,
      womanId: womanId ?? this.womanId,
      registeredOn: registeredOn ?? this.registeredOn,
      pregnancyMonthAtRegistration:
          pregnancyMonthAtRegistration ?? this.pregnancyMonthAtRegistration,
      status: status ?? this.status,
      closedOn: closedOn ?? this.closedOn,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (areaId.present) {
      map['area_id'] = Variable<String>(areaId.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdOnDevice.present) {
      map['created_on_device'] = Variable<DateTime>(createdOnDevice.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (womanId.present) {
      map['woman_id'] = Variable<String>(womanId.value);
    }
    if (registeredOn.present) {
      map['registered_on'] = Variable<String>(registeredOn.value);
    }
    if (pregnancyMonthAtRegistration.present) {
      map['pregnancy_month_at_registration'] = Variable<int>(
        pregnancyMonthAtRegistration.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (closedOn.present) {
      map['closed_on'] = Variable<String>(closedOn.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PregnanciesCompanion(')
          ..write('id: $id, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('areaId: $areaId, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdOnDevice: $createdOnDevice, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('womanId: $womanId, ')
          ..write('registeredOn: $registeredOn, ')
          ..write(
            'pregnancyMonthAtRegistration: $pregnancyMonthAtRegistration, ',
          )
          ..write('status: $status, ')
          ..write('closedOn: $closedOn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ObstetricHistoryTable extends ObstetricHistory
    with TableInfo<$ObstetricHistoryTable, LocalObstetricHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ObstetricHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _areaIdMeta = const VerificationMeta('areaId');
  @override
  late final GeneratedColumn<String> areaId = GeneratedColumn<String>(
    'area_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdOnDeviceMeta = const VerificationMeta(
    'createdOnDevice',
  );
  @override
  late final GeneratedColumn<DateTime> createdOnDevice =
      GeneratedColumn<DateTime>(
        'created_on_device',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _womanIdMeta = const VerificationMeta(
    'womanId',
  );
  @override
  late final GeneratedColumn<String> womanId = GeneratedColumn<String>(
    'woman_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previousPregnanciesMeta =
      const VerificationMeta('previousPregnancies');
  @override
  late final GeneratedColumn<int> previousPregnancies = GeneratedColumn<int>(
    'previous_pregnancies',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _previousCSectionsMeta = const VerificationMeta(
    'previousCSections',
  );
  @override
  late final GeneratedColumn<int> previousCSections = GeneratedColumn<int>(
    'previous_c_sections',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stillbirthsMeta = const VerificationMeta(
    'stillbirths',
  );
  @override
  late final GeneratedColumn<int> stillbirths = GeneratedColumn<int>(
    'stillbirths',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _knownConditionsMeta = const VerificationMeta(
    'knownConditions',
  );
  @override
  late final GeneratedColumn<String> knownConditions = GeneratedColumn<String>(
    'known_conditions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverSeq,
    areaId,
    createdBy,
    createdOnDevice,
    deletedAt,
    womanId,
    previousPregnancies,
    previousCSections,
    stillbirths,
    knownConditions,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'obstetric_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalObstetricHistory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('area_id')) {
      context.handle(
        _areaIdMeta,
        areaId.isAcceptableOrUnknown(data['area_id']!, _areaIdMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('created_on_device')) {
      context.handle(
        _createdOnDeviceMeta,
        createdOnDevice.isAcceptableOrUnknown(
          data['created_on_device']!,
          _createdOnDeviceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdOnDeviceMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('woman_id')) {
      context.handle(
        _womanIdMeta,
        womanId.isAcceptableOrUnknown(data['woman_id']!, _womanIdMeta),
      );
    } else if (isInserting) {
      context.missing(_womanIdMeta);
    }
    if (data.containsKey('previous_pregnancies')) {
      context.handle(
        _previousPregnanciesMeta,
        previousPregnancies.isAcceptableOrUnknown(
          data['previous_pregnancies']!,
          _previousPregnanciesMeta,
        ),
      );
    }
    if (data.containsKey('previous_c_sections')) {
      context.handle(
        _previousCSectionsMeta,
        previousCSections.isAcceptableOrUnknown(
          data['previous_c_sections']!,
          _previousCSectionsMeta,
        ),
      );
    }
    if (data.containsKey('stillbirths')) {
      context.handle(
        _stillbirthsMeta,
        stillbirths.isAcceptableOrUnknown(
          data['stillbirths']!,
          _stillbirthsMeta,
        ),
      );
    }
    if (data.containsKey('known_conditions')) {
      context.handle(
        _knownConditionsMeta,
        knownConditions.isAcceptableOrUnknown(
          data['known_conditions']!,
          _knownConditionsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalObstetricHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalObstetricHistory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      areaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}area_id'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      createdOnDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_on_device'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      womanId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}woman_id'],
      )!,
      previousPregnancies: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}previous_pregnancies'],
      )!,
      previousCSections: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}previous_c_sections'],
      )!,
      stillbirths: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stillbirths'],
      )!,
      knownConditions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}known_conditions'],
      ),
    );
  }

  @override
  $ObstetricHistoryTable createAlias(String alias) {
    return $ObstetricHistoryTable(attachedDatabase, alias);
  }
}

class LocalObstetricHistory extends DataClass
    implements Insertable<LocalObstetricHistory> {
  final String id;
  final int? serverSeq;
  final String? areaId;
  final String? createdBy;
  final DateTime createdOnDevice;
  final DateTime? deletedAt;
  final String womanId;
  final int previousPregnancies;
  final int previousCSections;
  final int stillbirths;
  final String? knownConditions;
  const LocalObstetricHistory({
    required this.id,
    this.serverSeq,
    this.areaId,
    this.createdBy,
    required this.createdOnDevice,
    this.deletedAt,
    required this.womanId,
    required this.previousPregnancies,
    required this.previousCSections,
    required this.stillbirths,
    this.knownConditions,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    if (!nullToAbsent || areaId != null) {
      map['area_id'] = Variable<String>(areaId);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    map['created_on_device'] = Variable<DateTime>(createdOnDevice);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['woman_id'] = Variable<String>(womanId);
    map['previous_pregnancies'] = Variable<int>(previousPregnancies);
    map['previous_c_sections'] = Variable<int>(previousCSections);
    map['stillbirths'] = Variable<int>(stillbirths);
    if (!nullToAbsent || knownConditions != null) {
      map['known_conditions'] = Variable<String>(knownConditions);
    }
    return map;
  }

  ObstetricHistoryCompanion toCompanion(bool nullToAbsent) {
    return ObstetricHistoryCompanion(
      id: Value(id),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      areaId: areaId == null && nullToAbsent
          ? const Value.absent()
          : Value(areaId),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      createdOnDevice: Value(createdOnDevice),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      womanId: Value(womanId),
      previousPregnancies: Value(previousPregnancies),
      previousCSections: Value(previousCSections),
      stillbirths: Value(stillbirths),
      knownConditions: knownConditions == null && nullToAbsent
          ? const Value.absent()
          : Value(knownConditions),
    );
  }

  factory LocalObstetricHistory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalObstetricHistory(
      id: serializer.fromJson<String>(json['id']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      areaId: serializer.fromJson<String?>(json['areaId']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      createdOnDevice: serializer.fromJson<DateTime>(json['createdOnDevice']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      womanId: serializer.fromJson<String>(json['womanId']),
      previousPregnancies: serializer.fromJson<int>(
        json['previousPregnancies'],
      ),
      previousCSections: serializer.fromJson<int>(json['previousCSections']),
      stillbirths: serializer.fromJson<int>(json['stillbirths']),
      knownConditions: serializer.fromJson<String?>(json['knownConditions']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'areaId': serializer.toJson<String?>(areaId),
      'createdBy': serializer.toJson<String?>(createdBy),
      'createdOnDevice': serializer.toJson<DateTime>(createdOnDevice),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'womanId': serializer.toJson<String>(womanId),
      'previousPregnancies': serializer.toJson<int>(previousPregnancies),
      'previousCSections': serializer.toJson<int>(previousCSections),
      'stillbirths': serializer.toJson<int>(stillbirths),
      'knownConditions': serializer.toJson<String?>(knownConditions),
    };
  }

  LocalObstetricHistory copyWith({
    String? id,
    Value<int?> serverSeq = const Value.absent(),
    Value<String?> areaId = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
    DateTime? createdOnDevice,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? womanId,
    int? previousPregnancies,
    int? previousCSections,
    int? stillbirths,
    Value<String?> knownConditions = const Value.absent(),
  }) => LocalObstetricHistory(
    id: id ?? this.id,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    areaId: areaId.present ? areaId.value : this.areaId,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    createdOnDevice: createdOnDevice ?? this.createdOnDevice,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    womanId: womanId ?? this.womanId,
    previousPregnancies: previousPregnancies ?? this.previousPregnancies,
    previousCSections: previousCSections ?? this.previousCSections,
    stillbirths: stillbirths ?? this.stillbirths,
    knownConditions: knownConditions.present
        ? knownConditions.value
        : this.knownConditions,
  );
  LocalObstetricHistory copyWithCompanion(ObstetricHistoryCompanion data) {
    return LocalObstetricHistory(
      id: data.id.present ? data.id.value : this.id,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      areaId: data.areaId.present ? data.areaId.value : this.areaId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdOnDevice: data.createdOnDevice.present
          ? data.createdOnDevice.value
          : this.createdOnDevice,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      womanId: data.womanId.present ? data.womanId.value : this.womanId,
      previousPregnancies: data.previousPregnancies.present
          ? data.previousPregnancies.value
          : this.previousPregnancies,
      previousCSections: data.previousCSections.present
          ? data.previousCSections.value
          : this.previousCSections,
      stillbirths: data.stillbirths.present
          ? data.stillbirths.value
          : this.stillbirths,
      knownConditions: data.knownConditions.present
          ? data.knownConditions.value
          : this.knownConditions,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalObstetricHistory(')
          ..write('id: $id, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('areaId: $areaId, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdOnDevice: $createdOnDevice, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('womanId: $womanId, ')
          ..write('previousPregnancies: $previousPregnancies, ')
          ..write('previousCSections: $previousCSections, ')
          ..write('stillbirths: $stillbirths, ')
          ..write('knownConditions: $knownConditions')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverSeq,
    areaId,
    createdBy,
    createdOnDevice,
    deletedAt,
    womanId,
    previousPregnancies,
    previousCSections,
    stillbirths,
    knownConditions,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalObstetricHistory &&
          other.id == this.id &&
          other.serverSeq == this.serverSeq &&
          other.areaId == this.areaId &&
          other.createdBy == this.createdBy &&
          other.createdOnDevice == this.createdOnDevice &&
          other.deletedAt == this.deletedAt &&
          other.womanId == this.womanId &&
          other.previousPregnancies == this.previousPregnancies &&
          other.previousCSections == this.previousCSections &&
          other.stillbirths == this.stillbirths &&
          other.knownConditions == this.knownConditions);
}

class ObstetricHistoryCompanion extends UpdateCompanion<LocalObstetricHistory> {
  final Value<String> id;
  final Value<int?> serverSeq;
  final Value<String?> areaId;
  final Value<String?> createdBy;
  final Value<DateTime> createdOnDevice;
  final Value<DateTime?> deletedAt;
  final Value<String> womanId;
  final Value<int> previousPregnancies;
  final Value<int> previousCSections;
  final Value<int> stillbirths;
  final Value<String?> knownConditions;
  final Value<int> rowid;
  const ObstetricHistoryCompanion({
    this.id = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.areaId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdOnDevice = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.womanId = const Value.absent(),
    this.previousPregnancies = const Value.absent(),
    this.previousCSections = const Value.absent(),
    this.stillbirths = const Value.absent(),
    this.knownConditions = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ObstetricHistoryCompanion.insert({
    required String id,
    this.serverSeq = const Value.absent(),
    this.areaId = const Value.absent(),
    this.createdBy = const Value.absent(),
    required DateTime createdOnDevice,
    this.deletedAt = const Value.absent(),
    required String womanId,
    this.previousPregnancies = const Value.absent(),
    this.previousCSections = const Value.absent(),
    this.stillbirths = const Value.absent(),
    this.knownConditions = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdOnDevice = Value(createdOnDevice),
       womanId = Value(womanId);
  static Insertable<LocalObstetricHistory> custom({
    Expression<String>? id,
    Expression<int>? serverSeq,
    Expression<String>? areaId,
    Expression<String>? createdBy,
    Expression<DateTime>? createdOnDevice,
    Expression<DateTime>? deletedAt,
    Expression<String>? womanId,
    Expression<int>? previousPregnancies,
    Expression<int>? previousCSections,
    Expression<int>? stillbirths,
    Expression<String>? knownConditions,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (areaId != null) 'area_id': areaId,
      if (createdBy != null) 'created_by': createdBy,
      if (createdOnDevice != null) 'created_on_device': createdOnDevice,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (womanId != null) 'woman_id': womanId,
      if (previousPregnancies != null)
        'previous_pregnancies': previousPregnancies,
      if (previousCSections != null) 'previous_c_sections': previousCSections,
      if (stillbirths != null) 'stillbirths': stillbirths,
      if (knownConditions != null) 'known_conditions': knownConditions,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ObstetricHistoryCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverSeq,
    Value<String?>? areaId,
    Value<String?>? createdBy,
    Value<DateTime>? createdOnDevice,
    Value<DateTime?>? deletedAt,
    Value<String>? womanId,
    Value<int>? previousPregnancies,
    Value<int>? previousCSections,
    Value<int>? stillbirths,
    Value<String?>? knownConditions,
    Value<int>? rowid,
  }) {
    return ObstetricHistoryCompanion(
      id: id ?? this.id,
      serverSeq: serverSeq ?? this.serverSeq,
      areaId: areaId ?? this.areaId,
      createdBy: createdBy ?? this.createdBy,
      createdOnDevice: createdOnDevice ?? this.createdOnDevice,
      deletedAt: deletedAt ?? this.deletedAt,
      womanId: womanId ?? this.womanId,
      previousPregnancies: previousPregnancies ?? this.previousPregnancies,
      previousCSections: previousCSections ?? this.previousCSections,
      stillbirths: stillbirths ?? this.stillbirths,
      knownConditions: knownConditions ?? this.knownConditions,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (areaId.present) {
      map['area_id'] = Variable<String>(areaId.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdOnDevice.present) {
      map['created_on_device'] = Variable<DateTime>(createdOnDevice.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (womanId.present) {
      map['woman_id'] = Variable<String>(womanId.value);
    }
    if (previousPregnancies.present) {
      map['previous_pregnancies'] = Variable<int>(previousPregnancies.value);
    }
    if (previousCSections.present) {
      map['previous_c_sections'] = Variable<int>(previousCSections.value);
    }
    if (stillbirths.present) {
      map['stillbirths'] = Variable<int>(stillbirths.value);
    }
    if (knownConditions.present) {
      map['known_conditions'] = Variable<String>(knownConditions.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ObstetricHistoryCompanion(')
          ..write('id: $id, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('areaId: $areaId, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdOnDevice: $createdOnDevice, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('womanId: $womanId, ')
          ..write('previousPregnancies: $previousPregnancies, ')
          ..write('previousCSections: $previousCSections, ')
          ..write('stillbirths: $stillbirths, ')
          ..write('knownConditions: $knownConditions, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entityTableMeta = const VerificationMeta(
    'entityTable',
  );
  @override
  late final GeneratedColumn<String> entityTable = GeneratedColumn<String>(
    'entity_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _queuedAtMeta = const VerificationMeta(
    'queuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
    'queued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityTable,
    recordId,
    payload,
    priority,
    attempts,
    lastError,
    queuedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_table')) {
      context.handle(
        _entityTableMeta,
        entityTable.isAcceptableOrUnknown(
          data['entity_table']!,
          _entityTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_entityTableMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('queued_at')) {
      context.handle(
        _queuedAtMeta,
        queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_queuedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {entityTable, recordId},
  ];
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_table'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      queuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}queued_at'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  final int id;

  /// Server table name, for example `households`.
  final String entityTable;
  final String recordId;

  /// The record as it is pushed (JSON), see `docs/openapi.yaml` SyncPushRequest.
  final String payload;

  /// Higher goes first; emergency alerts will use this (M5 FE-4).
  final int priority;
  final int attempts;

  /// Set when the server refused the record; it is then no longer pushed.
  final String? lastError;
  final DateTime queuedAt;
  const OutboxEntry({
    required this.id,
    required this.entityTable,
    required this.recordId,
    required this.payload,
    required this.priority,
    required this.attempts,
    this.lastError,
    required this.queuedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_table'] = Variable<String>(entityTable);
    map['record_id'] = Variable<String>(recordId);
    map['payload'] = Variable<String>(payload);
    map['priority'] = Variable<int>(priority);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['queued_at'] = Variable<DateTime>(queuedAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      entityTable: Value(entityTable),
      recordId: Value(recordId),
      payload: Value(payload),
      priority: Value(priority),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      queuedAt: Value(queuedAt),
    );
  }

  factory OutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      id: serializer.fromJson<int>(json['id']),
      entityTable: serializer.fromJson<String>(json['entityTable']),
      recordId: serializer.fromJson<String>(json['recordId']),
      payload: serializer.fromJson<String>(json['payload']),
      priority: serializer.fromJson<int>(json['priority']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityTable': serializer.toJson<String>(entityTable),
      'recordId': serializer.toJson<String>(recordId),
      'payload': serializer.toJson<String>(payload),
      'priority': serializer.toJson<int>(priority),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
    };
  }

  OutboxEntry copyWith({
    int? id,
    String? entityTable,
    String? recordId,
    String? payload,
    int? priority,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    DateTime? queuedAt,
  }) => OutboxEntry(
    id: id ?? this.id,
    entityTable: entityTable ?? this.entityTable,
    recordId: recordId ?? this.recordId,
    payload: payload ?? this.payload,
    priority: priority ?? this.priority,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    queuedAt: queuedAt ?? this.queuedAt,
  );
  OutboxEntry copyWithCompanion(OutboxCompanion data) {
    return OutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      entityTable: data.entityTable.present
          ? data.entityTable.value
          : this.entityTable,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      payload: data.payload.present ? data.payload.value : this.payload,
      priority: data.priority.present ? data.priority.value : this.priority,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('id: $id, ')
          ..write('entityTable: $entityTable, ')
          ..write('recordId: $recordId, ')
          ..write('payload: $payload, ')
          ..write('priority: $priority, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('queuedAt: $queuedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityTable,
    recordId,
    payload,
    priority,
    attempts,
    lastError,
    queuedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.id == this.id &&
          other.entityTable == this.entityTable &&
          other.recordId == this.recordId &&
          other.payload == this.payload &&
          other.priority == this.priority &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.queuedAt == this.queuedAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<int> id;
  final Value<String> entityTable;
  final Value<String> recordId;
  final Value<String> payload;
  final Value<int> priority;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<DateTime> queuedAt;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.entityTable = const Value.absent(),
    this.recordId = const Value.absent(),
    this.payload = const Value.absent(),
    this.priority = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.queuedAt = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.id = const Value.absent(),
    required String entityTable,
    required String recordId,
    required String payload,
    this.priority = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime queuedAt,
  }) : entityTable = Value(entityTable),
       recordId = Value(recordId),
       payload = Value(payload),
       queuedAt = Value(queuedAt);
  static Insertable<OutboxEntry> custom({
    Expression<int>? id,
    Expression<String>? entityTable,
    Expression<String>? recordId,
    Expression<String>? payload,
    Expression<int>? priority,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<DateTime>? queuedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityTable != null) 'entity_table': entityTable,
      if (recordId != null) 'record_id': recordId,
      if (payload != null) 'payload': payload,
      if (priority != null) 'priority': priority,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (queuedAt != null) 'queued_at': queuedAt,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? entityTable,
    Value<String>? recordId,
    Value<String>? payload,
    Value<int>? priority,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<DateTime>? queuedAt,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      entityTable: entityTable ?? this.entityTable,
      recordId: recordId ?? this.recordId,
      payload: payload ?? this.payload,
      priority: priority ?? this.priority,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      queuedAt: queuedAt ?? this.queuedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityTable.present) {
      map['entity_table'] = Variable<String>(entityTable.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('entityTable: $entityTable, ')
          ..write('recordId: $recordId, ')
          ..write('payload: $payload, ')
          ..write('priority: $priority, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('queuedAt: $queuedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final String key;
  final String value;
  const SyncStateData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(key: Value(key), value: Value(value));
  }

  factory SyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
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

  SyncStateData copyWith({String? key, String? value}) =>
      SyncStateData(key: key ?? this.key, value: value ?? this.value);
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
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
      (other is SyncStateData &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncStateData> custom({
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

  SyncStateCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
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
    return (StringBuffer('SyncStateCompanion(')
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
  late final $HouseholdsTable households = $HouseholdsTable(this);
  late final $WomenTable women = $WomenTable(this);
  late final $PregnanciesTable pregnancies = $PregnanciesTable(this);
  late final $ObstetricHistoryTable obstetricHistory = $ObstetricHistoryTable(
    this,
  );
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    households,
    women,
    pregnancies,
    obstetricHistory,
    outbox,
    syncState,
  ];
}

typedef $$HouseholdsTableCreateCompanionBuilder = HouseholdsCompanion Function({
  required String id,
  Value<int?> serverSeq,
  Value<String?> householdNumber,
  Value<String?> address,
  Value<String?> village,
  Value<double?> latitude,
  Value<double?> longitude,
  required DateTime createdOnDevice,
  Value<DateTime?> deletedAt,
  Value<String?> areaId,
  Value<String?> createdBy,
  Value<int> rowid,
});
typedef $$HouseholdsTableUpdateCompanionBuilder = HouseholdsCompanion Function({
  Value<String> id,
  Value<int?> serverSeq,
  Value<String?> householdNumber,
  Value<String?> address,
  Value<String?> village,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<DateTime> createdOnDevice,
  Value<DateTime?> deletedAt,
  Value<String?> areaId,
  Value<String?> createdBy,
  Value<int> rowid,
});

class $$HouseholdsTableFilterComposer
    extends Composer<_$AppDatabase, $HouseholdsTable> {
  $$HouseholdsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get householdNumber => $composableBuilder(
    column: $table.householdNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get village => $composableBuilder(
    column: $table.village,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdOnDevice => $composableBuilder(
    column: $table.createdOnDevice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get areaId => $composableBuilder(
    column: $table.areaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HouseholdsTableOrderingComposer
    extends Composer<_$AppDatabase, $HouseholdsTable> {
  $$HouseholdsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get householdNumber => $composableBuilder(
    column: $table.householdNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get village => $composableBuilder(
    column: $table.village,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdOnDevice => $composableBuilder(
    column: $table.createdOnDevice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get areaId => $composableBuilder(
    column: $table.areaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HouseholdsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HouseholdsTable> {
  $$HouseholdsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumn<String> get householdNumber => $composableBuilder(
    column: $table.householdNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get village =>
      $composableBuilder(column: $table.village, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<DateTime> get createdOnDevice => $composableBuilder(
    column: $table.createdOnDevice,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get areaId =>
      $composableBuilder(column: $table.areaId, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);
}

class $$HouseholdsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HouseholdsTable,
          LocalHousehold,
          $$HouseholdsTableFilterComposer,
          $$HouseholdsTableOrderingComposer,
          $$HouseholdsTableAnnotationComposer,
          $$HouseholdsTableCreateCompanionBuilder,
          $$HouseholdsTableUpdateCompanionBuilder,
          (
            LocalHousehold,
            BaseReferences<_$AppDatabase, $HouseholdsTable, LocalHousehold>,
          ),
          LocalHousehold,
          PrefetchHooks Function()
        > {
  $$HouseholdsTableTableManager(_$AppDatabase db, $HouseholdsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HouseholdsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HouseholdsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HouseholdsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<String?> householdNumber = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> village = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<DateTime> createdOnDevice = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> areaId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HouseholdsCompanion(
                id: id,
                serverSeq: serverSeq,
                householdNumber: householdNumber,
                address: address,
                village: village,
                latitude: latitude,
                longitude: longitude,
                createdOnDevice: createdOnDevice,
                deletedAt: deletedAt,
                areaId: areaId,
                createdBy: createdBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverSeq = const Value.absent(),
                Value<String?> householdNumber = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> village = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                required DateTime createdOnDevice,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> areaId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HouseholdsCompanion.insert(
                id: id,
                serverSeq: serverSeq,
                householdNumber: householdNumber,
                address: address,
                village: village,
                latitude: latitude,
                longitude: longitude,
                createdOnDevice: createdOnDevice,
                deletedAt: deletedAt,
                areaId: areaId,
                createdBy: createdBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HouseholdsTable, LocalHousehold>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $HouseholdsTable,
                    LocalHousehold
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HouseholdsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HouseholdsTable,
      LocalHousehold,
      $$HouseholdsTableFilterComposer,
      $$HouseholdsTableOrderingComposer,
      $$HouseholdsTableAnnotationComposer,
      $$HouseholdsTableCreateCompanionBuilder,
      $$HouseholdsTableUpdateCompanionBuilder,
      (
        LocalHousehold,
        BaseReferences<_$AppDatabase, $HouseholdsTable, LocalHousehold>,
      ),
      LocalHousehold,
      PrefetchHooks Function()
    >;
typedef $$WomenTableCreateCompanionBuilder = WomenCompanion Function({
  required String id,
  Value<int?> serverSeq,
  Value<String?> areaId,
  Value<String?> createdBy,
  required DateTime createdOnDevice,
  Value<DateTime?> deletedAt,
  required String householdId,
  required String patientCode,
  required String name,
  Value<int?> age,
  Value<String?> husbandName,
  Value<String?> contactNumber,
  Value<int> rowid,
});
typedef $$WomenTableUpdateCompanionBuilder = WomenCompanion Function({
  Value<String> id,
  Value<int?> serverSeq,
  Value<String?> areaId,
  Value<String?> createdBy,
  Value<DateTime> createdOnDevice,
  Value<DateTime?> deletedAt,
  Value<String> householdId,
  Value<String> patientCode,
  Value<String> name,
  Value<int?> age,
  Value<String?> husbandName,
  Value<String?> contactNumber,
  Value<int> rowid,
});

class $$WomenTableFilterComposer extends Composer<_$AppDatabase, $WomenTable> {
  $$WomenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get areaId => $composableBuilder(
    column: $table.areaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdOnDevice => $composableBuilder(
    column: $table.createdOnDevice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get patientCode => $composableBuilder(
    column: $table.patientCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get husbandName => $composableBuilder(
    column: $table.husbandName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactNumber => $composableBuilder(
    column: $table.contactNumber,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WomenTableOrderingComposer
    extends Composer<_$AppDatabase, $WomenTable> {
  $$WomenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get areaId => $composableBuilder(
    column: $table.areaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdOnDevice => $composableBuilder(
    column: $table.createdOnDevice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get patientCode => $composableBuilder(
    column: $table.patientCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get husbandName => $composableBuilder(
    column: $table.husbandName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactNumber => $composableBuilder(
    column: $table.contactNumber,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WomenTableAnnotationComposer
    extends Composer<_$AppDatabase, $WomenTable> {
  $$WomenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumn<String> get areaId =>
      $composableBuilder(column: $table.areaId, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdOnDevice => $composableBuilder(
    column: $table.createdOnDevice,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get patientCode => $composableBuilder(
    column: $table.patientCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get age =>
      $composableBuilder(column: $table.age, builder: (column) => column);

  GeneratedColumn<String> get husbandName => $composableBuilder(
    column: $table.husbandName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contactNumber => $composableBuilder(
    column: $table.contactNumber,
    builder: (column) => column,
  );
}

class $$WomenTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WomenTable,
          LocalWoman,
          $$WomenTableFilterComposer,
          $$WomenTableOrderingComposer,
          $$WomenTableAnnotationComposer,
          $$WomenTableCreateCompanionBuilder,
          $$WomenTableUpdateCompanionBuilder,
          (LocalWoman, BaseReferences<_$AppDatabase, $WomenTable, LocalWoman>),
          LocalWoman,
          PrefetchHooks Function()
        > {
  $$WomenTableTableManager(_$AppDatabase db, $WomenTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WomenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WomenTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WomenTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<String?> areaId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<DateTime> createdOnDevice = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> householdId = const Value.absent(),
                Value<String> patientCode = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> age = const Value.absent(),
                Value<String?> husbandName = const Value.absent(),
                Value<String?> contactNumber = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WomenCompanion(
                id: id,
                serverSeq: serverSeq,
                areaId: areaId,
                createdBy: createdBy,
                createdOnDevice: createdOnDevice,
                deletedAt: deletedAt,
                householdId: householdId,
                patientCode: patientCode,
                name: name,
                age: age,
                husbandName: husbandName,
                contactNumber: contactNumber,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverSeq = const Value.absent(),
                Value<String?> areaId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                required DateTime createdOnDevice,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String householdId,
                required String patientCode,
                required String name,
                Value<int?> age = const Value.absent(),
                Value<String?> husbandName = const Value.absent(),
                Value<String?> contactNumber = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WomenCompanion.insert(
                id: id,
                serverSeq: serverSeq,
                areaId: areaId,
                createdBy: createdBy,
                createdOnDevice: createdOnDevice,
                deletedAt: deletedAt,
                householdId: householdId,
                patientCode: patientCode,
                name: name,
                age: age,
                husbandName: husbandName,
                contactNumber: contactNumber,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WomenTable, LocalWoman>(table),
                  BaseReferences<_$AppDatabase, $WomenTable, LocalWoman>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WomenTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WomenTable,
      LocalWoman,
      $$WomenTableFilterComposer,
      $$WomenTableOrderingComposer,
      $$WomenTableAnnotationComposer,
      $$WomenTableCreateCompanionBuilder,
      $$WomenTableUpdateCompanionBuilder,
      (LocalWoman, BaseReferences<_$AppDatabase, $WomenTable, LocalWoman>),
      LocalWoman,
      PrefetchHooks Function()
    >;
typedef $$PregnanciesTableCreateCompanionBuilder =
    PregnanciesCompanion Function({
      required String id,
      Value<int?> serverSeq,
      Value<String?> areaId,
      Value<String?> createdBy,
      required DateTime createdOnDevice,
      Value<DateTime?> deletedAt,
      required String womanId,
      required String registeredOn,
      required int pregnancyMonthAtRegistration,
      Value<String> status,
      Value<String?> closedOn,
      Value<int> rowid,
    });
typedef $$PregnanciesTableUpdateCompanionBuilder =
    PregnanciesCompanion Function({
      Value<String> id,
      Value<int?> serverSeq,
      Value<String?> areaId,
      Value<String?> createdBy,
      Value<DateTime> createdOnDevice,
      Value<DateTime?> deletedAt,
      Value<String> womanId,
      Value<String> registeredOn,
      Value<int> pregnancyMonthAtRegistration,
      Value<String> status,
      Value<String?> closedOn,
      Value<int> rowid,
    });

class $$PregnanciesTableFilterComposer
    extends Composer<_$AppDatabase, $PregnanciesTable> {
  $$PregnanciesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get areaId => $composableBuilder(
    column: $table.areaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdOnDevice => $composableBuilder(
    column: $table.createdOnDevice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get womanId => $composableBuilder(
    column: $table.womanId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registeredOn => $composableBuilder(
    column: $table.registeredOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pregnancyMonthAtRegistration => $composableBuilder(
    column: $table.pregnancyMonthAtRegistration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get closedOn => $composableBuilder(
    column: $table.closedOn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PregnanciesTableOrderingComposer
    extends Composer<_$AppDatabase, $PregnanciesTable> {
  $$PregnanciesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get areaId => $composableBuilder(
    column: $table.areaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdOnDevice => $composableBuilder(
    column: $table.createdOnDevice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get womanId => $composableBuilder(
    column: $table.womanId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registeredOn => $composableBuilder(
    column: $table.registeredOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pregnancyMonthAtRegistration => $composableBuilder(
    column: $table.pregnancyMonthAtRegistration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get closedOn => $composableBuilder(
    column: $table.closedOn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PregnanciesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PregnanciesTable> {
  $$PregnanciesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumn<String> get areaId =>
      $composableBuilder(column: $table.areaId, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdOnDevice => $composableBuilder(
    column: $table.createdOnDevice,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get womanId =>
      $composableBuilder(column: $table.womanId, builder: (column) => column);

  GeneratedColumn<String> get registeredOn => $composableBuilder(
    column: $table.registeredOn,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pregnancyMonthAtRegistration => $composableBuilder(
    column: $table.pregnancyMonthAtRegistration,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get closedOn =>
      $composableBuilder(column: $table.closedOn, builder: (column) => column);
}

class $$PregnanciesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PregnanciesTable,
          LocalPregnancy,
          $$PregnanciesTableFilterComposer,
          $$PregnanciesTableOrderingComposer,
          $$PregnanciesTableAnnotationComposer,
          $$PregnanciesTableCreateCompanionBuilder,
          $$PregnanciesTableUpdateCompanionBuilder,
          (
            LocalPregnancy,
            BaseReferences<_$AppDatabase, $PregnanciesTable, LocalPregnancy>,
          ),
          LocalPregnancy,
          PrefetchHooks Function()
        > {
  $$PregnanciesTableTableManager(_$AppDatabase db, $PregnanciesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PregnanciesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PregnanciesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PregnanciesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<String?> areaId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<DateTime> createdOnDevice = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> womanId = const Value.absent(),
                Value<String> registeredOn = const Value.absent(),
                Value<int> pregnancyMonthAtRegistration = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> closedOn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PregnanciesCompanion(
                id: id,
                serverSeq: serverSeq,
                areaId: areaId,
                createdBy: createdBy,
                createdOnDevice: createdOnDevice,
                deletedAt: deletedAt,
                womanId: womanId,
                registeredOn: registeredOn,
                pregnancyMonthAtRegistration: pregnancyMonthAtRegistration,
                status: status,
                closedOn: closedOn,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverSeq = const Value.absent(),
                Value<String?> areaId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                required DateTime createdOnDevice,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String womanId,
                required String registeredOn,
                required int pregnancyMonthAtRegistration,
                Value<String> status = const Value.absent(),
                Value<String?> closedOn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PregnanciesCompanion.insert(
                id: id,
                serverSeq: serverSeq,
                areaId: areaId,
                createdBy: createdBy,
                createdOnDevice: createdOnDevice,
                deletedAt: deletedAt,
                womanId: womanId,
                registeredOn: registeredOn,
                pregnancyMonthAtRegistration: pregnancyMonthAtRegistration,
                status: status,
                closedOn: closedOn,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PregnanciesTable, LocalPregnancy>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PregnanciesTable,
                    LocalPregnancy
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PregnanciesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PregnanciesTable,
      LocalPregnancy,
      $$PregnanciesTableFilterComposer,
      $$PregnanciesTableOrderingComposer,
      $$PregnanciesTableAnnotationComposer,
      $$PregnanciesTableCreateCompanionBuilder,
      $$PregnanciesTableUpdateCompanionBuilder,
      (
        LocalPregnancy,
        BaseReferences<_$AppDatabase, $PregnanciesTable, LocalPregnancy>,
      ),
      LocalPregnancy,
      PrefetchHooks Function()
    >;
typedef $$ObstetricHistoryTableCreateCompanionBuilder =
    ObstetricHistoryCompanion Function({
      required String id,
      Value<int?> serverSeq,
      Value<String?> areaId,
      Value<String?> createdBy,
      required DateTime createdOnDevice,
      Value<DateTime?> deletedAt,
      required String womanId,
      Value<int> previousPregnancies,
      Value<int> previousCSections,
      Value<int> stillbirths,
      Value<String?> knownConditions,
      Value<int> rowid,
    });
typedef $$ObstetricHistoryTableUpdateCompanionBuilder =
    ObstetricHistoryCompanion Function({
      Value<String> id,
      Value<int?> serverSeq,
      Value<String?> areaId,
      Value<String?> createdBy,
      Value<DateTime> createdOnDevice,
      Value<DateTime?> deletedAt,
      Value<String> womanId,
      Value<int> previousPregnancies,
      Value<int> previousCSections,
      Value<int> stillbirths,
      Value<String?> knownConditions,
      Value<int> rowid,
    });

class $$ObstetricHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $ObstetricHistoryTable> {
  $$ObstetricHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get areaId => $composableBuilder(
    column: $table.areaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdOnDevice => $composableBuilder(
    column: $table.createdOnDevice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get womanId => $composableBuilder(
    column: $table.womanId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get previousPregnancies => $composableBuilder(
    column: $table.previousPregnancies,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get previousCSections => $composableBuilder(
    column: $table.previousCSections,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stillbirths => $composableBuilder(
    column: $table.stillbirths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get knownConditions => $composableBuilder(
    column: $table.knownConditions,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ObstetricHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $ObstetricHistoryTable> {
  $$ObstetricHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get areaId => $composableBuilder(
    column: $table.areaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdOnDevice => $composableBuilder(
    column: $table.createdOnDevice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get womanId => $composableBuilder(
    column: $table.womanId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get previousPregnancies => $composableBuilder(
    column: $table.previousPregnancies,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get previousCSections => $composableBuilder(
    column: $table.previousCSections,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stillbirths => $composableBuilder(
    column: $table.stillbirths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get knownConditions => $composableBuilder(
    column: $table.knownConditions,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ObstetricHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $ObstetricHistoryTable> {
  $$ObstetricHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumn<String> get areaId =>
      $composableBuilder(column: $table.areaId, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdOnDevice => $composableBuilder(
    column: $table.createdOnDevice,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get womanId =>
      $composableBuilder(column: $table.womanId, builder: (column) => column);

  GeneratedColumn<int> get previousPregnancies => $composableBuilder(
    column: $table.previousPregnancies,
    builder: (column) => column,
  );

  GeneratedColumn<int> get previousCSections => $composableBuilder(
    column: $table.previousCSections,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stillbirths => $composableBuilder(
    column: $table.stillbirths,
    builder: (column) => column,
  );

  GeneratedColumn<String> get knownConditions => $composableBuilder(
    column: $table.knownConditions,
    builder: (column) => column,
  );
}

class $$ObstetricHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ObstetricHistoryTable,
          LocalObstetricHistory,
          $$ObstetricHistoryTableFilterComposer,
          $$ObstetricHistoryTableOrderingComposer,
          $$ObstetricHistoryTableAnnotationComposer,
          $$ObstetricHistoryTableCreateCompanionBuilder,
          $$ObstetricHistoryTableUpdateCompanionBuilder,
          (
            LocalObstetricHistory,
            BaseReferences<
              _$AppDatabase,
              $ObstetricHistoryTable,
              LocalObstetricHistory
            >,
          ),
          LocalObstetricHistory,
          PrefetchHooks Function()
        > {
  $$ObstetricHistoryTableTableManager(
    _$AppDatabase db,
    $ObstetricHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ObstetricHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ObstetricHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ObstetricHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<String?> areaId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<DateTime> createdOnDevice = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> womanId = const Value.absent(),
                Value<int> previousPregnancies = const Value.absent(),
                Value<int> previousCSections = const Value.absent(),
                Value<int> stillbirths = const Value.absent(),
                Value<String?> knownConditions = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ObstetricHistoryCompanion(
                id: id,
                serverSeq: serverSeq,
                areaId: areaId,
                createdBy: createdBy,
                createdOnDevice: createdOnDevice,
                deletedAt: deletedAt,
                womanId: womanId,
                previousPregnancies: previousPregnancies,
                previousCSections: previousCSections,
                stillbirths: stillbirths,
                knownConditions: knownConditions,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverSeq = const Value.absent(),
                Value<String?> areaId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                required DateTime createdOnDevice,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String womanId,
                Value<int> previousPregnancies = const Value.absent(),
                Value<int> previousCSections = const Value.absent(),
                Value<int> stillbirths = const Value.absent(),
                Value<String?> knownConditions = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ObstetricHistoryCompanion.insert(
                id: id,
                serverSeq: serverSeq,
                areaId: areaId,
                createdBy: createdBy,
                createdOnDevice: createdOnDevice,
                deletedAt: deletedAt,
                womanId: womanId,
                previousPregnancies: previousPregnancies,
                previousCSections: previousCSections,
                stillbirths: stillbirths,
                knownConditions: knownConditions,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ObstetricHistoryTable, LocalObstetricHistory>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ObstetricHistoryTable,
                    LocalObstetricHistory
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ObstetricHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ObstetricHistoryTable,
      LocalObstetricHistory,
      $$ObstetricHistoryTableFilterComposer,
      $$ObstetricHistoryTableOrderingComposer,
      $$ObstetricHistoryTableAnnotationComposer,
      $$ObstetricHistoryTableCreateCompanionBuilder,
      $$ObstetricHistoryTableUpdateCompanionBuilder,
      (
        LocalObstetricHistory,
        BaseReferences<
          _$AppDatabase,
          $ObstetricHistoryTable,
          LocalObstetricHistory
        >,
      ),
      LocalObstetricHistory,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  Value<int> id,
  required String entityTable,
  required String recordId,
  required String payload,
  Value<int> priority,
  Value<int> attempts,
  Value<String?> lastError,
  required DateTime queuedAt,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<int> id,
  Value<String> entityTable,
  Value<String> recordId,
  Value<String> payload,
  Value<int> priority,
  Value<int> attempts,
  Value<String?> lastError,
  Value<DateTime> queuedAt,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityTable => $composableBuilder(
    column: $table.entityTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityTable => $composableBuilder(
    column: $table.entityTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityTable => $composableBuilder(
    column: $table.entityTable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxEntry,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (
            OutboxEntry,
            BaseReferences<_$AppDatabase, $OutboxTable, OutboxEntry>,
          ),
          OutboxEntry,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityTable = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> queuedAt = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                entityTable: entityTable,
                recordId: recordId,
                payload: payload,
                priority: priority,
                attempts: attempts,
                lastError: lastError,
                queuedAt: queuedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entityTable,
                required String recordId,
                required String payload,
                Value<int> priority = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime queuedAt,
              }) => OutboxCompanion.insert(
                id: id,
                entityTable: entityTable,
                recordId: recordId,
                payload: payload,
                priority: priority,
                attempts: attempts,
                lastError: lastError,
                queuedAt: queuedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxEntry>(table),
                  BaseReferences<_$AppDatabase, $OutboxTable, OutboxEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxEntry,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxEntry, BaseReferences<_$AppDatabase, $OutboxTable, OutboxEntry>),
      OutboxEntry,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
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

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateData,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateData,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
          ),
          SyncStateData,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SyncStateCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStateTable, SyncStateData>(table),
                  BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateData,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateData,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
      ),
      SyncStateData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$HouseholdsTableTableManager get households =>
      $$HouseholdsTableTableManager(_db, _db.households);
  $$WomenTableTableManager get women =>
      $$WomenTableTableManager(_db, _db.women);
  $$PregnanciesTableTableManager get pregnancies =>
      $$PregnanciesTableTableManager(_db, _db.pregnancies);
  $$ObstetricHistoryTableTableManager get obstetricHistory =>
      $$ObstetricHistoryTableTableManager(_db, _db.obstetricHistory);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
}
