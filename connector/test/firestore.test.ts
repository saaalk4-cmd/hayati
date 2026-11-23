import { test } from "node:test";
import assert from "node:assert/strict";
import {
  DELETE, decode, encode, expandDotted, leafPaths, quoteSegment,
} from "../src/firestore.ts";

test("encode/decode keep app formats (ints stay ints)", () => {
  const data = { createdAt: 1795467944914, amount: 150.5, title: "مهمة", done: false, note: null, steps: [{ t: "أ", d: true }] };
  const back = decode(encode(data));
  assert.deepEqual(back, data);
  assert.deepEqual(encode(150), { integerValue: "150" });
  assert.deepEqual(encode(1.5), { doubleValue: 1.5 });
});

test("merge paths reach the leaves like admin SDK", () => {
  assert.deepEqual(leafPaths({ page: 5, log: { "2026-11-23": 5 } }), [["page"], ["log", "2026-11-23"]]);
  assert.equal(["log", "2026-11-23"].map(quoteSegment).join("."), "log.`2026-11-23`");
});

test("update with dotted keys and delete", () => {
  const { fields, paths } = expandDotted({ "done.2026-11-23": true, "done.2026-11-22": DELETE });
  assert.deepEqual(fields, { done: { "2026-11-23": true } });
  assert.deepEqual(paths, [["done", "2026-11-23"], ["done", "2026-11-22"]]);
});
