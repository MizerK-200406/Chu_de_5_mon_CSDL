import { useEffect, useMemo, useRef, useState, type FormEvent, type KeyboardEvent } from 'react';
import { api, type BacSi, type CaTrong, type KetQuaDatLich, type Khoa, type TenCa } from './api';

const shiftLabels: Record<TenCa, { label: string; time: string }> = {
  Sang: { label: 'Buổi sáng', time: '07:30 – 11:30' },
  Chieu: { label: 'Buổi chiều', time: '13:30 – 17:00' },
  Toi: { label: 'Buổi tối', time: '18:00 – 20:00' },
};

function todayInVietnam() {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(new Date());
  const value = (type: string) => parts.find((part) => part.type === type)?.value ?? '';
  return `${value('year')}-${value('month')}-${value('day')}`;
}

function formatDate(value: string) {
  if (!value) return 'Chưa chọn';
  const [year, month, day] = value.split('-').map(Number);
  return new Intl.DateTimeFormat('vi-VN', {
    weekday: 'long', day: '2-digit', month: '2-digit', year: 'numeric', timeZone: 'Asia/Ho_Chi_Minh',
  }).format(new Date(Date.UTC(year, month - 1, day)));
}

function toIsoDate(day: string, month: string, year: string): string {
  if (day.length !== 2 || month.length !== 2 || year.length !== 4) return '';
  const dayNumber = Number(day);
  const monthNumber = Number(month);
  const yearNumber = Number(year);
  const parsed = new Date(Date.UTC(yearNumber, monthNumber - 1, dayNumber));
  if (
    yearNumber < 1000 || parsed.getUTCFullYear() !== yearNumber ||
    parsed.getUTCMonth() !== monthNumber - 1 || parsed.getUTCDate() !== dayNumber
  ) return '';
  return `${year}-${month}-${day}`;
}

function SegmentedDateInput({ value, onChange, min, max, label }: {
  value: string;
  onChange: (value: string) => void;
  min?: string;
  max?: string;
  label: string;
}) {
  const initial = value ? value.split('-') : ['', '', ''];
  const [parts, setParts] = useState<[string, string, string]>([initial[2] ?? '', initial[1] ?? '', initial[0] ?? '']);
  const inputs = [useRef<HTMLInputElement>(null), useRef<HTMLInputElement>(null), useRef<HTMLInputElement>(null)];
  const limits = [2, 2, 4];
  const complete = parts.every((part, index) => part.length === limits[index]);
  const iso = toIsoDate(parts[0], parts[1], parts[2]);
  const outOfRange = Boolean(iso && ((min && iso < min) || (max && iso > max)));
  const invalid = complete && (!iso || outOfRange);

  function updatePart(index: number, rawValue: string) {
    const next = [...parts] as [string, string, string];
    next[index] = rawValue.replace(/\D/g, '').slice(0, limits[index]);
    setParts(next);
    const nextIso = toIsoDate(next[0], next[1], next[2]);
    onChange(nextIso && (!min || nextIso >= min) && (!max || nextIso <= max) ? nextIso : '');
    if (next[index].length === limits[index]) {
      if (index < 2) inputs[index + 1].current?.focus();
      else inputs[index].current?.blur();
    }
  }

  function handleKeyDown(index: number, event: KeyboardEvent<HTMLInputElement>) {
    if (event.key === 'Backspace' && parts[index] === '' && index > 0) inputs[index - 1].current?.focus();
  }

  return (
    <div className="segmented-date-wrap">
      <div className={`segmented-date ${invalid ? 'invalid' : ''}`}>
        {(['Ngày', 'Tháng', 'Năm'] as const).map((partLabel, index) => (
          <span className="date-segment" key={partLabel}>
            <input
              ref={inputs[index]}
              type="text"
              inputMode="numeric"
              autoComplete="off"
              aria-label={`${label} - ${partLabel}`}
              aria-invalid={invalid}
              placeholder={index === 0 ? 'DD' : index === 1 ? 'MM' : 'YYYY'}
              value={parts[index]}
              maxLength={limits[index]}
              required
              onChange={(event) => updatePart(index, event.target.value)}
              onKeyDown={(event) => handleKeyDown(index, event)}
            />
            {index < 2 && <i>/</i>}
          </span>
        ))}
      </div>
      {invalid && <small className="date-error">{outOfRange ? `${label} nằm ngoài khoảng cho phép.` : `${label} không tồn tại.`}</small>}
    </div>
  );
}

