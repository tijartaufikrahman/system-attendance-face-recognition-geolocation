using Microsoft.EntityFrameworkCore;
using RestAPIAttendaces.Interfaces;

public class AnnouncementRepository : IAnnouncement
{
    private readonly AppDbContext _context;

    public AnnouncementRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<Announcement>> GetAll()
    {
        return await _context.Announcement.OrderByDescending(a => a.CreatedAt).ToListAsync();
    }

    public async Task<Announcement?> GetById(int id)
    {
        return await _context.Announcement.FindAsync(id);
    }

    public async Task<List<Announcement>> GetByCompanyId(int companyId)
    {
        return await _context.Announcement
            .Where(a => a.CompanyId == companyId)
            .OrderByDescending(a => a.CreatedAt)
            .ToListAsync();
    }

    public async Task<Announcement> Create(Announcement announcement)
    {
        announcement.Title = announcement.Title?.Trim() ?? string.Empty;
        announcement.Content = announcement.Content?.Trim() ?? string.Empty;
        announcement.TargetType = string.IsNullOrWhiteSpace(announcement.TargetType)
            ? "all"
            : announcement.TargetType.Trim().ToLowerInvariant();
        announcement.CreatedAt = DateTime.Now;
        _context.Announcement.Add(announcement);
        await _context.SaveChangesAsync();
        return announcement;
    }

    public async Task<bool> Update(int id, Announcement announcement)
    {
        var existing = await _context.Announcement.FindAsync(id);
        if (existing == null) return false;

        existing.Title = announcement.Title?.Trim() ?? string.Empty;
        existing.Content = announcement.Content?.Trim() ?? string.Empty;
        existing.TargetType = string.IsNullOrWhiteSpace(announcement.TargetType)
            ? "all"
            : announcement.TargetType.Trim().ToLowerInvariant();
        existing.TargetIds = announcement.TargetIds;
        existing.CompanyId = announcement.CompanyId;
        existing.UpdatedAt = DateTime.Now;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> Delete(int id)
    {
        var existing = await _context.Announcement.FindAsync(id);
        if (existing == null) return false;

        _context.Announcement.Remove(existing);
        await _context.SaveChangesAsync();
        return true;
    }
}
