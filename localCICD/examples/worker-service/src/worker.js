export function createHeartbeat(serviceName = "worker-service") {
  return {
    service: serviceName,
    status: "ok",
    handledAt: new Date(0).toISOString()
  };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const intervalMs = Number(process.env.WORKER_INTERVAL_MS || 5000);
  console.log("worker-service worker started");
  setInterval(() => {
    console.log(JSON.stringify(createHeartbeat()));
  }, intervalMs);
}

