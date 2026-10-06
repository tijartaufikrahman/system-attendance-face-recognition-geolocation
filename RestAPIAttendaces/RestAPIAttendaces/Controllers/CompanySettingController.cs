using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace RestAPIAttendaces.Controllers
{
    [ApiController]
    [Route("api/company-settings")]
    public class CompanySettingController : BaseApiController
    {
        private readonly AppDbContext _context;

        public CompanySettingController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet("company")]
        public async Task<IActionResult> GetCompanySetting()
        {
            var companyId = GetCompanyId();
            if (!companyId.HasValue) return Forbid();

            var setting = await _context.CompanySetting
                .AsNoTracking()
                .FirstOrDefaultAsync(s => s.CompanyId == companyId.Value);

            if (setting == null)
            {
                setting = new CompanySetting
                {
                    CompanyId = companyId.Value,
                    RadiusMeters = 50,
                    FaceTolerance = 0.45
                };
                _context.CompanySetting.Add(setting);
                await _context.SaveChangesAsync();
            }

            return Ok(setting);
        }

        [HttpPut("company")]
        public async Task<IActionResult> UpdateCompanySetting([FromBody] CompanySettingRequest request)
        {
            var companyId = GetCompanyId();
            if (!companyId.HasValue) return Forbid();
            if (request.FaceTolerance < 0.1 || request.FaceTolerance > 0.99)
                return BadRequest(new { message = "Akurasi wajah harus antara 0.10 sampai 0.99." });
            if (request.RadiusMeters < 1 || request.RadiusMeters > 10000)
                return BadRequest(new { message = "Radius lokasi harus antara 1 sampai 10000 meter." });

            var setting = await _context.CompanySetting
                .FirstOrDefaultAsync(s => s.CompanyId == companyId.Value);
            if (setting == null)
            {
                setting = new CompanySetting { CompanyId = companyId.Value };
                _context.CompanySetting.Add(setting);
            }

            setting.FaceTolerance = request.FaceTolerance;
            setting.RadiusMeters = request.RadiusMeters;
            setting.UpdatedAt = DateTime.Now;
            setting.UpdatedBy = GetUserId();
            await _context.SaveChangesAsync();
            return Ok(setting);
        }
    }

    public sealed class CompanySettingRequest
    {
        public int RadiusMeters { get; set; } = 50;
        public double FaceTolerance { get; set; } = 0.45;
    }
}
