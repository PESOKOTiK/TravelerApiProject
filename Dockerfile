# =====================================================================
# Stage 1: Build Stage (.NET 8 SDK Alpine)
# =====================================================================
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
WORKDIR /src

# Copy csproj and restore dependencies first (layer caching optimization)
COPY ["src/TravelerApi/TravelerApi.csproj", "src/TravelerApi/"]
RUN dotnet restore "src/TravelerApi/TravelerApi.csproj"

# Copy remaining source files and publish Release build
COPY ["src/TravelerApi/", "src/TravelerApi/"]
WORKDIR "/src/src/TravelerApi"
RUN dotnet publish "TravelerApi.csproj" -c Release -o /app/publish /p:UseAppHost=false

# =====================================================================
# Stage 2: Runtime Stage (.NET 8 ASP.NET Runtime Alpine)
# =====================================================================
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime
WORKDIR /app

# Install wget & curl for container healthchecks and create non-root user (UID/GID 1000)
RUN apk add --no-cache wget curl icu-libs && \
    addgroup -g 1000 appgroup && \
    adduser -u 1000 -G appgroup -s /bin/sh -D appuser && \
    mkdir -p /app/logs /app/tmp && \
    chown -R 1000:1000 /app

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    ASPNETCORE_URLS=http://+:5000 \
    ASPNETCORE_ENVIRONMENT=Production

COPY --from=build --chown=1000:1000 /app/publish .

# Best practice #10: Run container process as non-root user
USER 1000:1000

EXPOSE 5000

ENTRYPOINT ["dotnet", "TravelerApi.dll"]
