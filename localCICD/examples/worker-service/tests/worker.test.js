import assert from "node:assert/strict";
import { test } from "node:test";
import { createHeartbeat } from "../src/worker.js";

test("heartbeat includes service name", () => {
  assert.equal(createHeartbeat("worker").service, "worker");
});

