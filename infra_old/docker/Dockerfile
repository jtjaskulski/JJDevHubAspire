FROM mcr.microsoft.com/dotnet/sdk:11.0.100-rc.2@sha256:db7d1f28c0805ea69fe43f73e54cffd2a0689a0c637a6078328e27c5aab2314a AS build
WORKDIR /src

ENV NUGET_PACKAGES=/root/.nuget/packages

COPY nuget.config Directory.Build.props Directory.Packages.props global.json ./
COPY src/aspire/JJDevHub.ServiceDefaults/ src/aspire/JJDevHub.ServiceDefaults/
COPY src/building-blocks/ src/building-blocks/
COPY src/services/Identity/ src/services/Identity/

# global.json stays on preview.7 so local SDKs can roll forward. This image only has rc.2.
RUN sed -i 's/11.0.100-preview.7.26381.103/11.0.100-rc.2.26504.105/' global.json \
 && dotnet restore src/services/Identity/Identity.API/Identity.API.csproj --configfile nuget.config --locked-mode
RUN dotnet publish src/services/Identity/Identity.API/Identity.API.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:11.0.0-rc.2@sha256:9a52cade70623cb66cad79baeea5ae9995b42b38d169ccc2a95b4f6b041e9874 AS runtime
# 11.0-preview stayed on preview.7 (CRITICAL/HIGH in the shared framework, fixed in rc.2).
# Upgrade OpenSSL from Ubuntu. Drop unused /usr/bin/pebble if the base image still ships it.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade --no-install-recommends libssl3t64 openssl openssl-provider-legacy \
 && rm -rf /var/lib/apt/lists/* /usr/bin/pebble /var/lib/pebble
WORKDIR /app
COPY --from=build /app .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "Identity.API.dll"]
