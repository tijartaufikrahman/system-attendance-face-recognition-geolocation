namespace RestAPIAttendaces.Interfaces
{
    public interface ISchedule
    {
        Task<List<Schedule>> GetAll();
        Task<Schedule?> GetById(int id);
        Task<Schedule> Create(Schedule schedule);
        Task<bool> Update(int id, Schedule schedule);
        Task<(bool success, string? error)> Delete(int id);
    }
}
