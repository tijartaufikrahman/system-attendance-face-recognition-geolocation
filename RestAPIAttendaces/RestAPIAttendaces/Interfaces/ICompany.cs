namespace RestAPIAttendaces.Interfaces
{
    public interface ICompany
    {
        Task<List<Company>> GetAll();
        Task<Company?> GetById(int id);
        Task<Company> Create(Company company);
        Task<bool> Update(int id, Company company);
        Task<bool> Delete(int id);
        Task<RestAPIAttendaces.DTOs.CompanyWithAdminResponse?> CreateWithAdmin(RestAPIAttendaces.DTOs.CreateCompanyWithAdminRequest request);
    }
}
