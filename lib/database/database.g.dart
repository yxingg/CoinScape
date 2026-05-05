// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CoinsTable extends Coins with TableInfo<$CoinsTable, Coin> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoinsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _faceValueMeta = const VerificationMeta(
    'faceValue',
  );
  @override
  late final GeneratedColumn<double> faceValue = GeneratedColumn<double>(
    'face_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _materialMeta = const VerificationMeta(
    'material',
  );
  @override
  late final GeneratedColumn<String> material = GeneratedColumn<String>(
    'material',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diameterMeta = const VerificationMeta(
    'diameter',
  );
  @override
  late final GeneratedColumn<double> diameter = GeneratedColumn<double>(
    'diameter',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mintageMeta = const VerificationMeta(
    'mintage',
  );
  @override
  late final GeneratedColumn<String> mintage = GeneratedColumn<String>(
    'mintage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mintMeta = const VerificationMeta('mint');
  @override
  late final GeneratedColumn<String> mint = GeneratedColumn<String>(
    'mint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gradeMeta = const VerificationMeta('grade');
  @override
  late final GeneratedColumn<String> grade = GeneratedColumn<String>(
    'grade',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitPriceMeta = const VerificationMeta(
    'unitPrice',
  );
  @override
  late final GeneratedColumn<double> unitPrice = GeneratedColumn<double>(
    'unit_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantityUnitMeta = const VerificationMeta(
    'quantityUnit',
  );
  @override
  late final GeneratedColumn<String> quantityUnit = GeneratedColumn<String>(
    'quantity_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _collectionTimeMeta = const VerificationMeta(
    'collectionTime',
  );
  @override
  late final GeneratedColumn<DateTime> collectionTime =
      GeneratedColumn<DateTime>(
        'collection_time',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commentsMeta = const VerificationMeta(
    'comments',
  );
  @override
  late final GeneratedColumn<String> comments = GeneratedColumn<String>(
    'comments',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstImagePathMeta = const VerificationMeta(
    'firstImagePath',
  );
  @override
  late final GeneratedColumn<String> firstImagePath = GeneratedColumn<String>(
    'first_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    year,
    faceValue,
    material,
    weight,
    diameter,
    mintage,
    mint,
    grade,
    unitPrice,
    quantity,
    quantityUnit,
    collectionTime,
    createdAt,
    comments,
    firstImagePath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'coins';
  @override
  VerificationContext validateIntegrity(
    Insertable<Coin> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('face_value')) {
      context.handle(
        _faceValueMeta,
        faceValue.isAcceptableOrUnknown(data['face_value']!, _faceValueMeta),
      );
    }
    if (data.containsKey('material')) {
      context.handle(
        _materialMeta,
        material.isAcceptableOrUnknown(data['material']!, _materialMeta),
      );
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('diameter')) {
      context.handle(
        _diameterMeta,
        diameter.isAcceptableOrUnknown(data['diameter']!, _diameterMeta),
      );
    }
    if (data.containsKey('mintage')) {
      context.handle(
        _mintageMeta,
        mintage.isAcceptableOrUnknown(data['mintage']!, _mintageMeta),
      );
    }
    if (data.containsKey('mint')) {
      context.handle(
        _mintMeta,
        mint.isAcceptableOrUnknown(data['mint']!, _mintMeta),
      );
    }
    if (data.containsKey('grade')) {
      context.handle(
        _gradeMeta,
        grade.isAcceptableOrUnknown(data['grade']!, _gradeMeta),
      );
    }
    if (data.containsKey('unit_price')) {
      context.handle(
        _unitPriceMeta,
        unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta),
      );
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('quantity_unit')) {
      context.handle(
        _quantityUnitMeta,
        quantityUnit.isAcceptableOrUnknown(
          data['quantity_unit']!,
          _quantityUnitMeta,
        ),
      );
    }
    if (data.containsKey('collection_time')) {
      context.handle(
        _collectionTimeMeta,
        collectionTime.isAcceptableOrUnknown(
          data['collection_time']!,
          _collectionTimeMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('comments')) {
      context.handle(
        _commentsMeta,
        comments.isAcceptableOrUnknown(data['comments']!, _commentsMeta),
      );
    }
    if (data.containsKey('first_image_path')) {
      context.handle(
        _firstImagePathMeta,
        firstImagePath.isAcceptableOrUnknown(
          data['first_image_path']!,
          _firstImagePathMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Coin map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Coin(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      faceValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}face_value'],
      ),
      material: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}material'],
      ),
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      ),
      diameter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}diameter'],
      ),
      mintage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mintage'],
      ),
      mint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mint'],
      ),
      grade: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grade'],
      ),
      unitPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unit_price'],
      ),
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      ),
      quantityUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quantity_unit'],
      ),
      collectionTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}collection_time'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      comments: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comments'],
      ),
      firstImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_image_path'],
      ),
    );
  }

  @override
  $CoinsTable createAlias(String alias) {
    return $CoinsTable(attachedDatabase, alias);
  }
}

class Coin extends DataClass implements Insertable<Coin> {
  final String id;
  final String name;
  final int? year;
  final double? faceValue;
  final String? material;
  final double? weight;
  final double? diameter;
  final String? mintage;
  final String? mint;
  final String? grade;
  final double? unitPrice;
  final int? quantity;
  final String? quantityUnit;
  final DateTime? collectionTime;
  final DateTime createdAt;
  final String? comments;
  final String? firstImagePath;
  const Coin({
    required this.id,
    required this.name,
    this.year,
    this.faceValue,
    this.material,
    this.weight,
    this.diameter,
    this.mintage,
    this.mint,
    this.grade,
    this.unitPrice,
    this.quantity,
    this.quantityUnit,
    this.collectionTime,
    required this.createdAt,
    this.comments,
    this.firstImagePath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || faceValue != null) {
      map['face_value'] = Variable<double>(faceValue);
    }
    if (!nullToAbsent || material != null) {
      map['material'] = Variable<String>(material);
    }
    if (!nullToAbsent || weight != null) {
      map['weight'] = Variable<double>(weight);
    }
    if (!nullToAbsent || diameter != null) {
      map['diameter'] = Variable<double>(diameter);
    }
    if (!nullToAbsent || mintage != null) {
      map['mintage'] = Variable<String>(mintage);
    }
    if (!nullToAbsent || mint != null) {
      map['mint'] = Variable<String>(mint);
    }
    if (!nullToAbsent || grade != null) {
      map['grade'] = Variable<String>(grade);
    }
    if (!nullToAbsent || unitPrice != null) {
      map['unit_price'] = Variable<double>(unitPrice);
    }
    if (!nullToAbsent || quantity != null) {
      map['quantity'] = Variable<int>(quantity);
    }
    if (!nullToAbsent || quantityUnit != null) {
      map['quantity_unit'] = Variable<String>(quantityUnit);
    }
    if (!nullToAbsent || collectionTime != null) {
      map['collection_time'] = Variable<DateTime>(collectionTime);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || comments != null) {
      map['comments'] = Variable<String>(comments);
    }
    if (!nullToAbsent || firstImagePath != null) {
      map['first_image_path'] = Variable<String>(firstImagePath);
    }
    return map;
  }

