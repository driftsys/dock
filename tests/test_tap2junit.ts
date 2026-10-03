import { parseTap, toJunit } from "../scripts/tap2junit.ts";

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

function rejects(input: string) {
  try {
    parseTap(input);
  } catch {
    return;
  }
  throw new Error("Expected malformed TAP to be rejected");
}

Deno.test("TAP13 success, failure diagnostics, SKIP and TODO", () => {
  const cases = parseTap(`TAP version 13
1..4
ok 1 - works
not ok 2 - broken
  ---
  message: expected <value> & actual
  severity: fail
  ...
ok 3 - optional # SKIP unavailable
not ok 4 - future # TODO implement
`);
  equal(cases.map((test) => test.status), [
    "passed",
    "failed",
    "skipped",
    "skipped",
  ]);
  equal(cases[1].diagnostics.includes("expected <value> & actual"), true);
  const xml = toJunit(cases, 'suite "A"');
  equal(xml.includes('tests="4" failures="1" skipped="2"'), true);
  equal(xml.includes('name="suite &quot;A&quot;"'), true);
  equal(xml.includes('classname="suite &quot;A&quot;"'), true);
  equal(xml.includes("expected &lt;value&gt; &amp; actual"), true);
  equal(xml.includes('<skipped message="unavailable"'), true);
  equal(xml.includes('<skipped message="implement"'), true);
});

Deno.test("trailing plan, implicit numbers and CRLF", () => {
  const cases = parseTap("ok - first\r\nnot ok - second\r\n1..2\r\n");
  equal(cases.map((test) => test.name), ["first", "second"]);
  equal(cases.map((test) => test.status), ["passed", "failed"]);
  equal(toJunit(cases).includes('>second</failure>'), true);
});

Deno.test("empty skip-all plan", () => {
  equal(parseTap("TAP version 13\n1..0 # SKIP no tests\n"), []);
});

Deno.test("XML removes forbidden controls and escapes attributes", () => {
  const xml = toJunit(parseTap('1..1\nok 1 - <tag> & "quote"\u0001\n'));
  equal(xml.includes("&lt;tag&gt; &amp; &quot;quote&quot;"), true);
  equal(xml.includes("\u0001"), false);
});

Deno.test("invalid, partial, nested and bailed-out streams fail", () => {
  for (
    const input of [
      "",
      "ok 1 - missing plan",
      "1..2\nok 1 - incomplete",
      "1..1\nok 1\nok 2",
      "1..1\nok 2",
      "ok 1\n1..2\nok 2",
      "1..1\n1..1\nok 1",
      "1..1\nBail out! failure",
      "1..1\n  ok 1 - nested\nok 1 - parent",
      "1..1\nunknown output\nok 1",
      "1..1\nnot ok 1\n  ---\nmessage: unfinished",
    ]
  ) rejects(input);
});
