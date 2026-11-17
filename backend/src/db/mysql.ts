import { config } from 'dotenv';
import { fileURLToPath } from 'node:url';
import mysql, { type Pool, type PoolConnection, type RowDataPacket } from 'mysql2/promise';

config({ path: fileURLToPath(new URL('../../.env', import.meta.url)), quiet: true });

let pool: Pool | undefined;

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing database configuration: ${name}`);
  }
  return value;
}

function getPool(): Pool {
  if (pool) return pool;

  const host = required('DB_HOST');
  const port = Number(required('DB_PORT'));
  const database = required('DB_NAME');
  const user = required('DB_USER');
  const password = required('DB_PASSWORD');

  if (!Number.isInteger(port) || port < 1 || port > 65535 || user === 'root') {
    throw new Error('Invalid database configuration');
  }

  pool = mysql.createPool({
    host,
    port,
    database,
    user,
    password,
    waitForConnections: true,
    connectionLimit: 5,
    connectTimeout: 5000,
  });

  return pool;
}

export function getDbConnection(): Promise<PoolConnection> {
  return getPool().getConnection();
}

export async function countDatabaseTables(): Promise<number> {
  const [rows] = await getPool().query<RowDataPacket[]>(
    "SELECT COUNT(*) AS totalTables FROM information_schema.tables WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE'",
  );
  return Number(rows[0].totalTables);
}

interface KhoaRow extends RowDataPacket {
  MaKhoa: string;
  TenKhoa: string;
  SoDienThoai: string | null;
}

export async function listKhoa() {
  const [rows] = await getPool().query<KhoaRow[]>(
    'SELECT MaKhoa, TenKhoa, SoDienThoai FROM Khoa ORDER BY TenKhoa ASC',
  );
  return rows.map(({ MaKhoa, TenKhoa, SoDienThoai }) => ({ MaKhoa, TenKhoa, SoDienThoai }));
}

interface BacSiRow extends RowDataPacket {
  MaBS: string;
  HoTen: string;
  ChuyenMon: string | null;
  MaKhoa: string;
}

export async function listActiveDoctorsByDepartment(maKhoa: string) {
  const [departments] = await getPool().execute<RowDataPacket[]>(
    'SELECT MaKhoa FROM Khoa WHERE MaKhoa = ? LIMIT 1',
    [maKhoa],
  );
  if (departments.length === 0) return null;

  const [rows] = await getPool().execute<BacSiRow[]>(
    'SELECT MaBS, HoTen, ChuyenMon, MaKhoa FROM BacSi WHERE MaKhoa = ? AND TrangThai = ? ORDER BY HoTen ASC',
    [maKhoa, 'DangLamViec'],
  );
  return rows.map(({ MaBS, HoTen, ChuyenMon, MaKhoa }) => ({ MaBS, HoTen, ChuyenMon, MaKhoa }));
}

interface DoctorStatusRow extends RowDataPacket {
  TrangThai: 'DangLamViec' | 'TamNghi' | 'NghiViec';
}

export async function getDoctorStatus(maBS: string) {
  const [rows] = await getPool().execute<DoctorStatusRow[]>(
    'SELECT TrangThai FROM BacSi WHERE MaBS = ? LIMIT 1',
    [maBS],
  );
  return rows[0]?.TrangThai ?? null;
}

interface AppointmentCountRow extends RowDataPacket {
  Ca: 'Sang' | 'Chieu' | 'Toi';
  DaDat: number;
}

export async function countAppointmentsByShift(maBS: string, ngayHen: string) {
  const [rows] = await getPool().execute<AppointmentCountRow[]>(
    'SELECT Ca, COUNT(*) AS DaDat FROM LichHen WHERE MaBS = ? AND NgayHen = ? AND TrangThai <> ? GROUP BY Ca',
    [maBS, ngayHen, 'Huy'],
  );
  return rows.map(({ Ca, DaDat }) => ({ Ca, DaDat: Number(DaDat) }));
}
