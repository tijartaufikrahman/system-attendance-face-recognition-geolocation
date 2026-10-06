using Microsoft.EntityFrameworkCore;
using RestAPIAttendaces.Interfaces;

public class CompanyLocationRepository : ICompanyLocation
{
    private readonly AppDbContext _context;

    public CompanyLocationRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<CompanyLocation>> GetAll()
    {
        return await _context.CompanyLocation.ToListAsync();
    }

    public async Task<CompanyLocation?> GetById(int id)
    {
        return await _context.CompanyLocation.FindAsync(id);
    }

    public async Task<List<CompanyLocation>> GetByCompanyId(int companyId)
    {
        return await _context.CompanyLocation.Where(cl => cl.CompanyId == companyId).ToListAsync();
    }

    public async Task<CompanyLocation> Create(CompanyLocation location)
    {
        location.CreatedAt = DateTime.Now;
        _context.CompanyLocation.Add(location);
        await _context.SaveChangesAsync();
        return location;
    }

    public async Task<bool> Update(int id, CompanyLocation location)
    {
        var existing = await _context.CompanyLocation.FindAsync(id);
        if (existing == null) return false;

        existing.Name = location.Name;
        existing.CompanyId = location.CompanyId;
        existing.Address = location.Address;
        existing.Latitude = location.Latitude;
        existing.Longitude = location.Longitude;
        existing.RadiusMeters = location.RadiusMeters;
        existing.UpdatedAt = DateTime.Now;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<(bool success, string? error)> Delete(int id)
    {
        var existing = await _context.CompanyLocation.FindAsync(id);
        if (existing == null) return (false, "Lokasi tidak ditemukan");

        var hasUsers = await _context.User.AnyAsync(u => u.LocationId == id);
        if (hasUsers)
            return (false, "Tidak bisa menghapus: masih ada karyawan yang terdaftar di lokasi ini");

        var hasAttendances = await _context.Attendance.AnyAsync(a => a.LocationId == id);
        if (hasAttendances)
            return (false, "Tidak bisa menghapus: lokasi memiliki riwayat presensi");

        _context.CompanyLocation.Remove(existing);
        await _context.SaveChangesAsync();
        return (true, null);
    }
}
