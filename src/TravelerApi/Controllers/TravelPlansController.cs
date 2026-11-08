using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TravelerApi.Data;
using TravelerApi.DTOs;
using TravelerApi.Models;

namespace TravelerApi.Controllers;

[ApiController]
[Route("api/travel-plans")]
public class TravelPlansController : ControllerBase
{
    private readonly AppDbContext _db;

    public TravelPlansController(AppDbContext db)
    {
        _db = db;
    }

    // GET /api/travel-plans
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var plans = await _db.TravelPlans
            .AsNoTracking()
            .OrderByDescending(p => p.CreatedAt)
            .Select(p => MapToResponse(p, null))
            .ToListAsync();

        return Ok(plans);
    }

    // GET /api/travel-plans/{id}
    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(string id)
    {
        if (!Guid.TryParse(id, out var planGuid))
            return BadRequest(new { error = "Validation error", details = new[] { "Invalid UUID format for id" } });

        var plan = await _db.TravelPlans
            .AsNoTracking()
            .Include(p => p.Locations.OrderBy(l => l.VisitOrder))
            .FirstOrDefaultAsync(p => p.Id == planGuid);

        if (plan == null)
            return NotFound(new { error = "Travel plan not found" });

        var locDtos = plan.Locations
            .OrderBy(l => l.VisitOrder)
            .Select(MapLocationToResponse)
            .ToList();

        return Ok(MapToResponse(plan, locDtos));
    }

    // POST /api/travel-plans
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] TravelPlanCreateDto? dto)
    {
        var errors = ValidatePlanDto(dto);
        if (errors.Count > 0)
            return BadRequest(new { error = "Validation error", details = errors });

        var now = DateTimeOffset.UtcNow;
        var plan = new TravelPlan
        {
            Id = Guid.NewGuid(),
            Title = dto!.Title!.Trim(),
            Description = dto.Description,
            StartDate = dto.StartDate,
            EndDate = dto.EndDate,
            Budget = dto.Budget,
            Currency = string.IsNullOrWhiteSpace(dto.Currency) ? "USD" : dto.Currency.Trim().ToUpperInvariant(),
            IsPublic = dto.IsPublic ?? false,
            Version = 1,
            CreatedAt = now,
            UpdatedAt = now
        };

        _db.TravelPlans.Add(plan);
        await _db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = plan.Id }, MapToResponse(plan, new List<LocationResponseDto>()));
    }

    // PUT /api/travel-plans/{id}
    [HttpPut("{id}")]
    public async Task<IActionResult> Update(string id, [FromBody] TravelPlanUpdateDto? dto)
    {
        if (!Guid.TryParse(id, out var planGuid))
            return BadRequest(new { error = "Validation error", details = new[] { "Invalid UUID format for id" } });

        var errors = ValidatePlanDto(dto);
        if (dto?.Version == null || dto.Version < 1)
            errors.Add("Valid 'version' (>= 1) is required for optimistic locking.");

        if (errors.Count > 0)
            return BadRequest(new { error = "Validation error", details = errors });

        var existing = await _db.TravelPlans.AsNoTracking().FirstOrDefaultAsync(p => p.Id == planGuid);
        if (existing == null)
            return NotFound(new { error = "Travel plan not found" });

        var currency = string.IsNullOrWhiteSpace(dto!.Currency) ? existing.Currency : dto.Currency.Trim().ToUpperInvariant();
        var isPublic = dto.IsPublic ?? existing.IsPublic;
        var now = DateTimeOffset.UtcNow;

        // Problem 1 Solution: Optimistic Locking via atomic SQL UPDATE with WHERE version = @expectedVersion
        int rowsAffected = await _db.Database.ExecuteSqlInterpolatedAsync($@"
            UPDATE travel_plans
            SET title = {dto.Title!.Trim()},
                description = {dto.Description},
                start_date = {dto.StartDate},
                end_date = {dto.EndDate},
                budget = {dto.Budget},
                currency = {currency},
                is_public = {isPublic},
                version = version + 1,
                updated_at = {now}
            WHERE id = {planGuid} AND version = {dto.Version!.Value}");

        if (rowsAffected == 0)
        {
            var current = await _db.TravelPlans.AsNoTracking().FirstOrDefaultAsync(p => p.Id == planGuid);
            if (current == null)
                return NotFound(new { error = "Travel plan not found" });

            return Conflict(new
            {
                error = "Conflict: Travel plan was modified by another user",
                current_version = current.Version
            });
        }

        var updated = await _db.TravelPlans
            .AsNoTracking()
            .Include(p => p.Locations.OrderBy(l => l.VisitOrder))
            .FirstAsync(p => p.Id == planGuid);

        var locDtos = updated.Locations.OrderBy(l => l.VisitOrder).Select(MapLocationToResponse).ToList();
        return Ok(MapToResponse(updated, locDtos));
    }

    // DELETE /api/travel-plans/{id}
    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(string id)
    {
        if (!Guid.TryParse(id, out var planGuid))
            return BadRequest(new { error = "Validation error", details = new[] { "Invalid UUID format for id" } });

        int rowsAffected = await _db.Database.ExecuteSqlInterpolatedAsync(
            $"DELETE FROM travel_plans WHERE id = {planGuid}");

        if (rowsAffected == 0)
            return NotFound(new { error = "Travel plan not found" });

        return NoContent();
    }

    // POST /api/travel-plans/{id}/locations
    [HttpPost("{id}/locations")]
    public async Task<IActionResult> AddLocation(string id, [FromBody] LocationCreateDto? dto)
    {
        if (!Guid.TryParse(id, out var planGuid))
            return BadRequest(new { error = "Validation error", details = new[] { "Invalid UUID format for id" } });

        var errors = LocationsController.ValidateLocationDto(dto);
        if (errors.Count > 0)
            return BadRequest(new { error = "Validation error", details = errors });

        await using var transaction = await _db.Database.BeginTransactionAsync();

        // Problem 2 Solution: Pessimistic row-level lock (FOR UPDATE) on parent travel_plan
        // Serializes concurrent location additions to the same travel plan so MAX(visit_order) + 1 is strictly sequential
        var parentPlan = await _db.TravelPlans
            .FromSqlInterpolated($"SELECT * FROM travel_plans WHERE id = {planGuid} FOR UPDATE")
            .FirstOrDefaultAsync();

        if (parentPlan == null)
        {
            await transaction.RollbackAsync();
            return NotFound(new { error = "Travel plan not found" });
        }

        int maxOrder = await _db.Locations
            .Where(l => l.TravelPlanId == planGuid)
            .Select(l => (int?)l.VisitOrder)
            .MaxAsync() ?? 0;

        int assignedOrder = dto!.VisitOrder ?? (maxOrder + 1);

        if (dto.VisitOrder.HasValue && dto.VisitOrder.Value <= maxOrder)
        {
            // Shift existing locations down if inserting in the middle
            await _db.Database.ExecuteSqlInterpolatedAsync($@"
                UPDATE locations
                SET visit_order = visit_order + 1
                WHERE travel_plan_id = {planGuid} AND visit_order >= {assignedOrder}");
        }

        var location = new Location
        {
            Id = Guid.NewGuid(),
            TravelPlanId = planGuid,
            Name = dto.Name!.Trim(),
            Address = dto.Address,
            Latitude = dto.Latitude,
            Longitude = dto.Longitude,
            VisitOrder = assignedOrder,
            ArrivalDate = dto.ArrivalDate,
            DepartureDate = dto.DepartureDate,
            Budget = dto.Budget,
            Notes = dto.Notes,
            Version = 1,
            CreatedAt = DateTimeOffset.UtcNow
        };

        _db.Locations.Add(location);

        // Also bump parent updated_at and version for parent-level tracking
        await _db.Database.ExecuteSqlInterpolatedAsync($@"
            UPDATE travel_plans
            SET version = version + 1, updated_at = NOW()
            WHERE id = {planGuid}");

        await _db.SaveChangesAsync();
        await transaction.CommitAsync();

        return StatusCode(StatusCodes.Status201Created, MapLocationToResponse(location));
    }

    internal static List<string> ValidatePlanDto(TravelPlanCreateDto? dto)
    {
        var errors = new List<string>();
        if (dto == null)
        {
            errors.Add("Request body is required.");
            return errors;
        }

        if (string.IsNullOrWhiteSpace(dto.Title))
            errors.Add("Title is required and cannot be empty.");
        else if (dto.Title.Trim().Length > 200)
            errors.Add("Title must not exceed 200 characters.");

        if (dto.StartDate.HasValue && dto.EndDate.HasValue && dto.EndDate.Value < dto.StartDate.Value)
            errors.Add("end_date must be greater than or equal to start_date.");

        if (dto.Budget.HasValue && dto.Budget.Value < 0)
            errors.Add("budget must be non-negative (>= 0).");

        if (dto.Currency != null && dto.Currency.Trim().Length != 3)
            errors.Add("currency must be an ISO 3-character code (e.g., USD, EUR).");

        return errors;
    }

    internal static TravelPlanResponseDto MapToResponse(TravelPlan p, List<LocationResponseDto>? locations) => new()
    {
        Id = p.Id,
        Title = p.Title,
        Description = p.Description,
        StartDate = p.StartDate,
        EndDate = p.EndDate,
        Budget = p.Budget,
        Currency = p.Currency,
        IsPublic = p.IsPublic,
        Version = p.Version,
        CreatedAt = p.CreatedAt,
        UpdatedAt = p.UpdatedAt,
        Locations = locations
    };

    internal static LocationResponseDto MapLocationToResponse(Location l) => new()
    {
        Id = l.Id,
        TravelPlanId = l.TravelPlanId,
        Name = l.Name,
        Address = l.Address,
        Latitude = l.Latitude,
        Longitude = l.Longitude,
        VisitOrder = l.VisitOrder,
        ArrivalDate = l.ArrivalDate,
        DepartureDate = l.DepartureDate,
        Budget = l.Budget,
        Notes = l.Notes,
        Version = l.Version,
        CreatedAt = l.CreatedAt
    };
}