  CoinsCompanion toCompanion(bool nullToAbsent) {
    return CoinsCompanion(
      id: Value(id),
      name: Value(name),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      faceValue: faceValue == null && nullToAbsent
          ? const Value.absent()
          : Value(faceValue),
      material: material == null && nullToAbsent
          ? const Value.absent()
          : Value(material),
      weight: weight == null && nullToAbsent
          ? const Value.absent()
          : Value(weight),
      diameter: diameter == null && nullToAbsent
          ? const Value.absent()
          : Value(diameter),
      mintage: mintage == null && nullToAbsent
          ? const Value.absent()
          : Value(mintage),
      mint: mint == null && nullToAbsent ? const Value.absent() : Value(mint),
      grade: grade == null && nullToAbsent
          ? const Value.absent()
          : Value(grade),
      unitPrice: unitPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(unitPrice),
      quantity: quantity == null && nullToAbsent
          ? const Value.absent()
          : Value(quantity),
      quantityUnit: quantityUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(quantityUnit),
      collectionTime: collectionTime == null && nullToAbsent
          ? const Value.absent()
          : Value(collectionTime),
      createdAt: Value(createdAt),
      comments: comments == null && nullToAbsent
          ? const Value.absent()
          : Value(comments),
      firstImagePath: firstImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(firstImagePath),
    );
  }

