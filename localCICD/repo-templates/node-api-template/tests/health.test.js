import assert from "node:assert/strict";
import { test } from "node:test";
import { createServer } from "../src/server.js";

test("GET /health returns ok", async () => {
  const server = createServer();
  await new Promise((resolve) => server.listen(0, resolve));
  const address = server.address();

  try {
    const response = await fetch(`http://127.0.0.1:${address.port}/health`);
    assert.equal(response.status, 200);
    assert.equal((await response.json()).status, "ok");
  }
  finally {
    server.close();
  }
});
