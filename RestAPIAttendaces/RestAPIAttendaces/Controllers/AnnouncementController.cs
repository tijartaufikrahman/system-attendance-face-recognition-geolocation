using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestAPIAttendaces.Interfaces;

namespace RestAPIAttendaces.Controllers
{
    [ApiController]
    [Route("api/announcements")]
    public class AnnouncementController : BaseApiController
    {
        private readonly IAnnouncement _announcement;
        private readonly AppDbContext _context;

        public AnnouncementController(IAnnouncement announcement, AppDbContext context)
        {
            _announcement = announcement;
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var companyId = GetCompanyId();
            var all = companyId.HasValue
                ? await _announcement.GetByCompanyId(companyId.Value)
                : await _announcement.GetAll();
            return Ok(all);
        }

        [HttpGet("me")]
        public async Task<IActionResult> GetMine()
        {
            var userId = GetUserId();
            if (userId == 0) return Unauthorized();
            var user = await _context.User.AsNoTracking()
                .FirstOrDefaultAsync(u => u.Id == userId && u.IsActive);
            if (user == null) return NotFound();

            var announcements = await _context.Announcement.AsNoTracking()
                .Where(a => a.CompanyId == user.CompanyId)
                .OrderByDescending(a => a.CreatedAt)
                .ToListAsync();
            var readIds = await _context.AnnouncementRead.AsNoTracking()
                .Where(r => r.UserId == user.Id)
                .Select(r => r.AnnouncementId)
                .ToListAsync();

            var visible = announcements.Where(a =>
            {
                var targetType = (a.TargetType ?? "all").Trim().ToLowerInvariant();
                if (targetType is "all" or "everyone" or "company") return true;
                var ids = (a.TargetIds ?? string.Empty)
                    .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                    .Select(id => int.TryParse(id, out var value) ? value : 0);
                return targetType is "users" or "user" or "employees" or "employee"
                    ? ids.Contains(user.Id)
                    : targetType is "position" or "positions" && user.PositionId.HasValue &&
                      ids.Contains(user.PositionId.Value);
            }).ToList();
            return Ok(visible.Select(a => new
            {
                a.Id,
                a.CompanyId,
                a.Title,
                a.Content,
                a.TargetType,
                a.TargetIds,
                a.CreatedAt,
                a.CreatedBy,
                a.UpdatedAt,
                a.UpdatedBy,
                isRead = readIds.Contains(a.Id)
            }));
        }

        [HttpGet("unread-count")]
        public async Task<IActionResult> GetUnreadCount()
        {
            var userId = GetUserId();
            if (userId == 0) return Unauthorized();
            var user = await _context.User.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId && u.IsActive);
            if (user == null) return NotFound();
            var readIds = _context.AnnouncementRead.Where(r => r.UserId == userId).Select(r => r.AnnouncementId);
            var announcements = await _context.Announcement.AsNoTracking()
                .Where(a => a.CompanyId == user.CompanyId)
                .ToListAsync();
            var visible = announcements.Where(a => IsVisibleToUser(a, user));
            return Ok(new { count = visible.Count(a => !readIds.Contains(a.Id)) });
        }

