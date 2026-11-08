using Microsoft.EntityFrameworkCore;
using TravelerApi.Models;

namespace TravelerApi.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<TravelPlan> TravelPlans => Set<TravelPlan>();
    public DbSet<Location> Locations => Set<Location>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<TravelPlan>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Version).IsConcurrencyToken();
            entity.HasMany(e => e.Locations)
                  .WithOne(l => l.TravelPlan)
                  .HasForeignKey(l => l.TravelPlanId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Location>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Version).IsConcurrencyToken();
            entity.HasIndex(e => new { e.TravelPlanId, e.VisitOrder }).IsUnique();
        });
    }
}
