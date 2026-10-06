using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestAPIAttendaces.Interfaces;

namespace RestAPIAttendaces.Controllers
{
    [ApiController]
    [Route("api/overtimes")]
    public class OvertimeController : BaseApiController
    {
        private readonly IOvertime _overtime;
        private readonly AppDbContext _context;
        public OvertimeController(IOvertime overtime, AppDbContext context)
        {
            _overtime = overtime;
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            try
            {
                var companyId = GetCompanyId();
                var all = await _overtime.GetAll(companyId);
                return Ok(all);
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Gagal mengambil data lembur" });
            }
        }

        // Get overtimes for a specific user (for mobile app)
        [HttpGet("user/{userId}")]
        public async Task<IActionResult> GetByUserId(int userId)
        {
            try
            {
                if (userId != GetUserId() && !CanReviewRequests())
                    return Forbid();
                var companyId = GetCompanyId();
                if (companyId.HasValue && !await _context.User.AnyAsync(u => u.Id == userId && u.CompanyId == companyId.Value))
                    return NotFound(new { Message = "Data karyawan tidak ditemukan" });
                var result = await _overtime.GetByUserId(userId, companyId);
                return Ok(result);
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Gagal mengambil data lembur" });
            }
        }

        [HttpGet("me")]
        public async Task<IActionResult> GetMine()
        {
            var userId = GetUserId();
            if (userId == 0) return Unauthorized();
            var values = await _overtime.GetByUserId(userId, GetCompanyId());
            var unique = values
                .OrderByDescending(o => o.Date)
                .ThenByDescending(o => o.CreatedAt)
                .ToList();

            var ids = unique.Select(o => o.Id).ToList();
            var attendances = await _context.Attendance
                .Where(a => a.OvertimeId != null && ids.Contains(a.OvertimeId.Value))
                .ToListAsync();

            var result = unique.Select(o =>
            {
                var att = attendances
                    .Where(a => a.OvertimeId == o.Id)
                    .OrderByDescending(a => a.CreatedAt)
                    .FirstOrDefault();
                return new
                {
                    o.Id,
                    o.UserId,
                    o.Date,
                    requestType = o.RequestType,
                    requestedBy = o.RequestedBy,
                    scheduleId = o.ScheduleId,
                    scheduleName = o.Schedule?.Name,
                    startTime = o.Schedule?.ClockIn,
                    endTime = o.Schedule?.ClockOut,
                    o.Status,
                    o.Note,
                    o.RejectionReason,
                    o.RespondedBy,
                    o.RespondedAt,
                    o.CreatedAt,
                    o.UpdatedAt,
                    attendanceId = att?.Id,
                    checkedIn = att?.ClockIn != null,
                    checkedOut = att?.ClockOut != null
                };
            });
            return Ok(result);
        }

        [HttpPost("request")]
        public async Task<IActionResult> CreateEmployeeRequest([FromBody] OvertimeRequest request)
        {
            try
            {
                var userId = GetUserId();
                var companyId = GetCompanyId();
                if (userId == 0) return Unauthorized();
                if (request.ScheduleId <= 0 || request.Date == default)
                    return BadRequest(new { Message = "Tanggal dan jadwal lembur wajib diisi." });
                if (!await IsValidAssignment(userId, request.ScheduleId, companyId))
                    return BadRequest(new { Message = "Jadwal lembur tidak sesuai dengan perusahaan Anda." });
                if (await _context.Overtime.AnyAsync(o => o.UserId == userId && o.Date == request.Date.Date
                    && o.Status != OvertimeStatuses.REJECTED && o.Status != OvertimeStatuses.CANCELLED))
                    return BadRequest(new { Message = "Anda sudah memiliki pengajuan atau penugasan lembur pada tanggal tersebut." });

                var overtime = new Overtime
                {
                    UserId = userId,
                    Date = request.Date.Date,
                    RequestType = OvertimeStatuses.EMPLOYEE_REQUEST,
                    RequestedBy = userId,
                    ScheduleId = request.ScheduleId,
                    Status = OvertimeStatuses.PENDING_SUPERVISOR,
                    Note = request.Note,
                    CreatedAt = DateTime.Now
                };
                var result = await _overtime.Create(overtime);
                return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Gagal mengajukan lembur" });
            }
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            try
            {
                var result = await _overtime.GetById(id);
                if (result == null) return NotFound(new { Message = "Data lembur tidak ditemukan" });
                var companyId = GetCompanyId();
                if (companyId.HasValue && result.User?.CompanyId != companyId.Value)
                    return NotFound(new { Message = "Data lembur tidak ditemukan" });
                return Ok(result);
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Gagal mengambil data lembur" });
            }
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] Overtime overtime)
        {
            try
            {
                if (!CanReviewRequests()) return Forbid();
                var companyId = GetCompanyId();
                if (!await IsValidAssignment(overtime.UserId, overtime.ScheduleId, companyId))
                    return BadRequest(new { Message = "Karyawan dan jadwal lembur harus berada dalam perusahaan yang sama." });
                overtime.CreatedAt = DateTime.Now;
                overtime.RequestType = OvertimeStatuses.ADMIN_ASSIGNMENT;
                overtime.RequestedBy = GetUserId();
                overtime.Status = OvertimeStatuses.PENDING_EMPLOYEE;
                var result = await _overtime.Create(overtime);
                return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Gagal menugaskan lembur" });
            }
        }

