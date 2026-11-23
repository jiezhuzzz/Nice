# SAFETY: openFirewall is any-source; the box is NAT'd (v4) and ULA-only (v6).
{nice, ...}: {
  den.aspects.homelab.glance.nixos = {config, ...}: {
    nice.web.services.glance = {
      port = 8083;
      lan = true;
      order = 10;
    };

    services.glance = {
      enable = true;
      openFirewall = true;
      environmentFile = config.age.secrets.waqi-token.path;
      settings = {
        server = {
          host = "0.0.0.0";
          port = config.nice.web.services.glance.port;
        };

        pages = [
          {
            name = "Home";
            columns = [
              {
                size = "small";
                widgets = [
                  {
                    type = "weather";
                    location = "Chicago, Illinois, United States";
                    units = "metric";
                    "hour-format" = "24h";
                  }
                  {
                    type = "custom-api";
                    title = "Air Quality";
                    cache = "10m";
                    url = "https://api.waqi.info/feed/geo:${builtins.toJSON nice.facts.location.latitude};${builtins.toJSON nice.facts.location.longitude}/?token=\${WAQI_TOKEN}";
                    template = ''
                      {{ $aqi := printf "%03s" (.JSON.String "data.aqi") }}
                      {{ $aqiraw := .JSON.String "data.aqi" }}
                      {{ $updated := .JSON.String "data.time.iso" }}
                      {{ $humidity := .JSON.String "data.iaqi.h.v" }}
                      {{ $ozone := .JSON.String "data.iaqi.o3.v" }}
                      {{ $pm25 := .JSON.String "data.iaqi.pm25.v" }}
                      {{ $pressure := .JSON.String "data.iaqi.p.v" }}
                      <div class="flex justify-between">
                        <div class="size-h5">
                          {{ if le $aqi "050" }}
                            <div class="color-positive">Good air quality</div>
                          {{ else if le $aqi "100" }}
                            <div class="color-primary">Moderate air quality</div>
                          {{ else }}
                            <div class="color-negative">Bad air quality</div>
                          {{ end }}
                        </div>
                      </div>
                      <div class="color-highlight size-h2">AQI: {{ $aqiraw }}</div>
                      <div style="border-bottom: 1px solid; margin-block: 10px;"></div>
                      <div class="margin-block-2">
                        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
                          <div>
                            <div class="size-h3 color-highlight">{{ $humidity }}%</div>
                            <div class="size-h6">HUMIDITY</div>
                          </div>
                          <div>
                            <div class="size-h3 color-highlight">{{ $ozone }} μg/m³</div>
                            <div class="size-h6">OZONE</div>
                          </div>
                          <div>
                            <div class="size-h3 color-highlight">{{ $pm25 }} μg/m³</div>
                            <div class="size-h6">PM2.5</div>
                          </div>
                          <div>
                            <div class="size-h3 color-highlight">{{ $pressure }} hPa</div>
                            <div class="size-h6">PRESSURE</div>
                          </div>
                        </div>
                        <div class="size-h6" style="margin-top: 10px;">Last Updated at {{ slice $updated 11 16 }}</div>
                      </div>
                    '';
                  }
                ];
              }
              {
                size = "full";
                widgets = [
                  {type = "hacker-news";}
                  {type = "lobsters";}
                  {
                    type = "rss";
                    title = "Tech News";
                    style = "detailed-list";
                    limit = 15;
                    "collapse-after" = 5;
                    feeds = [
                      {
                        url = "https://arstechnica.com/feed/";
                        title = "Ars Technica";
                      }
                      {
                        url = "https://www.theverge.com/rss/index.xml";
                        title = "The Verge";
                      }
                      {
                        url = "https://simonwillison.net/atom/everything/";
                        title = "Simon Willison";
                      }
                      {
                        url = "https://newsletter.pragmaticengineer.com/feed";
                        title = "Pragmatic Engineer";
                      }
                    ];
                  }
                ];
              }
              {
                size = "small";
                widgets = [
                  {
                    type = "monitor";
                    title = "Services";
                    cache = "1m";
                    sites =
                      map (svc: {
                        inherit (svc.tile) title icon;
                        inherit (svc) url;
                        "check-url" = "http://127.0.0.1:${toString svc.port}";
                      })
                      (builtins.filter (svc: svc.tile != null) config.nice.web.ordered);
                  }
                ];
              }
            ];
          }
        ];
      };
    };
  };
}
