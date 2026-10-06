using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestAPIAttendaces.Interfaces;
using System.Globalization;

namespace RestAPIAttendaces.Controllers
{
    [ApiController]
    [Route("api/attendances")]
    public class AttendanceController : BaseApiController
    {
        private readonly IAttendance _attendance;
        private readonly AppDbContext _context;
        public AttendanceController(IAttendance attendance, AppDbContext context)
        {
            _attendance = attendance;
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var companyId = GetCompanyId();
            var query = _context.Attendance
                .AsNoTracking()
                .Include(a => a.User)
                .Include(a => a.Location)
                .Include(a => a.Attachments)
                .AsQueryable();

            if (companyId.HasValue)
                query = query.Where(a => a.User != null && a.User.CompanyId == companyId.Value);

            return Ok(await query
                .OrderByDescending(a => a.Date)
                .ThenByDescending(a => a.ClockIn)
                .ToListAsync());
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var result = await _attendance.GetById(id);
            if (result == null) return NotFound();
            return Ok(result);
        }

        [HttpGet("me")]
        public async Task<IActionResult> GetMine([FromQuery] int? year, [FromQuery] int? month)
        {
            var userId = GetUserId();
            if (userId == 0) return Unauthorized();
            var query = _context.Attendance
                .AsNoTracking()
                .Include(a => a.Location)
                .Include(a => a.Attachments)
                .Where(a => a.UserId == userId);
            if (year.HasValue) query = query.Where(a => a.Date.Year == year.Value);
            if (month.HasValue) query = query.Where(a => a.Date.Month == month.Value);
            return Ok(await query.OrderByDescending(a => a.Date).ThenByDescending(a => a.ClockIn).ToListAsync());
        }

        // Status absensi hari ini: dipakai mobile untuk menentukan mode (check-in / check-out / sudah selesai)
        // dan daftar lembur yang sudah disetujui & masih butuh absen (check-in/check-out) hari ini.
        [HttpGet("today-status")]
        public async Task<IActionResult> GetTodayStatus()
        {
            var userId = GetUserId();
            if (userId == 0) return Unauthorized();
            var today = DateTime.Now.Date;

            var regular = await _context.Attendance
                .AsNoTracking()
                .Where(a => a.UserId == userId && a.Date == today && a.OvertimeId == null)
                .OrderByDescending(a => a.CreatedAt)
                .FirstOrDefaultAsync();

            var approvedOvertimes = await _context.Overtime
                .AsNoTracking()
                .Where(o => o.UserId == userId
                    && o.Status == OvertimeStatuses.APPROVED
                    && o.Date.Date == today)
                .Include(o => o.Schedule)
                .ToListAsync();
            var overtimeIds = approvedOvertimes.Select(o => o.Id).ToList();
            var overtimeAttendances = await _context.Attendance
                .AsNoTracking()
                .Where(a => a.OvertimeId != null && overtimeIds.Contains(a.OvertimeId.Value))
                .ToListAsync();

            return Ok(new
            {
                regular = regular == null ? null : new
                {
                    id = regular.Id,
                    status = regular.Status,
                    clockIn = regular.ClockIn,
                    clockOut = regular.ClockOut,
                    completed = regular.Status.Equals("Hadir", StringComparison.OrdinalIgnoreCase)
                        ? regular.ClockOut != null
                        : true
                },
                overtimes = approvedOvertimes.Select(o =>
                {
                    var att = overtimeAttendances
                        .Where(a => a.OvertimeId == o.Id)
                        .OrderByDescending(a => a.CreatedAt)
                        .FirstOrDefault();
                    return new
                    {
                        overtimeId = o.Id,
                        date = o.Date,
                        requestType = o.RequestType,
                        scheduleId = o.ScheduleId,
                        scheduleName = o.Schedule?.Name,
                        startTime = o.Schedule?.ClockIn,
                        endTime = o.Schedule?.ClockOut,
                        note = o.Note,
                        attendanceId = att?.Id,
                        clockIn = att?.ClockIn,
                        clockOut = att?.ClockOut,
                        completed = att != null && att.ClockOut != null
                    };
                })
            });
        }

