using Microsoft.EntityFrameworkCore;
using RestAPIAttendaces.Interfaces;

public class UserRepository : IUser
{
    private readonly AppDbContext _context;

    public UserRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<User>> GetAll()
    {
        return await _context.User.Include(u => u.Role).Include(u => u.Position).Include(u => u.Schedule).ToListAsync();
    }

    public async Task<User?> GetById(int id)
    {
        return await _context.User.FindAsync(id);
    }

    public async Task<User> Create(User user)
    {
        user.CreatedAt = DateTime.Now;
        _context.User.Add(user);
        await _context.SaveChangesAsync();
        return user;
    }

    public async Task<bool> Update(int id, User user)
    {
        var existing = await _context.User.FindAsync(id);
        if (existing == null) return false;

        existing.Name = user.Name;
        existing.Email = user.Email;
        existing.RoleId = user.RoleId;
        if (user.CompanyId > 0) existing.CompanyId = user.CompanyId;
        existing.LocationId = user.LocationId;
        existing.PositionId = user.PositionId;
        existing.ScheduleId = user.ScheduleId;
        existing.IsActive = user.IsActive;
        if (!string.IsNullOrEmpty(user.Password))
        {
            existing.Password = user.Password;
        }
        existing.UpdatedAt = DateTime.Now;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<(bool success, string? error)> Delete(int id)
    {
        var existing = await _context.User.FindAsync(id);
        if (existing == null) return (false, "Karyawan tidak ditemukan");

        // Check if user has attendances
        var hasAttendances = await _context.Attendance.AnyAsync(a => a.UserId == id);
        if (hasAttendances)
            return (false, "Tidak bisa menghapus: karyawan memiliki data presensi");

        // Check if user has overtimes
        var hasOvertimes = await _context.Overtime.AnyAsync(o => o.UserId == id);
        if (hasOvertimes)
            return (false, "Tidak bisa menghapus: karyawan memiliki data lembur");

        _context.User.Remove(existing);
        await _context.SaveChangesAsync();
        return (true, null);
    }
}
