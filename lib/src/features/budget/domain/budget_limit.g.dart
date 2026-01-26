// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_limit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BudgetPeriodAdapter extends TypeAdapter<BudgetPeriod> {
  @override
  final int typeId = 4;

  @override
  BudgetPeriod read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BudgetPeriod.week;
      case 1:
        return BudgetPeriod.month;
      case 2:
        return BudgetPeriod.year;
      default:
        return BudgetPeriod.month;
    }
  }

  @override
  void write(BinaryWriter writer, BudgetPeriod obj) {
    switch (obj) {
      case BudgetPeriod.week:
        writer.writeByte(0);
        break;
      case BudgetPeriod.month:
        writer.writeByte(1);
        break;
      case BudgetPeriod.year:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetPeriodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BudgetLimitAdapter extends TypeAdapter<BudgetLimit> {
  @override
  final int typeId = 5;

  @override
  BudgetLimit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BudgetLimit(
      id: fields[0] as String,
      category: fields[1] as ExpenseCategory,
      limitAmount: fields[2] as double,
      period: fields[3] as BudgetPeriod,
      createdAt: fields[4] as DateTime,
      isActive: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, BudgetLimit obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.limitAmount)
      ..writeByte(3)
      ..write(obj.period)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetLimitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