        [HttpPost("mobile")]
        [Consumes("multipart/form-data")]
        public async Task<IActionResult> CreateMobile(
            [FromForm] string status,
            [FromForm] string? mode,
            [FromForm] int? overtimeId,
            [FromForm] string? note,
            [FromForm] int? locationId,
            [FromForm] string? latitude,
            [FromForm] string? longitude,
            [FromForm] string? accuracyMeters,
            [FromForm] string? distanceMeters,
            [FromForm] string? faceSimilarity,
            [FromForm] string? companyTolerance,
            [FromForm] bool faceVerified,
            [FromForm] bool livenessVerified,
            [FromForm] List<IFormFile>? attachments)
        {
            var userId = GetUserId();
            if (userId == 0) return Unauthorized();
            var user = await _context.User.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId);
            if (user == null || !user.IsActive) return Unauthorized();
            if (string.IsNullOrWhiteSpace(status)) return BadRequest(new { message = "Status absensi wajib diisi." });
            status = status.Trim();
            if (!status.Equals("Hadir", StringComparison.OrdinalIgnoreCase) &&
                !status.Equals("Izin", StringComparison.OrdinalIgnoreCase) &&
                !status.Equals("Sakit", StringComparison.OrdinalIgnoreCase) &&
                !status.Equals("Lembur", StringComparison.OrdinalIgnoreCase))
                return BadRequest(new { message = "Status absensi tidak dikenali." });

            var setting = await _context.CompanySetting.AsNoTracking()
                .FirstOrDefaultAsync(s => s.CompanyId == user.CompanyId);
            var today = DateTime.Now.Date;
            var effectiveMode = string.IsNullOrWhiteSpace(mode)
                ? (status.Equals("Hadir", StringComparison.OrdinalIgnoreCase) ||
                   status.Equals("Lembur", StringComparison.OrdinalIgnoreCase)
                    ? "checkin"
                    : "leave")
                : mode.Trim().ToLowerInvariant();

            if (effectiveMode is not ("checkin" or "checkout" or "leave"))
                return BadRequest(new { message = "Mode absensi tidak dikenali." });

            // Izin / Sakit: satu kali submit per hari, tanpa check-in/check-out.
            if (effectiveMode == "leave")
            {
                if (status.Equals("Hadir", StringComparison.OrdinalIgnoreCase) ||
                    status.Equals("Lembur", StringComparison.OrdinalIgnoreCase))
                    return BadRequest(new { message = "Hadir dan Lembur harus menggunakan check-in." });
                if (string.IsNullOrWhiteSpace(note))
                    return BadRequest(new { message = "Keterangan wajib diisi untuk Izin atau Sakit." });

                var existingLeave = await _context.Attendance
                    .FirstOrDefaultAsync(a => a.UserId == userId && a.Date == today && a.OvertimeId == null);
                if (existingLeave != null)
                    return BadRequest(new { message = "Anda sudah mengisi absensi untuk hari ini." });

                var leave = new Attendance
                {
                    UserId = userId,
                    LocationId = locationId,
                    Date = today,
                    ClockIn = null,
                    ClockOut = null,
                    Status = status,
                    Note = note,
                    CompanyTolerance = setting?.FaceTolerance,
                    CreatedBy = userId
                };
                _context.Attendance.Add(leave);
                await _context.SaveChangesAsync();
                await SaveAttachments(leave.Id, attachments, userId);
                return CreatedAtAction(nameof(GetById), new { id = leave.Id }, leave);
            }

            if (status.Equals("Izin", StringComparison.OrdinalIgnoreCase) ||
                status.Equals("Sakit", StringComparison.OrdinalIgnoreCase))
                return BadRequest(new { message = "Izin dan Sakit tidak memerlukan check-in atau check-out." });

