using Microsoft.AspNetCore.Mvc;
using RestAPIAttendaces.Interfaces;

namespace RestAPIAttendaces.Controllers
{
    [ApiController]
    [Route("api/positions")]
    public class PositionController : BaseApiController
    {
        private readonly IPosition _position;
        public PositionController(IPosition position) { _position = position; }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            try
            {
                var companyId = GetCompanyId();
                var all = await _position.GetAll();
                if (companyId.HasValue)
                    all = all.Where(p => p.CompanyId == companyId.Value).ToList();
                return Ok(all);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal mengambil data jabatan", Error = ex.Message });
            }
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            try
            {
                var result = await _position.GetById(id);
                if (result == null) return NotFound(new { Message = "Jabatan tidak ditemukan" });
                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal mengambil data jabatan", Error = ex.Message });
            }
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] Position position)
        {
            try
            {
                var companyId = GetCompanyId();
                if (companyId.HasValue)
                    position.CompanyId = companyId.Value;

                if (position.CompanyId <= 0)
                    return BadRequest(new { Message = "company_id wajib diisi. Pastikan Anda login sebagai admin perusahaan." });

                if (string.IsNullOrWhiteSpace(position.Name))
                    return BadRequest(new { Message = "Nama jabatan wajib diisi" });

                var result = await _position.Create(position);
                return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal menambahkan jabatan", Error = ex.Message });
            }
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] Position position)
        {
            try
            {
                var companyId = GetCompanyId();
                if (companyId.HasValue)
                    position.CompanyId = companyId.Value;

                if (position.CompanyId <= 0)
                    return BadRequest(new { Message = "company_id wajib diisi. Pastikan Anda login sebagai admin perusahaan." });

                var result = await _position.Update(id, position);
                if (!result) return NotFound(new { Message = "Jabatan tidak ditemukan" });
                return Ok(new { Message = "Jabatan berhasil diupdate" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal mengupdate jabatan", Error = ex.Message });
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                var (success, error) = await _position.Delete(id);
                if (!success)
                    return BadRequest(new { Message = error ?? "Gagal menghapus jabatan" });
                return Ok(new { Message = "Jabatan berhasil dihapus" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal menghapus jabatan", Error = ex.Message });
            }
        }
    }
}
