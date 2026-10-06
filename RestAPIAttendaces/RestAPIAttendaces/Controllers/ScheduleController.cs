using Microsoft.AspNetCore.Mvc;
using RestAPIAttendaces.Interfaces;

namespace RestAPIAttendaces.Controllers
{
    [ApiController]
    [Route("api/schedules")]
    public class ScheduleController : BaseApiController
    {
        private readonly ISchedule _schedule;
        public ScheduleController(ISchedule schedule) { _schedule = schedule; }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            try
            {
                var companyId = GetCompanyId();
                var all = await _schedule.GetAll();
                if (companyId.HasValue)
                    all = all.Where(s => s.CompanyId == companyId.Value).ToList();
                return Ok(all);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal mengambil data jam kerja", Error = ex.Message });
            }
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            try
            {
                var result = await _schedule.GetById(id);
                if (result == null) return NotFound(new { Message = "Jam kerja tidak ditemukan" });
                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal mengambil data jam kerja", Error = ex.Message });
            }
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] Schedule schedule)
        {
            try
            {
                var companyId = GetCompanyId();
                if (companyId.HasValue)
                    schedule.CompanyId = companyId.Value;

                if (schedule.CompanyId <= 0)
                    return BadRequest(new { Message = "company_id wajib diisi. Pastikan Anda login sebagai admin perusahaan." });

                if (string.IsNullOrWhiteSpace(schedule.Name))
                    return BadRequest(new { Message = "Nama jam kerja wajib diisi" });

                var result = await _schedule.Create(schedule);
                return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal menambahkan jam kerja", Error = ex.Message });
            }
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] Schedule schedule)
        {
            try
            {
                var companyId = GetCompanyId();
                if (companyId.HasValue)
                    schedule.CompanyId = companyId.Value;

                if (schedule.CompanyId <= 0)
                    return BadRequest(new { Message = "company_id wajib diisi. Pastikan Anda login sebagai admin perusahaan." });

                var result = await _schedule.Update(id, schedule);
                if (!result) return NotFound(new { Message = "Jam kerja tidak ditemukan" });
                return Ok(new { Message = "Jam kerja berhasil diupdate" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal mengupdate jam kerja", Error = ex.Message });
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                var (success, error) = await _schedule.Delete(id);
                if (!success)
                    return BadRequest(new { Message = error ?? "Gagal menghapus jam kerja" });
                return Ok(new { Message = "Jam kerja berhasil dihapus" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Message = "Gagal menghapus jam kerja", Error = ex.Message });
            }
        }
    }
}
