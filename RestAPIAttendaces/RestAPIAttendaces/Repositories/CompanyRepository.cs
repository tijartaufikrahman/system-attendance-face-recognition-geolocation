using Microsoft.EntityFrameworkCore;
using RestAPIAttendaces.DTOs;
using RestAPIAttendaces.Interfaces;

public class CompanyRepository : ICompany
{
    private readonly AppDbContext _context;

    public CompanyRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<Company>> GetAll()
    {
        return await _context.Company
            .Include(c => c.CompanySetting)
            .ToListAsync();
    }

    public async Task<Company?> GetById(int id)
    {
        return await _context.Company
            .Include(c => c.CompanySetting)
            .FirstOrDefaultAsync(c => c.Id == id);
    }

    public async Task<Company> Create(Company company)
    {
        company.CreatedAt = DateTime.Now;
        _context.Company.Add(company);
        await _context.SaveChangesAsync();

        // Auto-create CompanySettings dengan default values
        var settings = new CompanySetting
        {
            CompanyId = company.Id,
            RadiusMeters = 50,
            FaceTolerance = 0.45,
            CreatedAt = DateTime.Now
        };
        _context.CompanySetting.Add(settings);
        await _context.SaveChangesAsync();

        return company;
    }

    public async Task<bool> Update(int id, Company company)
    {
        var existing = await _context.Company.FindAsync(id);
        if (existing == null) return false;

        existing.Name = company.Name;
        existing.Address = company.Address;
        existing.Phone = company.Phone;
        existing.LogoPath = company.LogoPath;
        existing.IsActive = company.IsActive;
        existing.UpdatedAt = DateTime.Now;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> Delete(int id)
    {
        var existing = await _context.Company.FindAsync(id);
        if (existing == null) return false;

        // Hapus CompanySettings dulu
        var settings = await _context.CompanySetting.FirstOrDefaultAsync(s => s.CompanyId == id);
        if (settings != null) _context.CompanySetting.Remove(settings);

        _context.Company.Remove(existing);
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<CompanyWithAdminResponse?> CreateWithAdmin(CreateCompanyWithAdminRequest request)
    {
        try
        {
            // 1. Create Company
            var company = new Company
            {
                Name = request.Name,
                Address = request.Address,
                Phone = request.Phone,
                IsActive = true,
                CreatedAt = DateTime.Now
            };
            _context.Company.Add(company);
            await _context.SaveChangesAsync();
            Console.WriteLine($"[OK] Company created: id={company.Id}");

            // 2. Create CompanySettings (default)
            var settings = new CompanySetting
            {
                CompanyId = company.Id,
                RadiusMeters = 50,
                FaceTolerance = 0.45,
                CreatedAt = DateTime.Now
            };
            _context.CompanySetting.Add(settings);
            await _context.SaveChangesAsync();
            Console.WriteLine($"[OK] CompanySettings created for company_id={company.Id}");

            // 3. Create Role "Admin HR" & "Employee" untuk perusahaan ini
            var adminRole = new Role
            {
                CompanyId = company.Id,
                Name = "Admin HR",
                Platform = "web",
                CreatedAt = DateTime.Now
            };
            _context.Role.Add(adminRole);

            var employeeRole = new Role
            {
                CompanyId = company.Id,
                Name = "Employee",
                Platform = "mobile",
                CreatedAt = DateTime.Now
            };
            _context.Role.Add(employeeRole);

            await _context.SaveChangesAsync();
            Console.WriteLine($"[OK] Roles created for company_id={company.Id}: Admin HR ({adminRole.Id}), Employee ({employeeRole.Id})");

            // 4. Create Admin HR user
            var adminUser = new User
            {
                CompanyId = company.Id,
                RoleId = adminRole.Id,
                Name = request.AdminName,
                Email = request.AdminEmail,
                Password = BCrypt.Net.BCrypt.HashPassword(request.AdminPassword),
                IsActive = true,
                CreatedAt = DateTime.Now
            };
            _context.User.Add(adminUser);
            await _context.SaveChangesAsync();
            Console.WriteLine($"[OK] Admin user created: id={adminUser.Id}, email={adminUser.Email}");

            return new CompanyWithAdminResponse
            {
                CompanyId = company.Id,
                CompanyName = company.Name,
                AdminId = adminUser.Id,
                AdminName = adminUser.Name,
                AdminEmail = adminUser.Email,
                Message = "Perusahaan dan akun Admin HR berhasil dibuat"
            };
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ERROR] CreateWithAdmin: {ex.Message}");
            Console.WriteLine($"[ERROR] Inner: {ex.InnerException?.Message}");
            return null;
        }
    }
}