        // Batch create: assign lembur ke banyak karyawan, 1 record per user per hari
        [HttpPost("batch")]
        public async Task<IActionResult> CreateBatch([FromBody] OvertimeBatchRequest request)
        {
            try
            {
                if (!CanReviewRequests()) return Forbid();
                var userIds = request.UserIds?.Where(id => id > 0).Distinct().ToList() ?? new List<int>();
                if (userIds.Count == 0)
                    return BadRequest(new { Message = "Pilih minimal 1 karyawan" });
                var startDate = request.Date.Date;
                var companyId = GetCompanyId();
                if (request.ScheduleId <= 0)
                    return BadRequest(new { Message = "Pilih jadwal lembur" });
                var schedule = await _context.Schedule.FirstOrDefaultAsync(s =>
                    s.Id == request.ScheduleId &&
                    (!companyId.HasValue || s.CompanyId == companyId.Value));
                if (schedule == null)
                    return BadRequest(new { Message = "Jadwal lembur tidak ditemukan." });
                var validUsers = await _context.User
                    .Where(u => userIds.Contains(u.Id) && (!companyId.HasValue || u.CompanyId == companyId.Value))
                    .Select(u => u.Id)
                    .ToListAsync();
                if (validUsers.Count != userIds.Count)
                    return BadRequest(new { Message = "Terdapat karyawan yang tidak berada dalam perusahaan." });

                var created = new List<Overtime>();
                var existingKeys = await _context.Overtime
                    .Where(o => userIds.Contains(o.UserId) && o.Date == startDate
                        && o.Status != OvertimeStatuses.REJECTED && o.Status != OvertimeStatuses.CANCELLED)
                    .Select(o => o.UserId)
                    .ToListAsync();
                var existingSet = existingKeys.ToHashSet();
                foreach (var userId in validUsers)
                {
                    if (!existingSet.Add(userId))
                        continue;
                    var overtime = new Overtime
                    {
                        UserId = userId,
                        Date = startDate,
                        RequestType = OvertimeStatuses.ADMIN_ASSIGNMENT,
                        RequestedBy = GetUserId(),
                        ScheduleId = request.ScheduleId,
                        Status = OvertimeStatuses.PENDING_EMPLOYEE,
                        Note = request.Note,
                        CreatedAt = DateTime.Now
                    };
                    var result = await _overtime.Create(overtime);
                    created.Add(result);
                }

                return Ok(new
                {
                    Message = created.Count == 0
                        ? "Semua tugas lembur pada tanggal tersebut sudah tersedia."
                        : $"{created.Count} lembur berhasil ditugaskan",
                    Count = created.Count,
                    Skipped = userIds.Count - created.Count
                });
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Gagal menugaskan lembur" });
            }
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] Overtime overtime)
        {
            try
            {
                if (!CanReviewRequests()) return Forbid();
                var existing = await _overtime.GetById(id);
                if (existing == null)
                    return NotFound(new { Message = "Data lembur tidak ditemukan" });
                var companyId = GetCompanyId();
                if (companyId.HasValue && existing.User?.CompanyId != companyId.Value)
                    return NotFound(new { Message = "Data lembur tidak ditemukan" });
                if (!await IsValidAssignment(overtime.UserId, overtime.ScheduleId, companyId))
                    return BadRequest(new { Message = "Karyawan dan jadwal lembur harus berada dalam perusahaan yang sama." });
                var result = await _overtime.Update(id, overtime);
                if (!result) return NotFound(new { Message = "Data lembur tidak ditemukan" });
                return Ok(new { Message = "Berhasil diupdate" });
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Gagal mengupdate lembur" });
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                var existing = await _overtime.GetById(id);
                if (existing == null)
                    return NotFound(new { Message = "Data lembur tidak ditemukan" });
                var currentUserId = GetUserId();
                var isEmployeeOwner = existing.UserId == currentUserId
                    && string.Equals(existing.RequestType, OvertimeStatuses.EMPLOYEE_REQUEST, StringComparison.OrdinalIgnoreCase)
                    && string.Equals(existing.Status, OvertimeStatuses.PENDING_SUPERVISOR, StringComparison.OrdinalIgnoreCase);
                if (!isEmployeeOwner && !CanReviewRequests()) return Forbid();
                var companyId = GetCompanyId();
                if (companyId.HasValue)
                {
                    var belongsToCompany = await _context.User
                        .AnyAsync(u => u.Id == existing.UserId && u.CompanyId == companyId.Value);
                    if (!belongsToCompany) return NotFound(new { Message = "Data lembur tidak ditemukan" });
                }

                if (!string.Equals(existing.Status, OvertimeStatuses.PENDING_EMPLOYEE, StringComparison.OrdinalIgnoreCase)
                    && !string.Equals(existing.Status, OvertimeStatuses.PENDING_SUPERVISOR, StringComparison.OrdinalIgnoreCase))
                    return BadRequest(new { Message = "Tidak bisa menghapus lembur yang sudah disetujui" });

                var result = await _overtime.Delete(id);
                if (!result) return BadRequest(new { Message = "Tidak bisa menghapus lembur" });
                return Ok(new { Message = "Berhasil dihapus" });
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Gagal menghapus lembur" });
            }
        }

        // Approve oleh karyawan (mobile)
        [HttpPut("{id}/approve")]
        public async Task<IActionResult> Approve(int id)
        {
            try
            {
                var existing = await _overtime.GetById(id);
                if (existing == null)
                    return NotFound(new { Message = "Data lembur tidak ditemukan" });
                if (existing.UserId != GetUserId()
                    || !string.Equals(existing.RequestType, OvertimeStatuses.ADMIN_ASSIGNMENT, StringComparison.OrdinalIgnoreCase)
                    || !string.Equals(existing.Status, OvertimeStatuses.PENDING_EMPLOYEE, StringComparison.OrdinalIgnoreCase))
                    return Forbid();

                existing.Status = OvertimeStatuses.APPROVED;
                existing.RespondedBy = GetUserId();
                existing.RespondedAt = DateTime.Now;
                existing.UpdatedAt = DateTime.Now;
                await _overtime.Update(id, existing);
                return Ok(new { Message = "Lembur berhasil disetujui" });
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Gagal menyetujui lembur" });
            }
        }

        // Reject oleh karyawan (mobile)
        [HttpPut("{id}/reject")]
        public async Task<IActionResult> Reject(int id, [FromBody] OvertimeDecisionRequest? request)
        {
            try
            {
                var existing = await _overtime.GetById(id);
                if (existing == null)
                    return NotFound(new { Message = "Data lembur tidak ditemukan" });
                if (existing.UserId != GetUserId()
                    || !string.Equals(existing.RequestType, OvertimeStatuses.ADMIN_ASSIGNMENT, StringComparison.OrdinalIgnoreCase))
                    return Forbid();
                if (!string.Equals(existing.Status, OvertimeStatuses.PENDING_EMPLOYEE, StringComparison.OrdinalIgnoreCase))
                    return BadRequest(new { Message = "Lembur ini sudah diproses." });

                existing.Status = OvertimeStatuses.REJECTED;
                existing.RejectionReason = request?.RejectionReason;
                existing.RespondedBy = GetUserId();
                existing.RespondedAt = DateTime.Now;
                existing.UpdatedAt = DateTime.Now;
                await _overtime.Update(id, existing);
                return Ok(new { Message = "Lembur ditolak" });
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Gagal menolak lembur" });
            }
        }

        private async Task<bool> IsValidAssignment(int userId, int scheduleId, int? companyId)
        {
            return await _context.User.AnyAsync(u => u.Id == userId &&
                    (!companyId.HasValue || u.CompanyId == companyId.Value))
                && await _context.Schedule.AnyAsync(s => s.Id == scheduleId &&
                    (!companyId.HasValue || s.CompanyId == companyId.Value));
        }

        [HttpPut("{id}/review")]
        public async Task<IActionResult> Review(int id, [FromBody] OvertimeReviewRequest request)
        {
            try
            {
                if (!CanReviewRequests()) return Forbid();
                var existing = await _overtime.GetById(id);
                if (existing == null) return NotFound(new { Message = "Data lembur tidak ditemukan" });
                var companyId = GetCompanyId();
                if (companyId.HasValue && existing.User?.CompanyId != companyId.Value)
                    return NotFound(new { Message = "Data lembur tidak ditemukan" });
                if (!string.Equals(existing.RequestType, OvertimeStatuses.EMPLOYEE_REQUEST, StringComparison.OrdinalIgnoreCase)
                    || !string.Equals(existing.Status, OvertimeStatuses.PENDING_SUPERVISOR, StringComparison.OrdinalIgnoreCase))
                    return BadRequest(new { Message = "Pengajuan ini sudah diproses atau bukan pengajuan karyawan." });

                existing.Status = request.Approved ? OvertimeStatuses.APPROVED : OvertimeStatuses.REJECTED;
                existing.RejectionReason = request.Approved ? null : request.RejectionReason;
                existing.RespondedBy = GetUserId();
                existing.RespondedAt = DateTime.Now;
                existing.UpdatedAt = DateTime.Now;
                await _overtime.Update(id, existing);
                if (request.Approved)
                {
                    _context.Announcement.Add(new Announcement
                    {
                        CompanyId = existing.User!.CompanyId,
                        Title = "Pengajuan lembur disetujui",
                        Content = $"Pengajuan lembur tanggal {existing.Date:dd/MM/yyyy} pada jadwal {existing.Schedule?.Name ?? "yang dipilih"} telah disetujui. Silakan cek detail lembur dan lakukan absensi sesuai jadwal.",
                        TargetType = "users",
                        TargetIds = existing.UserId.ToString(),
                        CreatedAt = DateTime.Now,
                        CreatedBy = GetUserId()
                    });
                    await _context.SaveChangesAsync();
                }
                return Ok(new { Message = request.Approved ? "Pengajuan lembur disetujui" : "Pengajuan lembur ditolak" });
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Gagal memproses pengajuan lembur" });
            }
        }

        private bool CanReviewRequests()
        {
            var role = GetRoleName();
            return role.Equals("Superadmin", StringComparison.OrdinalIgnoreCase)
                || role.Equals("Admin HR", StringComparison.OrdinalIgnoreCase)
                || role.Equals("Admin", StringComparison.OrdinalIgnoreCase)
                || role.Equals("Supervisor", StringComparison.OrdinalIgnoreCase)
                || role.Equals("Manager", StringComparison.OrdinalIgnoreCase);
        }
    }

    // Request DTO for batch create
    public class OvertimeBatchRequest
    {
        public List<int> UserIds { get; set; } = new();
        public DateTime Date { get; set; }
        public int ScheduleId { get; set; }
        public string? Note { get; set; }
    }

    public class OvertimeDecisionRequest
    {
        public string? RejectionReason { get; set; }
    }

    public class OvertimeRequest
    {
        public DateTime Date { get; set; }
        public int ScheduleId { get; set; }
        public string? Note { get; set; }
    }

    public class OvertimeReviewRequest
    {
        public bool Approved { get; set; }
        public string? RejectionReason { get; set; }
    }
}
