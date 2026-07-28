import assert from "node:assert/strict";
import { test } from "node:test";
import { readFileSync } from "node:fs";

test("app entry contains project name", () => {
  const source = readFileSync("src/main.jsx", "utf8");
  assert.match(source, /__PROJECT_NAME__/);
});