type IconName = 'hospital' | 'department' | 'doctor' | 'calendar' | 'patient' | 'check' | 'phone';

function Icon({ name }: { name: IconName }) {
  const paths: Record<IconName, React.ReactNode> = {
    hospital: <><path d="M4 21V5a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v16"/><path d="M9 21v-4h3v4M8 8h5M10.5 5.5v5M17 9h2a1 1 0 0 1 1 1v11M3 21h19"/></>,
    department: <><path d="M4 20h16M6 20V9m12 11V9M3 9l9-5 9 5M9 13h2m2 0h2M9 17h2m2 0h2"/></>,
    doctor: <><circle cx="12" cy="8" r="4"/><path d="M4.5 21a7.5 7.5 0 0 1 15 0M9 15l3 3 3-3"/></>,
    calendar: <><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M16 3v4M8 3v4M3 10h18M8 14h.01M12 14h.01M16 14h.01M8 18h.01M12 18h.01"/></>,
    patient: <><circle cx="12" cy="7" r="4"/><path d="M5 21v-2a7 7 0 0 1 14 0v2M9 14l3 3 3-3"/></>,
    check: <path d="m5 12 4 4L19 6"/>,
    phone: <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.8 19.8 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.12 4.18 2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.12.9.34 1.78.65 2.63a2 2 0 0 1-.45 2.11L8.04 9.73a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.85.31 1.73.53 2.63.65A2 2 0 0 1 22 16.92z"/>,
  };
  return <svg className="icon" viewBox="0 0 24 24" aria-hidden="true">{paths[name]}</svg>;
}

