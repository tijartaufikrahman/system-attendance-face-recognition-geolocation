using System.Globalization;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

// Force InvariantCulture for all JSON serialization (decimal uses dot, not comma)
internal static class JsonSettings
{
    public static readonly JsonSerializerSettings Instance = new()
    {
        Culture = CultureInfo.InvariantCulture
    };
}

namespace WebsiteSystemAttendances.Services
{
    public class ApiClient
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IHttpContextAccessor _httpContextAccessor;

        public ApiClient(IHttpClientFactory httpClientFactory, IHttpContextAccessor httpContextAccessor)
        {
            _httpClientFactory = httpClientFactory;
            _httpContextAccessor = httpContextAccessor;
        }

        private HttpClient CreateClient()
        {
            var client = _httpClientFactory.CreateClient("ApiClient");
            client.Timeout = TimeSpan.FromSeconds(15);
            var token = _httpContextAccessor.HttpContext?.Session.GetString("JwtToken");
            if (!string.IsNullOrEmpty(token))
            {
                client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
            }
            return client;
        }

        // Auth endpoints
        public async Task<JsonResponse?> LoginAsync(string email, string password)
        {
            var client = CreateClient();
            var content = new StringContent(
                JsonConvert.SerializeObject(new { Email = email, Password = password }),
                Encoding.UTF8,
                "application/json");

            var response = await client.PostAsync("api/auth/login", content);
            var json = await response.Content.ReadAsStringAsync();

            if (response.IsSuccessStatusCode)
            {
                return new JsonResponse { Success = true, Data = json };
            }
            return new JsonResponse { Success = false, Message = "Email atau password salah" };
        }

        public async Task<JsonResponse?> PlatformLoginAsync(string email, string password)
        {
            var client = CreateClient();
            var content = new StringContent(
                JsonConvert.SerializeObject(new { Email = email, Password = password }),
                Encoding.UTF8,
                "application/json");

            var response = await client.PostAsync("api/auth/platform/login", content);
            var json = await response.Content.ReadAsStringAsync();

            if (response.IsSuccessStatusCode)
            {
                return new JsonResponse { Success = true, Data = json };
            }
            return new JsonResponse { Success = false, Message = "Email atau password salah" };
        }

        public async Task<JsonResponse?> ForgotPasswordAsync(string email)
        {
            var client = CreateClient();
            var content = new StringContent(
                JsonConvert.SerializeObject(new { Email = email }),
                Encoding.UTF8,
                "application/json");

            var response = await client.PostAsync("api/auth/forgot-password", content);
            var json = await response.Content.ReadAsStringAsync();
            return new JsonResponse { Success = response.IsSuccessStatusCode, Message = json, Data = json };
        }

        public async Task<JsonResponse?> VerifyOtpAsync(string email, string otp)
        {
            var client = CreateClient();
            var content = new FormUrlEncodedContent(new[]
            {
                new KeyValuePair<string, string>("email", email),
                new KeyValuePair<string, string>("otp", otp)
            });

            var response = await client.PostAsync("api/auth/verify-otp", content);
            var json = await response.Content.ReadAsStringAsync();
            return new JsonResponse { Success = response.IsSuccessStatusCode, Message = json, Data = json };
        }

        public async Task<JsonResponse?> ResetPasswordAsync(string email, string otp, string password)
        {
            var client = CreateClient();
            var content = new FormUrlEncodedContent(new[]
            {
                new KeyValuePair<string, string>("email", email),
                new KeyValuePair<string, string>("otp", otp),
                new KeyValuePair<string, string>("password", password)
            });

            var response = await client.PostAsync("api/auth/reset-password", content);
            var json = await response.Content.ReadAsStringAsync();
            return new JsonResponse { Success = response.IsSuccessStatusCode, Message = json, Data = json };
        }

        private static string? ExtractMessage(string json)
        {
            try
            {
                var jo = JObject.Parse(json);
                return jo["message"]?.ToString() ?? jo["error"]?.ToString() ?? jo["title"]?.ToString();
            }
            catch
            {
                return null;
            }
        }

        // Generic GET
        public async Task<JsonResponse?> GetAsync(string endpoint)
        {
            var client = CreateClient();
            var response = await client.GetAsync(endpoint);
            var json = await response.Content.ReadAsStringAsync();
            var msg = !response.IsSuccessStatusCode ? ExtractMessage(json) ?? json : null;
            return new JsonResponse { Success = response.IsSuccessStatusCode, Data = json, Message = msg };
        }

        // Generic GET by ID
        public async Task<JsonResponse?> GetByIdAsync(string endpoint, int id)
        {
            var client = CreateClient();
            var response = await client.GetAsync($"{endpoint}/{id}");
            var json = await response.Content.ReadAsStringAsync();
            var msg = !response.IsSuccessStatusCode ? ExtractMessage(json) ?? json : null;
            return new JsonResponse { Success = response.IsSuccessStatusCode, Data = json, Message = msg };
        }

        // Generic POST
        public async Task<JsonResponse?> PostAsync(string endpoint, object data)
        {
            var client = CreateClient();
            var content = new StringContent(
                JsonConvert.SerializeObject(data, JsonSettings.Instance),
                Encoding.UTF8,
                "application/json");

            var response = await client.PostAsync(endpoint, content);
            var json = await response.Content.ReadAsStringAsync();
            var msg = !response.IsSuccessStatusCode ? ExtractMessage(json) ?? json : null;
            return new JsonResponse { Success = response.IsSuccessStatusCode, Data = json, Message = msg };
        }

        // Generic PUT (dengan ID)
        public async Task<JsonResponse?> PutAsync(string endpoint, int id, object data)
        {
            var client = CreateClient();
            var content = new StringContent(
                JsonConvert.SerializeObject(data, JsonSettings.Instance),
                Encoding.UTF8,
                "application/json");
            var response = await client.PutAsync($"{endpoint}/{id}", content);
            var json = await response.Content.ReadAsStringAsync();
            var msg = !response.IsSuccessStatusCode ? ExtractMessage(json) ?? json : null;
            return new JsonResponse { Success = response.IsSuccessStatusCode, Data = json, Message = msg };
        }

        // Generic PUT (tanpa ID, untuk endpoint seperti /api/locations/company)
        public async Task<JsonResponse?> PutAsync(string endpoint, object data)
        {
            var client = CreateClient();
            var content = new StringContent(
                JsonConvert.SerializeObject(data, JsonSettings.Instance),
                Encoding.UTF8,
                "application/json");
            var response = await client.PutAsync(endpoint, content);
            var json = await response.Content.ReadAsStringAsync();
            var msg = !response.IsSuccessStatusCode ? ExtractMessage(json) ?? json : null;
            return new JsonResponse { Success = response.IsSuccessStatusCode, Data = json, Message = msg };
        }

        // Generic DELETE
        public async Task<JsonResponse?> DeleteAsync(string endpoint, int id)
        {
            var client = CreateClient();
            var response = await client.DeleteAsync($"{endpoint}/{id}");
            var json = await response.Content.ReadAsStringAsync();
            var msg = !response.IsSuccessStatusCode ? ExtractMessage(json) ?? json : null;
            return new JsonResponse { Success = response.IsSuccessStatusCode, Data = json, Message = msg };
        }
    }

    public class JsonResponse
    {
        public bool Success { get; set; }
        public string? Message { get; set; }
        public string? Data { get; set; }
    }
}
