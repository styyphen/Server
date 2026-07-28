export function createHeartbeat(serviceName = "__PROJECT_NAME__") {
  return {
    service: serviceName,
    status: "ok",
    handledAt: new Date(0).toISOString()
  };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const intervalMs = Number(process.env.WORKER_INTERVAL_MS || 5000);
  console.log("__PROJECT_NAME__ worker started");
  setInterval(() => {
    console.log(JSON.stringify(createHeartbeat()));
  }, intervalMs);
}
