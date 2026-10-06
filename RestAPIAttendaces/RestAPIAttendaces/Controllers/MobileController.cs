using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace RestAPIAttendaces.Controllers
{
    [Route("api/mobile")]
    public class MobileController : BaseApiController
    {
        private readonly AppDbContext _context;

        public MobileController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet("me")]
        public async Task<IActionResult> GetMe()
        {
            var userId = GetUserId();
            var user = await _context.User
                .AsNoTracking()
                .Include(u => u.Company)
                .Include(u => u.Role)
                .Include(u => u.Position)
                    .ThenInclude(p => p!.DefaultSchedule)
                .Include(u => u.Schedule)
                .Include(u => u.Location)
                .FirstOrDefaultAsync(u => u.Id == userId);
            if (user == null) return NotFound();

            var setting = await _context.CompanySetting.AsNoTracking()
                .FirstOrDefaultAsync(s => s.CompanyId == user.CompanyId);
            var registered = await _context.FaceEmbedding.AnyAsync(f => f.UserId == userId);
            return Ok(new
            {
                id = user.Id,
                name = user.Name,
                email = user.Email,
                companyId = user.CompanyId,
                companyName = user.Company?.Name,
                role = user.Role?.Name,
                position = user.Position?.Name,
                positionDescription = user.Position?.Description,
                location = user.Location?.Name ?? user.Location?.Address,
                schedule = user.Schedule == null && user.Position?.DefaultSchedule == null
                    ? null
                    : new
                    {
                        name = user.Schedule?.Name ?? user.Position?.DefaultSchedule?.Name,
                        clockIn = (user.Schedule ?? user.Position?.DefaultSchedule)?.ClockIn,
                        clockOut = (user.Schedule ?? user.Position?.DefaultSchedule)?.ClockOut
                    },
                faceRegistered = registered,
                radiusMeters = setting?.RadiusMeters ?? 50,
                faceTolerance = setting?.FaceTolerance ?? 0.45
            });
        }
    }
}
