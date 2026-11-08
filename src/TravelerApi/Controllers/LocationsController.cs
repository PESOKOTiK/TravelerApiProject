using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TravelerApi.Data;
using TravelerApi.DTOs;

namespace TravelerApi.Controllers;

[ApiController]
[Route("api/locations")]
public class LocationsController : ControllerBase
{
    private readonly AppDbContext _db;

    public LocationsController(AppDbContext db)
    {
        _db = db;
    }

    // PUT /api/locations/{id}
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateLocation(string id, [FromBody] LocationUpdateDto? dto)
    {
        if (!Guid.TryParse(id, out var locationGuid))
            return BadRequest(new { error = "Validation error", details = new[] { "Invalid UUID format for id" } });

        var errors = ValidateLocationDto(dto, isUpdate: true);
        if (errors.Count > 0)
            return BadRequest(new { error = "Validation error", details = errors });

        await using var transaction = await _db.Database.BeginTransactionAsync();

        var existing = await _db.Locations.AsNoTracking().FirstOrDefaultAsync(l => l.Id == locationGuid);
        if (existing == null)
        {
            await transaction.RollbackAsync();
            return NotFound(new { error = "Location not found" });
        }

        // Support partial/merged fields if not provided in update payload while validating merged state
        string newName = dto!.Name != null ? dto.Name.Trim() : existing.Name;
        string? newAddress = dto.Address ?? existing.Address;
        decimal? newLat = dto.Latitude ?? existing.Latitude;
        decimal? newLng = dto.Longitude ?? existing.Longitude;
        int newOrder = dto.VisitOrder ?? existing.VisitOrder;
        DateTimeOffset? newArrival = dto.ArrivalDate ?? existing.ArrivalDate;
        DateTimeOffset? newDeparture = dto.DepartureDate ?? existing.DepartureDate;
        decimal? newBudget = dto.Budget ?? existing.Budget;
        string? newNotes = dto.Notes ?? existing.Notes;

        if (newArrival.HasValue && newDeparture.HasValue && newDeparture.Value < newArrival.Value)
        {
            await transaction.RollbackAsync();
            return BadRequest(new { error = "Validation error", details = new[] { "departure_date must be >= arrival_date" } });
        }

        // Problem 3 ("І в раю муха сяде"): Optimistic locking on Location update
        // If client provides 'version', verify version match; otherwise use current version check
        int expectedVersion = dto.Version ?? existing.Version;

        if (newOrder != existing.VisitOrder)
        {
            // Lock parent travel plan when reordering locations to prevent order race conditions
            await _db.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT id FROM travel_plans WHERE id = {existing.TravelPlanId} FOR UPDATE");

            if (newOrder < existing.VisitOrder)
            {
                await _db.Database.ExecuteSqlInterpolatedAsync($@"
                    UPDATE locations
                    SET visit_order = visit_order + 1
                    WHERE travel_plan_id = {existing.TravelPlanId}
                      AND visit_order >= {newOrder}
                      AND visit_order < {existing.VisitOrder}
                      AND id <> {locationGuid}");
            }
            else
            {
                await _db.Database.ExecuteSqlInterpolatedAsync($@"
                    UPDATE locations
                    SET visit_order = visit_order - 1
                    WHERE travel_plan_id = {existing.TravelPlanId}
                      AND visit_order <= {newOrder}
                      AND visit_order > {existing.VisitOrder}
                      AND id <> {locationGuid}");
            }
        }

        int rowsAffected = await _db.Database.ExecuteSqlInterpolatedAsync($@"
            UPDATE locations
            SET name = {newName},
                address = {newAddress},
                latitude = {newLat},
                longitude = {newLng},
                visit_order = {newOrder},
                arrival_date = {newArrival},
                departure_date = {newDeparture},
                budget = {newBudget},
                notes = {newNotes},
                version = version + 1
            WHERE id = {locationGuid} AND version = {expectedVersion}");

        if (rowsAffected == 0)
        {
            await transaction.RollbackAsync();
            var current = await _db.Locations.AsNoTracking().FirstOrDefaultAsync(l => l.Id == locationGuid);
            if (current == null)
                return NotFound(new { error = "Location not found" });

            return Conflict(new
            {
                error = "Conflict: Location was modified by another user",
                current_version = current.Version
            });
        }

        // Also increment parent TravelPlan version
        await _db.Database.ExecuteSqlInterpolatedAsync($@"
            UPDATE travel_plans
            SET version = version + 1, updated_at = NOW()
            WHERE id = {existing.TravelPlanId}");

        await transaction.CommitAsync();

        var updated = await _db.Locations.AsNoTracking().FirstAsync(l => l.Id == locationGuid);
        return Ok(TravelPlansController.MapLocationToResponse(updated));
    }

    // DELETE /api/locations/{id}
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteLocation(string id)
    {
        if (!Guid.TryParse(id, out var locationGuid))
            return BadRequest(new { error = "Validation error", details = new[] { "Invalid UUID format for id" } });

        await using var transaction = await _db.Database.BeginTransactionAsync();

        var existing = await _db.Locations.AsNoTracking().FirstOrDefaultAsync(l => l.Id == locationGuid);
        if (existing == null)
        {
            await transaction.RollbackAsync();
            return NotFound(new { error = "Location not found" });
        }

        await _db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT id FROM travel_plans WHERE id = {existing.TravelPlanId} FOR UPDATE");

        await _db.Database.ExecuteSqlInterpolatedAsync(
            $"DELETE FROM locations WHERE id = {locationGuid} AND version = {expectedVersion}");

        // Re-compact visit_order after deletion so order stays sequential without gaps
        await _db.Database.ExecuteSqlInterpolatedAsync($@"
            UPDATE locations
            SET visit_order = visit_order - 1
            WHERE travel_plan_id = {existing.TravelPlanId} AND visit_order > {existing.VisitOrder}");

        await _db.Database.ExecuteSqlInterpolatedAsync($@"
            UPDATE travel_plans
            SET version = version + 1, updated_at = NOW()
            WHERE id = {existing.TravelPlanId}");

        await transaction.CommitAsync();
        return NoContent();
    }

    internal static List<string> ValidateLocationDto(LocationCreateDto? dto, bool isUpdate = false)
    {
        var errors = new List<string>();
        if (dto == null)
        {
            errors.Add("Request body is required.");
            return errors;
        }

        if (!isUpdate || dto.Name != null)
        {
            if (string.IsNullOrWhiteSpace(dto.Name))
                errors.Add("Location name is required and cannot be empty.");
            else if (dto.Name.Trim().Length > 200)
                errors.Add("Location name must not exceed 200 characters.");
        }

        if (dto.Latitude.HasValue && (dto.Latitude.Value < -90 || dto.Latitude.Value > 90))
            errors.Add("latitude must be between -90 and 90.");

        if (dto.Longitude.HasValue && (dto.Longitude.Value < -180 || dto.Longitude.Value > 180))
            errors.Add("longitude must be between -180 and 180.");

        if (dto.VisitOrder.HasValue && dto.VisitOrder.Value <= 0)
            errors.Add("visit_order must be greater than 0.");

        if (dto.ArrivalDate.HasValue && dto.DepartureDate.HasValue && dto.DepartureDate.Value < dto.ArrivalDate.Value)
            errors.Add("departure_date must be greater than or equal to arrival_date.");

        if (dto.Budget.HasValue && dto.Budget.Value < 0)
            errors.Add("budget must be non-negative (>= 0).");

        return errors;
    }
}
