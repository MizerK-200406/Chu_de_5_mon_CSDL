import express from 'express';
import { BookingFailure, createBooking, type BookingInput } from './booking.js';
import {
  countAppointmentsByShift,
  countDatabaseTables,
  getDoctorStatus,
  listActiveDoctorsByDepartment,
  listKhoa,
} from './db/mysql.js';

const app = express();
const port = 3000;

app.get('/api/health', (_request, response) => {
  response.json({ status: 'ok' });
});

app.get('/api/health/db', async (_request, response) => {
  try {
    const totalTables = await countDatabaseTables();
    response.json({ status: 'connected', totalTables });
  } catch {
    response.status(503).json({ status: 'unavailable', message: 'Không thể kết nối cơ sở dữ liệu.' });
  }
});

app.get('/api/khoa', async (_request, response) => {
  try {
    response.json(await listKhoa());
  } catch {
    response.status(503).json({ status: 'unavailable', message: 'Không thể tải danh sách khoa.' });
  }
});

app.get('/api/khoa/:maKhoa/bac-si', async (request, response) => {
  const maKhoa = request.params.maKhoa;
  if (!maKhoa || maKhoa.length > 10 || /\s|[/?#]/u.test(maKhoa)) {
    response.status(400).json({ message: 'Mã khoa không hợp lệ.' });
    return;
  }

  try {
    const doctors = await listActiveDoctorsByDepartment(maKhoa);
    if (doctors === null) {
      response.status(404).json({ message: 'Không tìm thấy khoa.' });
      return;
    }
    response.json(doctors);
  } catch {
    response.status(500).json({ message: 'Không thể tải danh sách bác sĩ.' });
  }
});

function isValidCalendarDate(value: unknown): value is string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;

  const [year, month, day] = value.split('-').map(Number);
  if (year < 1000) return false;
  const parsed = new Date(Date.UTC(year, month - 1, day));
  if (
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() !== month - 1 ||
    parsed.getUTCDate() !== day
  ) return false;

  return true;
}

function todayInVietnam(): string {
  const todayParts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date());
  const part = (type: string) => todayParts.find((item) => item.type === type)!.value;
  return `${part('year')}-${part('month')}-${part('day')}`;
}

function isValidAppointmentDate(value: unknown): value is string {
  return isValidCalendarDate(value) && value >= todayInVietnam();
}

app.get('/api/bac-si/:maBS/lich-trong', async (request, response) => {
  const maBS = request.params.maBS;
  const ngayHen = request.query.ngayHen;
  if (!maBS || !/^[A-Za-z0-9_-]{1,10}$/.test(maBS)) {
    response.status(400).json({ message: 'Mã bác sĩ không hợp lệ.' });
    return;
  }
  if (!isValidAppointmentDate(ngayHen)) {
    response.status(400).json({ message: 'Ngày hẹn không hợp lệ hoặc đã qua.' });
    return;
  }

  try {
    const status = await getDoctorStatus(maBS);
    if (status === null) {
      response.status(404).json({ message: 'Không tìm thấy bác sĩ.' });
      return;
    }
    if (status !== 'DangLamViec') {
      response.status(409).json({ message: 'Bác sĩ hiện không làm việc.' });
      return;
    }

    const counts = await countAppointmentsByShift(maBS, ngayHen);
    const byShift = new Map(counts.map(({ Ca, DaDat }) => [Ca, DaDat]));
    const Ca = (['Sang', 'Chieu', 'Toi'] as const).map((TenCa) => {
      const DaDat = byShift.get(TenCa) ?? 0;
      return { TenCa, DaDat, ConTrong: Math.max(0, 30 - DaDat) };
    });
    response.json({ MaBS: maBS, NgayHen: ngayHen, Ca });
  } catch {
    response.status(500).json({ message: 'Không thể kiểm tra lịch khám.' });
  }
});

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function optionalText(value: unknown, maxLength: number): string | null | undefined {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string') return undefined;
  const text = value.trim();
  if (!text) return null;
  return text.length <= maxLength && !/[\x00-\x1F\x7F]/.test(text) ? text : undefined;
}

function parseBookingRequest(body: unknown): BookingInput | null {
  if (!isRecord(body) || !isRecord(body.benhNhan) || !isRecord(body.lichHen)) return null;
  const patient = body.benhNhan;
  const appointment = body.lichHen;

  if (typeof patient.HoTen !== 'string') return null;
  const hoTen = patient.HoTen.trim();
  if (!hoTen || hoTen.length > 100 || /[\x00-\x1F\x7F]/.test(hoTen)) return null;
  if (!isValidCalendarDate(patient.NgaySinh) || patient.NgaySinh > todayInVietnam()) return null;
  if (patient.GioiTinh !== 'Nam' && patient.GioiTinh !== 'Nu') return null;

  const cccd = patient.CCCD === undefined || patient.CCCD === null || patient.CCCD === '' ? null : patient.CCCD;
  if (cccd !== null && (typeof cccd !== 'string' || !/^\d{12}$/.test(cccd))) return null;
  const soDienThoai = optionalText(patient.SoDienThoai, 15);
  const diaChi = optionalText(patient.DiaChi, 255);
  if (soDienThoai === undefined || diaChi === undefined) return null;

  if (typeof appointment.MaBS !== 'string' || !/^[A-Za-z0-9_-]{1,10}$/.test(appointment.MaBS)) return null;
  if (!isValidAppointmentDate(appointment.NgayHen)) return null;
  if (appointment.Ca !== 'Sang' && appointment.Ca !== 'Chieu' && appointment.Ca !== 'Toi') return null;

  return {
    benhNhan: {
      HoTen: hoTen,
      NgaySinh: patient.NgaySinh,
      GioiTinh: patient.GioiTinh,
      CCCD: cccd,
      SoDienThoai: soDienThoai,
      DiaChi: diaChi,
    },
    lichHen: {
      MaBS: appointment.MaBS,
      NgayHen: appointment.NgayHen,
      Ca: appointment.Ca,
    },
  };
}

const parseJson = express.json({ limit: '16kb' });
app.post('/api/lich-hen', (request, response, next) => {
  parseJson(request, response, (error) => {
    if (error) response.status(400).json({ message: 'JSON không hợp lệ.' });
    else next();
  });
}, async (request, response) => {
  const input = parseBookingRequest(request.body as unknown);
  if (!input) {
    response.status(400).json({ message: 'Thông tin đăng ký không hợp lệ.' });
    return;
  }

  try {
    response.status(201).json(await createBooking(input));
  } catch (error) {
    if (error instanceof BookingFailure) {
      switch (error.reason) {
        case 'DOCTOR_NOT_FOUND':
          response.status(404).json({ message: 'Không tìm thấy bác sĩ.' });
          return;
        case 'DOCTOR_INACTIVE':
          response.status(409).json({ message: 'Bác sĩ hiện không làm việc.' });
          return;
        case 'DUPLICATE_CCCD':
          response.status(409).json({ message: 'CCCD đã có hồ sơ bệnh nhân.' });
          return;
        case 'FULL':
          response.status(409).json({ message: 'Ca khám của bác sĩ đã đủ 30 lịch hẹn.' });
          return;
      }
    }
    response.status(500).json({ message: 'Không thể đặt lịch khám.' });
  }
});

app.listen(port, '127.0.0.1', () => {
  console.log(`Backend đang chạy tại http://127.0.0.1:${port}`);
});