  factory Coin.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Coin(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      year: serializer.fromJson<int?>(json['year']),
      faceValue: serializer.fromJson<double?>(json['faceValue']),
      material: serializer.fromJson<String?>(json['material']),
      weight: serializer.fromJson<double?>(json['weight']),
      diameter: serializer.fromJson<double?>(json['diameter']),
      mintage: serializer.fromJson<String?>(json['mintage']),
      mint: serializer.fromJson<String?>(json['mint']),
      grade: serializer.fromJson<String?>(json['grade']),
      unitPrice: serializer.fromJson<double?>(json['unitPrice']),
      quantity: serializer.fromJson<int?>(json['quantity']),
      quantityUnit: serializer.fromJson<String?>(json['quantityUnit']),
      collectionTime: serializer.fromJson<DateTime?>(json['collectionTime']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      comments: serializer.fromJson<String?>(json['comments']),
      firstImagePath: serializer.fromJson<String?>(json['firstImagePath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'year': serializer.toJson<int?>(year),
      'faceValue': serializer.toJson<double?>(faceValue),
      'material': serializer.toJson<String?>(material),
      'weight': serializer.toJson<double?>(weight),
      'diameter': serializer.toJson<double?>(diameter),
      'mintage': serializer.toJson<String?>(mintage),
      'mint': serializer.toJson<String?>(mint),
      'grade': serializer.toJson<String?>(grade),
      'unitPrice': serializer.toJson<double?>(unitPrice),
      'quantity': serializer.toJson<int?>(quantity),
      'quantityUnit': serializer.toJson<String?>(quantityUnit),
      'collectionTime': serializer.toJson<DateTime?>(collectionTime),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'comments': serializer.toJson<String?>(comments),
      'firstImagePath': serializer.toJson<String?>(firstImagePath),
    };
  }

  Coin copyWith({
    String? id,
    String? name,
    Value<int?> year = const Value.absent(),
    Value<double?> faceValue = const Value.absent(),
    Value<String?> material = const Value.absent(),
    Value<double?> weight = const Value.absent(),
    Value<double?> diameter = const Value.absent(),
    Value<String?> mintage = const Value.absent(),
    Value<String?> mint = const Value.absent(),
    Value<String?> grade = const Value.absent(),
    Value<double?> unitPrice = const Value.absent(),
    Value<int?> quantity = const Value.absent(),
    Value<String?> quantityUnit = const Value.absent(),
    Value<DateTime?> collectionTime = const Value.absent(),
    DateTime? createdAt,
    Value<String?> comments = const Value.absent(),
    Value<String?> firstImagePath = const Value.absent(),
  }) => Coin(
    id: id ?? this.id,
    name: name ?? this.name,
    year: year.present ? year.value : this.year,
    faceValue: faceValue.present ? faceValue.value : this.faceValue,
    material: material.present ? material.value : this.material,
    weight: weight.present ? weight.value : this.weight,
    diameter: diameter.present ? diameter.value : this.diameter,
    mintage: mintage.present ? mintage.value : this.mintage,
    mint: mint.present ? mint.value : this.mint,
    grade: grade.present ? grade.value : this.grade,
    unitPrice: unitPrice.present ? unitPrice.value : this.unitPrice,
    quantity: quantity.present ? quantity.value : this.quantity,
    quantityUnit: quantityUnit.present ? quantityUnit.value : this.quantityUnit,
    collectionTime: collectionTime.present
        ? collectionTime.value
        : this.collectionTime,
    createdAt: createdAt ?? this.createdAt,
    comments: comments.present ? comments.value : this.comments,
    firstImagePath: firstImagePath.present
        ? firstImagePath.value
        : this.firstImagePath,
  );
  Coin copyWithCompanion(CoinsCompanion data) {
    return Coin(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      year: data.year.present ? data.year.value : this.year,
      faceValue: data.faceValue.present ? data.faceValue.value : this.faceValue,
      material: data.material.present ? data.material.value : this.material,
      weight: data.weight.present ? data.weight.value : this.weight,
      diameter: data.diameter.present ? data.diameter.value : this.diameter,
      mintage: data.mintage.present ? data.mintage.value : this.mintage,
      mint: data.mint.present ? data.mint.value : this.mint,
      grade: data.grade.present ? data.grade.value : this.grade,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      quantityUnit: data.quantityUnit.present
          ? data.quantityUnit.value
          : this.quantityUnit,
      collectionTime: data.collectionTime.present
          ? data.collectionTime.value
          : this.collectionTime,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      comments: data.comments.present ? data.comments.value : this.comments,
      firstImagePath: data.firstImagePath.present
          ? data.firstImagePath.value
          : this.firstImagePath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Coin(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('year: $year, ')
          ..write('faceValue: $faceValue, ')
          ..write('material: $material, ')
          ..write('weight: $weight, ')
          ..write('diameter: $diameter, ')
          ..write('mintage: $mintage, ')
          ..write('mint: $mint, ')
          ..write('grade: $grade, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('quantity: $quantity, ')
          ..write('quantityUnit: $quantityUnit, ')
          ..write('collectionTime: $collectionTime, ')
          ..write('createdAt: $createdAt, ')
          ..write('comments: $comments, ')
          ..write('firstImagePath: $firstImagePath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    year,
    faceValue,
    material,
    weight,
    diameter,
    mintage,
    mint,
    grade,
    unitPrice,
    quantity,
    quantityUnit,
    collectionTime,
    createdAt,
    comments,
    firstImagePath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Coin &&
          other.id == this.id &&
          other.name == this.name &&
          other.year == this.year &&
          other.faceValue == this.faceValue &&
          other.material == this.material &&
          other.weight == this.weight &&
          other.diameter == this.diameter &&
          other.mintage == this.mintage &&
          other.mint == this.mint &&
          other.grade == this.grade &&
          other.unitPrice == this.unitPrice &&
          other.quantity == this.quantity &&
          other.quantityUnit == this.quantityUnit &&
          other.collectionTime == this.collectionTime &&
          other.createdAt == this.createdAt &&
          other.comments == this.comments &&
          other.firstImagePath == this.firstImagePath);
}

class CoinsCompanion extends UpdateCompanion<Coin> {
  final Value<String> id;
  final Value<String> name;
  final Value<int?> year;
  final Value<double?> faceValue;
  final Value<String?> material;
  final Value<double?> weight;
  final Value<double?> diameter;
  final Value<String?> mintage;
  final Value<String?> mint;
  final Value<String?> grade;
  final Value<double?> unitPrice;
  final Value<int?> quantity;
  final Value<String?> quantityUnit;
  final Value<DateTime?> collectionTime;
  final Value<DateTime> createdAt;
  final Value<String?> comments;
  final Value<String?> firstImagePath;
  final Value<int> rowid;
  const CoinsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.year = const Value.absent(),
    this.faceValue = const Value.absent(),
    this.material = const Value.absent(),
    this.weight = const Value.absent(),
    this.diameter = const Value.absent(),
    this.mintage = const Value.absent(),
    this.mint = const Value.absent(),
    this.grade = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.quantity = const Value.absent(),
    this.quantityUnit = const Value.absent(),
    this.collectionTime = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.comments = const Value.absent(),
    this.firstImagePath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CoinsCompanion.insert({
    required String id,
    required String name,
    this.year = const Value.absent(),
    this.faceValue = const Value.absent(),
    this.material = const Value.absent(),
    this.weight = const Value.absent(),
    this.diameter = const Value.absent(),
    this.mintage = const Value.absent(),
    this.mint = const Value.absent(),
    this.grade = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.quantity = const Value.absent(),
    this.quantityUnit = const Value.absent(),
    this.collectionTime = const Value.absent(),
    required DateTime createdAt,
    this.comments = const Value.absent(),
    this.firstImagePath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Coin> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? year,
    Expression<double>? faceValue,
    Expression<String>? material,
    Expression<double>? weight,
    Expression<double>? diameter,
    Expression<String>? mintage,
    Expression<String>? mint,
    Expression<String>? grade,
    Expression<double>? unitPrice,
    Expression<int>? quantity,
    Expression<String>? quantityUnit,
    Expression<DateTime>? collectionTime,
    Expression<DateTime>? createdAt,
    Expression<String>? comments,
    Expression<String>? firstImagePath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (year != null) 'year': year,
      if (faceValue != null) 'face_value': faceValue,
      if (material != null) 'material': material,
      if (weight != null) 'weight': weight,
      if (diameter != null) 'diameter': diameter,
      if (mintage != null) 'mintage': mintage,
      if (mint != null) 'mint': mint,
      if (grade != null) 'grade': grade,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (quantity != null) 'quantity': quantity,
      if (quantityUnit != null) 'quantity_unit': quantityUnit,
      if (collectionTime != null) 'collection_time': collectionTime,
      if (createdAt != null) 'created_at': createdAt,
      if (comments != null) 'comments': comments,
      if (firstImagePath != null) 'first_image_path': firstImagePath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CoinsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int?>? year,
    Value<double?>? faceValue,
    Value<String?>? material,
    Value<double?>? weight,
    Value<double?>? diameter,
    Value<String?>? mintage,
    Value<String?>? mint,
    Value<String?>? grade,
    Value<double?>? unitPrice,
    Value<int?>? quantity,
    Value<String?>? quantityUnit,
    Value<DateTime?>? collectionTime,
    Value<DateTime>? createdAt,
    Value<String?>? comments,
    Value<String?>? firstImagePath,
    Value<int>? rowid,
  }) {
    return CoinsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      year: year ?? this.year,
      faceValue: faceValue ?? this.faceValue,
      material: material ?? this.material,
      weight: weight ?? this.weight,
      diameter: diameter ?? this.diameter,
      mintage: mintage ?? this.mintage,
      mint: mint ?? this.mint,
      grade: grade ?? this.grade,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      collectionTime: collectionTime ?? this.collectionTime,
      createdAt: createdAt ?? this.createdAt,
      comments: comments ?? this.comments,
      firstImagePath: firstImagePath ?? this.firstImagePath,
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
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (faceValue.present) {
      map['face_value'] = Variable<double>(faceValue.value);
    }
    if (material.present) {
      map['material'] = Variable<String>(material.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (diameter.present) {
      map['diameter'] = Variable<double>(diameter.value);
    }
    if (mintage.present) {
      map['mintage'] = Variable<String>(mintage.value);
    }
    if (mint.present) {
      map['mint'] = Variable<String>(mint.value);
    }
    if (grade.present) {
      map['grade'] = Variable<String>(grade.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<double>(unitPrice.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (quantityUnit.present) {
      map['quantity_unit'] = Variable<String>(quantityUnit.value);
    }
    if (collectionTime.present) {
      map['collection_time'] = Variable<DateTime>(collectionTime.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (comments.present) {
      map['comments'] = Variable<String>(comments.value);
    }
    if (firstImagePath.present) {
      map['first_image_path'] = Variable<String>(firstImagePath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoinsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('year: $year, ')
          ..write('faceValue: $faceValue, ')
          ..write('material: $material, ')
          ..write('weight: $weight, ')
          ..write('diameter: $diameter, ')
          ..write('mintage: $mintage, ')
          ..write('mint: $mint, ')
          ..write('grade: $grade, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('quantity: $quantity, ')
          ..write('quantityUnit: $quantityUnit, ')
          ..write('collectionTime: $collectionTime, ')
          ..write('createdAt: $createdAt, ')
          ..write('comments: $comments, ')
          ..write('firstImagePath: $firstImagePath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeriesTable extends Series with TableInfo<$SeriesTable, SeriesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, description, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeriesData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SeriesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeriesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SeriesTable createAlias(String alias) {
    return $SeriesTable(attachedDatabase, alias);
  }
}

class SeriesData extends DataClass implements Insertable<SeriesData> {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  const SeriesData({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SeriesCompanion toCompanion(bool nullToAbsent) {
    return SeriesCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: Value(createdAt),
    );
  }

  factory SeriesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeriesData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SeriesData copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    DateTime? createdAt,
  }) => SeriesData(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    createdAt: createdAt ?? this.createdAt,
  );
  SeriesData copyWithCompanion(SeriesCompanion data) {
    return SeriesData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeriesData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeriesData &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.createdAt == this.createdAt);
}

class SeriesCompanion extends UpdateCompanion<SeriesData> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SeriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeriesCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<SeriesData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SeriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CoinSeriesLinkTable extends CoinSeriesLink
    with TableInfo<$CoinSeriesLinkTable, CoinSeriesLinkData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoinSeriesLinkTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _coinIdMeta = const VerificationMeta('coinId');
  @override
  late final GeneratedColumn<String> coinId = GeneratedColumn<String>(
    'coin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES coins (id)',
    ),
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
    'series_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES series (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [coinId, seriesId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'coin_series_link';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoinSeriesLinkData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('coin_id')) {
      context.handle(
        _coinIdMeta,
        coinId.isAcceptableOrUnknown(data['coin_id']!, _coinIdMeta),
      );
    } else if (isInserting) {
      context.missing(_coinIdMeta);
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {coinId, seriesId};
  @override
  CoinSeriesLinkData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoinSeriesLinkData(
      coinId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}coin_id'],
      )!,
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_id'],
      )!,
    );
  }

  @override
  $CoinSeriesLinkTable createAlias(String alias) {
    return $CoinSeriesLinkTable(attachedDatabase, alias);
  }
}

class CoinSeriesLinkData extends DataClass
    implements Insertable<CoinSeriesLinkData> {
  final String coinId;
  final String seriesId;
  const CoinSeriesLinkData({required this.coinId, required this.seriesId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['coin_id'] = Variable<String>(coinId);
    map['series_id'] = Variable<String>(seriesId);
    return map;
  }

  CoinSeriesLinkCompanion toCompanion(bool nullToAbsent) {
    return CoinSeriesLinkCompanion(
      coinId: Value(coinId),
      seriesId: Value(seriesId),
    );
  }

  factory CoinSeriesLinkData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoinSeriesLinkData(
      coinId: serializer.fromJson<String>(json['coinId']),
      seriesId: serializer.fromJson<String>(json['seriesId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'coinId': serializer.toJson<String>(coinId),
      'seriesId': serializer.toJson<String>(seriesId),
    };
  }

  CoinSeriesLinkData copyWith({String? coinId, String? seriesId}) =>
      CoinSeriesLinkData(
        coinId: coinId ?? this.coinId,
        seriesId: seriesId ?? this.seriesId,
      );
  CoinSeriesLinkData copyWithCompanion(CoinSeriesLinkCompanion data) {
    return CoinSeriesLinkData(
      coinId: data.coinId.present ? data.coinId.value : this.coinId,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoinSeriesLinkData(')
          ..write('coinId: $coinId, ')
          ..write('seriesId: $seriesId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(coinId, seriesId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoinSeriesLinkData &&
          other.coinId == this.coinId &&
          other.seriesId == this.seriesId);
}

class CoinSeriesLinkCompanion extends UpdateCompanion<CoinSeriesLinkData> {
  final Value<String> coinId;
  final Value<String> seriesId;
  final Value<int> rowid;
  const CoinSeriesLinkCompanion({
    this.coinId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CoinSeriesLinkCompanion.insert({
    required String coinId,
    required String seriesId,
    this.rowid = const Value.absent(),
  }) : coinId = Value(coinId),
       seriesId = Value(seriesId);
  static Insertable<CoinSeriesLinkData> custom({
    Expression<String>? coinId,
    Expression<String>? seriesId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (coinId != null) 'coin_id': coinId,
      if (seriesId != null) 'series_id': seriesId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CoinSeriesLinkCompanion copyWith({
    Value<String>? coinId,
    Value<String>? seriesId,
    Value<int>? rowid,
  }) {
    return CoinSeriesLinkCompanion(
      coinId: coinId ?? this.coinId,
      seriesId: seriesId ?? this.seriesId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (coinId.present) {
      map['coin_id'] = Variable<String>(coinId.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoinSeriesLinkCompanion(')
          ..write('coinId: $coinId, ')
          ..write('seriesId: $seriesId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CoinImagesTable extends CoinImages
    with TableInfo<$CoinImagesTable, CoinImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoinImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coinIdMeta = const VerificationMeta('coinId');
  @override
  late final GeneratedColumn<String> coinId = GeneratedColumn<String>(
    'coin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES coins (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, coinId, imagePath, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'coin_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoinImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('coin_id')) {
      context.handle(
        _coinIdMeta,
        coinId.isAcceptableOrUnknown(data['coin_id']!, _coinIdMeta),
      );
    } else if (isInserting) {
      context.missing(_coinIdMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CoinImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoinImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      coinId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}coin_id'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $CoinImagesTable createAlias(String alias) {
    return $CoinImagesTable(attachedDatabase, alias);
  }
}

class CoinImage extends DataClass implements Insertable<CoinImage> {
  final String id;
  final String coinId;
  final String imagePath;
  final int sortOrder;
  const CoinImage({
    required this.id,
    required this.coinId,
    required this.imagePath,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['coin_id'] = Variable<String>(coinId);
    map['image_path'] = Variable<String>(imagePath);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  CoinImagesCompanion toCompanion(bool nullToAbsent) {
    return CoinImagesCompanion(
      id: Value(id),
      coinId: Value(coinId),
      imagePath: Value(imagePath),
      sortOrder: Value(sortOrder),
    );
  }

  factory CoinImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoinImage(
      id: serializer.fromJson<String>(json['id']),
      coinId: serializer.fromJson<String>(json['coinId']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'coinId': serializer.toJson<String>(coinId),
      'imagePath': serializer.toJson<String>(imagePath),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  CoinImage copyWith({
    String? id,
    String? coinId,
    String? imagePath,
    int? sortOrder,
  }) => CoinImage(
    id: id ?? this.id,
    coinId: coinId ?? this.coinId,
    imagePath: imagePath ?? this.imagePath,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  CoinImage copyWithCompanion(CoinImagesCompanion data) {
    return CoinImage(
      id: data.id.present ? data.id.value : this.id,
      coinId: data.coinId.present ? data.coinId.value : this.coinId,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoinImage(')
          ..write('id: $id, ')
          ..write('coinId: $coinId, ')
          ..write('imagePath: $imagePath, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, coinId, imagePath, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoinImage &&
          other.id == this.id &&
          other.coinId == this.coinId &&
          other.imagePath == this.imagePath &&
          other.sortOrder == this.sortOrder);
}

class CoinImagesCompanion extends UpdateCompanion<CoinImage> {
  final Value<String> id;
  final Value<String> coinId;
  final Value<String> imagePath;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const CoinImagesCompanion({
    this.id = const Value.absent(),
    this.coinId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CoinImagesCompanion.insert({
    required String id,
    required String coinId,
    required String imagePath,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       coinId = Value(coinId),
       imagePath = Value(imagePath);
  static Insertable<CoinImage> custom({
    Expression<String>? id,
    Expression<String>? coinId,
    Expression<String>? imagePath,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (coinId != null) 'coin_id': coinId,
      if (imagePath != null) 'image_path': imagePath,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CoinImagesCompanion copyWith({
    Value<String>? id,
    Value<String>? coinId,
    Value<String>? imagePath,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return CoinImagesCompanion(
      id: id ?? this.id,
      coinId: coinId ?? this.coinId,
      imagePath: imagePath ?? this.imagePath,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (coinId.present) {
      map['coin_id'] = Variable<String>(coinId.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoinImagesCompanion(')
          ..write('id: $id, ')
          ..write('coinId: $coinId, ')
          ..write('imagePath: $imagePath, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeriesImagesTable extends SeriesImages
    with TableInfo<$SeriesImagesTable, SeriesImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeriesImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
    'series_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES series (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, seriesId, imagePath, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeriesImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesIdMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SeriesImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeriesImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_id'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $SeriesImagesTable createAlias(String alias) {
    return $SeriesImagesTable(attachedDatabase, alias);
  }
}

class SeriesImage extends DataClass implements Insertable<SeriesImage> {
  final String id;
  final String seriesId;
  final String imagePath;
  final int sortOrder;
  const SeriesImage({
    required this.id,
    required this.seriesId,
    required this.imagePath,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['series_id'] = Variable<String>(seriesId);
    map['image_path'] = Variable<String>(imagePath);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  SeriesImagesCompanion toCompanion(bool nullToAbsent) {
    return SeriesImagesCompanion(
      id: Value(id),
      seriesId: Value(seriesId),
      imagePath: Value(imagePath),
      sortOrder: Value(sortOrder),
    );
  }

  factory SeriesImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeriesImage(
      id: serializer.fromJson<String>(json['id']),
      seriesId: serializer.fromJson<String>(json['seriesId']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'seriesId': serializer.toJson<String>(seriesId),
      'imagePath': serializer.toJson<String>(imagePath),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  SeriesImage copyWith({
    String? id,
    String? seriesId,
    String? imagePath,
    int? sortOrder,
  }) => SeriesImage(
    id: id ?? this.id,
    seriesId: seriesId ?? this.seriesId,
    imagePath: imagePath ?? this.imagePath,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  SeriesImage copyWithCompanion(SeriesImagesCompanion data) {
    return SeriesImage(
      id: data.id.present ? data.id.value : this.id,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeriesImage(')
          ..write('id: $id, ')
          ..write('seriesId: $seriesId, ')
          ..write('imagePath: $imagePath, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, seriesId, imagePath, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeriesImage &&
          other.id == this.id &&
          other.seriesId == this.seriesId &&
          other.imagePath == this.imagePath &&
          other.sortOrder == this.sortOrder);
}

class SeriesImagesCompanion extends UpdateCompanion<SeriesImage> {
  final Value<String> id;
  final Value<String> seriesId;
  final Value<String> imagePath;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const SeriesImagesCompanion({
    this.id = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeriesImagesCompanion.insert({
    required String id,
    required String seriesId,
    required String imagePath,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       seriesId = Value(seriesId),
       imagePath = Value(imagePath);
  static Insertable<SeriesImage> custom({
    Expression<String>? id,
    Expression<String>? seriesId,
    Expression<String>? imagePath,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (seriesId != null) 'series_id': seriesId,
      if (imagePath != null) 'image_path': imagePath,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeriesImagesCompanion copyWith({
    Value<String>? id,
    Value<String>? seriesId,
    Value<String>? imagePath,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return SeriesImagesCompanion(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      imagePath: imagePath ?? this.imagePath,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeriesImagesCompanion(')
          ..write('id: $id, ')
          ..write('seriesId: $seriesId, ')
          ..write('imagePath: $imagePath, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CoinsTable coins = $CoinsTable(this);
  late final $SeriesTable series = $SeriesTable(this);
  late final $CoinSeriesLinkTable coinSeriesLink = $CoinSeriesLinkTable(this);
  late final $CoinImagesTable coinImages = $CoinImagesTable(this);
  late final $SeriesImagesTable seriesImages = $SeriesImagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    coins,
    series,
    coinSeriesLink,
    coinImages,
    seriesImages,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'coins',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('coin_images', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'series',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('series_images', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$CoinsTableCreateCompanionBuilder =
    CoinsCompanion Function({
      required String id,
      required String name,
      Value<int?> year,
      Value<double?> faceValue,
      Value<String?> material,
      Value<double?> weight,
      Value<double?> diameter,
      Value<String?> mintage,
      Value<String?> mint,
      Value<String?> grade,
      Value<double?> unitPrice,
      Value<int?> quantity,
      Value<String?> quantityUnit,
      Value<DateTime?> collectionTime,
      required DateTime createdAt,
      Value<String?> comments,
      Value<String?> firstImagePath,
      Value<int> rowid,
    });
typedef $$CoinsTableUpdateCompanionBuilder =
    CoinsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int?> year,
      Value<double?> faceValue,
      Value<String?> material,
      Value<double?> weight,
      Value<double?> diameter,
      Value<String?> mintage,
      Value<String?> mint,
      Value<String?> grade,
      Value<double?> unitPrice,
      Value<int?> quantity,
      Value<String?> quantityUnit,
      Value<DateTime?> collectionTime,
      Value<DateTime> createdAt,
      Value<String?> comments,
      Value<String?> firstImagePath,
      Value<int> rowid,
    });

final class $$CoinsTableReferences
    extends BaseReferences<_$AppDatabase, $CoinsTable, Coin> {
  $$CoinsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CoinSeriesLinkTable, List<CoinSeriesLinkData>>
  _coinSeriesLinkRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.coinSeriesLink,
    aliasName: $_aliasNameGenerator(db.coins.id, db.coinSeriesLink.coinId),
  );

  $$CoinSeriesLinkTableProcessedTableManager get coinSeriesLinkRefs {
    final manager = $$CoinSeriesLinkTableTableManager(
      $_db,
      $_db.coinSeriesLink,
    ).filter((f) => f.coinId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_coinSeriesLinkRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CoinImagesTable, List<CoinImage>>
  _coinImagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.coinImages,
    aliasName: $_aliasNameGenerator(db.coins.id, db.coinImages.coinId),
  );

  $$CoinImagesTableProcessedTableManager get coinImagesRefs {
    final manager = $$CoinImagesTableTableManager(
      $_db,
      $_db.coinImages,
    ).filter((f) => f.coinId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_coinImagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CoinsTableFilterComposer extends Composer<_$AppDatabase, $CoinsTable> {
  $$CoinsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get faceValue => $composableBuilder(
    column: $table.faceValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get material => $composableBuilder(
    column: $table.material,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get diameter => $composableBuilder(
    column: $table.diameter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mintage => $composableBuilder(
    column: $table.mintage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mint => $composableBuilder(
    column: $table.mint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quantityUnit => $composableBuilder(
    column: $table.quantityUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get collectionTime => $composableBuilder(
    column: $table.collectionTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comments => $composableBuilder(
    column: $table.comments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstImagePath => $composableBuilder(
    column: $table.firstImagePath,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> coinSeriesLinkRefs(
    Expression<bool> Function($$CoinSeriesLinkTableFilterComposer f) f,
  ) {
    final $$CoinSeriesLinkTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.coinSeriesLink,
      getReferencedColumn: (t) => t.coinId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoinSeriesLinkTableFilterComposer(
            $db: $db,
            $table: $db.coinSeriesLink,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> coinImagesRefs(
    Expression<bool> Function($$CoinImagesTableFilterComposer f) f,
  ) {
    final $$CoinImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.coinImages,
      getReferencedColumn: (t) => t.coinId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoinImagesTableFilterComposer(
            $db: $db,
            $table: $db.coinImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CoinsTableOrderingComposer
    extends Composer<_$AppDatabase, $CoinsTable> {
  $$CoinsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get faceValue => $composableBuilder(
    column: $table.faceValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get material => $composableBuilder(
    column: $table.material,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get diameter => $composableBuilder(
    column: $table.diameter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mintage => $composableBuilder(
    column: $table.mintage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mint => $composableBuilder(
    column: $table.mint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quantityUnit => $composableBuilder(
    column: $table.quantityUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get collectionTime => $composableBuilder(
    column: $table.collectionTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comments => $composableBuilder(
    column: $table.comments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstImagePath => $composableBuilder(
    column: $table.firstImagePath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoinsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoinsTable> {
  $$CoinsTableAnnotationComposer({
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

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<double> get faceValue =>
      $composableBuilder(column: $table.faceValue, builder: (column) => column);

  GeneratedColumn<String> get material =>
      $composableBuilder(column: $table.material, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<double> get diameter =>
      $composableBuilder(column: $table.diameter, builder: (column) => column);

  GeneratedColumn<String> get mintage =>
      $composableBuilder(column: $table.mintage, builder: (column) => column);

  GeneratedColumn<String> get mint =>
      $composableBuilder(column: $table.mint, builder: (column) => column);

  GeneratedColumn<String> get grade =>
      $composableBuilder(column: $table.grade, builder: (column) => column);

  GeneratedColumn<double> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get quantityUnit => $composableBuilder(
    column: $table.quantityUnit,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get collectionTime => $composableBuilder(
    column: $table.collectionTime,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get comments =>
      $composableBuilder(column: $table.comments, builder: (column) => column);

  GeneratedColumn<String> get firstImagePath => $composableBuilder(
    column: $table.firstImagePath,
    builder: (column) => column,
  );

  Expression<T> coinSeriesLinkRefs<T extends Object>(
    Expression<T> Function($$CoinSeriesLinkTableAnnotationComposer a) f,
  ) {
    final $$CoinSeriesLinkTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.coinSeriesLink,
      getReferencedColumn: (t) => t.coinId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoinSeriesLinkTableAnnotationComposer(
            $db: $db,
            $table: $db.coinSeriesLink,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> coinImagesRefs<T extends Object>(
    Expression<T> Function($$CoinImagesTableAnnotationComposer a) f,
  ) {
    final $$CoinImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.coinImages,
      getReferencedColumn: (t) => t.coinId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoinImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.coinImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CoinsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoinsTable,
          Coin,
          $$CoinsTableFilterComposer,
          $$CoinsTableOrderingComposer,
          $$CoinsTableAnnotationComposer,
          $$CoinsTableCreateCompanionBuilder,
          $$CoinsTableUpdateCompanionBuilder,
          (Coin, $$CoinsTableReferences),
          Coin,
          PrefetchHooks Function({bool coinSeriesLinkRefs, bool coinImagesRefs})
        > {
  $$CoinsTableTableManager(_$AppDatabase db, $CoinsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoinsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoinsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoinsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<double?> faceValue = const Value.absent(),
                Value<String?> material = const Value.absent(),
                Value<double?> weight = const Value.absent(),
                Value<double?> diameter = const Value.absent(),
                Value<String?> mintage = const Value.absent(),
                Value<String?> mint = const Value.absent(),
                Value<String?> grade = const Value.absent(),
                Value<double?> unitPrice = const Value.absent(),
                Value<int?> quantity = const Value.absent(),
                Value<String?> quantityUnit = const Value.absent(),
                Value<DateTime?> collectionTime = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> comments = const Value.absent(),
                Value<String?> firstImagePath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoinsCompanion(
                id: id,
                name: name,
                year: year,
                faceValue: faceValue,
                material: material,
                weight: weight,
                diameter: diameter,
                mintage: mintage,
                mint: mint,
                grade: grade,
                unitPrice: unitPrice,
                quantity: quantity,
                quantityUnit: quantityUnit,
                collectionTime: collectionTime,
                createdAt: createdAt,
                comments: comments,
                firstImagePath: firstImagePath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int?> year = const Value.absent(),
                Value<double?> faceValue = const Value.absent(),
                Value<String?> material = const Value.absent(),
                Value<double?> weight = const Value.absent(),
                Value<double?> diameter = const Value.absent(),
                Value<String?> mintage = const Value.absent(),
                Value<String?> mint = const Value.absent(),
                Value<String?> grade = const Value.absent(),
                Value<double?> unitPrice = const Value.absent(),
                Value<int?> quantity = const Value.absent(),
                Value<String?> quantityUnit = const Value.absent(),
                Value<DateTime?> collectionTime = const Value.absent(),
                required DateTime createdAt,
                Value<String?> comments = const Value.absent(),
                Value<String?> firstImagePath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoinsCompanion.insert(
                id: id,
                name: name,
                year: year,
                faceValue: faceValue,
                material: material,
                weight: weight,
                diameter: diameter,
                mintage: mintage,
                mint: mint,
                grade: grade,
                unitPrice: unitPrice,
                quantity: quantity,
                quantityUnit: quantityUnit,
                collectionTime: collectionTime,
                createdAt: createdAt,
                comments: comments,
                firstImagePath: firstImagePath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$CoinsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({coinSeriesLinkRefs = false, coinImagesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (coinSeriesLinkRefs) db.coinSeriesLink,
                    if (coinImagesRefs) db.coinImages,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (coinSeriesLinkRefs)
                        await $_getPrefetchedData<
                          Coin,
                          $CoinsTable,
                          CoinSeriesLinkData
                        >(
                          currentTable: table,
                          referencedTable: $$CoinsTableReferences
                              ._coinSeriesLinkRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CoinsTableReferences(
                                db,
                                table,
                                p0,
                              ).coinSeriesLinkRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.coinId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (coinImagesRefs)
                        await $_getPrefetchedData<Coin, $CoinsTable, CoinImage>(
                          currentTable: table,
                          referencedTable: $$CoinsTableReferences
                              ._coinImagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CoinsTableReferences(
                                db,
                                table,
                                p0,
                              ).coinImagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.coinId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CoinsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoinsTable,
      Coin,
      $$CoinsTableFilterComposer,
      $$CoinsTableOrderingComposer,
      $$CoinsTableAnnotationComposer,
      $$CoinsTableCreateCompanionBuilder,
      $$CoinsTableUpdateCompanionBuilder,
      (Coin, $$CoinsTableReferences),
      Coin,
      PrefetchHooks Function({bool coinSeriesLinkRefs, bool coinImagesRefs})
    >;
typedef $$SeriesTableCreateCompanionBuilder =
    SeriesCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SeriesTableUpdateCompanionBuilder =
    SeriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$SeriesTableReferences
    extends BaseReferences<_$AppDatabase, $SeriesTable, SeriesData> {
  $$SeriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CoinSeriesLinkTable, List<CoinSeriesLinkData>>
  _coinSeriesLinkRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.coinSeriesLink,
    aliasName: $_aliasNameGenerator(db.series.id, db.coinSeriesLink.seriesId),
  );

  $$CoinSeriesLinkTableProcessedTableManager get coinSeriesLinkRefs {
    final manager = $$CoinSeriesLinkTableTableManager(
      $_db,
      $_db.coinSeriesLink,
    ).filter((f) => f.seriesId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_coinSeriesLinkRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SeriesImagesTable, List<SeriesImage>>
  _seriesImagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.seriesImages,
    aliasName: $_aliasNameGenerator(db.series.id, db.seriesImages.seriesId),
  );

  $$SeriesImagesTableProcessedTableManager get seriesImagesRefs {
    final manager = $$SeriesImagesTableTableManager(
      $_db,
      $_db.seriesImages,
    ).filter((f) => f.seriesId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_seriesImagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SeriesTableFilterComposer
    extends Composer<_$AppDatabase, $SeriesTable> {
  $$SeriesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> coinSeriesLinkRefs(
    Expression<bool> Function($$CoinSeriesLinkTableFilterComposer f) f,
  ) {
    final $$CoinSeriesLinkTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.coinSeriesLink,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoinSeriesLinkTableFilterComposer(
            $db: $db,
            $table: $db.coinSeriesLink,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> seriesImagesRefs(
    Expression<bool> Function($$SeriesImagesTableFilterComposer f) f,
  ) {
    final $$SeriesImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.seriesImages,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesImagesTableFilterComposer(
            $db: $db,
            $table: $db.seriesImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SeriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SeriesTable> {
  $$SeriesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeriesTable> {
  $$SeriesTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> coinSeriesLinkRefs<T extends Object>(
    Expression<T> Function($$CoinSeriesLinkTableAnnotationComposer a) f,
  ) {
    final $$CoinSeriesLinkTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.coinSeriesLink,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoinSeriesLinkTableAnnotationComposer(
            $db: $db,
            $table: $db.coinSeriesLink,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> seriesImagesRefs<T extends Object>(
    Expression<T> Function($$SeriesImagesTableAnnotationComposer a) f,
  ) {
    final $$SeriesImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.seriesImages,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.seriesImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SeriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeriesTable,
          SeriesData,
          $$SeriesTableFilterComposer,
          $$SeriesTableOrderingComposer,
          $$SeriesTableAnnotationComposer,
          $$SeriesTableCreateCompanionBuilder,
          $$SeriesTableUpdateCompanionBuilder,
          (SeriesData, $$SeriesTableReferences),
          SeriesData,
          PrefetchHooks Function({
            bool coinSeriesLinkRefs,
            bool seriesImagesRefs,
          })
        > {
  $$SeriesTableTableManager(_$AppDatabase db, $SeriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeriesCompanion(
                id: id,
                name: name,
                description: description,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SeriesCompanion.insert(
                id: id,
                name: name,
                description: description,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$SeriesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({coinSeriesLinkRefs = false, seriesImagesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (coinSeriesLinkRefs) db.coinSeriesLink,
                    if (seriesImagesRefs) db.seriesImages,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (coinSeriesLinkRefs)
                        await $_getPrefetchedData<
                          SeriesData,
                          $SeriesTable,
                          CoinSeriesLinkData
                        >(
                          currentTable: table,
                          referencedTable: $$SeriesTableReferences
                              ._coinSeriesLinkRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SeriesTableReferences(
                                db,
                                table,
                                p0,
                              ).coinSeriesLinkRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.seriesId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (seriesImagesRefs)
                        await $_getPrefetchedData<
                          SeriesData,
                          $SeriesTable,
                          SeriesImage
                        >(
                          currentTable: table,
                          referencedTable: $$SeriesTableReferences
                              ._seriesImagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SeriesTableReferences(
                                db,
                                table,
                                p0,
                              ).seriesImagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.seriesId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SeriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeriesTable,
      SeriesData,
      $$SeriesTableFilterComposer,
      $$SeriesTableOrderingComposer,
      $$SeriesTableAnnotationComposer,
      $$SeriesTableCreateCompanionBuilder,
      $$SeriesTableUpdateCompanionBuilder,
      (SeriesData, $$SeriesTableReferences),
      SeriesData,
      PrefetchHooks Function({bool coinSeriesLinkRefs, bool seriesImagesRefs})
    >;
typedef $$CoinSeriesLinkTableCreateCompanionBuilder =
    CoinSeriesLinkCompanion Function({
      required String coinId,
      required String seriesId,
      Value<int> rowid,
    });
typedef $$CoinSeriesLinkTableUpdateCompanionBuilder =
    CoinSeriesLinkCompanion Function({
      Value<String> coinId,
      Value<String> seriesId,
      Value<int> rowid,
    });

final class $$CoinSeriesLinkTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CoinSeriesLinkTable,
          CoinSeriesLinkData
        > {
  $$CoinSeriesLinkTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CoinsTable _coinIdTable(_$AppDatabase db) => db.coins.createAlias(
    $_aliasNameGenerator(db.coinSeriesLink.coinId, db.coins.id),
  );

  $$CoinsTableProcessedTableManager get coinId {
    final $_column = $_itemColumn<String>('coin_id')!;

    final manager = $$CoinsTableTableManager(
      $_db,
      $_db.coins,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_coinIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SeriesTable _seriesIdTable(_$AppDatabase db) => db.series.createAlias(
    $_aliasNameGenerator(db.coinSeriesLink.seriesId, db.series.id),
  );

  $$SeriesTableProcessedTableManager get seriesId {
    final $_column = $_itemColumn<String>('series_id')!;

    final manager = $$SeriesTableTableManager(
      $_db,
      $_db.series,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_seriesIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CoinSeriesLinkTableFilterComposer
    extends Composer<_$AppDatabase, $CoinSeriesLinkTable> {
  $$CoinSeriesLinkTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CoinsTableFilterComposer get coinId {
    final $$CoinsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.coinId,
      referencedTable: $db.coins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoinsTableFilterComposer(
            $db: $db,
            $table: $db.coins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SeriesTableFilterComposer get seriesId {
    final $$SeriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableFilterComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CoinSeriesLinkTableOrderingComposer
    extends Composer<_$AppDatabase, $CoinSeriesLinkTable> {
  $$CoinSeriesLinkTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CoinsTableOrderingComposer get coinId {
    final $$CoinsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.coinId,
      referencedTable: $db.coins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoinsTableOrderingComposer(
            $db: $db,
            $table: $db.coins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SeriesTableOrderingComposer get seriesId {
    final $$SeriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableOrderingComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CoinSeriesLinkTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoinSeriesLinkTable> {
  $$CoinSeriesLinkTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CoinsTableAnnotationComposer get coinId {
    final $$CoinsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.coinId,
      referencedTable: $db.coins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoinsTableAnnotationComposer(
            $db: $db,
            $table: $db.coins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SeriesTableAnnotationComposer get seriesId {
    final $$SeriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableAnnotationComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CoinSeriesLinkTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoinSeriesLinkTable,
          CoinSeriesLinkData,
          $$CoinSeriesLinkTableFilterComposer,
          $$CoinSeriesLinkTableOrderingComposer,
          $$CoinSeriesLinkTableAnnotationComposer,
          $$CoinSeriesLinkTableCreateCompanionBuilder,
          $$CoinSeriesLinkTableUpdateCompanionBuilder,
          (CoinSeriesLinkData, $$CoinSeriesLinkTableReferences),
          CoinSeriesLinkData,
          PrefetchHooks Function({bool coinId, bool seriesId})
        > {
  $$CoinSeriesLinkTableTableManager(
    _$AppDatabase db,
    $CoinSeriesLinkTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoinSeriesLinkTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoinSeriesLinkTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoinSeriesLinkTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> coinId = const Value.absent(),
                Value<String> seriesId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoinSeriesLinkCompanion(
                coinId: coinId,
                seriesId: seriesId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String coinId,
                required String seriesId,
                Value<int> rowid = const Value.absent(),
              }) => CoinSeriesLinkCompanion.insert(
                coinId: coinId,
                seriesId: seriesId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CoinSeriesLinkTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({coinId = false, seriesId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (coinId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.coinId,
                                referencedTable: $$CoinSeriesLinkTableReferences
                                    ._coinIdTable(db),
                                referencedColumn:
                                    $$CoinSeriesLinkTableReferences
                                        ._coinIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (seriesId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.seriesId,
                                referencedTable: $$CoinSeriesLinkTableReferences
                                    ._seriesIdTable(db),
                                referencedColumn:
                                    $$CoinSeriesLinkTableReferences
                                        ._seriesIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CoinSeriesLinkTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoinSeriesLinkTable,
      CoinSeriesLinkData,
      $$CoinSeriesLinkTableFilterComposer,
      $$CoinSeriesLinkTableOrderingComposer,
      $$CoinSeriesLinkTableAnnotationComposer,
      $$CoinSeriesLinkTableCreateCompanionBuilder,
      $$CoinSeriesLinkTableUpdateCompanionBuilder,
      (CoinSeriesLinkData, $$CoinSeriesLinkTableReferences),
      CoinSeriesLinkData,
      PrefetchHooks Function({bool coinId, bool seriesId})
    >;
typedef $$CoinImagesTableCreateCompanionBuilder =
    CoinImagesCompanion Function({
      required String id,
      required String coinId,
      required String imagePath,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$CoinImagesTableUpdateCompanionBuilder =
    CoinImagesCompanion Function({
      Value<String> id,
      Value<String> coinId,
      Value<String> imagePath,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$CoinImagesTableReferences
    extends BaseReferences<_$AppDatabase, $CoinImagesTable, CoinImage> {
  $$CoinImagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CoinsTable _coinIdTable(_$AppDatabase db) => db.coins.createAlias(
    $_aliasNameGenerator(db.coinImages.coinId, db.coins.id),
  );

  $$CoinsTableProcessedTableManager get coinId {
    final $_column = $_itemColumn<String>('coin_id')!;

    final manager = $$CoinsTableTableManager(
      $_db,
      $_db.coins,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_coinIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CoinImagesTableFilterComposer
    extends Composer<_$AppDatabase, $CoinImagesTable> {
  $$CoinImagesTableFilterComposer({
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

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$CoinsTableFilterComposer get coinId {
    final $$CoinsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.coinId,
      referencedTable: $db.coins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoinsTableFilterComposer(
            $db: $db,
            $table: $db.coins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CoinImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $CoinImagesTable> {
  $$CoinImagesTableOrderingComposer({
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

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$CoinsTableOrderingComposer get coinId {
    final $$CoinsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.coinId,
      referencedTable: $db.coins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoinsTableOrderingComposer(
            $db: $db,
            $table: $db.coins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CoinImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoinImagesTable> {
  $$CoinImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$CoinsTableAnnotationComposer get coinId {
    final $$CoinsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.coinId,
      referencedTable: $db.coins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoinsTableAnnotationComposer(
            $db: $db,
            $table: $db.coins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CoinImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoinImagesTable,
          CoinImage,
          $$CoinImagesTableFilterComposer,
          $$CoinImagesTableOrderingComposer,
          $$CoinImagesTableAnnotationComposer,
          $$CoinImagesTableCreateCompanionBuilder,
          $$CoinImagesTableUpdateCompanionBuilder,
          (CoinImage, $$CoinImagesTableReferences),
          CoinImage,
          PrefetchHooks Function({bool coinId})
        > {
  $$CoinImagesTableTableManager(_$AppDatabase db, $CoinImagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoinImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoinImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoinImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> coinId = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoinImagesCompanion(
                id: id,
                coinId: coinId,
                imagePath: imagePath,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String coinId,
                required String imagePath,
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoinImagesCompanion.insert(
                id: id,
                coinId: coinId,
                imagePath: imagePath,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CoinImagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({coinId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (coinId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.coinId,
                                referencedTable: $$CoinImagesTableReferences
                                    ._coinIdTable(db),
                                referencedColumn: $$CoinImagesTableReferences
                                    ._coinIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CoinImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoinImagesTable,
      CoinImage,
      $$CoinImagesTableFilterComposer,
      $$CoinImagesTableOrderingComposer,
      $$CoinImagesTableAnnotationComposer,
      $$CoinImagesTableCreateCompanionBuilder,
      $$CoinImagesTableUpdateCompanionBuilder,
      (CoinImage, $$CoinImagesTableReferences),
      CoinImage,
      PrefetchHooks Function({bool coinId})
    >;
typedef $$SeriesImagesTableCreateCompanionBuilder =
    SeriesImagesCompanion Function({
      required String id,
      required String seriesId,
      required String imagePath,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$SeriesImagesTableUpdateCompanionBuilder =
    SeriesImagesCompanion Function({
      Value<String> id,
      Value<String> seriesId,
      Value<String> imagePath,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$SeriesImagesTableReferences
    extends BaseReferences<_$AppDatabase, $SeriesImagesTable, SeriesImage> {
  $$SeriesImagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SeriesTable _seriesIdTable(_$AppDatabase db) => db.series.createAlias(
    $_aliasNameGenerator(db.seriesImages.seriesId, db.series.id),
  );

  $$SeriesTableProcessedTableManager get seriesId {
    final $_column = $_itemColumn<String>('series_id')!;

    final manager = $$SeriesTableTableManager(
      $_db,
      $_db.series,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_seriesIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SeriesImagesTableFilterComposer
    extends Composer<_$AppDatabase, $SeriesImagesTable> {
  $$SeriesImagesTableFilterComposer({
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

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$SeriesTableFilterComposer get seriesId {
    final $$SeriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableFilterComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SeriesImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $SeriesImagesTable> {
  $$SeriesImagesTableOrderingComposer({
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

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$SeriesTableOrderingComposer get seriesId {
    final $$SeriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableOrderingComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SeriesImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeriesImagesTable> {
  $$SeriesImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$SeriesTableAnnotationComposer get seriesId {
    final $$SeriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableAnnotationComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SeriesImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeriesImagesTable,
          SeriesImage,
          $$SeriesImagesTableFilterComposer,
          $$SeriesImagesTableOrderingComposer,
          $$SeriesImagesTableAnnotationComposer,
          $$SeriesImagesTableCreateCompanionBuilder,
          $$SeriesImagesTableUpdateCompanionBuilder,
          (SeriesImage, $$SeriesImagesTableReferences),
          SeriesImage,
          PrefetchHooks Function({bool seriesId})
        > {
  $$SeriesImagesTableTableManager(_$AppDatabase db, $SeriesImagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeriesImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeriesImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeriesImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> seriesId = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeriesImagesCompanion(
                id: id,
                seriesId: seriesId,
                imagePath: imagePath,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String seriesId,
                required String imagePath,
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeriesImagesCompanion.insert(
                id: id,
                seriesId: seriesId,
                imagePath: imagePath,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SeriesImagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({seriesId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (seriesId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.seriesId,
                                referencedTable: $$SeriesImagesTableReferences
                                    ._seriesIdTable(db),
                                referencedColumn: $$SeriesImagesTableReferences
                                    ._seriesIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SeriesImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeriesImagesTable,
      SeriesImage,
      $$SeriesImagesTableFilterComposer,
      $$SeriesImagesTableOrderingComposer,
      $$SeriesImagesTableAnnotationComposer,
      $$SeriesImagesTableCreateCompanionBuilder,
      $$SeriesImagesTableUpdateCompanionBuilder,
      (SeriesImage, $$SeriesImagesTableReferences),
      SeriesImage,
      PrefetchHooks Function({bool seriesId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CoinsTableTableManager get coins =>
      $$CoinsTableTableManager(_db, _db.coins);
  $$SeriesTableTableManager get series =>
      $$SeriesTableTableManager(_db, _db.series);
  $$CoinSeriesLinkTableTableManager get coinSeriesLink =>
      $$CoinSeriesLinkTableTableManager(_db, _db.coinSeriesLink);
  $$CoinImagesTableTableManager get coinImages =>
      $$CoinImagesTableTableManager(_db, _db.coinImages);
  $$SeriesImagesTableTableManager get seriesImages =>
      $$SeriesImagesTableTableManager(_db, _db.seriesImages);
}
