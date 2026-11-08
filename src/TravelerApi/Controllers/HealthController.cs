using Microsoft.AspNetCore.Mvc;
using TravelerApi.Data;

namespace TravelerApi.Controllers;

[ApiController]
[Route("api/health")]
public class HealthController : ControllerBase
{
    private readonly AppDbContext _db;

    public HealthController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> CheckHealth()
    {
        try
        {
            bool canConnect = await _db.Database.CanConnectAsync();
            if (!canConnect)
                return StatusCode(StatusCodes.Status503ServiceUnavailable, new { status = "Unhealthy", database = "Disconnected" });

            return Ok(new { status = "Healthy", database = "Connected", timestamp = DateTimeOffset.UtcNow });
        }
        catch (Exception ex)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new { status = "Unhealthy", error = ex.Message });
        }
    }
}
