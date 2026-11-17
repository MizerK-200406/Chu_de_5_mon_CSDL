import { randomBytes } from 'node:crypto';
import type { PoolConnection, RowDataPacket } from 'mysql2/promise';
import { getDbConnection } from './db/mysql.js';

export interface BookingInput {
  benhNhan: {
    HoTen: string;
    NgaySinh: string;
    GioiTinh: 'Nam' | 'Nu';
    CCCD: string | null;
    SoDienThoai: string | null;
    DiaChi: string | null;
  };
  lichHen: {
    MaBS: string;
    NgayHen: string;
    Ca: 'Sang' | 'Chieu' | 'Toi';
  };
}

type BookingFailureReason = 'DOCTOR_NOT_FOUND' | 'DOCTOR_INACTIVE' | 'DUPLICATE_CCCD' | 'FULL' | 'ID_COLLISION';

export class BookingFailure extends Error {
  constructor(readonly reason: BookingFailureReason) {
    super(reason);
  }
}

interface DoctorRow extends RowDataPacket {
  TrangThai: string;
}

interface CountRow extends RowDataPacket {
  DaDat: number;
}

interface LockRow extends RowDataPacket {
  Acquired: number;
}

function newCode(prefix: 'BN' | 'LH'): string {
  return prefix + randomBytes(6).toString('base64url');
}

function sqlError(error: unknown): { code?: string; sqlMessage?: string } {
  return error && typeof error === 'object' ? error as { code?: string; sqlMessage?: string } : {};
}

function isDuplicateIndex(error: unknown, index: string): boolean {
  const { code, sqlMessage } = sqlError(error);
  return code === 'ER_DUP_ENTRY' && typeof sqlMessage === 'string' && sqlMessage.includes(index);
}

async function insertPatient(connection: PoolConnection, input: BookingInput['benhNhan']): Promise<string> {
  for (let attempt = 0; attempt < 5; attempt++) {
    const maBN = newCode('BN');
    try {
      await connection.execute(
        'INSERT INTO BenhNhan (MaBN, HoTen, NgaySinh, GioiTinh, CCCD, SoDienThoai, DiaChi) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [maBN, input.HoTen, input.NgaySinh, input.GioiTinh, input.CCCD, input.SoDienThoai, input.DiaChi],
      );
      return maBN;
    } catch (error) {
      if (isDuplicateIndex(error, 'PRIMARY')) continue;
      if (isDuplicateIndex(error, 'uq_BenhNhan_CCCD')) throw new BookingFailure('DUPLICATE_CCCD');
      throw error;
    }
  }
  throw new BookingFailure('ID_COLLISION');
}

async function insertAppointment(connection: PoolConnection, maBN: string, input: BookingInput['lichHen']): Promise<string> {
  for (let attempt = 0; attempt < 5; attempt++) {
    const maLH = newCode('LH');
    try {
      await connection.execute(
        'INSERT INTO LichHen (MaLH, MaBN, MaBS, NgayHen, Ca, TrangThai) VALUES (?, ?, ?, ?, ?, ?)',
        [maLH, maBN, input.MaBS, input.NgayHen, input.Ca, 'ChoKham'],
      );
      return maLH;
    } catch (error) {
      if (isDuplicateIndex(error, 'PRIMARY')) continue;
      throw error;
    }
  }
  throw new BookingFailure('ID_COLLISION');
}

export async function createBooking(input: BookingInput) {
  const connection = await getDbConnection();
  let transactionStarted = false;
  let lockAcquired = false;
  const lockName = `ehr_booking_${input.lichHen.MaBS}`;

  try {
    // Named lock serializes all bookings for one doctor without requiring UPDATE permission on BacSi.
    const [locks] = await connection.execute<LockRow[]>('SELECT GET_LOCK(?, 10) AS Acquired', [lockName]);
    if (Number(locks[0]?.Acquired) !== 1) throw new Error('BOOKING_LOCK_TIMEOUT');
    lockAcquired = true;

    // READ COMMITTED ensures the count sees appointments committed by the prior lock holder.
    await connection.query('SET TRANSACTION ISOLATION LEVEL READ COMMITTED');
    await connection.beginTransaction();
    transactionStarted = true;

    const [doctors] = await connection.execute<DoctorRow[]>(
      'SELECT TrangThai FROM BacSi WHERE MaBS = ?',
      [input.lichHen.MaBS],
    );
    if (doctors.length === 0) throw new BookingFailure('DOCTOR_NOT_FOUND');
    if (doctors[0].TrangThai !== 'DangLamViec') throw new BookingFailure('DOCTOR_INACTIVE');

    if (input.benhNhan.CCCD !== null) {
      const [patients] = await connection.execute<RowDataPacket[]>(
        'SELECT MaBN FROM BenhNhan WHERE CCCD = ? LIMIT 1',
        [input.benhNhan.CCCD],
      );
      if (patients.length > 0) throw new BookingFailure('DUPLICATE_CCCD');
    }

    const [counts] = await connection.execute<CountRow[]>(
      'SELECT COUNT(*) AS DaDat FROM LichHen WHERE MaBS = ? AND NgayHen = ? AND Ca = ? AND TrangThai <> ?',
      [input.lichHen.MaBS, input.lichHen.NgayHen, input.lichHen.Ca, 'Huy'],
    );
    if (Number(counts[0].DaDat) >= 30) throw new BookingFailure('FULL');

    const maBN = await insertPatient(connection, input.benhNhan);
    const maLH = await insertAppointment(connection, maBN, input.lichHen);
    await connection.commit();
    transactionStarted = false;

    return {
      MaLH: maLH,
      MaBN: maBN,
      MaBS: input.lichHen.MaBS,
      NgayHen: input.lichHen.NgayHen,
      Ca: input.lichHen.Ca,
      TrangThai: 'ChoKham' as const,
    };
  } catch (error) {
    if (transactionStarted) {
      try { await connection.rollback(); } catch { /* Connection may already be unavailable. */ }
    }
    if (error instanceof BookingFailure) throw error;

    const { code, sqlMessage } = sqlError(error);
    if (code === 'ER_DUP_ENTRY' && typeof sqlMessage === 'string' && sqlMessage.includes('uq_BenhNhan_CCCD')) {
      throw new BookingFailure('DUPLICATE_CCCD');
    }
    if (code === 'ER_SIGNAL_EXCEPTION' && typeof sqlMessage === 'string') {
      if (sqlMessage.includes('30 lich hen')) throw new BookingFailure('FULL');
      if (sqlMessage.includes('DangLamViec')) throw new BookingFailure('DOCTOR_INACTIVE');
    }
    throw error;
  } finally {
    if (lockAcquired) {
      try { await connection.execute('SELECT RELEASE_LOCK(?)', [lockName]); } catch { /* Connection cleanup releases it too. */ }
    }
    connection.release();
  }
}
