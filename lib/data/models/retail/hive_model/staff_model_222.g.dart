// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_model_222.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RetailStaffModelAdapter extends TypeAdapter<RetailStaffModel> {
  @override
  final int typeId = 172;

  @override
  RetailStaffModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RetailStaffModel(
      id: fields[0] as String,
      firstName: fields[1] as String,
      lastName: fields[2] as String,
      email: fields[3] as String?,
      phone: fields[4] as String?,
      address: fields[5] as String?,
      username: fields[6] as String,
      pin: fields[7] as String,
      passwordHash: fields[8] as String?,
      role: fields[9] as String,
      employeeId: fields[10] as String?,
      department: fields[11] as String?,
      shift: fields[12] as String?,
      hireDate: fields[13] as DateTime?,
      canProcessSales: fields[14] as bool,
      canProcessReturns: fields[15] as bool,
      canGiveDiscounts: fields[16] as bool,
      maxDiscountPercent: fields[17] as double?,
      canAccessReports: fields[18] as bool,
      canManageInventory: fields[19] as bool,
      canManageStaff: fields[20] as bool,
      canVoidTransactions: fields[21] as bool,
      canOpenCashDrawer: fields[22] as bool,
      isActive: fields[23] as bool,
      createdAt: fields[24] as DateTime,
      lastLoginAt: fields[25] as DateTime?,
      notes: fields[26] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RetailStaffModel obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.firstName)
      ..writeByte(2)
      ..write(obj.lastName)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.phone)
      ..writeByte(5)
      ..write(obj.address)
      ..writeByte(6)
      ..write(obj.username)
      ..writeByte(7)
      ..write(obj.pin)
      ..writeByte(8)
      ..write(obj.passwordHash)
      ..writeByte(9)
      ..write(obj.role)
      ..writeByte(10)
      ..write(obj.employeeId)
      ..writeByte(11)
      ..write(obj.department)
      ..writeByte(12)
      ..write(obj.shift)
      ..writeByte(13)
      ..write(obj.hireDate)
      ..writeByte(14)
      ..write(obj.canProcessSales)
      ..writeByte(15)
      ..write(obj.canProcessReturns)
      ..writeByte(16)
      ..write(obj.canGiveDiscounts)
      ..writeByte(17)
      ..write(obj.maxDiscountPercent)
      ..writeByte(18)
      ..write(obj.canAccessReports)
      ..writeByte(19)
      ..write(obj.canManageInventory)
      ..writeByte(20)
      ..write(obj.canManageStaff)
      ..writeByte(21)
      ..write(obj.canVoidTransactions)
      ..writeByte(22)
      ..write(obj.canOpenCashDrawer)
      ..writeByte(23)
      ..write(obj.isActive)
      ..writeByte(24)
      ..write(obj.createdAt)
      ..writeByte(25)
      ..write(obj.lastLoginAt)
      ..writeByte(26)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RetailStaffModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