            if (!locationId.HasValue ||
                !await _context.CompanyLocation.AnyAsync(l =>
                    l.Id == locationId.Value && l.CompanyId == user.CompanyId))
                return BadRequest(new { message = "Lokasi absensi tidak sesuai dengan perusahaan Anda." });

            // Lembur wajib punya overtimeId dan tugas lembur berstatus approved milik user ini.
            Overtime? overtime = null;
            if (status.Equals("Lembur", StringComparison.OrdinalIgnoreCase))
            {
                if (overtimeId == null)
                    return BadRequest(new { message = "Sesi lembur tidak ditemukan." });
                overtime = await _context.Overtime.FirstOrDefaultAsync(o => o.Id == overtimeId.Value);
                if (overtime == null || overtime.UserId != userId)
                    return NotFound(new { message = "Tugas lembur tidak ditemukan." });
                if (!overtime.Status.Equals(OvertimeStatuses.APPROVED, StringComparison.OrdinalIgnoreCase))
                    return BadRequest(new { message = "Lembur ini belum disetujui." });
                if (today != overtime.Date.Date)
                    return BadRequest(new { message = "Sesi lembur ini tidak berlaku untuk hari ini." });
            }

            if (!faceVerified || !livenessVerified)
                return BadRequest(new { message = "Verifikasi wajah dan liveness belum berhasil." });

            var distanceMetersValue = ParseDouble(distanceMeters);
            if (setting != null && distanceMetersValue.HasValue &&
                distanceMetersValue.Value > setting.RadiusMeters)
                return BadRequest(new { message = "Lokasi berada di luar radius absensi company." });

            if (effectiveMode == "checkin")
            {
                Attendance? existing;
                if (overtime != null)
                {
                    existing = await _context.Attendance
                        .Where(a => a.OvertimeId == overtime.Id)
                        .OrderByDescending(a => a.CreatedAt)
                        .FirstOrDefaultAsync();
                    if (existing != null && existing.ClockOut == null)
                        return BadRequest(new { message = "Anda sudah check-in lembur ini, silakan check-out." });
                    if (existing != null && existing.ClockOut != null)
                        return BadRequest(new { message = "Absensi lembur ini sudah selesai." });
                }
                else
                {
                    existing = await _context.Attendance
                        .FirstOrDefaultAsync(a => a.UserId == userId && a.Date == today && a.OvertimeId == null);
                    if (existing != null && existing.ClockOut == null)
                        return BadRequest(new { message = "Anda sudah check-in hari ini, silakan check-out." });
                    if (existing != null)
                        return BadRequest(new { message = "Anda sudah mengisi absensi untuk hari ini." });
                }

                var attendance = new Attendance
                {
                    UserId = userId,
                    LocationId = locationId,
                    Date = today,
                    AttendanceType = overtime != null ? "OVERTIME" : "REGULAR",
                    ClockIn = DateTime.Now,
                    ClockOut = null,
                    OvertimeId = overtime?.Id,
                    Status = status,
                    Note = note,
                    Latitude = ParseDecimal(latitude),
                    Longitude = ParseDecimal(longitude),
                    AccuracyMeters = ParseDouble(accuracyMeters),
                    DistanceMeters = distanceMetersValue,
                    FaceSimilarity = ParseDouble(faceSimilarity),
                    CompanyTolerance = setting?.FaceTolerance,
                    FaceVerified = faceVerified,
                    LivenessVerified = livenessVerified,
                    CreatedBy = userId
                };
                _context.Attendance.Add(attendance);
                await _context.SaveChangesAsync();
                await SaveAttachments(attendance.Id, attachments, userId);
                return CreatedAtAction(nameof(GetById), new { id = attendance.Id }, attendance);
            }

