using Microsoft.EntityFrameworkCore;
using RestAPIAttendaces.Interfaces;

public class PositionRepository : IPosition
{
    private readonly AppDbContext _context;

    public PositionRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<Position>> GetAll()
    {
        return await _context.Position.ToListAsync();
    }

    public async Task<Position?> GetById(int id)
    {
        return await _context.Position.FindAsync(id);
    }

    public async Task<Position> Create(Position position)
    {
        position.CreatedAt = DateTime.Now;
        _context.Position.Add(position);
        await _context.SaveChangesAsync();
        return position;
    }

    public async Task<bool> Update(int id, Position position)
    {
        var existing = await _context.Position.FindAsync(id);
        if (existing == null) return false;

        existing.Name = position.Name;
        existing.CompanyId = position.CompanyId;
        existing.DefaultScheduleId = position.DefaultScheduleId;
        existing.Description = position.Description;
        existing.UpdatedAt = DateTime.Now;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<(bool success, string? error)> Delete(int id)
    {
        var existing = await _context.Position.FindAsync(id);
        if (existing == null) return (false, "Jabatan tidak ditemukan");

        // Check if any users reference this position
        var hasUsers = await _context.User.AnyAsync(u => u.PositionId == id);
        if (hasUsers)
            return (false, "Tidak bisa menghapus: masih ada karyawan yang menggunakan jabatan ini");

        _context.Position.Remove(existing);
        await _context.SaveChangesAsync();
        return (true, null);
    }
}
