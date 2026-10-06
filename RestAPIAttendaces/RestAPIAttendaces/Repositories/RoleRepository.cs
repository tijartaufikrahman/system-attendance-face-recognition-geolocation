using Microsoft.EntityFrameworkCore;
using RestAPIAttendaces.Interfaces;

public class RoleRepository : IRole
{
    private readonly AppDbContext _context;

    public RoleRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<Role>> GetAll()
    {
        return await _context.Role.ToListAsync();
    }

    public async Task<Role?> GetById(int id)
    {
        return await _context.Role.FindAsync(id);
    }

    public async Task<Role> Create(Role role)
    {
        role.CreatedAt = DateTime.Now;
        _context.Role.Add(role);
        await _context.SaveChangesAsync();
        return role;
    }

    public async Task<bool> Update(int id, Role role)
    {
        var existing = await _context.Role.FindAsync(id);
        if (existing == null) return false;

        existing.Name = role.Name;
        existing.Platform = role.Platform;
        existing.CompanyId = role.CompanyId;
        existing.UpdatedAt = DateTime.Now;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<(bool success, string? error)> Delete(int id)
    {
        var existing = await _context.Role.FindAsync(id);
        if (existing == null) return (false, "Role tidak ditemukan");

        // Check if any users reference this role
        var hasUsers = await _context.User.AnyAsync(u => u.RoleId == id);
        if (hasUsers)
            return (false, "Tidak bisa menghapus: masih ada karyawan yang menggunakan role ini");

        _context.Role.Remove(existing);
        await _context.SaveChangesAsync();
        return (true, null);
    }
}
