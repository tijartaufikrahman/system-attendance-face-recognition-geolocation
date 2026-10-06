using Microsoft.AspNetCore.Mvc;
using RestAPIAttendaces.Interfaces;

namespace RestAPIAttendaces.Controllers
{
    [ApiController]
    [Route("api/roles")]
    public class RoleController : BaseApiController
    {
        private readonly IRole _role;

        public RoleController(IRole role) { _role = role; }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var companyId = GetCompanyId();
            var allRoles = await _role.GetAll();

            // Filter by company_id (SuperAdmin tanpa company_id melihat semua)
            if (companyId.HasValue)
                allRoles = allRoles.Where(r => r.CompanyId == companyId.Value).ToList();

            return Ok(allRoles);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var result = await _role.GetById(id);
            if (result == null) return NotFound(new { Message = "Role tidak ditemukan" });

            var companyId = GetCompanyId();
            if (companyId.HasValue && result.CompanyId != companyId.Value)
                return Forbid();

            return Ok(result);
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] Role role)
        {
            var companyId = GetCompanyId();
            if (companyId.HasValue)
                role.CompanyId = companyId.Value;

            var result = await _role.Create(role);
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] Role role)
        {
            var companyId = GetCompanyId();
            if (companyId.HasValue) role.CompanyId = companyId.Value;

            var result = await _role.Update(id, role);
            if (!result) return NotFound(new { Message = "Role tidak ditemukan" });
            return Ok(new { Message = "Role berhasil diupdate" });
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var (success, error) = await _role.Delete(id);
            if (!success)
                return BadRequest(new { Message = error ?? "Gagal menghapus" });
            return Ok(new { Message = "Role berhasil dihapus" });
        }
    }
}