        [HttpPost("{id}/read")]
        public async Task<IActionResult> MarkRead(int id)
        {
            var userId = GetUserId();
            if (userId == 0) return Unauthorized();
            var user = await _context.User.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId && u.IsActive);
            var announcement = await _context.Announcement.AsNoTracking().FirstOrDefaultAsync(a => a.Id == id);
            if (user == null || announcement == null || announcement.CompanyId != user.CompanyId || !IsVisibleToUser(announcement, user))
                return NotFound();
            var existing = await _context.AnnouncementRead.FindAsync(id, userId);
            if (existing == null)
                _context.AnnouncementRead.Add(new AnnouncementRead { AnnouncementId = id, UserId = userId });
            else
                existing.ReadAt = DateTime.Now;
            await _context.SaveChangesAsync();
            return Ok(new { message = "Pengumuman ditandai sudah dibaca." });
        }

        private static bool IsVisibleToUser(Announcement announcement, User user)
        {
            var targetType = (announcement.TargetType ?? "all").Trim().ToLowerInvariant();
            if (targetType is "all" or "everyone" or "company") return true;
            var ids = (announcement.TargetIds ?? string.Empty)
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(value => int.TryParse(value, out var id) ? id : 0);
            return targetType is "users" or "user" or "employees" or "employee"
                ? ids.Contains(user.Id)
                : targetType is "position" or "positions" && user.PositionId.HasValue &&
                  ids.Contains(user.PositionId.Value);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var result = await _announcement.GetById(id);
            if (result == null) return NotFound();
            var companyId = GetCompanyId();
            if (companyId.HasValue && result.CompanyId != companyId.Value)
                return NotFound();
            return Ok(result);
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] Announcement announcement)
        {
            var companyId = GetCompanyId();
            if (!companyId.HasValue)
                return BadRequest(new { Message = "Pengumuman harus dibuat oleh admin perusahaan." });

            announcement.CompanyId = companyId.Value;
            var validation = await ValidateTarget(announcement, companyId.Value);
            if (validation != null) return validation;

            var result = await _announcement.Create(announcement);
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] Announcement announcement)
        {
            var companyId = GetCompanyId();
            if (!companyId.HasValue)
                return BadRequest(new { Message = "Pengumuman harus diubah oleh admin perusahaan." });

            var existing = await _announcement.GetById(id);
            if (existing == null || existing.CompanyId != companyId.Value)
                return NotFound(new { Message = "Pengumuman tidak ditemukan" });

            announcement.CompanyId = companyId.Value;
            var validation = await ValidateTarget(announcement, companyId.Value);
            if (validation != null) return validation;

            var result = await _announcement.Update(id, announcement);
            if (!result) return NotFound();
            return Ok(new { Message = "Berhasil diupdate" });
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var companyId = GetCompanyId();
            var existing = await _announcement.GetById(id);
            if (existing == null || (companyId.HasValue && existing.CompanyId != companyId.Value))
                return NotFound(new { Message = "Pengumuman tidak ditemukan" });

            var result = await _announcement.Delete(id);
            if (!result) return NotFound();
            return Ok(new { Message = "Berhasil dihapus" });
        }

        private async Task<IActionResult?> ValidateTarget(Announcement announcement, int companyId)
        {
            if (string.IsNullOrWhiteSpace(announcement.Title))
                return BadRequest(new { Message = "Judul pengumuman wajib diisi." });

            if (string.IsNullOrWhiteSpace(announcement.Content))
                return BadRequest(new { Message = "Isi pengumuman wajib diisi." });

            announcement.Title = announcement.Title.Trim();
            announcement.Content = announcement.Content.Trim();

            var targetType = (announcement.TargetType ?? "all").Trim().ToLowerInvariant();
            announcement.TargetType = targetType;

            if (targetType == "all")
            {
                announcement.TargetIds = null;
                return null;
            }

            if (targetType != "users" && targetType != "position")
                return BadRequest(new { Message = "Target pengumuman tidak valid." });

            var ids = (announcement.TargetIds ?? string.Empty)
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(value => int.TryParse(value, out var id) ? id : 0)
                .Where(id => id > 0)
                .Distinct()
                .ToList();

            if (ids.Count == 0)
                return BadRequest(new { Message = "Pilih minimal satu target pengumuman." });

            if (targetType == "users")
            {
                var count = await _context.User.CountAsync(u => u.CompanyId == companyId && ids.Contains(u.Id));
                if (count != ids.Count)
                    return BadRequest(new { Message = "Target karyawan tidak valid atau bukan bagian dari perusahaan Anda." });
            }
            else
            {
                var count = await _context.Position.CountAsync(p => p.CompanyId == companyId && ids.Contains(p.Id));
                if (count != ids.Count)
                    return BadRequest(new { Message = "Target jabatan tidak valid atau bukan bagian dari perusahaan Anda." });
            }

            announcement.TargetIds = string.Join(',', ids);
            return null;
        }
    }
}
