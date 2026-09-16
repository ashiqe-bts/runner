// npm install --prefix /tmp/skyway-validation gltf-validator
// SKYWAY_GLTF_VALIDATOR=/tmp/skyway-validation/node_modules/gltf-validator node tool/validate_assets.cjs
const fs = require('node:fs');
const validator = require(process.env.SKYWAY_GLTF_VALIDATOR || 'gltf-validator');
(async () => {
  const reports = [];
  let failures = 0;
  for (const file of fs.readdirSync('assets/native_models').filter(f => f.endsWith('.glb')).sort()) {
    const result = await validator.validateBytes(new Uint8Array(fs.readFileSync(`assets/native_models/${file}`)), {uri: file, maxIssues: 100});
    reports.push({file, issues: result.issues, info: result.info});
    failures += result.issues.numErrors + result.issues.numWarnings;
    console.log(`${file}: ${result.issues.numErrors} errors, ${result.issues.numWarnings} warnings`);
  }
  fs.mkdirSync('docs/validation', {recursive: true});
  fs.writeFileSync('docs/validation/gltf.json', JSON.stringify(reports, null, 2) + '\n');
  process.exitCode = failures ? 1 : 0;
})().catch(error => { console.error(error); process.exitCode = 1; });
