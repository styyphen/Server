using System.Diagnostics;
using System.Diagnostics.Metrics;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using OpenTelemetry.Logs;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

namespace Luhl.Observability;

public static class ProjectObservability
{
    public static IServiceCollection AddProjectObservability(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment hostEnvironment,
        ILoggingBuilder logging)
    {
        ArgumentNullException.ThrowIfNull(services);
        ArgumentNullException.ThrowIfNull(configuration);
        ArgumentNullException.ThrowIfNull(hostEnvironment);
        ArgumentNullException.ThrowIfNull(logging);

        var options = configuration
            .GetSection(ObservabilityOptions.SectionName)
            .Get<ObservabilityOptions>() ?? new ObservabilityOptions();

        if (string.IsNullOrWhiteSpace(options.EnvironmentName))
        {
            options.EnvironmentName = hostEnvironment.EnvironmentName;
        }

        var otlpEndpoint = new Uri(options.OtlpEndpoint);
        var activitySource = new ActivitySource(options.ServiceName);
        var meter = new Meter(options.ServiceName);
        var resourceBuilder = CreateResourceBuilder(options);

        services.AddSingleton(options);
        services.AddSingleton(activitySource);
        services.AddSingleton(meter);
        services.AddHealthChecks();

        if (options.EnableStructuredLogging)
        {
            logging.ClearProviders();
            logging.AddConsole();
            logging.AddOpenTelemetry(openTelemetry =>
            {
                openTelemetry.SetResourceBuilder(resourceBuilder);
                openTelemetry.IncludeFormattedMessage = true;
                openTelemetry.IncludeScopes = true;
                openTelemetry.ParseStateValues = true;
                openTelemetry.AddOtlpExporter(exporter =>
                {
                    exporter.Endpoint = otlpEndpoint;
                });
            });
        }

        var openTelemetryBuilder = services.AddOpenTelemetry()
            .ConfigureResource(resource => resource
                .AddService(serviceName: options.ServiceName, serviceVersion: options.ServiceVersion)
                .AddAttributes(new Dictionary<string, object>
                {
                    ["deployment.environment"] = options.EnvironmentName
                }));

        if (options.EnableTracing)
        {
            openTelemetryBuilder.WithTracing(tracing =>
            {
                tracing.AddSource(options.ServiceName);

                if (options.EnableAspNetCoreInstrumentation)
                {
                    tracing.AddAspNetCoreInstrumentation();
                }

                if (options.EnableHttpClientInstrumentation)
                {
                    tracing.AddHttpClientInstrumentation();
                }

                tracing.AddOtlpExporter(exporter =>
                {
                    exporter.Endpoint = otlpEndpoint;
                });
            });
        }

        if (options.EnableMetrics)
        {
            openTelemetryBuilder.WithMetrics(metrics =>
            {
                metrics.AddMeter(options.ServiceName);

                if (options.EnableAspNetCoreInstrumentation)
                {
                    metrics.AddAspNetCoreInstrumentation();
                }

                if (options.EnableHttpClientInstrumentation)
                {
                    metrics.AddHttpClientInstrumentation();
                }

                if (options.EnableRuntimeInstrumentation)
                {
                    metrics.AddRuntimeInstrumentation();
                }

                metrics.AddOtlpExporter((exporter, reader) =>
                {
                    exporter.Endpoint = otlpEndpoint;
                    reader.PeriodicExportingMetricReaderOptions.ExportIntervalMilliseconds =
                        options.MetricExportIntervalMilliseconds;
                });
            });
        }

        return services;
    }

    public static WebApplication UseProjectObservability(this WebApplication app)
    {
        ArgumentNullException.ThrowIfNull(app);

        app.MapHealthChecks("/health", new HealthCheckOptions
        {
            ResponseWriter = async (context, report) =>
            {
                context.Response.ContentType = "application/json";
                await context.Response.WriteAsJsonAsync(new
                {
                    status = report.Status.ToString(),
                    checks = report.Entries.Select(entry => new
                    {
                        name = entry.Key,
                        status = entry.Value.Status.ToString(),
                        description = entry.Value.Description
                    })
                });
            }
        });

        return app;
    }

    private static ResourceBuilder CreateResourceBuilder(ObservabilityOptions options)
    {
        return ResourceBuilder.CreateDefault()
            .AddService(serviceName: options.ServiceName, serviceVersion: options.ServiceVersion)
            .AddAttributes(new Dictionary<string, object>
            {
                ["deployment.environment"] = options.EnvironmentName
            });
    }
}
