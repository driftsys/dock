#!/usr/bin/env -S deno run
// Convert one flat TAP 13 stream from stdin to a JUnit report on stdout.

export const VERSION = "1.0.0";

export interface TapCase {
  name: string;
  status: "passed" | "failed" | "skipped";
  reason: string;
  diagnostics: string;
}

export function parseTap(input: string): TapCase[] {
  const cases: TapCase[] = [];
  let plan: number | undefined;
  let trailingPlan = false;
  let inDiagnostics = false;
  for (const line of input.replace(/\r\n/g, "\n").split("\n")) {
    if (inDiagnostics) {
      if (/^\s+\.\.\.\s*$/.test(line)) inDiagnostics = false;
      else cases[cases.length - 1].diagnostics += `${line.trim()}\n`;
      continue;
    }
    if (/^\s+---\s*$/.test(line) && cases.length > 0) {
      inDiagnostics = true;
      continue;
    }
    if (/^\s*$/.test(line) || /^#/.test(line) || line === "TAP version 13") {
      continue;
    }
    if (/^Bail out!/i.test(line)) throw new Error(line);
    const planned = /^1\.\.(\d+)(?:\s+#.*)?\s*$/.exec(line);
    if (planned) {
      if (plan !== undefined) throw new Error("Duplicate TAP plan");
      plan = Number(planned[1]);
      trailingPlan = cases.length > 0;
      continue;
    }
    const result = /^(not ok|ok)\b(?:\s+(\d+))?(?:\s*-\s*|\s+)?(.*)$/.exec(
      line,
    );
    if (!result || trailingPlan) throw new Error(`Invalid TAP line: ${line}`);
    const number = result[2] === undefined
      ? cases.length + 1
      : Number(result[2]);
    if (number !== cases.length + 1) {
      throw new Error("TAP numbers must be sequential");
    }
    const directive = /(?:^|\s+)#\s*(SKIP|TODO)\b\s*(.*)$/i.exec(result[3]);
    cases.push({
      name:
        (directive ? result[3].slice(0, directive.index) : result[3]).trim() ||
        `test ${number}`,
      status: directive ? "skipped" : result[1] === "ok" ? "passed" : "failed",
      reason: directive?.[2] || directive?.[1] || "",
      diagnostics: "",
    });
  }
  if (inDiagnostics) throw new Error("Unterminated TAP diagnostics");
  if (
    plan === undefined || !Number.isSafeInteger(plan) || plan !== cases.length
  ) {
    throw new Error(`TAP plan does not match ${cases.length} results`);
  }
  return cases;
}

function xmlEscape(value: string): string {
  return Array.from(value).filter((character) => {
    const code = character.codePointAt(0)!;
    return code === 9 || code === 10 || code === 13 ||
      (code >= 0x20 && code <= 0xd7ff) ||
      (code >= 0xe000 && code <= 0xfffd) ||
      (code >= 0x10000 && code <= 0x10ffff);
  }).join("")
    .replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;").replaceAll("'", "&apos;");
}

export function toJunit(cases: TapCase[], name = "TAP"): string {
  const counts = `tests="${cases.length}" failures="${
    cases.filter((test) => test.status === "failed").length
  }" skipped="${cases.filter((test) => test.status === "skipped").length}"`;
  const tests = cases.map((test) => {
    let detail = "";
    if (test.status === "failed") {
      detail = `<failure message="TAP test failed">${
        xmlEscape(test.diagnostics || test.name)
      }</failure>`;
    } else if (test.status === "skipped") {
      detail = `<skipped message="${xmlEscape(test.reason)}"/>`;
    }
    return `    <testcase name="${xmlEscape(test.name)}" classname="${
      xmlEscape(name)
    }">${detail}</testcase>`;
  }).join("\n");
  return `<?xml version="1.0" encoding="UTF-8"?>\n<testsuites ${counts}>\n  <testsuite name="${
    xmlEscape(name)
  }" ${counts}>\n${tests}\n  </testsuite>\n</testsuites>\n`;
}

if (import.meta.main) {
  try {
    if (Deno.args.length === 1 && Deno.args[0] === "--version") {
      console.log(`tap2junit ${VERSION}`);
    } else if (Deno.args.length === 1 && Deno.args[0] === "--help") {
      console.log("Usage: tap2junit [--name SUITE] < results.tap > junit.xml");
    } else {
      let name = "TAP";
      if (Deno.args.length > 0) {
        if (Deno.args.length !== 2 || Deno.args[0] !== "--name") {
          throw new Error("Usage: tap2junit [--name SUITE]");
        }
        name = Deno.args[1];
      }
      console.log(
        toJunit(parseTap(await new Response(Deno.stdin.readable).text()), name),
      );
    }
  } catch (error) {
    console.error(
      `tap2junit: ${error instanceof Error ? error.message : error}`,
    );
    Deno.exit(2);
  }
}
