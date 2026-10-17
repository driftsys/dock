const path = require("node:path");
console.log(JSON.stringify({
  runtime: process.versions.deno,
  name: path.basename(process.cwd()),
  args: process.argv.slice(2),
}));
