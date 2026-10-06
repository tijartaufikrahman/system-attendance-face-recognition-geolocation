using Microsoft.EntityFrameworkCore;
using RestAPIAttendaces.Interfaces;

public class PlatformUserRepository : IPlatformUser
{
    private readonly AppDbContext _context;

    public PlatformUserRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<PlatformUser>> GetAll()
    {
        return await _context.PlatformUser.ToListAsync();
    }

    public async Task<PlatformUser?> GetById(int id)
    {
        return await _context.PlatformUser.FindAsync(id);
    }

    public async Task<PlatformUser?> GetByEmail(string email)
    {
        return await _context.PlatformUser.FirstOrDefaultAsync(u => u.Email == email);
    }

    public async Task<PlatformUser> Create(PlatformUser user)
    {
        user.CreatedAt = DateTime.Now;
        _context.PlatformUser.Add(user);
        await _context.SaveChangesAsync();
        return user;
    }

    public async Task<bool> Update(int id, PlatformUser user)
    {
        var existing = await _context.PlatformUser.FindAsync(id);
        if (existing == null) return false;

        existing.Name = user.Name;
        existing.Email = user.Email;
        existing.IsActive = user.IsActive;
        existing.UpdatedAt = DateTime.Now;

        if (!string.IsNullOrEmpty(user.Password))
            existing.Password = BCrypt.Net.BCrypt.HashPassword(user.Password);

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> Delete(int id)
    {
        var existing = await _context.PlatformUser.FindAsync(id);
        if (existing == null) return false;

        _context.PlatformUser.Remove(existing);
        await _context.SaveChangesAsync();
        return true;
    }
}
