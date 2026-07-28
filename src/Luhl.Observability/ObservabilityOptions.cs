namespace Luhl.Observability;

public sealed class ObservabilityOptions
{
    public const string SectionName = "Observability";

    public string ServiceName { get; set; } = "local-service";

    public string ServiceVersion { get; set; } = "1.0.0";

    public string EnvironmentName { get; set; } = "Development";

    public string OtlpEndpoint { get; set; } = "http://localhost:4317";

    public bool EnableTracing { get; set; } = true;

    public bool EnableMetrics { get; set; } = true;

    public bool EnableStructuredLogging { get; set; } = true;

    public bool EnableRuntimeInstrumentation { get; set; } = true;

    public bool EnableHttpClientInstrumentation { get; set; } = true;

    public bool EnableAspNetCoreInstrumentation { get; set; } = true;

    public int MetricExportIntervalMilliseconds { get; set; } = 5000;
}