function App() {
  const [departments, setDepartments] = useState<Khoa[]>([]);
  const [doctors, setDoctors] = useState<BacSi[]>([]);
  const [selectedDepartment, setSelectedDepartment] = useState('');
  const [selectedDoctor, setSelectedDoctor] = useState('');
  const [appointmentDate, setAppointmentDate] = useState('');
  const [availability, setAvailability] = useState<CaTrong[]>([]);
  const [selectedShift, setSelectedShift] = useState<TenCa | ''>('');
  const [birthDate, setBirthDate] = useState('');
  const [loading, setLoading] = useState({ departments: true, doctors: false, availability: false, submit: false });
  const [error, setError] = useState('');
  const [result, setResult] = useState<KetQuaDatLich | null>(null);

  const selectedDepartmentData = departments.find((item) => item.MaKhoa === selectedDepartment);
  const selectedDoctorData = doctors.find((item) => item.MaBS === selectedDoctor);
  const canSubmit = Boolean(selectedDepartment && selectedDoctor && appointmentDate && selectedShift && !loading.submit);

  useEffect(() => {
    api.layKhoa()
      .then(setDepartments)
      .catch((reason: Error) => setError(reason.message))
      .finally(() => setLoading((value) => ({ ...value, departments: false })));
  }, []);

  useEffect(() => {
    setDoctors([]);
    setSelectedDoctor('');
    setAvailability([]);
    setSelectedShift('');
    if (!selectedDepartment) return;
    setLoading((value) => ({ ...value, doctors: true }));
    setError('');
    api.layBacSi(selectedDepartment)
      .then(setDoctors)
      .catch((reason: Error) => setError(reason.message))
      .finally(() => setLoading((value) => ({ ...value, doctors: false })));
  }, [selectedDepartment]);

  useEffect(() => {
    setAvailability([]);
    setSelectedShift('');
    if (!selectedDoctor || !appointmentDate) return;
    let active = true;
    setLoading((value) => ({ ...value, availability: true }));
    setError('');
    api.layLichTrong(selectedDoctor, appointmentDate)
      .then((data) => { if (active) setAvailability(data.Ca); })
      .catch((reason: Error) => { if (active) setError(reason.message); })
      .finally(() => { if (active) setLoading((value) => ({ ...value, availability: false })); });
    return () => { active = false; };
  }, [selectedDoctor, appointmentDate]);

  const progress = useMemo(() => [
    Boolean(selectedDepartment), Boolean(selectedDoctor), Boolean(appointmentDate && selectedShift),
  ], [selectedDepartment, selectedDoctor, appointmentDate, selectedShift]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!canSubmit) {
      setError('Vui lòng chọn đầy đủ khoa, bác sĩ, ngày và ca khám.');
      return;
    }
    const form = new FormData(event.currentTarget);
    if (!birthDate) {
      setError('Ngày sinh không hợp lệ hoặc chưa được nhập đầy đủ.');
      return;
    }
    setLoading((value) => ({ ...value, submit: true }));
    setError('');
    try {
      const response = await api.datLich({
        benhNhan: {
          HoTen: form.get('HoTen'), NgaySinh: birthDate, GioiTinh: form.get('GioiTinh'),
          CCCD: form.get('CCCD') || null, SoDienThoai: form.get('SoDienThoai') || null,
          DiaChi: form.get('DiaChi') || null,
        },
        lichHen: { MaBS: selectedDoctor, NgayHen: appointmentDate, Ca: selectedShift },
      });
      setResult(response);
      window.scrollTo({ top: 0, behavior: 'smooth' });
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Không thể đặt lịch khám.');
    } finally {
      setLoading((value) => ({ ...value, submit: false }));
    }
  }

  function reset() {
    setResult(null);
    setSelectedDepartment('');
    setAppointmentDate('');
    setBirthDate('');
    setError('');
  }

  if (result) {
    return (
      <div className="app-shell">
        <Header />
        <main className="success-page">
          <section className="success-card" aria-live="polite">
            <div className="success-mark"><Icon name="check" /></div>
            <p className="eyebrow">Đăng ký thành công</p>
            <h1>Lịch khám của bạn đã được ghi nhận</h1>
            <p className="success-lead">Vui lòng lưu mã lịch và có mặt sớm 15 phút để làm thủ tục.</p>
            <div className="booking-code"><span>Mã lịch khám</span><strong>{result.MaLH}</strong></div>
            <dl className="result-grid">
              <div><dt>Khoa khám</dt><dd>{selectedDepartmentData?.TenKhoa}</dd></div>
              <div><dt>Bác sĩ</dt><dd>{selectedDoctorData?.HoTen}</dd></div>
              <div><dt>Ngày khám</dt><dd>{formatDate(result.NgayHen)}</dd></div>
              <div><dt>Ca khám</dt><dd>{shiftLabels[result.Ca].label}</dd></div>
              <div><dt>Mã bệnh nhân</dt><dd>{result.MaBN}</dd></div>
              <div><dt>Trạng thái</dt><dd><span className="status-pill">Chờ khám</span></dd></div>
            </dl>
            <button className="primary-button" type="button" onClick={reset}>Đăng ký lịch khác</button>
            <p className="demo-note">Hệ thống demo học thuật · Không sử dụng dữ liệu bệnh nhân thật</p>
          </section>
        </main>
      </div>
    );
  }

  return (
    <div className="app-shell" id="top">
      <Header />
      <main className="page-grid">
        <aside className="intro-panel">
          <p className="eyebrow">Đặt lịch khám trực tuyến</p>
          <h1>Chủ động lịch khám,<br/><span>an tâm chăm sóc.</span></h1>
          <p className="intro-copy">Chọn chuyên khoa và bác sĩ phù hợp. Thông tin lịch khám được lưu trực tiếp vào hệ thống EHR.</p>
          <ol className="progress-list">
            {[
              ['Chọn khoa', selectedDepartmentData?.TenKhoa],
              ['Chọn bác sĩ', selectedDoctorData?.HoTen],
              ['Chọn lịch khám', selectedShift ? `${formatDate(appointmentDate)} · ${shiftLabels[selectedShift].label}` : ''],
            ].map(([label, detail], index) => (
              <li className={progress[index] ? 'done' : ''} key={label}>
                <span className="step-number">{progress[index] ? <Icon name="check" /> : index + 1}</span>
                <span><strong>{label}</strong><small>{detail || 'Chưa hoàn thành'}</small></span>
              </li>
            ))}
          </ol>
          <div className="privacy-note"><span>i</span><p><strong>Lưu ý bảo mật</strong>Website phục vụ demo học thuật. Không nhập dữ liệu bệnh nhân thật.</p></div>
        </aside>

        <form className="booking-form" onSubmit={submit}>
          {error && <div className="alert" role="alert"><strong>Chưa thể tiếp tục</strong><span>{error}</span><button type="button" aria-label="Đóng thông báo" onClick={() => setError('')}>×</button></div>}

          <section className="form-section">
            <SectionHeading icon="department" step="01" title="Chọn chuyên khoa" description="Lựa chọn khoa phù hợp với nhu cầu thăm khám" />
            <label className="field full-field"><span>Chuyên khoa <b>*</b></span>
              <select value={selectedDepartment} onChange={(event) => setSelectedDepartment(event.target.value)} disabled={loading.departments} required>
                <option value="">{loading.departments ? 'Đang tải danh sách khoa...' : 'Chọn chuyên khoa'}</option>
                {departments.map((item) => <option value={item.MaKhoa} key={item.MaKhoa}>{item.TenKhoa}</option>)}
              </select>
            </label>
            {selectedDepartmentData?.SoDienThoai && <p className="inline-note"><Icon name="phone" /> Số điện thoại khoa: {selectedDepartmentData.SoDienThoai}</p>}
          </section>

          <section className="form-section">
            <SectionHeading icon="doctor" step="02" title="Chọn bác sĩ" description="Danh sách chỉ hiển thị bác sĩ đang làm việc" />
            {!selectedDepartment ? <EmptyState text="Vui lòng chọn chuyên khoa trước" /> : loading.doctors ? <SkeletonCards /> : doctors.length === 0 ? <EmptyState text="Khoa này hiện chưa có bác sĩ nhận lịch" /> : (
              <div className="doctor-grid">
                {doctors.map((doctor) => (
                  <button className={`doctor-card ${selectedDoctor === doctor.MaBS ? 'selected' : ''}`} type="button" onClick={() => setSelectedDoctor(doctor.MaBS)} key={doctor.MaBS}>
                    <span className="doctor-avatar">{doctor.HoTen.replace(/^(TS\.|PGS\.TS\.|ThS\.|BSCKI{1,2}\.|BS\.)+/g, '').trim().split(' ').slice(-2).map((word) => word[0]).join('')}</span>
                    <span><strong>{doctor.HoTen}</strong><small>{doctor.ChuyenMon || 'Bác sĩ chuyên khoa'}</small></span>
                    <span className="radio-mark"><Icon name="check" /></span>
                  </button>
                ))}
              </div>
            )}
          </section>

          <section className="form-section">
            <SectionHeading icon="calendar" step="03" title="Chọn lịch khám" description="Số chỗ được cập nhật trực tiếp tại thời điểm tra cứu" />
            <label className="field date-field"><span>Ngày khám <b>*</b></span><SegmentedDateInput label="Ngày khám" min={todayInVietnam()} value={appointmentDate} onChange={setAppointmentDate} /></label>
            {selectedDoctor && appointmentDate ? loading.availability ? <SkeletonCards /> : (
              <div className="shift-grid">
                {availability.map((shift) => {
                  const disabled = shift.ConTrong === 0;
                  return <button type="button" disabled={disabled} className={`shift-card ${selectedShift === shift.TenCa ? 'selected' : ''}`} onClick={() => setSelectedShift(shift.TenCa)} key={shift.TenCa}>
                    <span className="shift-top"><strong>{shiftLabels[shift.TenCa].label}</strong><span className={disabled ? 'full' : ''}>{disabled ? 'Đã đầy' : `Còn ${shift.ConTrong} chỗ`}</span></span>
                    <small>{shiftLabels[shift.TenCa].time}</small>
                    <span className="capacity"><i style={{ width: `${Math.min(100, shift.DaDat / 30 * 100)}%` }} /></span>
                  </button>;
                })}
              </div>
            ) : <EmptyState text="Chọn bác sĩ và ngày khám để xem số chỗ còn lại" />}
          </section>

          <section className="form-section patient-section">
            <SectionHeading icon="patient" step="04" title="Thông tin bệnh nhân" description="Các trường có dấu * là bắt buộc" />
            <div className="field-grid">
              <label className="field full-field"><span>Họ và tên <b>*</b></span><input name="HoTen" maxLength={100} placeholder="Ví dụ: Nguyễn Văn An" autoComplete="name" required /></label>
              <label className="field"><span>Ngày sinh <b>*</b></span><SegmentedDateInput label="Ngày sinh" max={todayInVietnam()} value={birthDate} onChange={setBirthDate} /></label>
              <label className="field"><span>Giới tính <b>*</b></span><select name="GioiTinh" defaultValue="" required><option value="" disabled>Chọn giới tính</option><option value="Nam">Nam</option><option value="Nu">Nữ</option></select></label>
              <label className="field"><span>CCCD</span><input name="CCCD" inputMode="numeric" pattern="[0-9]{12}" maxLength={12} placeholder="12 chữ số (không bắt buộc)" /></label>
              <label className="field"><span>Số điện thoại</span><input name="SoDienThoai" type="tel" maxLength={15} placeholder="Ví dụ: 0912 345 678" autoComplete="tel" /></label>
              <label className="field full-field"><span>Địa chỉ</span><input name="DiaChi" maxLength={255} placeholder="Địa chỉ hiện tại (không bắt buộc)" autoComplete="street-address" /></label>
            </div>
          </section>

          <div className="submit-panel">
            <div><strong>Xác nhận đăng ký</strong><span>{selectedDoctorData && selectedShift ? `${selectedDoctorData.HoTen} · ${shiftLabels[selectedShift].label}` : 'Hoàn tất các bước để đặt lịch'}</span></div>
            <button className="primary-button" type="submit" disabled={!canSubmit}>{loading.submit ? <><span className="spinner" /> Đang ghi nhận...</> : 'Xác nhận đặt lịch'}</button>
          </div>
        </form>
      </main>
      <footer><span>© 2026 EHR Hospital Demo</span><span>Đồ án Cơ sở dữ liệu · PTIT</span></footer>
    </div>
  );
}

function Header() {
  return <header className="site-header"><a className="brand" href="#top"><span className="brand-mark"><Icon name="hospital" /></span><span><strong>EHR Hospital</strong><small>Đặt lịch khám trực tuyến</small></span></a><div className="system-status"><span /> Hệ thống đang hoạt động</div></header>;
}

function SectionHeading({ icon, step, title, description }: { icon: 'department' | 'doctor' | 'calendar' | 'patient'; step: string; title: string; description: string }) {
  return <div className="section-heading"><span className="section-icon"><Icon name={icon} /></span><div><p>Bước {step}</p><h2>{title}</h2><span>{description}</span></div></div>;
}

function EmptyState({ text }: { text: string }) {
  return <div className="empty-state"><span>•••</span>{text}</div>;
}

function SkeletonCards() {
  return <div className="skeleton-grid" aria-label="Đang tải"><span /><span /><span /></div>;
}

export default App;
