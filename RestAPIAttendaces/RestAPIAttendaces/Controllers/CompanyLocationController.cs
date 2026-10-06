using Microsoft.AspNetCore.Mvc;
using RestAPIAttendaces.Interfaces;

namespace RestAPIAttendaces.Controllers
{
    [ApiController]
    [Route("api/locations")]
    public class CompanyLocationController : BaseApiController
    {
        private readonly ICompanyLocation _location;
        public CompanyLocationController(ICompanyLocation location) { _location = location; }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            try     
            {
                var companyId = GetCompanyId();
                var all = await _location.GetAll();
                if (companyId.HasValue)
                    all = all.Where(l => l.CompanyId == companyId.Value).ToList();
                return Ok(all);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal mengambil data lokasi", Error = ex.Message });
            }
        }

        /// <summary>
        /// Ambil lokasi company yang sedang login (1 company = 1 lokasi)
        /// </summary>
        [HttpGet("company")]
        public async Task<IActionResult> GetMyCompanyLocation()
        {
            try
            {
                var companyId = GetCompanyId();
                if (!companyId.HasValue) return BadRequest(new { Message = "company_id tidak ditemukan di token" });

                var locations = await _location.GetByCompanyId(companyId.Value);
                var loc = locations.FirstOrDefault();
                if (loc == null) return NotFound(new { Message = "Belum ada lokasi" });
                return Ok(loc);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal mengambil lokasi", Error = ex.Message });
            }
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            try
            {
                var result = await _location.GetById(id);
                if (result == null) return NotFound(new { Message = "Lokasi tidak ditemukan" });
                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal mengambil data lokasi", Error = ex.Message });
            }
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CompanyLocation location)
        {
            try
            {
                var companyId = GetCompanyId();
                if (companyId.HasValue)
                    location.CompanyId = companyId.Value;

                // Validasi CompanyId harus valid (> 0)
                if (location.CompanyId <= 0)
                    return BadRequest(new { Message = "company_id wajib diisi. Pastikan Anda login sebagai admin perusahaan." });

                if (string.IsNullOrWhiteSpace(location.Name))
                    return BadRequest(new { Message = "Nama lokasi wajib diisi" });

                var result = await _location.Create(location);
                return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal menambahkan lokasi", Error = ex.Message });
            }
        }

        [HttpPut("company")]
        public async Task<IActionResult> UpdateMyLocation([FromBody] CompanyLocation location)
        {
            try
            {
                var companyId = GetCompanyId();
                if (!companyId.HasValue) return BadRequest(new { Message = "company_id tidak ditemukan di token" });

                var existing = (await _location.GetByCompanyId(companyId.Value)).FirstOrDefault();
                if (existing == null)
                {
                    // Belum ada, buat baru
                    location.CompanyId = companyId.Value;
                    var result = await _location.Create(location);
                    return Ok(result);
                }

                // Update yang sudah ada
                location.CompanyId = companyId.Value;
                await _location.Update(existing.Id, location);
                return Ok(new { Message = "Lokasi berhasil diupdate" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal mengupdate lokasi", Error = ex.Message });
            }
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] CompanyLocation location)
        {
            try
            {
                var companyId = GetCompanyId();
                if (companyId.HasValue)
                    location.CompanyId = companyId.Value;

                // Validasi CompanyId harus valid (> 0)
                if (location.CompanyId <= 0)
                    return BadRequest(new { Message = "company_id wajib diisi. Pastikan Anda login sebagai admin perusahaan." });

                var result = await _location.Update(id, location);
                if (!result) return NotFound(new { Message = "Lokasi tidak ditemukan" });
                return Ok(new { Message = "Lokasi berhasil diupdate" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal mengupdate lokasi", Error = ex.Message });
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                var (success, error) = await _location.Delete(id);
                if (!success)
                    return BadRequest(new { Message = error ?? "Gagal menghapus lokasi" });
                return Ok(new { Message = "Lokasi berhasil dihapus" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal menghapus lokasi", Error = ex.Message });
            }
        }
    }
}
