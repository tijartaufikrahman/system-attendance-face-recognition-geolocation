namespace RestAPIAttendaces.Interfaces
{
    public interface IAnnouncement
    {
        Task<List<Announcement>> GetAll();
        Task<Announcement?> GetById(int id);
        Task<List<Announcement>> GetByCompanyId(int companyId);
        Task<Announcement> Create(Announcement announcement);
        Task<bool> Update(int id, Announcement announcement);
        Task<bool> Delete(int id);
    }
}
