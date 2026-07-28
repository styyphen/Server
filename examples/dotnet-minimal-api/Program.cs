using System.Diagnostics;
using System.Diagnostics.Metrics;
using Luhl.Observability;

var builder = WebApplication.CreateBuilder(args);

var observability = builder.Configuration
    .GetSection("Observability")
    .Get<ObservabilityOptions>() ?? new ObservabilityOptions();

var serviceName = observability.ServiceName;

builder.Services.AddProjectObservability(
    builder.Configuration,
    builder.Environment,
    builder.Logging);

var app = builder.Build();

app.UseProjectObservability();

var activitySource = app.Services.GetRequiredService<ActivitySource>();
var meter = app.Services.GetRequiredService<Meter>();
var requestCounter = meter.CreateCounter<long>("sample.requests");
var requestDuration = meter.CreateHistogram<double>("sample.request.duration", "ms");
var sampleRunId = Environment.GetEnvironmentVariable("SAMPLE_RUN_ID") ?? "manual";

app.MapGet("/", (ILogger<Program> logger) =>
{
    requestCounter.Add(
        1,
        new KeyValuePair<string, object?>("route", "/"),
        new KeyValuePair<string, object?>("sample_run_id", sampleRunId));
    logger.LogInformation("Root endpoint handled for {ServiceName}.", serviceName);

    return Results.Ok(new
    {
        Service = serviceName,
        Status = "OK",
        Timestamp = DateTimeOffset.UtcNow
    });
});

app.MapGet("/work", async (ILogger<Program> logger, CancellationToken cancellationToken) =>
{
    var started = Stopwatch.GetTimestamp();

    using var activity = activitySource.StartActivity("sample-work");
    activity?.SetTag("work.kind", "demo");

    await Task.Delay(Random.Shared.Next(50, 250), cancellationToken);

    var elapsedMs = Stopwatch.GetElapsedTime(started).TotalMilliseconds;
    requestCounter.Add(
        1,
        new KeyValuePair<string, object?>("route", "/work"),
        new KeyValuePair<string, object?>("sample_run_id", sampleRunId));
    requestDuration.Record(
        elapsedMs,
        new KeyValuePair<string, object?>("route", "/work"),
        new KeyValuePair<string, object?>("sample_run_id", sampleRunId));

    logger.LogInformation("Sample work completed in {DurationMs} ms.", elapsedMs);

    return Results.Ok(new
    {
        Service = serviceName,
        DurationMs = elapsedMs
    });
});

app.MapGet("/warning", (ILogger<Program> logger) =>
{
    requestCounter.Add(
        1,
        new KeyValuePair<string, object?>("route", "/warning"),
        new KeyValuePair<string, object?>("sample_run_id", sampleRunId));
    logger.LogWarning("Sample warning emitted for local observability validation.");

    return Results.Ok(new
    {
        Message = "Warning log emitted"
    });
});

app.MapGet("/error", (ILogger<Program> logger) =>
{
    requestCounter.Add(
        1,
        new KeyValuePair<string, object?>("route", "/error"),
        new KeyValuePair<string, object?>("sample_run_id", sampleRunId));

    try
    {
        throw new InvalidOperationException("Sample exception for local observability validation.");
    }
    catch (Exception exception)
    {
        logger.LogError(exception, "Sample error emitted for local observability validation.");
        return Results.Problem("Sample error emitted.");
    }
});

app.Run();
