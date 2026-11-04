using System.Net;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Hosting;
using Xunit;

namespace JJDevHub.ServiceDefaults.Tests
{
    public sealed class HealthEndpointTests
    {
        [Fact]
        public async Task Health_endpoint_returns_ok_outside_development()
        {
            WebApplicationBuilder builder = WebApplication.CreateBuilder(
                new WebApplicationOptions
                {
                    EnvironmentName = Environments.Production
                });
            builder.WebHost.UseUrls("http://127.0.0.1:0");
            builder.AddServiceDefaults();

            await using WebApplication app = builder.Build();
            app.MapDefaultEndpoints();
            await app.StartAsync(CancellationToken.None);

            using var client = new HttpClient();
            using HttpResponseMessage response = await client.GetAsync(
                new Uri(new Uri(app.Urls.First()), "/health"),
                CancellationToken.None);

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        }
    }
}
