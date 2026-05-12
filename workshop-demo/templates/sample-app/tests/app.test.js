const test = require("node:test");
const assert = require("node:assert/strict");
const { buildMessage } = require("../src/app");

test("buildMessage returns the workshop message", () => {
    assert.equal(buildMessage(), "Azure DevOps workshop sample app");
});