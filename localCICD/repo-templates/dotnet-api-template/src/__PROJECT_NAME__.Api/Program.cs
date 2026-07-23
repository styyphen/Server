var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/health", () => Results.Ok(new
{
    status = "ok",
    service = "__PROJECT_NAME__"
}));

app.Run();

public partial class Program
{
}