            if (effectiveMode == "checkout")
            {
                Attendance? existing = overtime != null
                    ? await _context.Attendance
                        .Where(a => a.OvertimeId == overtime.Id && a.ClockOut == null)
                        .OrderByDescending(a => a.CreatedAt)
                        .FirstOrDefaultAsync()
                    : await _context.Attendance
                        .FirstOrDefaultAsync(a => a.UserId == userId && a.Date == today && a.OvertimeId == null && a.ClockOut == null);

                if (existing == null)
                    return BadRequest(new { message = "Tidak ada sesi absensi yang perlu di-check-out." });
                if (existing.ClockIn == null)
                    return BadRequest(new { message = "Anda belum check-in." });

                existing.ClockOut = DateTime.Now;
                existing.Latitude = ParseDecimal(latitude) ?? existing.Latitude;
                existing.Longitude = ParseDecimal(longitude) ?? existing.Longitude;
                existing.AccuracyMeters = ParseDouble(accuracyMeters) ?? existing.AccuracyMeters;
                existing.DistanceMeters = distanceMetersValue ?? existing.DistanceMeters;
                existing.FaceSimilarity = ParseDouble(faceSimilarity) ?? existing.FaceSimilarity;
                existing.UpdatedAt = DateTime.Now;
                existing.UpdatedBy = userId;
                if (!string.IsNullOrWhiteSpace(note)) existing.Note = note;
                await _context.SaveChangesAsync();
                await SaveAttachments(existing.Id, attachments, userId);
                return Ok(existing);
            }

            return BadRequest(new { message = "Mode absensi tidak dikenali." });
        }

        private async Task SaveAttachments(int attendanceId, List<IFormFile>? attachments, int userId)
        {
            if (attachments == null || attachments.Count == 0) return;
            var uploadRoot = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "attendances", attendanceId.ToString());
            Directory.CreateDirectory(uploadRoot);
            foreach (var file in attachments.Where(f => f.Length > 0))
            {
                var safeName = Path.GetFileName(file.FileName);
                var storedName = $"{Guid.NewGuid():N}_{safeName}";
                var path = Path.Combine(uploadRoot, storedName);
                await using var stream = System.IO.File.Create(path);
                await file.CopyToAsync(stream);
                _context.AttendanceAttachment.Add(new AttendanceAttachment
                {
                    AttendanceId = attendanceId,
                    FilePath = $"/uploads/attendances/{attendanceId}/{storedName}",
                    FileType = file.ContentType,
                    CreatedBy = userId
                });
            }
            await _context.SaveChangesAsync();
        }

        private static decimal? ParseDecimal(string? value) =>
            decimal.TryParse(value, NumberStyles.Any, CultureInfo.InvariantCulture, out var result) ? result : null;

        private static double? ParseDouble(string? value) =>
            double.TryParse(value, NumberStyles.Any, CultureInfo.InvariantCulture, out var result) ? result : null;

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] Attendance attendance)
        {
            attendance.CreatedAt = DateTime.Now;
            var result = await _attendance.Create(attendance);
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] Attendance attendance)
        {
            var result = await _attendance.Update(id, attendance);
            if (!result) return NotFound();
            return Ok(new { Message = "Berhasil diupdate" });
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var existing = await _context.Attendance
                .Include(a => a.User)
                .Include(a => a.Attachments)
                .FirstOrDefaultAsync(a => a.Id == id);
            if (existing == null) return NotFound(new { message = "Data presensi tidak ditemukan." });

            var companyId = GetCompanyId();
            if (companyId.HasValue && existing.User?.CompanyId != companyId.Value)
                return NotFound(new { message = "Data presensi tidak ditemukan." });

            var attachmentPaths = existing.Attachments
                .Select(a => Path.Combine(
                    Directory.GetCurrentDirectory(),
                    "wwwroot",
                    a.FilePath.TrimStart('/').Replace('/', Path.DirectorySeparatorChar)))
                .ToList();

            _context.Attendance.Remove(existing);
            await _context.SaveChangesAsync();

            foreach (var path in attachmentPaths)
            {
                if (System.IO.File.Exists(path))
                    System.IO.File.Delete(path);
            }

            return Ok(new { message = "Data presensi berhasil dihapus." });
        }
    }
}
