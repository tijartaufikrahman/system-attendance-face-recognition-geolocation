using Microsoft.AspNetCore.Mvc;
using RestAPIAttendaces.DTOs;
using RestAPIAttendaces.Interfaces;

namespace RestAPIAttendaces.Controllers
{
    [ApiController]
    [Route("api/companies")]
    public class CompanyController : ControllerBase
    {
        private readonly ICompany _company;

        public CompanyController(ICompany company)
        {
            _company = company;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var result = await _company.GetAll();
            return Ok(result);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var result = await _company.GetById(id);
            if (result == null) return NotFound(new { Message = "Company tidak ditemukan" });
            return Ok(result);
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] Company company)
        {
            var result = await _company.Create(company);
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        /// <summary>
        /// SuperAdmin: Buat perusahaan baru + akun Admin HR dalam 1 request
        /// </summary>
        [HttpPost("create-with-admin")]
        public async Task<IActionResult> CreateWithAdmin([FromBody] CreateCompanyWithAdminRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Name))
                return BadRequest(new { Message = "Nama perusahaan wajib diisi" });

            if (string.IsNullOrWhiteSpace(request.AdminName) || string.IsNullOrWhiteSpace(request.AdminEmail) || string.IsNullOrWhiteSpace(request.AdminPassword))
                return BadRequest(new { Message = "Data Admin HR wajib diisi (nama, email, password)" });

            var result = await _company.CreateWithAdmin(request);
            if (result == null)
                return StatusCode(500, new { Message = "Gagal membuat perusahaan. Cek log API untuk detail error." });

            return Ok(result);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] Company company)
        {
            var result = await _company.Update(id, company);
            if (!result) return NotFound(new { Message = "Company tidak ditemukan" });
            return Ok(new { Message = "Company berhasil diupdate" });
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var result = await _company.Delete(id);
            if (!result) return NotFound(new { Message = "Company tidak ditemukan" });
            return Ok(new { Message = "Company berhasil dihapus" });
        }
    }
}
